import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker


# The real connection string is provided via the DATABASE_URL environment
# variable (set in the host dashboard, never committed). The default below is a
# local-development-only placeholder that points at a local Postgres; it
# contains no real credentials.
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg://postgres:postgres@localhost:5432/mymoney_dev",
)

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()