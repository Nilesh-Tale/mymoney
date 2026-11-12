import '../core/api_client.dart';
import '../models/finance_models.dart';

class FinanceService {
  Future<UserProfile> getProfile() async {
    final response = await ApiClient.dio.get('/api/users/me');
    return UserProfile.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<FinanceAccount>> getAccounts() async {
    final response = await ApiClient.dio.get('/api/accounts');
    return (response.data as List)
        .map(
          (item) =>
              FinanceAccount.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<FinanceCategory>> getCategories({String? type}) async {
    final response = await ApiClient.dio.get(
      '/api/categories',
      queryParameters: type == null ? null : {'transaction_type': type},
    );
    return (response.data as List)
        .map(
          (item) =>
              FinanceCategory.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<FinanceTransaction>> getTransactions() async {
    final response = await ApiClient.dio.get('/api/transactions');
    final items = (response.data as List)
        .map(
          (item) => FinanceTransaction.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    items.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    return items;
  }

  Future<FinanceTransaction> createTransaction({
    required int accountId,
    required int categoryId,
    required String type,
    required double amount,
    required String description,
    required DateTime date,
  }) async {
    final response = await ApiClient.dio.post(
      '/api/transactions',
      data: _transactionPayload(
        accountId: accountId,
        categoryId: categoryId,
        type: type,
        amount: amount,
        description: description,
        date: date,
      ),
    );
    return FinanceTransaction.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<FinanceTransaction> updateTransaction({
    required int transactionId,
    required int accountId,
    required int categoryId,
    required String type,
    required double amount,
    required String description,
    required DateTime date,
  }) async {
    final response = await ApiClient.dio.put(
      '/api/transactions/$transactionId',
      data: _transactionPayload(
        accountId: accountId,
        categoryId: categoryId,
        type: type,
        amount: amount,
        description: description,
        date: date,
      ),
    );
    return FinanceTransaction.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> deleteTransaction(int transactionId) async {
    await ApiClient.dio.delete('/api/transactions/$transactionId');
  }

  Map<String, dynamic> _transactionPayload({
    required int accountId,
    required int categoryId,
    required String type,
    required double amount,
    required String description,
    required DateTime date,
  }) {
    final normalizedDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return {
      'account_id': accountId,
      'category_id': categoryId,
      'transaction_type': type,
      'amount': amount,
      'description': description,
      'transaction_date': normalizedDate,
    };
  }

  Future<FinanceAccount> createAccount({
    required String name,
    required String type,
    required double openingBalance,
  }) async {
    final response = await ApiClient.dio.post(
      '/api/accounts',
      data: {
        'name': name,
        'account_type': type,
        'opening_balance': openingBalance,
        'currency': 'INR',
      },
    );
    return FinanceAccount.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<FinanceAccount> updateAccount({
    required int accountId,
    required String name,
    required String type,
    required double openingBalance,
  }) async {
    final response = await ApiClient.dio.put(
      '/api/accounts/$accountId',
      data: {
        'name': name,
        'account_type': type,
        'opening_balance': openingBalance,
      },
    );
    return FinanceAccount.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> deleteAccount(int accountId) async {
    await ApiClient.dio.delete('/api/accounts/$accountId');
  }

  // ---------------------------------------------------------
  // CATEGORIES
  // ---------------------------------------------------------

  Future<FinanceCategory> createCategory({
    required String name,
    required String type,
    String icon = 'category',
    String color = '#7C6CF2',
  }) async {
    final response = await ApiClient.dio.post(
      '/api/categories',
      data: {
        'name': name,
        'transaction_type': type,
        'icon': icon,
        'color': color,
      },
    );
    return FinanceCategory.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> deleteCategory(int categoryId) async {
    await ApiClient.dio.delete('/api/categories/$categoryId');
  }

  // ---------------------------------------------------------
  // BUDGETS
  // ---------------------------------------------------------

  Future<List<BudgetStatus>> getBudgets({int? month, int? year}) async {
    final response = await ApiClient.dio.get(
      '/api/budgets',
      queryParameters: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      },
    );
    return (response.data as List)
        .map(
          (item) =>
              BudgetStatus.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> createBudget({
    required int categoryId,
    required double amount,
    required int month,
    required int year,
  }) async {
    await ApiClient.dio.post(
      '/api/budgets',
      data: {
        'category_id': categoryId,
        'amount': amount,
        'month': month,
        'year': year,
      },
    );
  }

  Future<void> updateBudget({
    required int budgetId,
    required double amount,
  }) async {
    await ApiClient.dio.put(
      '/api/budgets/$budgetId',
      data: {'amount': amount},
    );
  }

  Future<void> deleteBudget(int budgetId) async {
    await ApiClient.dio.delete('/api/budgets/$budgetId');
  }

  // ---------------------------------------------------------
  // SAVINGS GOALS
  // ---------------------------------------------------------

  Future<List<SavingsGoal>> getSavingsGoals() async {
    final response = await ApiClient.dio.get('/api/savings-goals');
    return (response.data as List)
        .map(
          (item) =>
              SavingsGoal.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> createSavingsGoal({
    required String name,
    required double targetAmount,
    required double currentAmount,
    DateTime? targetDate,
  }) async {
    await ApiClient.dio.post(
      '/api/savings-goals',
      data: {
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        if (targetDate != null) 'target_date': _dateString(targetDate),
      },
    );
  }

  Future<void> updateSavingsGoal({
    required int goalId,
    String? name,
    double? targetAmount,
    DateTime? targetDate,
    String? status,
  }) async {
    await ApiClient.dio.put(
      '/api/savings-goals/$goalId',
      data: {
        if (name != null) 'name': name,
        if (targetAmount != null) 'target_amount': targetAmount,
        if (targetDate != null) 'target_date': _dateString(targetDate),
        if (status != null) 'status': status,
      },
    );
  }

  Future<void> contributeToGoal({
    required int goalId,
    required double amount,
  }) async {
    await ApiClient.dio.post(
      '/api/savings-goals/$goalId/contribute',
      data: {'amount': amount},
    );
  }

  Future<void> deleteSavingsGoal(int goalId) async {
    await ApiClient.dio.delete('/api/savings-goals/$goalId');
  }

  // ---------------------------------------------------------
  // RECURRING TRANSACTIONS
  // ---------------------------------------------------------

  Future<List<RecurringTransaction>> getRecurring() async {
    final response = await ApiClient.dio.get('/api/recurring-transactions');
    return (response.data as List)
        .map(
          (item) => RecurringTransaction.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> createRecurring({
    required int accountId,
    required int categoryId,
    required String type,
    required double amount,
    required String description,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    await ApiClient.dio.post(
      '/api/recurring-transactions',
      data: {
        'account_id': accountId,
        'category_id': categoryId,
        'transaction_type': type,
        'amount': amount,
        'description': description,
        'frequency': frequency,
        'start_date': _dateString(startDate),
        if (endDate != null) 'end_date': _dateString(endDate),
      },
    );
  }

  Future<void> toggleRecurring({
    required int recurringId,
    required bool isActive,
  }) async {
    await ApiClient.dio.put(
      '/api/recurring-transactions/$recurringId',
      data: {'is_active': isActive},
    );
  }

  Future<void> postRecurringNow(int recurringId) async {
    await ApiClient.dio.post('/api/recurring-transactions/$recurringId/post');
  }

  Future<void> deleteRecurring(int recurringId) async {
    await ApiClient.dio.delete('/api/recurring-transactions/$recurringId');
  }

  // ---------------------------------------------------------
  // ANALYTICS
  // ---------------------------------------------------------

  Future<AnalyticsSummary> getAnalytics({int months = 6}) async {
    final response = await ApiClient.dio.get(
      '/api/analytics/summary',
      queryParameters: {'months': months},
    );
    return AnalyticsSummary.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
