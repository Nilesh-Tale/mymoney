from datetime import datetime, date
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from database.connection import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    full_name: Mapped[str] = mapped_column(String(150), nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Account(Base):
    __tablename__ = "accounts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    account_type: Mapped[str] = mapped_column(String(30), nullable=False)
    opening_balance: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=0, nullable=False
    )
    currency: Mapped[str] = mapped_column(String(3), default="INR")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Category(Base):
    __tablename__ = "categories"
    __table_args__ = (
        UniqueConstraint("name", "transaction_type", name="uq_category_name_type"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    transaction_type: Mapped[str] = mapped_column(String(20), nullable=False)
    icon: Mapped[str] = mapped_column(String(50), default="category")
    color: Mapped[str] = mapped_column(String(20), default="#7C6CF2")
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"), nullable=False, index=True
    )
    account_id: Mapped[int] = mapped_column(
        ForeignKey("accounts.id"), nullable=False
    )
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.id"), nullable=False
    )
    transaction_type: Mapped[str] = mapped_column(String(20), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    transaction_date: Mapped[date] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Budget(Base):
    __tablename__ = "budgets"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "category_id", "month", "year",
            name="uq_budget_user_category_period",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.id"), nullable=False
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    month: Mapped[int] = mapped_column(Integer, nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False)


class SavingsGoal(Base):
    __tablename__ = "savings_goals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    target_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    current_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=0, nullable=False
    )
    target_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="active")


class RecurringTransaction(Base):
    __tablename__ = "recurring_transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    account_id: Mapped[int] = mapped_column(
        ForeignKey("accounts.id"), nullable=False
    )
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.id"), nullable=False
    )
    transaction_type: Mapped[str] = mapped_column(String(20), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    frequency: Mapped[str] = mapped_column(String(20), nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    next_due_date: Mapped[date] = mapped_column(Date, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class LoginEvent(Base):
    """One row per login attempt — the basis for login history and the
    active-viewers / activity dashboard."""

    __tablename__ = "login_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )
    success: Mapped[bool] = mapped_column(Boolean, nullable=False, index=True)
    ip_address: Mapped[str] = mapped_column(String(64), default="")
    user_agent: Mapped[str] = mapped_column(String(400), default="")
    # Short random id identifying the issued session token (success only).
    # Used to count distinct active viewers without storing the token itself.
    session_id: Mapped[str | None] = mapped_column(
        String(40), nullable=True, index=True
    )


class SessionHeartbeat(Base):
    """Last-seen timestamp per active session, refreshed on each authenticated
    request. Active viewers = distinct sessions seen in the last few minutes."""

    __tablename__ = "session_heartbeats"

    session_id: Mapped[str] = mapped_column(String(40), primary_key=True)
    last_seen: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    ip_address: Mapped[str] = mapped_column(String(64), default="")
    user_agent: Mapped[str] = mapped_column(String(400), default="")
    # When true, this specific session's token is rejected (forced logout).
    revoked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)


class AppSetting(Base):
    """Simple key/value store for app-wide settings, e.g. the global session
    revoke cutoff used by 'log out all other devices'."""

    __tablename__ = "app_settings"

    key: Mapped[str] = mapped_column(String(60), primary_key=True)
    value: Mapped[str] = mapped_column(String(200), default="")
