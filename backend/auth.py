"""Single shared-password authentication.

The whole app is gated behind one password (set via the APP_PASSWORD env var).
A successful login returns a signed JWT; all data routes require that token.

Environment variables:
  ENVIRONMENT   - "production" (default) or "development". In production the
                  app fails CLOSED: it refuses to authenticate unless both
                  APP_PASSWORD and a strong JWT_SECRET are configured.
  APP_PASSWORD  - the shared password required to log in. Required in prod.
  JWT_SECRET    - independent random secret used to sign tokens. Required in
                  prod; must be reasonably long. Never derived from the
                  password.
  JWT_TTL_DAYS  - token lifetime in days (default 30).
"""

import hmac
import os
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from database.connection import get_db

# Settings key used to store the global "log out all devices" cutoff: any token
# with iat < this unix timestamp is rejected.
REVOKE_CUTOFF_KEY = "session_revoke_cutoff"

_ALGORITHM = "HS256"

# Minimum acceptable JWT secret length in production.
_MIN_SECRET_LEN = 16

# Bearer token scheme. auto_error=False so we can return a clean 401 ourselves.
_bearer = HTTPBearer(auto_error=False)


def is_production() -> bool:
    """Default to production so a misconfigured deploy fails CLOSED, not open.
    Only an explicit ENVIRONMENT=development (or =dev/local) relaxes this."""
    env = os.getenv("ENVIRONMENT", "production").strip().lower()
    return env not in ("development", "dev", "local")


def _app_password() -> str | None:
    value = os.getenv("APP_PASSWORD", "").strip()
    return value or None


class _MisconfiguredError(HTTPException):
    """Returned (503) when the server is missing required security config in
    production, so it fails closed instead of silently running insecure."""

    def __init__(self, what: str):
        super().__init__(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Server is not configured securely ({what}). "
            "Set the required environment variables.",
        )


def _jwt_secret() -> str:
    """Return the signing secret.

    SECURITY: the secret is NEVER derived from the password. In production a
    strong JWT_SECRET is mandatory; if it is missing/weak we refuse to operate.
    In development only, a clearly-marked insecure constant is allowed so the
    app runs locally without configuration.
    """
    secret = os.getenv("JWT_SECRET", "").strip()
    if is_production():
        if len(secret) < _MIN_SECRET_LEN:
            raise _MisconfiguredError("JWT_SECRET missing or too short")
        return secret
    # Development fallback only.
    return secret or "insecure-dev-secret-do-not-use-in-production"


def _ttl() -> timedelta:
    try:
        days = int(os.getenv("JWT_TTL_DAYS", "30"))
    except ValueError:
        days = 30
    return timedelta(days=max(1, days))


def verify_password(candidate: str) -> bool:
    """Constant-time comparison of the submitted password against APP_PASSWORD.

    SECURITY: fails CLOSED. If APP_PASSWORD is not configured in production the
    server refuses all logins (503) rather than letting anyone in. Only in
    development is an unset password treated as "open".
    """
    expected = _app_password()
    if expected is None:
        if is_production():
            raise _MisconfiguredError("APP_PASSWORD not set")
        return True  # development convenience only
    return hmac.compare_digest(candidate or "", expected)


# ---------------------------------------------------------
# LOGIN RATE LIMITING (DB-backed, per IP)
# ---------------------------------------------------------
#
# After MAX_FAILURES failed attempts within WINDOW, an IP is locked out for
# LOCKOUT seconds. A successful login clears that IP. State is stored in the
# database so it SURVIVES server restarts (the free host sleeps/restarts often,
# which would otherwise reset an attacker's failure count).

import time as _time

_MAX_FAILURES = int(os.getenv("LOGIN_MAX_FAILURES", "5"))
_WINDOW_SECONDS = int(os.getenv("LOGIN_WINDOW_SECONDS", "900"))      # 15 min
_LOCKOUT_SECONDS = int(os.getenv("LOGIN_LOCKOUT_SECONDS", "900"))    # 15 min


def rate_limit_check(db: Session, ip: str) -> int | None:
    """Return seconds remaining in lockout if the IP is locked, else None."""
    from models.models import LoginThrottle

    now = int(_time.time())
    row = db.get(LoginThrottle, ip)
    if row is None:
        return None
    if row.locked_until and now < row.locked_until:
        return row.locked_until - now + 1
    return None


def record_failure(db: Session, ip: str) -> None:
    from models.models import LoginThrottle

    now = int(_time.time())
    row = db.get(LoginThrottle, ip)
    if row is None:
        row = LoginThrottle(
            ip_address=ip, fail_count=0, window_start=now, locked_until=0
        )
        db.add(row)

    # Reset the counting window if it has elapsed.
    if now - row.window_start > _WINDOW_SECONDS:
        row.window_start = now
        row.fail_count = 0

    row.fail_count += 1
    if row.fail_count >= _MAX_FAILURES:
        row.locked_until = now + _LOCKOUT_SECONDS

    db.commit()


def record_success(db: Session, ip: str) -> None:
    from models.models import LoginThrottle

    row = db.get(LoginThrottle, ip)
    if row is not None:
        db.delete(row)
        db.commit()


def new_session_id() -> str:
    return secrets.token_hex(16)


def create_token(session_id: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": "shared-user",
        "sid": session_id,
        "iat": int(now.timestamp()),
        "exp": int((now + _ttl()).timestamp()),
    }
    return jwt.encode(payload, _jwt_secret(), algorithm=_ALGORITHM)


def _decode(token: str) -> dict:
    return jwt.decode(token, _jwt_secret(), algorithms=[_ALGORITHM])


def _revoke_cutoff(db: Session) -> int:
    # Imported here to avoid a circular import at module load time.
    from models.models import AppSetting

    row = db.get(AppSetting, REVOKE_CUTOFF_KEY)
    if row is None or not row.value:
        return 0
    try:
        return int(row.value)
    except ValueError:
        return 0


def require_auth(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> str | None:
    """FastAPI dependency that rejects requests without a valid token.

    Also enforces session revocation:
      - a global cutoff ("log out all other devices"), and
      - a per-session revoked flag ("log out this device").

    Returns the session id from the token (or None in no-password dev mode) so
    routes can record a heartbeat.
    """
    from models.models import SessionHeartbeat

    # If no password is configured: in dev, skip auth entirely; in production,
    # fail CLOSED (refuse the request) rather than exposing data.
    if _app_password() is None:
        if is_production():
            raise _MisconfiguredError("APP_PASSWORD not set")
        return None

    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        payload = _decode(credentials.credentials)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired. Please log in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    sid = payload.get("sid")
    issued_at = int(payload.get("iat", 0))

    # Global revocation: token issued before the cutoff is dead.
    if issued_at < _revoke_cutoff(db):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session was logged out remotely. Please log in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Per-session revocation.
    if sid:
        hb = db.get(SessionHeartbeat, sid)
        if hb is not None and hb.revoked:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="This device was logged out remotely. Please log in again.",
                headers={"WWW-Authenticate": "Bearer"},
            )

    return sid
