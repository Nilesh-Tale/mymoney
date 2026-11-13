

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from database.connection import engine, get_db, Base, SessionLocal
from models.models import (
    User,
    Account,
    Category,
    Transaction,
    Budget,
    SavingsGoal,
    RecurringTransaction,
    LoginEvent,
    SessionHeartbeat,
    AppSetting,
    LoginThrottle,
)
from routes.api import router, auth_router

from fastapi.middleware.cors import CORSMiddleware

DEFAULT_CATEGORIES = [
    ("Salary", "income", "wallet", "#22A06B"),
    ("Business", "income", "briefcase", "#22A06B"),
    ("Investment", "income", "trending_up", "#22A06B"),
    ("Other Income", "income", "plus_circle", "#22A06B"),

    ("Food", "expense", "restaurant", "#F97316"),
    ("Shopping", "expense", "shopping_bag", "#8B5CF6"),
    ("Transport", "expense", "directions_car", "#3B82F6"),
    ("Housing", "expense", "home", "#EC4899"),
    ("Healthcare", "expense", "medical_services", "#EF4444"),
    ("Entertainment", "expense", "movie", "#A855F7"),
    ("Education", "expense", "school", "#0EA5E9"),
    ("Bills", "expense", "receipt", "#64748B"),
    ("Other Expense", "expense", "category", "#7C6CF2"),
]


def _ensure_session_columns():
    """Lightweight migration: add columns introduced after session_heartbeats
    was first created. create_all() does not ALTER existing tables."""
    statements = [
        "ALTER TABLE session_heartbeats "
        "ADD COLUMN IF NOT EXISTS revoked BOOLEAN NOT NULL DEFAULT FALSE",
        "ALTER TABLE session_heartbeats "
        "ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ DEFAULT now()",
    ]
    with engine.begin() as conn:
        for stmt in statements:
            conn.execute(text(stmt))


def initialize_database():
    Base.metadata.create_all(bind=engine)
    _ensure_session_columns()

    db = SessionLocal()

    try:
        user = db.query(User).filter(User.id == 1).first()

        if not user:
            user = User(
                full_name="Sayali Nilesh",
                email="sayali@example.com",
            )
            db.add(user)
            db.commit()

        for name, transaction_type, icon, color in DEFAULT_CATEGORIES:
            category = db.query(Category).filter(
                Category.name == name,
                Category.transaction_type == transaction_type,
            ).first()

            if not category:
                db.add(
                    Category(
                        name=name,
                        transaction_type=transaction_type,
                        icon=icon,
                        color=color,
                        is_default=True,
                    )
                )

        db.commit()

        print("Database initialized successfully.")

    except Exception:
        db.rollback()
        raise

    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Starting Sayali Nilesh backend...")

    initialize_database()

    yield

    engine.dispose()
    print("Sayali Nilesh backend stopped.")


from auth import is_production

# In production, disable the interactive API docs and the OpenAPI schema so the
# full route/field map is not published to the world. They remain available in
# development for convenience.
_docs_enabled = not is_production()

app = FastAPI(
    title="Sayali Nilesh – Personal Finance Manager",
    description="Personal finance management REST API.",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if _docs_enabled else None,
    redoc_url="/redoc" if _docs_enabled else None,
    openapi_url="/openapi.json" if _docs_enabled else None,
)


@app.middleware("http")
async def security_headers(request, call_next):
    """Add defensive response headers to every response."""
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cross-Origin-Resource-Policy"] = "same-site"
    # This is a JSON API; a strict CSP prevents the responses from being
    # abused as rendered content.
    response.headers["Content-Security-Policy"] = "default-src 'none'"
    if is_production():
        response.headers["Strict-Transport-Security"] = (
            "max-age=31536000; includeSubDomains"
        )
    return response


app.include_router(auth_router)
app.include_router(router)

# CORS configuration.
#
# Localhost (any port) is always allowed for local development. In production,
# set CORS_ALLOW_ORIGINS to a comma-separated list of exact origins that are
# permitted to call this API, e.g.:
#
#   CORS_ALLOW_ORIGINS=https://your-username.github.io
#
# Note: for GitHub Pages, the origin is just the scheme + host
# (https://your-username.github.io) WITHOUT the /repo path.
_extra_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ALLOW_ORIGINS", "").split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_extra_origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {
        "application": "Sayali Nilesh",
        "description": "Personal Finance Manager",
        "status": "running",
    }


@app.get("/api/health")
def health_check():
    return {
        "status": "healthy",
        "application": "Sayali Nilesh",
        "version": "1.0.0",
    }


@app.get("/api/health/db")
def database_health(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))

        return {
            "database": "PostgreSQL",
            "status": "connected",
        }

    except Exception:
        return {
            "database": "PostgreSQL",
            "status": "disconnected",
        }