"""Single shared-password authentication.

The whole app is gated behind one password (set via the APP_PASSWORD env var).
A successful login returns a signed JWT; all data routes require that token.

Environment variables:
  APP_PASSWORD  - the shared password required to log in. If unset, auth is
                  effectively disabled for local development (see note below).
  JWT_SECRET    - secret key used to sign tokens. MUST be set in production.
  JWT_TTL_DAYS  - token lifetime in days (default 30).
"""

import hmac
import os
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

_ALGORITHM = "HS256"

# Bearer token scheme. auto_error=False so we can return a clean 401 ourselves.
_bearer = HTTPBearer(auto_error=False)


def _app_password() -> str | None:
    value = os.getenv("APP_PASSWORD", "").strip()
    return value or None


def _jwt_secret() -> str:
    # Fall back to the password if no dedicated secret is set, so the app still
    # works when only APP_PASSWORD is configured. A dedicated JWT_SECRET is
    # strongly recommended in production.
    secret = os.getenv("JWT_SECRET", "").strip()
    if secret:
        return secret
    password = _app_password()
    if password:
        return f"derived-secret::{password}"
    # Last-resort constant for local dev when nothing is configured.
    return "insecure-dev-secret-change-me"


def _ttl() -> timedelta:
    try:
        days = int(os.getenv("JWT_TTL_DAYS", "30"))
    except ValueError:
        days = 30
    return timedelta(days=max(1, days))


def verify_password(candidate: str) -> bool:
    """Constant-time comparison of the submitted password against APP_PASSWORD.

    If APP_PASSWORD is not set (local dev), any password is accepted so the
    app remains usable without configuration.
    """
    expected = _app_password()
    if expected is None:
        return True
    return hmac.compare_digest(candidate or "", expected)


# ---------------------------------------------------------
# LOGIN RATE LIMITING (in-memory, per IP)
# ---------------------------------------------------------
#
# After MAX_FAILURES failed attempts within WINDOW, an IP is locked out for
# LOCKOUT. A successful login clears that IP's failure record. State is
# in-memory: it resets if the service restarts, which is acceptable for a
# single-instance deployment and fails safe (never locks out legitimately).

import time as _time
from threading import Lock as _Lock

_MAX_FAILURES = int(os.getenv("LOGIN_MAX_FAILURES", "5"))
_WINDOW_SECONDS = int(os.getenv("LOGIN_WINDOW_SECONDS", "900"))      # 15 min
_LOCKOUT_SECONDS = int(os.getenv("LOGIN_LOCKOUT_SECONDS", "900"))    # 15 min

_failures: dict[str, list[float]] = {}
_lockouts: dict[str, float] = {}
_rl_lock = _Lock()


def rate_limit_check(ip: str) -> int | None:
    """Return seconds remaining in lockout if the IP is locked, else None."""
    now = _time.time()
    with _rl_lock:
        until = _lockouts.get(ip)
        if until is not None:
            if now < until:
                return int(until - now) + 1
            # Lockout expired.
            _lockouts.pop(ip, None)
            _failures.pop(ip, None)
    return None


def record_failure(ip: str) -> None:
    now = _time.time()
    with _rl_lock:
        hits = [t for t in _failures.get(ip, []) if now - t < _WINDOW_SECONDS]
        hits.append(now)
        _failures[ip] = hits
        if len(hits) >= _MAX_FAILURES:
            _lockouts[ip] = now + _LOCKOUT_SECONDS


def record_success(ip: str) -> None:
    with _rl_lock:
        _failures.pop(ip, None)
        _lockouts.pop(ip, None)


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


def require_auth(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str | None:
    """FastAPI dependency that rejects requests without a valid token.

    Returns the session id from the token (or None in no-password dev mode) so
    routes can record a heartbeat.
    """
    # If no password is configured (local dev), skip the check entirely.
    if _app_password() is None:
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

    return payload.get("sid")
