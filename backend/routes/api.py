from calendar import monthrange
from datetime import date, timedelta
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from database.connection import get_db
from models.models import (
    User,
    Account,
    Category,
    Transaction,
    Budget,
    SavingsGoal,
    RecurringTransaction,
)
from schemas.schemas import (
    AccountCreate,
    AccountUpdate,
    AccountResponse,
    CategoryCreate,
    CategoryUpdate,
    CategoryResponse,
    TransactionCreate,
    TransactionUpdate,
    TransactionResponse,
    UserResponse,
    BudgetCreate,
    BudgetUpdate,
    BudgetResponse,
    BudgetStatus,
    SavingsGoalCreate,
    SavingsGoalUpdate,
    SavingsGoalResponse,
    SavingsContribution,
    RecurringTransactionCreate,
    RecurringTransactionUpdate,
    RecurringTransactionResponse,
    AnalyticsSummary,
    CategoryBreakdownItem,
    MonthlyTrendItem,
)

router = APIRouter(prefix="/api", tags=["Personal Finance"])

# Initial single-user setup. Authentication will be added in a later stage.
DEFAULT_USER_ID = 1


def get_default_user(db: Session):
    user = db.query(User).filter(User.id == DEFAULT_USER_ID).first()

    if not user:
        raise HTTPException(
            status_code=500,
            detail="Default user is not initialized.",
        )

    return user


def get_owned_account(db: Session, account_id: int):
    account = db.query(Account).filter(
        Account.id == account_id,
        Account.user_id == DEFAULT_USER_ID,
    ).first()

    if not account:
        raise HTTPException(status_code=404, detail="Account not found.")

    return account


def get_category(db: Session, category_id: int):
    category = db.query(Category).filter(
        Category.id == category_id
    ).first()

    if not category:
        raise HTTPException(status_code=404, detail="Category not found.")

    return category


# ---------------------------------------------------------
# USER
# ---------------------------------------------------------

@router.get("/users/me", response_model=UserResponse)
def get_profile(db: Session = Depends(get_db)):
    return get_default_user(db)


# ---------------------------------------------------------
# ACCOUNTS
# ---------------------------------------------------------

@router.post(
    "/accounts",
    response_model=AccountResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_account(
    payload: AccountCreate,
    db: Session = Depends(get_db),
):
    get_default_user(db)

    account = Account(
        user_id=DEFAULT_USER_ID,
        **payload.model_dump(),
    )

    db.add(account)
    db.commit()
    db.refresh(account)

    return account


@router.get("/accounts", response_model=list[AccountResponse])
def get_accounts(db: Session = Depends(get_db)):
    return db.query(Account).filter(
        Account.user_id == DEFAULT_USER_ID
    ).order_by(Account.id.desc()).all()


@router.get("/accounts/{account_id}", response_model=AccountResponse)
def get_account(account_id: int, db: Session = Depends(get_db)):
    return get_owned_account(db, account_id)


@router.put("/accounts/{account_id}", response_model=AccountResponse)
def update_account(
    account_id: int,
    payload: AccountUpdate,
    db: Session = Depends(get_db),
):
    account = get_owned_account(db, account_id)

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(account, key, value)

    db.commit()
    db.refresh(account)

    return account


@router.delete("/accounts/{account_id}")
def delete_account(account_id: int, db: Session = Depends(get_db)):
    account = get_owned_account(db, account_id)

    if db.query(Transaction).filter(
        Transaction.account_id == account_id
    ).first():
        raise HTTPException(
            status_code=409,
            detail="This account has transactions and cannot be deleted.",
        )

    db.delete(account)
    db.commit()

    return {"message": "Account deleted successfully."}


# ---------------------------------------------------------
# CATEGORIES
# ---------------------------------------------------------

@router.post(
    "/categories",
    response_model=CategoryResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_category(
    payload: CategoryCreate,
    db: Session = Depends(get_db),
):
    category = Category(
        **payload.model_dump(),
        is_default=False,
    )

    db.add(category)

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="A category with this name and type may already exist.",
        )

    db.refresh(category)
    return category


@router.get("/categories", response_model=list[CategoryResponse])
def get_categories(
    transaction_type: str | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(Category)

    if transaction_type:
        if transaction_type not in ["income", "expense"]:
            raise HTTPException(
                status_code=400,
                detail="transaction_type must be income or expense.",
            )

        query = query.filter(
            Category.transaction_type == transaction_type
        )

    return query.order_by(Category.name).all()


@router.put("/categories/{category_id}", response_model=CategoryResponse)
def update_category(
    category_id: int,
    payload: CategoryUpdate,
    db: Session = Depends(get_db),
):
    category = get_category(db, category_id)

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(category, key, value)

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Category update conflicts with an existing category.",
        )

    db.refresh(category)
    return category


@router.delete("/categories/{category_id}")
def delete_category(category_id: int, db: Session = Depends(get_db)):
    category = get_category(db, category_id)

    if category.is_default:
        raise HTTPException(
            status_code=403,
            detail="Default categories cannot be deleted.",
        )

    if db.query(Transaction).filter(
        Transaction.category_id == category_id
    ).first():
        raise HTTPException(
            status_code=409,
            detail="Category is used by transactions and cannot be deleted.",
        )

    db.delete(category)
    db.commit()

    return {"message": "Category deleted successfully."}


# ---------------------------------------------------------
# TRANSACTIONS
# ---------------------------------------------------------

@router.post(
    "/transactions",
    response_model=TransactionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_transaction(
    payload: TransactionCreate,
    db: Session = Depends(get_db),
):
    get_default_user(db)
    get_owned_account(db, payload.account_id)

    category = get_category(db, payload.category_id)

    if category.transaction_type != payload.transaction_type:
        raise HTTPException(
            status_code=400,
            detail="Transaction type does not match category type.",
        )

    transaction = Transaction(
        user_id=DEFAULT_USER_ID,
        **payload.model_dump(),
    )

    db.add(transaction)
    db.commit()
    db.refresh(transaction)

    return transaction


@router.get("/transactions", response_model=list[TransactionResponse])
def get_transactions(
    transaction_type: str | None = None,
    account_id: int | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(Transaction).filter(
        Transaction.user_id == DEFAULT_USER_ID
    )

    if transaction_type:
        if transaction_type not in ["income", "expense"]:
            raise HTTPException(
                status_code=400,
                detail="transaction_type must be income or expense.",
            )

        query = query.filter(
            Transaction.transaction_type == transaction_type
        )

    if account_id is not None:
        query = query.filter(Transaction.account_id == account_id)

    return query.order_by(
        Transaction.transaction_date.desc(),
        Transaction.id.desc(),
    ).all()


@router.get(
    "/transactions/{transaction_id}",
    response_model=TransactionResponse,
)
def get_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
):
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == DEFAULT_USER_ID,
    ).first()

    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found.")

    return transaction


@router.put(
    "/transactions/{transaction_id}",
    response_model=TransactionResponse,
)
def update_transaction(
    transaction_id: int,
    payload: TransactionUpdate,
    db: Session = Depends(get_db),
):
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == DEFAULT_USER_ID,
    ).first()

    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found.")

    updates = payload.model_dump(exclude_unset=True)

    account_id = updates.get("account_id", transaction.account_id)
    category_id = updates.get("category_id", transaction.category_id)
    transaction_type = updates.get(
        "transaction_type", transaction.transaction_type
    )

    get_owned_account(db, account_id)
    category = get_category(db, category_id)

    if category.transaction_type != transaction_type:
        raise HTTPException(
            status_code=400,
            detail="Transaction type does not match category type.",
        )

    for key, value in updates.items():
        setattr(transaction, key, value)

    db.commit()
    db.refresh(transaction)

    return transaction


@router.delete("/transactions/{transaction_id}")
def delete_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
):
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == DEFAULT_USER_ID,
    ).first()

    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found.")

    db.delete(transaction)
    db.commit()

    return {"message": "Transaction deleted successfully."}


# ---------------------------------------------------------
# SHARED HELPERS
# ---------------------------------------------------------

def get_owned_savings_goal(db: Session, goal_id: int) -> SavingsGoal:
    goal = db.query(SavingsGoal).filter(
        SavingsGoal.id == goal_id,
        SavingsGoal.user_id == DEFAULT_USER_ID,
    ).first()

    if not goal:
        raise HTTPException(status_code=404, detail="Savings goal not found.")

    return goal


def get_owned_budget(db: Session, budget_id: int) -> Budget:
    budget = db.query(Budget).filter(
        Budget.id == budget_id,
        Budget.user_id == DEFAULT_USER_ID,
    ).first()

    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found.")

    return budget


def get_owned_recurring(db: Session, recurring_id: int) -> RecurringTransaction:
    recurring = db.query(RecurringTransaction).filter(
        RecurringTransaction.id == recurring_id,
        RecurringTransaction.user_id == DEFAULT_USER_ID,
    ).first()

    if not recurring:
        raise HTTPException(
            status_code=404, detail="Recurring transaction not found."
        )

    return recurring


def _advance_date(current: date, frequency: str) -> date:
    if frequency == "daily":
        return current + timedelta(days=1)
    if frequency == "weekly":
        return current + timedelta(weeks=1)
    if frequency == "yearly":
        try:
            return current.replace(year=current.year + 1)
        except ValueError:
            # Handle Feb 29 -> Feb 28
            return current.replace(year=current.year + 1, day=28)
    # monthly (default)
    month = current.month + 1
    year = current.year + (month - 1) // 12
    month = (month - 1) % 12 + 1
    day = min(current.day, monthrange(year, month)[1])
    return date(year, month, day)


def _goal_percent(current: Decimal, target: Decimal) -> float:
    if target <= 0:
        return 0.0
    return round(min(float(current) / float(target) * 100, 100), 2)


def _savings_response(goal: SavingsGoal) -> SavingsGoalResponse:
    return SavingsGoalResponse(
        id=goal.id,
        user_id=goal.user_id,
        name=goal.name,
        target_amount=goal.target_amount,
        current_amount=goal.current_amount,
        target_date=goal.target_date,
        status=goal.status,
        percent_complete=_goal_percent(goal.current_amount, goal.target_amount),
    )


# ---------------------------------------------------------
# BUDGETS
# ---------------------------------------------------------

@router.post(
    "/budgets",
    response_model=BudgetResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_budget(payload: BudgetCreate, db: Session = Depends(get_db)):
    get_default_user(db)

    category = get_category(db, payload.category_id)
    if category.transaction_type != "expense":
        raise HTTPException(
            status_code=400,
            detail="Budgets can only be set for expense categories.",
        )

    budget = Budget(user_id=DEFAULT_USER_ID, **payload.model_dump())
    db.add(budget)

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="A budget for this category and period already exists.",
        )

    db.refresh(budget)
    return budget


@router.get("/budgets", response_model=list[BudgetStatus])
def get_budgets(
    month: int | None = None,
    year: int | None = None,
    db: Session = Depends(get_db),
):
    today = date.today()
    month = month or today.month
    year = year or today.year

    budgets = db.query(Budget).filter(
        Budget.user_id == DEFAULT_USER_ID,
        Budget.month == month,
        Budget.year == year,
    ).all()

    results: list[BudgetStatus] = []

    for budget in budgets:
        category = db.query(Category).filter(
            Category.id == budget.category_id
        ).first()

        spent = db.query(func.coalesce(func.sum(Transaction.amount), 0)).filter(
            Transaction.user_id == DEFAULT_USER_ID,
            Transaction.category_id == budget.category_id,
            Transaction.transaction_type == "expense",
            func.extract("month", Transaction.transaction_date) == month,
            func.extract("year", Transaction.transaction_date) == year,
        ).scalar()

        spent = Decimal(str(spent))
        remaining = budget.amount - spent
        percent = (
            round(float(spent) / float(budget.amount) * 100, 2)
            if budget.amount > 0
            else 0.0
        )

        results.append(
            BudgetStatus(
                id=budget.id,
                category_id=budget.category_id,
                category_name=category.name if category else "Unknown",
                category_color=category.color if category else "#7C6CF2",
                amount=budget.amount,
                month=budget.month,
                year=budget.year,
                spent=spent,
                remaining=remaining,
                percent_used=percent,
            )
        )

    results.sort(key=lambda b: b.percent_used, reverse=True)
    return results


@router.put("/budgets/{budget_id}", response_model=BudgetResponse)
def update_budget(
    budget_id: int,
    payload: BudgetUpdate,
    db: Session = Depends(get_db),
):
    budget = get_owned_budget(db, budget_id)

    updates = payload.model_dump(exclude_unset=True)
    if "category_id" in updates:
        category = get_category(db, updates["category_id"])
        if category.transaction_type != "expense":
            raise HTTPException(
                status_code=400,
                detail="Budgets can only be set for expense categories.",
            )

    for key, value in updates.items():
        setattr(budget, key, value)

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="A budget for this category and period already exists.",
        )

    db.refresh(budget)
    return budget


@router.delete("/budgets/{budget_id}")
def delete_budget(budget_id: int, db: Session = Depends(get_db)):
    budget = get_owned_budget(db, budget_id)
    db.delete(budget)
    db.commit()
    return {"message": "Budget deleted successfully."}


# ---------------------------------------------------------
# SAVINGS GOALS
# ---------------------------------------------------------

@router.post(
    "/savings-goals",
    response_model=SavingsGoalResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_savings_goal(
    payload: SavingsGoalCreate,
    db: Session = Depends(get_db),
):
    get_default_user(db)

    goal = SavingsGoal(user_id=DEFAULT_USER_ID, **payload.model_dump())

    if goal.current_amount >= goal.target_amount:
        goal.status = "completed"

    db.add(goal)
    db.commit()
    db.refresh(goal)
    return _savings_response(goal)


@router.get("/savings-goals", response_model=list[SavingsGoalResponse])
def get_savings_goals(db: Session = Depends(get_db)):
    goals = db.query(SavingsGoal).filter(
        SavingsGoal.user_id == DEFAULT_USER_ID
    ).order_by(SavingsGoal.id.desc()).all()

    return [_savings_response(goal) for goal in goals]


@router.get("/savings-goals/{goal_id}", response_model=SavingsGoalResponse)
def get_savings_goal(goal_id: int, db: Session = Depends(get_db)):
    return _savings_response(get_owned_savings_goal(db, goal_id))


@router.put("/savings-goals/{goal_id}", response_model=SavingsGoalResponse)
def update_savings_goal(
    goal_id: int,
    payload: SavingsGoalUpdate,
    db: Session = Depends(get_db),
):
    goal = get_owned_savings_goal(db, goal_id)

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(goal, key, value)

    if goal.current_amount >= goal.target_amount and goal.status == "active":
        goal.status = "completed"

    db.commit()
    db.refresh(goal)
    return _savings_response(goal)


@router.post(
    "/savings-goals/{goal_id}/contribute",
    response_model=SavingsGoalResponse,
)
def contribute_to_goal(
    goal_id: int,
    payload: SavingsContribution,
    db: Session = Depends(get_db),
):
    goal = get_owned_savings_goal(db, goal_id)

    goal.current_amount = goal.current_amount + payload.amount

    if goal.current_amount >= goal.target_amount:
        goal.status = "completed"

    db.commit()
    db.refresh(goal)
    return _savings_response(goal)


@router.delete("/savings-goals/{goal_id}")
def delete_savings_goal(goal_id: int, db: Session = Depends(get_db)):
    goal = get_owned_savings_goal(db, goal_id)
    db.delete(goal)
    db.commit()
    return {"message": "Savings goal deleted successfully."}


# ---------------------------------------------------------
# RECURRING TRANSACTIONS
# ---------------------------------------------------------

@router.post(
    "/recurring-transactions",
    response_model=RecurringTransactionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_recurring(
    payload: RecurringTransactionCreate,
    db: Session = Depends(get_db),
):
    get_default_user(db)
    get_owned_account(db, payload.account_id)

    category = get_category(db, payload.category_id)
    if category.transaction_type != payload.transaction_type:
        raise HTTPException(
            status_code=400,
            detail="Transaction type does not match category type.",
        )

    if payload.end_date and payload.end_date < payload.start_date:
        raise HTTPException(
            status_code=400,
            detail="End date cannot be before the start date.",
        )

    recurring = RecurringTransaction(
        user_id=DEFAULT_USER_ID,
        next_due_date=payload.start_date,
        **payload.model_dump(),
    )

    db.add(recurring)
    db.commit()
    db.refresh(recurring)
    return recurring


@router.get(
    "/recurring-transactions",
    response_model=list[RecurringTransactionResponse],
)
def get_recurring(
    is_active: bool | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(RecurringTransaction).filter(
        RecurringTransaction.user_id == DEFAULT_USER_ID
    )

    if is_active is not None:
        query = query.filter(RecurringTransaction.is_active == is_active)

    return query.order_by(RecurringTransaction.next_due_date).all()


@router.put(
    "/recurring-transactions/{recurring_id}",
    response_model=RecurringTransactionResponse,
)
def update_recurring(
    recurring_id: int,
    payload: RecurringTransactionUpdate,
    db: Session = Depends(get_db),
):
    recurring = get_owned_recurring(db, recurring_id)
    updates = payload.model_dump(exclude_unset=True)

    account_id = updates.get("account_id", recurring.account_id)
    category_id = updates.get("category_id", recurring.category_id)
    transaction_type = updates.get(
        "transaction_type", recurring.transaction_type
    )

    get_owned_account(db, account_id)
    category = get_category(db, category_id)

    if category.transaction_type != transaction_type:
        raise HTTPException(
            status_code=400,
            detail="Transaction type does not match category type.",
        )

    for key, value in updates.items():
        setattr(recurring, key, value)

    db.commit()
    db.refresh(recurring)
    return recurring


@router.post(
    "/recurring-transactions/{recurring_id}/post",
    response_model=TransactionResponse,
    status_code=status.HTTP_201_CREATED,
)
def post_recurring_now(recurring_id: int, db: Session = Depends(get_db)):
    """Materialize a recurring template into a real transaction and advance
    its next due date."""
    recurring = get_owned_recurring(db, recurring_id)

    if not recurring.is_active:
        raise HTTPException(
            status_code=400,
            detail="This recurring transaction is not active.",
        )

    transaction = Transaction(
        user_id=DEFAULT_USER_ID,
        account_id=recurring.account_id,
        category_id=recurring.category_id,
        transaction_type=recurring.transaction_type,
        amount=recurring.amount,
        description=recurring.description,
        transaction_date=recurring.next_due_date,
    )
    db.add(transaction)

    recurring.next_due_date = _advance_date(
        recurring.next_due_date, recurring.frequency
    )

    if recurring.end_date and recurring.next_due_date > recurring.end_date:
        recurring.is_active = False

    db.commit()
    db.refresh(transaction)
    return transaction


@router.delete("/recurring-transactions/{recurring_id}")
def delete_recurring(recurring_id: int, db: Session = Depends(get_db)):
    recurring = get_owned_recurring(db, recurring_id)
    db.delete(recurring)
    db.commit()
    return {"message": "Recurring transaction deleted successfully."}


# ---------------------------------------------------------
# ANALYTICS
# ---------------------------------------------------------

def _category_breakdown(
    db: Session,
    transaction_type: str,
    start: date | None,
    end: date | None,
) -> list[CategoryBreakdownItem]:
    query = db.query(
        Transaction.category_id,
        func.sum(Transaction.amount).label("total"),
    ).filter(
        Transaction.user_id == DEFAULT_USER_ID,
        Transaction.transaction_type == transaction_type,
    )

    if start:
        query = query.filter(Transaction.transaction_date >= start)
    if end:
        query = query.filter(Transaction.transaction_date <= end)

    rows = query.group_by(Transaction.category_id).all()

    grand_total = sum(Decimal(str(row.total)) for row in rows)
    if grand_total <= 0:
        return []

    categories = {
        c.id: c for c in db.query(Category).all()
    }

    items: list[CategoryBreakdownItem] = []
    for category_id, total in rows:
        total = Decimal(str(total))
        category = categories.get(category_id)
        items.append(
            CategoryBreakdownItem(
                category_id=category_id,
                category_name=category.name if category else "Unknown",
                category_color=category.color if category else "#7C6CF2",
                total=total,
                percent=round(float(total) / float(grand_total) * 100, 2),
            )
        )

    items.sort(key=lambda i: i.total, reverse=True)
    return items


@router.get("/analytics/summary", response_model=AnalyticsSummary)
def analytics_summary(
    months: int = 6,
    db: Session = Depends(get_db),
):
    get_default_user(db)

    months = max(1, min(months, 24))

    today = date.today()
    # Start of the window: first day of the month `months - 1` ago.
    start_year = today.year
    start_month = today.month - (months - 1)
    while start_month <= 0:
        start_month += 12
        start_year -= 1
    window_start = date(start_year, start_month, 1)

    all_txns = db.query(Transaction).filter(
        Transaction.user_id == DEFAULT_USER_ID,
        Transaction.transaction_date >= window_start,
    ).all()

    total_income = Decimal("0")
    total_expense = Decimal("0")
    income_count = 0
    expense_count = 0

    for t in all_txns:
        if t.transaction_type == "income":
            total_income += t.amount
            income_count += 1
        else:
            total_expense += t.amount
            expense_count += 1

    avg_income = (
        total_income / income_count if income_count else Decimal("0")
    )
    avg_expense = (
        total_expense / expense_count if expense_count else Decimal("0")
    )

    # Monthly trend
    buckets: dict[tuple[int, int], dict[str, Decimal]] = {}
    cursor_year, cursor_month = start_year, start_month
    for _ in range(months):
        buckets[(cursor_year, cursor_month)] = {
            "income": Decimal("0"),
            "expense": Decimal("0"),
        }
        cursor_month += 1
        if cursor_month > 12:
            cursor_month = 1
            cursor_year += 1

    for t in all_txns:
        key = (t.transaction_date.year, t.transaction_date.month)
        if key in buckets:
            if t.transaction_type == "income":
                buckets[key]["income"] += t.amount
            else:
                buckets[key]["expense"] += t.amount

    month_labels = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]
    monthly_trend = [
        MonthlyTrendItem(
            year=year,
            month=month,
            label=month_labels[month - 1],
            income=values["income"],
            expense=values["expense"],
            net=values["income"] - values["expense"],
        )
        for (year, month), values in buckets.items()
    ]

    return AnalyticsSummary(
        total_income=total_income,
        total_expense=total_expense,
        net_balance=total_income - total_expense,
        transaction_count=len(all_txns),
        avg_income=avg_income,
        avg_expense=avg_expense,
        top_expense_categories=_category_breakdown(
            db, "expense", window_start, today
        ),
        top_income_categories=_category_breakdown(
            db, "income", window_start, today
        ),
        monthly_trend=monthly_trend,
    )
