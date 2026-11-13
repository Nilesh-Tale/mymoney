import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/api_client.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

final financeServiceProvider = Provider<FinanceService>(
  (ref) => FinanceService(),
);

/// Whether the user currently holds a token. The UI watches this to decide
/// between the login screen and the app. Seeded from any persisted token.
final authStateProvider = StateProvider<bool>(
  (ref) => ApiClient.isAuthenticated,
);

final accountsProvider = FutureProvider<List<FinanceAccount>>(
  (ref) => ref.watch(financeServiceProvider).getAccounts(),
);
final categoriesProvider = FutureProvider<List<FinanceCategory>>(
  (ref) => ref.watch(financeServiceProvider).getCategories(),
);
final transactionsProvider = FutureProvider<List<FinanceTransaction>>(
  (ref) => ref.watch(financeServiceProvider).getTransactions(),
);

final incomeCategoriesProvider = FutureProvider<List<FinanceCategory>>(
  (ref) => ref.watch(financeServiceProvider).getCategories(type: 'income'),
);
final expenseCategoriesProvider = FutureProvider<List<FinanceCategory>>(
  (ref) => ref.watch(financeServiceProvider).getCategories(type: 'expense'),
);

/// Selected period for the budgets view, as (month, year).
final budgetPeriodProvider = StateProvider<({int month, int year})>((ref) {
  final now = DateTime.now();
  return (month: now.month, year: now.year);
});

final budgetsProvider = FutureProvider<List<BudgetStatus>>((ref) {
  final period = ref.watch(budgetPeriodProvider);
  return ref
      .watch(financeServiceProvider)
      .getBudgets(month: period.month, year: period.year);
});

final savingsGoalsProvider = FutureProvider<List<SavingsGoal>>(
  (ref) => ref.watch(financeServiceProvider).getSavingsGoals(),
);

final recurringProvider = FutureProvider<List<RecurringTransaction>>(
  (ref) => ref.watch(financeServiceProvider).getRecurring(),
);

/// Number of months to include in the analytics window.
final analyticsMonthsProvider = StateProvider<int>((ref) => 6);

final analyticsProvider = FutureProvider<AnalyticsSummary>((ref) {
  final months = ref.watch(analyticsMonthsProvider);
  return ref.watch(financeServiceProvider).getAnalytics(months: months);
});

final profileProvider = FutureProvider(
  (ref) => ref.watch(financeServiceProvider).getProfile(),
);

final activitySummaryProvider = FutureProvider<ActivitySummary>(
  (ref) => ref.watch(financeServiceProvider).getActivitySummary(),
);

final loginHistoryProvider = FutureProvider<List<LoginEvent>>(
  (ref) => ref.watch(financeServiceProvider).getLoginHistory(limit: 100),
);
