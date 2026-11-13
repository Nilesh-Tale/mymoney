class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
  });

  final int id;
  final String fullName;
  final String email;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: (json['id'] as num).toInt(),
    fullName: json['full_name']?.toString() ?? 'User',
    email: json['email']?.toString() ?? '',
  );
}

class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.name,
    required this.accountType,
    required this.openingBalance,
    required this.currency,
  });

  final int id;
  final String name;
  final String accountType;
  final double openingBalance;
  final String currency;

  factory FinanceAccount.fromJson(Map<String, dynamic> json) => FinanceAccount(
    id: (json['id'] as num).toInt(),
    name: json['name']?.toString() ?? 'Account',
    accountType: json['account_type']?.toString() ?? 'other',
    openingBalance: _number(json['opening_balance']),
    currency: json['currency']?.toString() ?? 'INR',
  );
}

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.transactionType,
    required this.icon,
    required this.color,
  });

  final int id;
  final String name;
  final String transactionType;
  final String icon;
  final String color;

  factory FinanceCategory.fromJson(Map<String, dynamic> json) =>
      FinanceCategory(
        id: (json['id'] as num).toInt(),
        name: json['name']?.toString() ?? 'Other',
        transactionType: json['transaction_type']?.toString() ?? 'expense',
        icon: json['icon']?.toString() ?? 'category',
        color: json['color']?.toString() ?? '#635BDB',
      );
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.transactionType,
    required this.amount,
    required this.description,
    required this.transactionDate,
  });

  final int id;
  final int accountId;
  final int categoryId;
  final String transactionType;
  final double amount;
  final String description;
  final DateTime transactionDate;

  bool get isIncome => transactionType == 'income';

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) =>
      FinanceTransaction(
        id: (json['id'] as num).toInt(),
        accountId: (json['account_id'] as num).toInt(),
        categoryId: (json['category_id'] as num).toInt(),
        transactionType: json['transaction_type']?.toString() ?? 'expense',
        amount: _number(json['amount']),
        description: json['description']?.toString() ?? '',
        transactionDate:
            DateTime.tryParse(json['transaction_date']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class BudgetStatus {
  const BudgetStatus({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.amount,
    required this.month,
    required this.year,
    required this.spent,
    required this.remaining,
    required this.percentUsed,
  });

  final int id;
  final int categoryId;
  final String categoryName;
  final String categoryColor;
  final double amount;
  final int month;
  final int year;
  final double spent;
  final double remaining;
  final double percentUsed;

  bool get isOverBudget => spent > amount;

  factory BudgetStatus.fromJson(Map<String, dynamic> json) => BudgetStatus(
    id: (json['id'] as num).toInt(),
    categoryId: (json['category_id'] as num).toInt(),
    categoryName: json['category_name']?.toString() ?? 'Unknown',
    categoryColor: json['category_color']?.toString() ?? '#7C6CF2',
    amount: _number(json['amount']),
    month: (json['month'] as num).toInt(),
    year: (json['year'] as num).toInt(),
    spent: _number(json['spent']),
    remaining: _number(json['remaining']),
    percentUsed: _number(json['percent_used']),
  );
}

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.status,
    required this.percentComplete,
  });

  final int id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String status;
  final double percentComplete;

  bool get isCompleted => status == 'completed';

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
    id: (json['id'] as num).toInt(),
    name: json['name']?.toString() ?? 'Goal',
    targetAmount: _number(json['target_amount']),
    currentAmount: _number(json['current_amount']),
    targetDate: json['target_date'] == null
        ? null
        : DateTime.tryParse(json['target_date'].toString()),
    status: json['status']?.toString() ?? 'active',
    percentComplete: _number(json['percent_complete']),
  );
}

class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.transactionType,
    required this.amount,
    required this.description,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.nextDueDate,
    required this.isActive,
  });

  final int id;
  final int accountId;
  final int categoryId;
  final String transactionType;
  final double amount;
  final String description;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextDueDate;
  final bool isActive;

  bool get isIncome => transactionType == 'income';

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) =>
      RecurringTransaction(
        id: (json['id'] as num).toInt(),
        accountId: (json['account_id'] as num).toInt(),
        categoryId: (json['category_id'] as num).toInt(),
        transactionType: json['transaction_type']?.toString() ?? 'expense',
        amount: _number(json['amount']),
        description: json['description']?.toString() ?? '',
        frequency: json['frequency']?.toString() ?? 'monthly',
        startDate:
            DateTime.tryParse(json['start_date']?.toString() ?? '') ??
            DateTime.now(),
        endDate: json['end_date'] == null
            ? null
            : DateTime.tryParse(json['end_date'].toString()),
        nextDueDate:
            DateTime.tryParse(json['next_due_date']?.toString() ?? '') ??
            DateTime.now(),
        isActive: json['is_active'] == true,
      );
}

class CategoryBreakdown {
  const CategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.total,
    required this.percent,
  });

  final int categoryId;
  final String categoryName;
  final String categoryColor;
  final double total;
  final double percent;

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) =>
      CategoryBreakdown(
        categoryId: (json['category_id'] as num).toInt(),
        categoryName: json['category_name']?.toString() ?? 'Unknown',
        categoryColor: json['category_color']?.toString() ?? '#7C6CF2',
        total: _number(json['total']),
        percent: _number(json['percent']),
      );
}

class MonthlyTrend {
  const MonthlyTrend({
    required this.year,
    required this.month,
    required this.label,
    required this.income,
    required this.expense,
    required this.net,
  });

  final int year;
  final int month;
  final String label;
  final double income;
  final double expense;
  final double net;

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) => MonthlyTrend(
    year: (json['year'] as num).toInt(),
    month: (json['month'] as num).toInt(),
    label: json['label']?.toString() ?? '',
    income: _number(json['income']),
    expense: _number(json['expense']),
    net: _number(json['net']),
  );
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.transactionCount,
    required this.avgIncome,
    required this.avgExpense,
    required this.topExpenseCategories,
    required this.topIncomeCategories,
    required this.monthlyTrend,
  });

  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final int transactionCount;
  final double avgIncome;
  final double avgExpense;
  final List<CategoryBreakdown> topExpenseCategories;
  final List<CategoryBreakdown> topIncomeCategories;
  final List<MonthlyTrend> monthlyTrend;

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    List<CategoryBreakdown> breakdown(dynamic raw) => (raw as List? ?? [])
        .map(
          (e) => CategoryBreakdown.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return AnalyticsSummary(
      totalIncome: _number(json['total_income']),
      totalExpense: _number(json['total_expense']),
      netBalance: _number(json['net_balance']),
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      avgIncome: _number(json['avg_income']),
      avgExpense: _number(json['avg_expense']),
      topExpenseCategories: breakdown(json['top_expense_categories']),
      topIncomeCategories: breakdown(json['top_income_categories']),
      monthlyTrend: (json['monthly_trend'] as List? ?? [])
          .map(
            (e) => MonthlyTrend.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
}

class ActivitySummary {
  const ActivitySummary({
    required this.activeViewers,
    required this.totalLogins,
    required this.successfulLogins,
    required this.failedLogins,
    required this.lastLoginAt,
    required this.recentFailed24h,
  });

  final int activeViewers;
  final int totalLogins;
  final int successfulLogins;
  final int failedLogins;
  final DateTime? lastLoginAt;
  final int recentFailed24h;

  factory ActivitySummary.fromJson(Map<String, dynamic> json) =>
      ActivitySummary(
        activeViewers: (json['active_viewers'] as num?)?.toInt() ?? 0,
        totalLogins: (json['total_logins'] as num?)?.toInt() ?? 0,
        successfulLogins: (json['successful_logins'] as num?)?.toInt() ?? 0,
        failedLogins: (json['failed_logins'] as num?)?.toInt() ?? 0,
        lastLoginAt: json['last_login_at'] == null
            ? null
            : DateTime.tryParse(json['last_login_at'].toString()),
        recentFailed24h: (json['recent_failed_24h'] as num?)?.toInt() ?? 0,
      );
}

class LoginEvent {
  const LoginEvent({
    required this.id,
    required this.createdAt,
    required this.success,
    required this.ipAddress,
    required this.userAgent,
  });

  final int id;
  final DateTime createdAt;
  final bool success;
  final String ipAddress;
  final String userAgent;

  factory LoginEvent.fromJson(Map<String, dynamic> json) => LoginEvent(
    id: (json['id'] as num).toInt(),
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
    success: json['success'] == true,
    ipAddress: json['ip_address']?.toString() ?? '',
    userAgent: json['user_agent']?.toString() ?? '',
  );

  /// A short, human-friendly device/browser label derived from the user-agent.
  String get device {
    final ua = userAgent.toLowerCase();
    String os = 'Unknown';
    if (ua.contains('android')) {
      os = 'Android';
    } else if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ios')) {
      os = 'iOS';
    } else if (ua.contains('windows')) {
      os = 'Windows';
    } else if (ua.contains('mac os') || ua.contains('macintosh')) {
      os = 'macOS';
    } else if (ua.contains('linux')) {
      os = 'Linux';
    } else if (ua.contains('curl')) {
      os = 'curl';
    }
    String browser = '';
    if (ua.contains('edg/')) {
      browser = 'Edge';
    } else if (ua.contains('chrome')) {
      browser = 'Chrome';
    } else if (ua.contains('firefox')) {
      browser = 'Firefox';
    } else if (ua.contains('safari')) {
      browser = 'Safari';
    }
    return browser.isEmpty ? os : '$browser · $os';
  }
}

class ActiveSession {
  const ActiveSession({
    required this.sessionId,
    required this.startedAt,
    required this.lastSeen,
    required this.ipAddress,
    required this.userAgent,
    required this.isCurrent,
  });

  final String sessionId;
  final DateTime startedAt;
  final DateTime lastSeen;
  final String ipAddress;
  final String userAgent;
  final bool isCurrent;

  factory ActiveSession.fromJson(Map<String, dynamic> json) => ActiveSession(
    sessionId: json['session_id']?.toString() ?? '',
    startedAt:
        DateTime.tryParse(json['started_at']?.toString() ?? '') ??
        DateTime.now(),
    lastSeen:
        DateTime.tryParse(json['last_seen']?.toString() ?? '') ??
        DateTime.now(),
    ipAddress: json['ip_address']?.toString() ?? '',
    userAgent: json['user_agent']?.toString() ?? '',
    isCurrent: json['is_current'] == true,
  );

  /// Reuse the same user-agent parsing as LoginEvent.
  String get device => LoginEvent(
    id: 0,
    createdAt: lastSeen,
    success: true,
    ipAddress: ipAddress,
    userAgent: userAgent,
  ).device;
}

double _number(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
