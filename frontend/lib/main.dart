import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'core/api_client.dart';
import 'models/finance_models.dart';
import 'providers/finance_providers.dart';
import 'screens/feature_screens.dart';
import 'screens/login_screen.dart';
import 'screens/transaction_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore any saved session so the user stays logged in across reloads.
  await ApiClient.loadToken();
  runApp(const ProviderScope(child: SayaliNileshApp()));
}

class SayaliNileshApp extends ConsumerWidget {
  const SayaliNileshApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When the server rejects the token (expired/invalid), drop auth state so
    // the app returns to the login screen.
    ApiClient.onUnauthorized = () {
      ref.read(authStateProvider.notifier).state = false;
    };

    final loggedIn = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Sayali Nilesh – Personal Finance Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: loggedIn ? const MainDashboard() : const LoginScreen(),
    );
  }
}

class AppColors {
  static const primary = Color(0xFF635BDB);
  static const background = Color(0xFFF7F8FC);
  static const text = Color(0xFF20213A);
  static const secondaryText = Color(0xFF9294A5);
  static const green = Color(0xFF23B58A);
  static const red = Color(0xFFEF6B78);
  static const border = Color(0xFFEDEEF4);
  static const purpleLight = Color(0xFFF0EEFF);
}

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});
  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  int selectedIndex = 0;
  final currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  final menuItems = const [
    'Dashboard',
    'Transactions',
    'Income',
    'Expenses',
    'Budgets',
    'Savings Goals',
    'Recurring',
    'Accounts',
    'Analytics',
    'Activity',
    'Settings',
  ];
  final menuIcons = const [
    Icons.grid_view_rounded,
    Icons.receipt_long_rounded,
    Icons.trending_up_rounded,
    Icons.trending_down_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.savings_rounded,
    Icons.autorenew_rounded,
    Icons.account_balance_rounded,
    Icons.bar_chart_rounded,
    Icons.shield_outlined,
    Icons.settings_rounded,
  ];

  Future<void> refreshData() async {
    ref.invalidate(accountsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(transactionsProvider);
    await Future.wait([
      ref.read(accountsProvider.future),
      ref.read(categoriesProvider.future),
      ref.read(transactionsProvider.future),
    ]);
  }

  Future<void> openAddTransaction(
    List<FinanceAccount> accounts,
    List<FinanceCategory> categories,
  ) async {
    if (accounts.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => const AddAccountDialog(),
      );
      ref.invalidate(accountsProvider);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) =>
          AddTransactionDialog(accounts: accounts, categories: categories),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 850;
    return Scaffold(
      drawer: isMobile
          ? Drawer(
              backgroundColor: Colors.white,
              child: SafeArea(child: buildSidebar()),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile) buildSidebar(),
          Expanded(
            child: Column(
              children: [
                buildTopBar(isMobile),
                Expanded(child: buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSidebar() => Container(
    width: 250,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(25, 28, 20, 35),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sayali Nilesh',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 27, bottom: 13),
          child: Text(
            'MAIN MENU',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: menuItems.length,
            itemBuilder: (context, index) {
              final selected = selectedIndex == index;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 3,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() => selectedIndex = index);
                    if (MediaQuery.sizeOf(context).width < 850 &&
                        Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.purpleLight
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          menuIcons[index],
                          size: 19,
                          color: selected
                              ? AppColors.primary
                              : AppColors.secondaryText,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            menuItems[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.text,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F6FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.primary,
                size: 23,
              ),
              SizedBox(height: 10),
              Text(
                'Smart Money Tip',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Track your expenses regularly to improve your savings.',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget buildTopBar(bool isMobile) => Container(
    height: 78,
    padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 30),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        if (isMobile)
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        Expanded(
          child: Text(
            menuItems[selectedIndex],
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        if (!isMobile)
          Container(
            width: 230,
            height: 39,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: AppColors.secondaryText,
                  size: 19,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Search anything...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: 8),
        const CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.purpleLight,
          child: Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Log out',
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, color: AppColors.text),
        ),
      ],
    ),
  );

  Future<void> _logout() async {
    await ref.read(financeServiceProvider).logout();
    // Clear any cached data so the next login starts fresh.
    ref.invalidate(accountsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(transactionsProvider);
    ref.read(authStateProvider.notifier).state = false;
  }

  Widget buildBody() {
    switch (selectedIndex) {
      case 0:
        return buildDashboard();
      case 1:
        return const TransactionManagementScreen();
      case 2:
        return const IncomeExpenseScreen(isIncome: true);
      case 3:
        return const IncomeExpenseScreen(isIncome: false);
      case 4:
        return const BudgetsScreen();
      case 5:
        return const SavingsGoalsScreen();
      case 6:
        return const RecurringScreen();
      case 7:
        return const AccountsScreen();
      case 8:
        return const AnalyticsScreen();
      case 9:
        return const ActivityScreen();
      case 10:
        return const SettingsScreen();
      default:
        return buildDashboard();
    }
  }

  Widget buildDashboard() {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    return RefreshIndicator(
      onRefresh: refreshData,
      child: transactionsAsync.when(
        loading: () => ListView(
          children: const [
            SizedBox(height: 260),
            Center(child: CircularProgressIndicator()),
            Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Loading your financial data...'),
              ),
            ),
          ],
        ),
        error: (error, _) => ListView(
          children: [
            const SizedBox(height: 100),
            _ErrorPanel(
              message: ApiClient.errorMessage(error),
              onRetry: refreshData,
            ),
          ],
        ),
        data: (transactions) => accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 100),
              _ErrorPanel(
                message: ApiClient.errorMessage(error),
                onRetry: refreshData,
              ),
            ],
          ),
          data: (accounts) => categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ListView(
              children: [
                const SizedBox(height: 100),
                _ErrorPanel(
                  message: ApiClient.errorMessage(error),
                  onRetry: refreshData,
                ),
              ],
            ),
            data: (categories) =>
                _dashboardContent(accounts, categories, transactions),
          ),
        ),
      ),
    );
  }

  Widget _dashboardContent(
    List<FinanceAccount> accounts,
    List<FinanceCategory> categories,
    List<FinanceTransaction> transactions,
  ) {
    final income = transactions
        .where((t) => t.isIncome)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final expenses = transactions
        .where((t) => !t.isIncome)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final opening = accounts.fold<double>(
      0,
      (sum, a) => sum + a.openingBalance,
    );
    final balance = opening + income - expenses;
    final mobile = MediaQuery.sizeOf(context).width < 650;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(mobile ? 16 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: mobile ? 21 : 25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Here is your financial overview.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => openAddTransaction(accounts, categories),
                icon: const Icon(Icons.add, size: 18),
                label: Text(mobile ? 'Add' : 'Add Transaction'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 14,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 27),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth < 650
                  ? 1
                  : constraints.maxWidth < 1050
                  ? 2
                  : 4;
              final cards = [
                _SummaryData(
                  'Total Balance',
                  balance,
                  Icons.account_balance_wallet_rounded,
                  AppColors.primary,
                  'Opening balance + net transactions',
                ),
                _SummaryData(
                  'Total Income',
                  income,
                  Icons.trending_up_rounded,
                  AppColors.green,
                  'Money received',
                ),
                _SummaryData(
                  'Total Expenses',
                  expenses,
                  Icons.trending_down_rounded,
                  AppColors.red,
                  'Money spent',
                ),
                _SummaryData(
                  'Accounts',
                  accounts.length.toDouble(),
                  Icons.account_balance_rounded,
                  const Color(0xFFEFAC4B),
                  'Connected financial accounts',
                  isCount: true,
                ),
              ];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 145,
                ),
                itemBuilder: (_, i) => _summaryCard(cards[i]),
              );
            },
          ),
          const SizedBox(height: 25),
          _charts(transactions, categories),
          const SizedBox(height: 25),
          _transactionsTable(transactions, accounts, categories, mobile),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _summaryCard(_SummaryData data) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .025),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data.title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: data.color, size: 19),
            ),
          ],
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            data.isCount
                ? data.amount.toInt().toString()
                : currency.format(data.amount),
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          data.change,
          style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
        ),
      ],
    ),
  );

  Widget _charts(
    List<FinanceTransaction> transactions,
    List<FinanceCategory> categories,
  ) {
    final expenses = transactions.where((t) => !t.isIncome).toList();
    final totals = <int, double>{};
    for (final item in expenses) {
      totals[item.categoryId] = (totals[item.categoryId] ?? 0) + item.amount;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final palette = [
      AppColors.primary,
      AppColors.green,
      const Color(0xFFEFAC4B),
      AppColors.red,
      const Color(0xFF62A6D8),
      const Color(0xFF9B7CE8),
    ];
    final totalExpense = expenses.fold<double>(0, (sum, t) => sum + t.amount);
    final categoryNames = {for (final c in categories) c.id: c.name};
    final categoryWidget = Container(
      height: 320,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense Categories',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Spending distribution from saved transactions',
            style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
          ),
          Expanded(
            child: expenses.isEmpty
                ? const Center(
                    child: Text(
                      'No expenses recorded yet',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 32,
                            sectionsSpace: 3,
                            sections: sorted
                                .asMap()
                                .entries
                                .map(
                                  (entry) => PieChartSectionData(
                                    value: entry.value.value,
                                    color: palette[entry.key % palette.length],
                                    radius: 25,
                                    showTitle: false,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          shrinkWrap: true,
                          children: sorted.take(5).toList().asMap().entries.map(
                            (entry) {
                              final percent = totalExpense == 0
                                  ? 0
                                  : entry.value.value / totalExpense * 100;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color:
                                            palette[entry.key % palette.length],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        categoryNames[entry.value.key] ??
                                            'Other',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${percent.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ).toList(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
    final monthly = _monthlyTotals(transactions);
    final maxY = monthly.fold<double>(
      0,
      (m, e) => [m, e.$2, e.$3].reduce((a, b) => a > b ? a : b),
    );
    final chart = Container(
      height: 320,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Income vs Expenses',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Monthly financial comparison',
            style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _legend(AppColors.primary, 'Income'),
              const SizedBox(width: 18),
              _legend(AppColors.green, 'Expenses'),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY <= 0 ? 100 : maxY * 1.2,
                barGroups: List.generate(
                  6,
                  (i) => BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: monthly[i].$2,
                        color: AppColors.primary,
                        width: 9,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                      BarChartRodData(
                        toY: monthly[i].$3,
                        color: AppColors.green,
                        width: 9,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (v, _) => Text(
                        _compactAmount(v),
                        style: const TextStyle(
                          fontSize: 8,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        return i < 0 || i >= 6
                            ? const SizedBox()
                            : Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Text(
                                  monthly[i].$1,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 850
          ? Column(
              children: [chart, const SizedBox(height: 18), categoryWidget],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: chart),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: categoryWidget),
              ],
            ),
    );
  }

  List<(String, double, double)> _monthlyTotals(
    List<FinanceTransaction> transactions,
  ) {
    final now = DateTime.now();
    return List.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index, 1);
      double income = 0, expense = 0;
      for (final t in transactions) {
        if (t.transactionDate.year == month.year &&
            t.transactionDate.month == month.month) {
          if (t.isIncome) {
            income += t.amount;
          } else {
            expense += t.amount;
          }
        }
      }
      return (DateFormat('MMM').format(month), income, expense);
    });
  }

  String _compactAmount(double value) => value >= 100000
      ? '${(value / 100000).toStringAsFixed(1)}L'
      : value >= 1000
      ? '${(value / 1000).toStringAsFixed(0)}k'
      : value.toStringAsFixed(0);
  Widget _legend(Color color, String label) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
      ),
    ],
  );

  Widget _transactionsTable(
    List<FinanceTransaction> transactions,
    List<FinanceAccount> accounts,
    List<FinanceCategory> categories,
    bool mobile,
  ) {
    final accountNames = {for (final a in accounts) a.id: a.name};
    final categoryNames = {for (final c in categories) c.id: c.name};
    final recent = transactions.take(8).toList();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => selectedIndex = 1),
                child: const Text(
                  'View All',
                  style: TextStyle(color: AppColors.primary, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(25),
              child: Center(
                child: Text(
                  'No transactions yet. Add your first income or expense.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            )
          else if (mobile)
            ...recent.map(
              (t) => _mobileTransaction(t, accountNames, categoryNames),
            )
          else ...[
            const Divider(color: AppColors.border),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _TableHeader('TRANSACTION')),
                  Expanded(flex: 2, child: _TableHeader('CATEGORY')),
                  Expanded(flex: 2, child: _TableHeader('ACCOUNT')),
                  Expanded(flex: 2, child: _TableHeader('DATE')),
                  Expanded(flex: 2, child: _TableHeader('AMOUNT')),
                ],
              ),
            ),
            const Divider(color: AppColors.border),
            ...recent.map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor:
                                (t.isIncome ? AppColors.green : AppColors.red)
                                    .withValues(alpha: .1),
                            child: Icon(
                              t.isIncome
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                              color: t.isIncome
                                  ? AppColors.green
                                  : AppColors.red,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              t.description,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        categoryNames[t.categoryId] ?? 'Other',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        accountNames[t.accountId] ?? 'Account',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat('dd MMM yyyy').format(t.transactionDate),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${t.isIncome ? '+' : '-'}${currency.format(t.amount)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: t.isIncome ? AppColors.green : AppColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mobileTransaction(
    FinanceTransaction t,
    Map<int, String> accounts,
    Map<int, String> categories,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: (t.isIncome ? AppColors.green : AppColors.red)
          .withValues(alpha: .1),
      child: Icon(
        t.isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
        color: t.isIncome ? AppColors.green : AppColors.red,
        size: 17,
      ),
    ),
    title: Text(
      t.description,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      '${categories[t.categoryId] ?? 'Other'} • ${accounts[t.accountId] ?? 'Account'} • ${DateFormat('dd MMM').format(t.transactionDate)}',
      style: const TextStyle(fontSize: 10),
    ),
    trailing: Text(
      '${t.isIncome ? '+' : '-'}${currency.format(t.amount)}',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: t.isIncome ? AppColors.green : AppColors.red,
      ),
    ),
  );

}

class _SummaryData {
  const _SummaryData(
    this.title,
    this.amount,
    this.icon,
    this.color,
    this.change, {
    this.isCount = false,
  });
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final String change;
  final bool isCount;
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      color: AppColors.secondaryText,
      letterSpacing: .5,
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.red),
          const SizedBox(height: 12),
          const Text(
            'Unable to load financial data',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class AddTransactionDialog extends ConsumerStatefulWidget {
  const AddTransactionDialog({
    super.key,
    required this.accounts,
    required this.categories,
  });
  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;
  @override
  ConsumerState<AddTransactionDialog> createState() =>
      _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<AddTransactionDialog> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  bool isIncome = false;
  bool saving = false;
  int? categoryId;
  int? accountId;
  DateTime date = DateTime.now();
  List<FinanceCategory> get availableCategories => widget.categories
      .where((c) => c.transactionType == (isIncome ? 'income' : 'expense'))
      .toList();
  @override
  void initState() {
    super.initState();
    accountId = widget.accounts.first.id;
    final list = availableCategories;
    categoryId = list.isEmpty ? null : list.first.id;
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  InputDecoration decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 19),
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
  );

  Future<void> save() async {
    if (!formKey.currentState!.validate() ||
        categoryId == null ||
        accountId == null) {
      return;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(financeServiceProvider)
          .createTransaction(
            accountId: accountId!,
            categoryId: categoryId!,
            type: isIncome ? 'income' : 'expense',
            amount: double.parse(amountController.text.trim()),
            description: titleController.text.trim(),
            date: date,
          );
      ref.invalidate(transactionsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved successfully')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.errorMessage(error)),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add Transaction',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _typeButton('Expense', false)),
                  const SizedBox(width: 10),
                  Expanded(child: _typeButton('Income', true)),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: titleController,
                decoration: decoration('Transaction Name', Icons.edit_rounded),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter a transaction name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: decoration(
                  'Amount (₹)',
                  Icons.currency_rupee_rounded,
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return n == null || !n.isFinite || n <= 0
                      ? 'Enter a valid positive amount'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: categoryId,
                decoration: decoration('Category', Icons.category_rounded),
                items: availableCategories
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => categoryId = v),
                validator: (v) => v == null ? 'Select a category' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: accountId,
                decoration: decoration(
                  'Payment Account',
                  Icons.account_balance_rounded,
                ),
                items: widget.accounts
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => accountId = v),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) setState(() => date = picked);
                      },
                icon: const Icon(Icons.calendar_today_rounded, size: 17),
                label: Text(DateFormat('dd MMM yyyy').format(date)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: saving ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Transaction',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _typeButton(String label, bool income) {
    final selected = isIncome == income;
    return InkWell(
      onTap: saving
          ? null
          : () => setState(() {
              isIncome = income;
              final list = availableCategories;
              categoryId = list.isEmpty ? null : list.first.id;
            }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.purpleLight : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selected ? AppColors.primary : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class AddAccountDialog extends ConsumerStatefulWidget {
  const AddAccountDialog({super.key});
  @override
  ConsumerState<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<AddAccountDialog> {
  final name = TextEditingController();
  final balance = TextEditingController(text: '0');
  String type = 'bank';
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add your first account'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Account name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'Account type'),
            items: const [
              DropdownMenuItem(value: 'bank', child: Text('Bank')),
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
              DropdownMenuItem(
                value: 'credit_card',
                child: Text('Credit Card'),
              ),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => type = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Opening balance (₹)'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                final amount = double.tryParse(balance.text) ?? -1;
                if (name.text.trim().isEmpty || amount < 0) return;
                setState(() => saving = true);
                try {
                  await ref
                      .read(financeServiceProvider)
                      .createAccount(
                        name: name.text.trim(),
                        type: type,
                        openingBalance: amount,
                      );
                  ref.invalidate(accountsProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Account created. Tap Add Transaction again.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiClient.errorMessage(e))),
                    );
                  }
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
        child: saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save account'),
      ),
    ],
  );
}
