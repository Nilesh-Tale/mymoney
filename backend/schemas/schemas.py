from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


TransactionType = Literal["income", "expense"]


class UserResponse(BaseModel):
    id: int
    full_name: str
    email: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class LoginRequest(BaseModel):
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class LoginEventResponse(BaseModel):
    id: int
    created_at: datetime
    success: bool
    ip_address: str
    user_agent: str

    model_config = ConfigDict(from_attributes=True)


class ActivitySummary(BaseModel):
    active_viewers: int
    total_logins: int
    successful_logins: int
    failed_logins: int
    last_login_at: datetime | None
    recent_failed_24h: int


class AccountCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    account_type: Literal["bank", "cash", "wallet", "credit_card", "other"]
    opening_balance: Decimal = Field(default=Decimal("0"), ge=0)
    currency: str = Field(default="INR", min_length=3, max_length=3)


class AccountUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    account_type: Literal[
        "bank", "cash", "wallet", "credit_card", "other"
    ] | None = None
    opening_balance: Decimal | None = Field(default=None, ge=0)
    currency: str | None = Field(default=None, min_length=3, max_length=3)


class AccountResponse(AccountCreate):
    id: int
    user_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    transaction_type: TransactionType
    icon: str = "category"
    color: str = "#7C6CF2"


class CategoryUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    transaction_type: TransactionType | None = None
    icon: str | None = None
    color: str | None = None


class CategoryResponse(CategoryCreate):
    id: int
    is_default: bool

    model_config = ConfigDict(from_attributes=True)


class TransactionCreate(BaseModel):
    account_id: int
    category_id: int
    transaction_type: TransactionType
    amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    description: str = ""
    transaction_date: date


class TransactionUpdate(BaseModel):
    account_id: int | None = None
    category_id: int | None = None
    transaction_type: TransactionType | None = None
    amount: Decimal | None = Field(
        default=None, gt=0, max_digits=14, decimal_places=2
    )
    description: str | None = None
    transaction_date: date | None = None


class TransactionResponse(TransactionCreate):
    id: int
    user_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------
# BUDGETS
# ---------------------------------------------------------

class BudgetCreate(BaseModel):
    category_id: int
    amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    month: int = Field(ge=1, le=12)
    year: int = Field(ge=2000, le=2100)


class BudgetUpdate(BaseModel):
    category_id: int | None = None
    amount: Decimal | None = Field(
        default=None, gt=0, max_digits=14, decimal_places=2
    )
    month: int | None = Field(default=None, ge=1, le=12)
    year: int | None = Field(default=None, ge=2000, le=2100)


class BudgetResponse(BudgetCreate):
    id: int
    user_id: int

    model_config = ConfigDict(from_attributes=True)


class BudgetStatus(BaseModel):
    """A budget enriched with its live spending progress."""

    id: int
    category_id: int
    category_name: str
    category_color: str
    amount: Decimal
    month: int
    year: int
    spent: Decimal
    remaining: Decimal
    percent_used: float


# ---------------------------------------------------------
# SAVINGS GOALS
# ---------------------------------------------------------

class SavingsGoalCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    target_amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    current_amount: Decimal = Field(
        default=Decimal("0"), ge=0, max_digits=14, decimal_places=2
    )
    target_date: date | None = None


class SavingsGoalUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=150)
    target_amount: Decimal | None = Field(
        default=None, gt=0, max_digits=14, decimal_places=2
    )
    current_amount: Decimal | None = Field(
        default=None, ge=0, max_digits=14, decimal_places=2
    )
    target_date: date | None = None
    status: Literal["active", "completed", "paused"] | None = None


class SavingsContribution(BaseModel):
    amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)


class SavingsGoalResponse(BaseModel):
    id: int
    user_id: int
    name: str
    target_amount: Decimal
    current_amount: Decimal
    target_date: date | None
    status: str
    percent_complete: float

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------
# RECURRING TRANSACTIONS
# ---------------------------------------------------------

Frequency = Literal["daily", "weekly", "monthly", "yearly"]


class RecurringTransactionCreate(BaseModel):
    account_id: int
    category_id: int
    transaction_type: TransactionType
    amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    description: str = ""
    frequency: Frequency
    start_date: date
    end_date: date | None = None


class RecurringTransactionUpdate(BaseModel):
    account_id: int | None = None
    category_id: int | None = None
    transaction_type: TransactionType | None = None
    amount: Decimal | None = Field(
        default=None, gt=0, max_digits=14, decimal_places=2
    )
    description: str | None = None
    frequency: Frequency | None = None
    start_date: date | None = None
    end_date: date | None = None
    is_active: bool | None = None


class RecurringTransactionResponse(BaseModel):
    id: int
    user_id: int
    account_id: int
    category_id: int
    transaction_type: TransactionType
    amount: Decimal
    description: str
    frequency: str
    start_date: date
    end_date: date | None
    next_due_date: date
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------
# ANALYTICS
# ---------------------------------------------------------

class CategoryBreakdownItem(BaseModel):
    category_id: int
    category_name: str
    category_color: str
    total: Decimal
    percent: float


class MonthlyTrendItem(BaseModel):
    year: int
    month: int
    label: str
    income: Decimal
    expense: Decimal
    net: Decimal


class AnalyticsSummary(BaseModel):
    total_income: Decimal
    total_expense: Decimal
    net_balance: Decimal
    transaction_count: int
    avg_income: Decimal
    avg_expense: Decimal
    top_expense_categories: list[CategoryBreakdownItem]
    top_income_categories: list[CategoryBreakdownItem]
    monthly_trend: list[MonthlyTrendItem]
