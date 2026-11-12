import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/finance_models.dart';
import '../providers/finance_providers.dart';

// ---------------------------------------------------------
// SHARED STYLING + HELPERS
// ---------------------------------------------------------

class AppTheme {
  static const primary = Color(0xFF635BDB);
  static const background = Color(0xFFF7F8FC);
  static const text = Color(0xFF20213A);
  static const muted = Color(0xFF9294A5);
  static const green = Color(0xFF23B58A);
  static const red = Color(0xFFEF6B78);
  static const amber = Color(0xFFEFAC4B);
  static const border = Color(0xFFEDEEF4);
  static const lavender = Color(0xFFF0EEFF);
}

final currencyFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

final compactCurrency = NumberFormat.compactCurrency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 1,
);

Color parseHexColor(String hex, {Color fallback = AppTheme.primary}) {
  var value = hex.replaceAll('#', '').trim();
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

BoxDecoration cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(15),
  border: Border.all(color: AppTheme.border),
);

InputDecoration fieldDecoration(String label, [IconData? icon]) =>
    InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 19),
      filled: true,
      fillColor: AppTheme.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );

void showMessage(BuildContext context, String text, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppTheme.red : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ],
        );
        if (action == null) return titleBlock;
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [titleBlock, const SizedBox(height: 14), action!],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: titleBlock), action!],
              );
      },
    );
  }
}

Widget primaryButton({
  required String label,
  required VoidCallback? onPressed,
  IconData icon = Icons.add_rounded,
}) {
  return FilledButton.icon(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
    icon: Icon(icon, size: 19),
    label: Text(label),
  );
}

class AsyncStatePanel extends StatelessWidget {
  const AsyncStatePanel({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: AppTheme.red),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(30),
    decoration: cardDecoration(),
    child: Column(
      children: [
        Icon(icon, size: 42, color: AppTheme.muted),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

/// Generic scaffold that wraps a feature page body in a refreshable,
/// scrollable, padded container with the shared background.
class FeatureScaffold extends StatelessWidget {
  const FeatureScaffold({
    super.key,
    required this.onRefresh,
    required this.children,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: children,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// ACCOUNTS PAGE
// ---------------------------------------------------------

const _accountTypeLabels = {
  'bank': 'Bank',
  'cash': 'Cash',
  'wallet': 'Wallet',
  'credit_card': 'Credit Card',
  'other': 'Other',
};

const _accountTypeIcons = {
  'bank': Icons.account_balance_rounded,
  'cash': Icons.payments_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'credit_card': Icons.credit_card_rounded,
  'other': Icons.category_rounded,
};

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(accountsProvider);
    ref.invalidate(transactionsProvider);
    await ref.read(accountsProvider.future);
  }

  double _balanceFor(
    FinanceAccount account,
    List<FinanceTransaction> transactions,
  ) {
    final net = transactions
        .where((t) => t.accountId == account.id)
        .fold<double>(0, (sum, t) => sum + (t.isIncome ? t.amount : -t.amount));
    return account.openingBalance + net;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return accountsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => AsyncStatePanel(
        title: 'Unable to load accounts',
        message: ApiClient.errorMessage(e),
        onRetry: () => _refresh(ref),
      ),
      data: (accounts) {
        final transactions = transactionsAsync.value ?? [];
        final totalBalance = accounts.fold<double>(
          0,
          (sum, a) => sum + _balanceFor(a, transactions),
        );
        return FeatureScaffold(
          onRefresh: () => _refresh(ref),
          children: [
            PageHeader(
              title: 'Accounts',
              subtitle: 'Manage your bank, cash and wallet accounts.',
              action: primaryButton(
                label: 'Add Account',
                onPressed: () => _openEditor(context, ref),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF8B7FF0)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      currencyFormat.format(totalBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${accounts.length} account${accounts.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (accounts.isEmpty)
              const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No accounts yet',
                message: 'Add your first account to start tracking money.',
              )
            else
              ...accounts.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _accountTile(
                    context,
                    ref,
                    a,
                    _balanceFor(a, transactions),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _accountTile(
    BuildContext context,
    WidgetRef ref,
    FinanceAccount account,
    double balance,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppTheme.lavender,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _accountTypeIcons[account.accountType] ?? Icons.category_rounded,
              color: AppTheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_accountTypeLabels[account.accountType] ?? 'Other'} • Opening ${currencyFormat.format(account.openingBalance)}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormat.format(balance),
                style: TextStyle(
                  color: balance < 0 ? AppTheme.red : AppTheme.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _openEditor(context, ref, account: account),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _delete(context, ref, account),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppTheme.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    FinanceAccount? account,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AccountEditorDialog(account: account),
    );
    if (saved == true) {
      ref.invalidate(accountsProvider);
      if (context.mounted) {
        showMessage(
          context,
          account == null ? 'Account created.' : 'Account updated.',
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FinanceAccount account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete account?'),
        content: Text('"${account.name}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(financeServiceProvider).deleteAccount(account.id);
      ref.invalidate(accountsProvider);
      if (context.mounted) showMessage(context, 'Account deleted.');
    } catch (e) {
      if (context.mounted) {
        showMessage(context, ApiClient.errorMessage(e), isError: true);
      }
    }
  }
}

class _AccountEditorDialog extends ConsumerStatefulWidget {
  const _AccountEditorDialog({this.account});
  final FinanceAccount? account;

  @override
  ConsumerState<_AccountEditorDialog> createState() =>
      _AccountEditorDialogState();
}

class _AccountEditorDialogState extends ConsumerState<_AccountEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late String _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _balance = TextEditingController(
      text: a == null ? '0' : a.openingBalance.toStringAsFixed(2),
    );
    _type = a?.accountType ?? 'bank';
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(financeServiceProvider);
      final amount = double.parse(_balance.text.trim());
      if (widget.account == null) {
        await service.createAccount(
          name: _name.text.trim(),
          type: _type,
          openingBalance: amount,
        );
      } else {
        await service.updateAccount(
          accountId: widget.account!.id,
          name: _name.text.trim(),
          type: _type,
          openingBalance: amount,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, ApiClient.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.account == null ? 'Add Account' : 'Edit Account',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  decoration: fieldDecoration('Account name', Icons.edit_rounded),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: fieldDecoration('Type', Icons.category_rounded),
                  items: _accountTypeLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _type = v ?? 'bank'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _balance,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: fieldDecoration(
                    'Opening balance (₹)',
                    Icons.currency_rupee_rounded,
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || n < 0 ? 'Enter a valid amount' : null;
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// INCOME / EXPENSES PAGES
// ---------------------------------------------------------

class IncomeExpenseScreen extends ConsumerWidget {
  const IncomeExpenseScreen({super.key, required this.isIncome});

  final bool isIncome;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(transactionsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(accountsProvider);
    await ref.read(transactionsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = isIncome ? AppTheme.green : AppTheme.red;
    final transactionsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountsProvider).value ?? [];
    final categoryNames = {for (final c in categories) c.id: c.name};
    final accountNames = {for (final a in accounts) a.id: a.name};

    return transactionsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => AsyncStatePanel(
        title: 'Unable to load data',
        message: ApiClient.errorMessage(e),
        onRetry: () => _refresh(ref),
      ),
      data: (all) {
        final items = all.where((t) => t.isIncome == isIncome).toList()
          ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
        final total = items.fold<double>(0, (sum, t) => sum + t.amount);

        // Breakdown by category for the mini insight bar.
        final byCategory = <int, double>{};
        for (final t in items) {
          byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amount;
        }
        final sorted = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return FeatureScaffold(
          onRefresh: () => _refresh(ref),
          children: [
            PageHeader(
              title: isIncome ? 'Income' : 'Expenses',
              subtitle: isIncome
                  ? 'All money coming in, grouped and totalled.'
                  : 'All money going out, grouped and totalled.',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: cardDecoration(),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isIncome
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total ${isIncome ? 'Income' : 'Expenses'}',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            currencyFormat.format(total),
                            style: TextStyle(
                              color: accent,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${items.length} entries',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (sorted.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'By category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...sorted.take(6).map((entry) {
                      final percent = total == 0 ? 0.0 : entry.value / total;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    categoryNames[entry.key] ?? 'Other',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(entry.value),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: percent,
                                minHeight: 7,
                                backgroundColor: AppTheme.background,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (items.isEmpty)
              EmptyState(
                icon: isIncome
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                title: 'No ${isIncome ? 'income' : 'expenses'} yet',
                message:
                    'Add a transaction from the Dashboard or Transactions page.',
              )
            else
              ...items.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    decoration: cardDecoration(),
                    child: Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isIncome
                                ? Icons.south_west_rounded
                                : Icons.north_east_rounded,
                            color: accent,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.description.isEmpty
                                    ? 'Untitled'
                                    : t.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${categoryNames[t.categoryId] ?? 'Other'} • ${accountNames[t.accountId] ?? 'Account'} • ${DateFormat('dd MMM yyyy').format(t.transactionDate)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isIncome ? '+' : '−'}${currencyFormat.format(t.amount)}',
                          style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------
// BUDGETS PAGE
// ---------------------------------------------------------

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(budgetsProvider);
    await ref.read(budgetsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(budgetPeriodProvider);
    final budgetsAsync = ref.watch(budgetsProvider);

    return budgetsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => AsyncStatePanel(
        title: 'Unable to load budgets',
        message: ApiClient.errorMessage(e),
        onRetry: () => _refresh(ref),
      ),
      data: (budgets) {
        final totalBudget = budgets.fold<double>(0, (s, b) => s + b.amount);
        final totalSpent = budgets.fold<double>(0, (s, b) => s + b.spent);
        return FeatureScaffold(
          onRefresh: () => _refresh(ref),
          children: [
            PageHeader(
              title: 'Budgets',
              subtitle: 'Set monthly spending limits and track progress.',
              action: primaryButton(
                label: 'Add Budget',
                onPressed: () => _openEditor(context, ref),
              ),
            ),
            const SizedBox(height: 18),
            _periodSelector(ref, period),
            const SizedBox(height: 16),
            if (budgets.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: Row(
                  children: [
                    _overviewStat('Budgeted', totalBudget, AppTheme.primary),
                    _divider(),
                    _overviewStat('Spent', totalSpent, AppTheme.red),
                    _divider(),
                    _overviewStat(
                      'Remaining',
                      totalBudget - totalSpent,
                      AppTheme.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (budgets.isEmpty)
              const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No budgets for this period',
                message: 'Add a budget for an expense category to track it.',
              )
            else
              ...budgets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _budgetCard(context, ref, b),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 38,
    color: AppTheme.border,
    margin: const EdgeInsets.symmetric(horizontal: 6),
  );

  Widget _overviewStat(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFormat.format(value),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodSelector(WidgetRef ref, ({int month, int year}) period) {
    void shift(int delta) {
      var m = period.month + delta;
      var y = period.year;
      if (m < 1) {
        m = 12;
        y--;
      } else if (m > 12) {
        m = 1;
        y++;
      }
      ref.read(budgetPeriodProvider.notifier).state = (month: m, year: y);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: cardDecoration(),
      child: Row(
        children: [
          IconButton(
            onPressed: () => shift(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_monthNames[period.month - 1]} ${period.year}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => shift(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _budgetCard(BuildContext context, WidgetRef ref, BudgetStatus b) {
    final color = parseHexColor(b.categoryColor);
    final ratio = b.amount == 0 ? 0.0 : (b.spent / b.amount).clamp(0.0, 1.0);
    final barColor = b.isOverBudget
        ? AppTheme.red
        : (b.percentUsed >= 80 ? AppTheme.amber : color);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.pie_chart_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  b.categoryName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _openEditor(context, ref, budget: b),
                icon: const Icon(Icons.edit_outlined, size: 16),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _delete(context, ref, b),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: AppTheme.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              backgroundColor: AppTheme.background,
              color: barColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${currencyFormat.format(b.spent)} of ${currencyFormat.format(b.amount)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ),
              Text(
                b.isOverBudget
                    ? 'Over by ${currencyFormat.format(b.spent - b.amount)}'
                    : '${currencyFormat.format(b.remaining)} left',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: b.isOverBudget ? AppTheme.red : AppTheme.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    BudgetStatus? budget,
  }) async {
    final period = ref.read(budgetPeriodProvider);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BudgetEditorDialog(
        budget: budget,
        month: period.month,
        year: period.year,
      ),
    );
    if (saved == true) {
      ref.invalidate(budgetsProvider);
      if (context.mounted) {
        showMessage(context, budget == null ? 'Budget added.' : 'Budget updated.');
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BudgetStatus b,
  ) async {
    try {
      await ref.read(financeServiceProvider).deleteBudget(b.id);
      ref.invalidate(budgetsProvider);
      if (context.mounted) showMessage(context, 'Budget deleted.');
    } catch (e) {
      if (context.mounted) {
        showMessage(context, ApiClient.errorMessage(e), isError: true);
      }
    }
  }
}

class _BudgetEditorDialog extends ConsumerStatefulWidget {
  const _BudgetEditorDialog({
    this.budget,
    required this.month,
    required this.year,
  });

  final BudgetStatus? budget;
  final int month;
  final int year;

  @override
  ConsumerState<_BudgetEditorDialog> createState() =>
      _BudgetEditorDialogState();
}

class _BudgetEditorDialogState extends ConsumerState<_BudgetEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.budget == null ? '' : widget.budget!.amount.toStringAsFixed(2),
    );
    _categoryId = widget.budget?.categoryId;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.budget == null && _categoryId == null) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(financeServiceProvider);
      final amount = double.parse(_amount.text.trim());
      if (widget.budget == null) {
        await service.createBudget(
          categoryId: _categoryId!,
          amount: amount,
          month: widget.month,
          year: widget.year,
        );
      } else {
        await service.updateBudget(budgetId: widget.budget!.id, amount: amount);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, ApiClient.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.budget != null;
    final expenseCats = ref.watch(expenseCategoriesProvider).value ?? [];
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing ? 'Edit Budget' : 'Add Budget',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_monthNames[widget.month - 1]} ${widget.year}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const SizedBox(height: 18),
                if (editing)
                  TextFormField(
                    initialValue: widget.budget!.categoryName,
                    enabled: false,
                    decoration:
                        fieldDecoration('Category', Icons.category_rounded),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration:
                        fieldDecoration('Expense category', Icons.category_rounded),
                    items: expenseCats
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) => v == null ? 'Select a category' : null,
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: fieldDecoration(
                    'Monthly limit (₹)',
                    Icons.currency_rupee_rounded,
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || n <= 0 ? 'Enter a valid amount' : null;
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SAVINGS GOALS PAGE
// ---------------------------------------------------------

class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(savingsGoalsProvider);
    await ref.read(savingsGoalsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsProvider);
    return goalsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => AsyncStatePanel(
        title: 'Unable to load goals',
        message: ApiClient.errorMessage(e),
        onRetry: () => _refresh(ref),
      ),
      data: (goals) {
        final totalSaved = goals.fold<double>(0, (s, g) => s + g.currentAmount);
        final totalTarget = goals.fold<double>(0, (s, g) => s + g.targetAmount);
        return FeatureScaffold(
          onRefresh: () => _refresh(ref),
          children: [
            PageHeader(
              title: 'Savings Goals',
              subtitle: 'Set targets and track how close you are.',
              action: primaryButton(
                label: 'Add Goal',
                onPressed: () => _openEditor(context, ref),
              ),
            ),
            const SizedBox(height: 18),
            if (goals.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total saved',
                            style:
                                TextStyle(fontSize: 11, color: AppTheme.muted),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            currencyFormat.format(totalSaved),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'of ${currencyFormat.format(totalTarget)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (goals.isEmpty)
              const EmptyState(
                icon: Icons.savings_outlined,
                title: 'No savings goals yet',
                message: 'Create a goal like an emergency fund or a trip.',
              )
            else
              ...goals.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _goalCard(context, ref, g),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _goalCard(BuildContext context, WidgetRef ref, SavingsGoal g) {
    final ratio = (g.percentComplete / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: AppTheme.lavender,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  g.isCompleted
                      ? Icons.emoji_events_rounded
                      : Icons.savings_rounded,
                  color: g.isCompleted ? AppTheme.amber : AppTheme.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                    if (g.targetDate != null)
                      Text(
                        'Target: ${DateFormat('dd MMM yyyy').format(g.targetDate!)}',
                        style:
                            const TextStyle(fontSize: 10, color: AppTheme.muted),
                      ),
                  ],
                ),
              ),
              if (g.isCompleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.green,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 19),
                onSelected: (value) {
                  if (value == 'delete') _delete(context, ref, g);
                  if (value == 'edit') _openEditor(context, ref, goal: g);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              backgroundColor: AppTheme.background,
              color: g.isCompleted ? AppTheme.green : AppTheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${currencyFormat.format(g.currentAmount)} of ${currencyFormat.format(g.targetAmount)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ),
              Text(
                '${g.percentComplete.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
          if (!g.isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _contribute(context, ref, g),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Add contribution'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _contribute(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal g,
  ) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Contribute to "${g.name}"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: fieldDecoration('Amount (₹)', Icons.currency_rupee_rounded),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              final n = double.tryParse(controller.text.trim());
              if (n != null && n > 0) Navigator.pop(dialogContext, n);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (amount == null) return;
    try {
      await ref
          .read(financeServiceProvider)
          .contributeToGoal(goalId: g.id, amount: amount);
      ref.invalidate(savingsGoalsProvider);
      if (context.mounted) showMessage(context, 'Contribution added.');
    } catch (e) {
      if (context.mounted) {
        showMessage(context, ApiClient.errorMessage(e), isError: true);
      }
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    SavingsGoal? goal,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SavingsGoalEditorDialog(goal: goal),
    );
    if (saved == true) {
      ref.invalidate(savingsGoalsProvider);
      if (context.mounted) {
        showMessage(context, goal == null ? 'Goal created.' : 'Goal updated.');
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal g,
  ) async {
    try {
      await ref.read(financeServiceProvider).deleteSavingsGoal(g.id);
      ref.invalidate(savingsGoalsProvider);
      if (context.mounted) showMessage(context, 'Goal deleted.');
    } catch (e) {
      if (context.mounted) {
        showMessage(context, ApiClient.errorMessage(e), isError: true);
      }
    }
  }
}

class _SavingsGoalEditorDialog extends ConsumerStatefulWidget {
  const _SavingsGoalEditorDialog({this.goal});
  final SavingsGoal? goal;

  @override
  ConsumerState<_SavingsGoalEditorDialog> createState() =>
      _SavingsGoalEditorDialogState();
}

class _SavingsGoalEditorDialogState
    extends ConsumerState<_SavingsGoalEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _current;
  DateTime? _targetDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _name = TextEditingController(text: g?.name ?? '');
    _target = TextEditingController(
      text: g == null ? '' : g.targetAmount.toStringAsFixed(2),
    );
    _current = TextEditingController(
      text: g == null ? '0' : g.currentAmount.toStringAsFixed(2),
    );
    _targetDate = g?.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _current.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(financeServiceProvider);
      if (widget.goal == null) {
        await service.createSavingsGoal(
          name: _name.text.trim(),
          targetAmount: double.parse(_target.text.trim()),
          currentAmount: double.parse(_current.text.trim()),
          targetDate: _targetDate,
        );
      } else {
        await service.updateSavingsGoal(
          goalId: widget.goal!.id,
          name: _name.text.trim(),
          targetAmount: double.parse(_target.text.trim()),
          targetDate: _targetDate,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, ApiClient.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.goal != null;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing ? 'Edit Goal' : 'Add Savings Goal',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  decoration: fieldDecoration('Goal name', Icons.flag_rounded),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _target,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: fieldDecoration(
                    'Target amount (₹)',
                    Icons.flag_circle_rounded,
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || n <= 0 ? 'Enter a valid amount' : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _current,
                  enabled: !editing,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: fieldDecoration(
                    editing ? 'Current (use contribute)' : 'Starting amount (₹)',
                    Icons.savings_rounded,
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '0');
                    return n == null || n < 0 ? 'Enter a valid amount' : null;
                  },
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _targetDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _targetDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 17),
                  label: Text(
                    _targetDate == null
                        ? 'Target date (optional)'
                        : DateFormat('dd MMM yyyy').format(_targetDate!),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// ANALYTICS PAGE
// ---------------------------------------------------------

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(analyticsProvider);
    await ref.read(analyticsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(analyticsMonthsProvider);
    final analyticsAsync = ref.watch(analyticsProvider);

    return analyticsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => AsyncStatePanel(
        title: 'Unable to load analytics',
        message: ApiClient.errorMessage(e),
        onRetry: () => _refresh(ref),
      ),
      data: (data) => FeatureScaffold(
        onRefresh: () => _refresh(ref),
        children: [
          PageHeader(
            title: 'Analytics',
            subtitle: 'Your income and spending analysis.',
          ),
          const SizedBox(height: 16),
          _rangeSelector(ref, months),
          const SizedBox(height: 16),
          _statGrid(data),
          const SizedBox(height: 16),
          _trendChart(data),
          const SizedBox(height: 16),
          _breakdownCard(
            'Top Spending Categories',
            data.topExpenseCategories,
            AppTheme.red,
          ),
          const SizedBox(height: 16),
          _breakdownCard(
            'Top Income Sources',
            data.topIncomeCategories,
            AppTheme.green,
          ),
        ],
      ),
    );
  }

  Widget _rangeSelector(WidgetRef ref, int months) {
    const options = [3, 6, 12];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: cardDecoration(),
      child: Row(
        children: options.map((m) {
          final selected = months == m;
          return Expanded(
            child: InkWell(
              onTap: () =>
                  ref.read(analyticsMonthsProvider.notifier).state = m,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.lavender : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    'Last $m months',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppTheme.primary : AppTheme.muted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statGrid(AnalyticsSummary data) {
    final cards = [
      _StatCard('Total Income', currencyFormat.format(data.totalIncome),
          Icons.trending_up_rounded, AppTheme.green),
      _StatCard('Total Expenses', currencyFormat.format(data.totalExpense),
          Icons.trending_down_rounded, AppTheme.red),
      _StatCard('Net Balance', currencyFormat.format(data.netBalance),
          Icons.account_balance_wallet_rounded,
          data.netBalance < 0 ? AppTheme.red : AppTheme.primary),
      _StatCard('Avg Expense', currencyFormat.format(data.avgExpense),
          Icons.analytics_rounded, AppTheme.amber),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth < 560 ? 2 : 4;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: cards,
        );
      },
    );
  }

  Widget _trendChart(AnalyticsSummary data) {
    final trend = data.monthlyTrend;
    final maxY = trend.fold<double>(
      0,
      (m, t) => [m, t.income, t.expense].reduce((a, b) => a > b ? a : b),
    );
    return Container(
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Income vs Expenses',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legendDot(AppTheme.primary, 'Income'),
              const SizedBox(width: 16),
              _legendDot(AppTheme.green, 'Expenses'),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: trend.isEmpty
                ? const Center(
                    child: Text(
                      'No data for this range',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxY <= 0 ? 100 : maxY * 1.2,
                      barGroups: List.generate(
                        trend.length,
                        (i) => BarChartGroupData(
                          x: i,
                          barsSpace: 4,
                          barRods: [
                            BarChartRodData(
                              toY: trend[i].income,
                              color: AppTheme.primary,
                              width: 9,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                            BarChartRodData(
                              toY: trend[i].expense,
                              color: AppTheme.green,
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
                            const FlLine(color: AppTheme.border, strokeWidth: 1),
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
                            reservedSize: 38,
                            getTitlesWidget: (v, _) => Text(
                              compactCurrency.format(v),
                              style: const TextStyle(
                                fontSize: 8,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= trend.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Text(
                                  trend[i].label,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.muted,
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
  }

  Widget _breakdownCard(
    String title,
    List<CategoryBreakdown> items,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No data in this range',
                style: TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            )
          else
            ...items.take(6).map((item) {
              final color = parseHexColor(item.categoryColor, fallback: accent);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.categoryName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${currencyFormat.format(item.total)}  •  ${item.percent.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (item.percent / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppTheme.background,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
    ],
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.title, this.value, this.icon, this.color);
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.text,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// RECURRING TRANSACTIONS PAGE
// ---------------------------------------------------------

const _frequencyLabels = {
  'daily': 'Daily',
  'weekly': 'Weekly',
  'monthly': 'Monthly',
  'yearly': 'Yearly',
};

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(recurringProvider);
    ref.invalidate(transactionsProvider);
    await ref.read(recurringProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountsProvider).value ?? [];
    final categoryNames = {for (final c in categories) c.id: c.name};
    final accountNames = {for (final a in accounts) a.id: a.name};

    return recurringAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => AsyncStatePanel(
        title: 'Unable to load recurring transactions',
        message: ApiClient.errorMessage(e),
        onRetry: () => _refresh(ref),
      ),
      data: (items) => FeatureScaffold(
        onRefresh: () => _refresh(ref),
        children: [
          PageHeader(
            title: 'Recurring',
            subtitle: 'Automate regular income and bills.',
            action: primaryButton(
              label: 'Add Recurring',
              onPressed: accounts.isEmpty
                  ? null
                  : () => _openEditor(context, ref),
            ),
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.autorenew_rounded,
              title: 'No recurring transactions',
              message: 'Add a salary, rent or subscription to automate it.',
            )
          else
            ...items.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _recurringCard(
                  context,
                  ref,
                  r,
                  categoryNames[r.categoryId] ?? 'Other',
                  accountNames[r.accountId] ?? 'Account',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recurringCard(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction r,
    String category,
    String account,
  ) {
    final accent = r.isIncome ? AppTheme.green : AppTheme.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.autorenew_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.description.isEmpty ? category : r.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_frequencyLabels[r.frequency] ?? r.frequency} • $category • $account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              Text(
                '${r.isIncome ? '+' : '−'}${currencyFormat.format(r.amount)}',
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.event_rounded,
                size: 14,
                color: r.isActive ? AppTheme.primary : AppTheme.muted,
              ),
              const SizedBox(width: 5),
              Text(
                r.isActive
                    ? 'Next: ${DateFormat('dd MMM yyyy').format(r.nextDueDate)}'
                    : 'Paused',
                style: TextStyle(
                  fontSize: 10,
                  color: r.isActive ? AppTheme.text : AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (r.isActive)
                TextButton.icon(
                  onPressed: () => _postNow(context, ref, r),
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Post now', style: TextStyle(fontSize: 11)),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: r.isActive ? 'Pause' : 'Resume',
                onPressed: () => _toggle(context, ref, r),
                icon: Icon(
                  r.isActive
                      ? Icons.pause_circle_outline_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 19,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _delete(context, ref, r),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppTheme.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _postNow(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction r,
  ) async {
    try {
      await ref.read(financeServiceProvider).postRecurringNow(r.id);
      ref.invalidate(recurringProvider);
      ref.invalidate(transactionsProvider);
      if (context.mounted) showMessage(context, 'Transaction posted.');
    } catch (e) {
      if (context.mounted) {
        showMessage(context, ApiClient.errorMessage(e), isError: true);
      }
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction r,
  ) async {
    try {
      await ref
          .read(financeServiceProvider)
          .toggleRecurring(recurringId: r.id, isActive: !r.isActive);
      ref.invalidate(recurringProvider);
      if (context.mounted) {
        showMessage(context, r.isActive ? 'Paused.' : 'Resumed.');
      }
    } catch (e) {
      if (context.mounted) {
        showMessage(context, ApiClient.errorMessage(e), isError: true);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction r,
  ) async {
    try {
      await ref.read(financeServiceProvider).deleteRecurring(r.id);
      ref.invalidate(recurringProvider);
      if (context.mounted) showMessage(context, 'Recurring deleted.');
    } catch (e) {
      if (context.mounted) {
        showMessage(context, ApiClient.errorMessage(e), isError: true);
      }
    }
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final accounts = ref.read(accountsProvider).value ?? [];
    final categories = ref.read(categoriesProvider).value ?? [];
    if (accounts.isEmpty || categories.isEmpty) {
      showMessage(
        context,
        'Add an account and categories first.',
        isError: true,
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _RecurringEditorDialog(accounts: accounts, categories: categories),
    );
    if (saved == true) {
      ref.invalidate(recurringProvider);
      if (context.mounted) showMessage(context, 'Recurring transaction added.');
    }
  }
}

class _RecurringEditorDialog extends ConsumerStatefulWidget {
  const _RecurringEditorDialog({
    required this.accounts,
    required this.categories,
  });

  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;

  @override
  ConsumerState<_RecurringEditorDialog> createState() =>
      _RecurringEditorDialogState();
}

class _RecurringEditorDialogState
    extends ConsumerState<_RecurringEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  bool _income = false;
  int? _accountId;
  int? _categoryId;
  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now();
  bool _saving = false;

  List<FinanceCategory> get _available => widget.categories
      .where((c) => c.transactionType == (_income ? 'income' : 'expense'))
      .toList();

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.first.id;
    final list = _available;
    _categoryId = list.isEmpty ? null : list.first.id;
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _accountId == null ||
        _categoryId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(financeServiceProvider).createRecurring(
            accountId: _accountId!,
            categoryId: _categoryId!,
            type: _income ? 'income' : 'expense',
            amount: double.parse(_amount.text.trim()),
            description: _description.text.trim(),
            frequency: _frequency,
            startDate: _startDate,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, ApiClient.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Recurring Transaction',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _typeButton('Expense', false)),
                    const SizedBox(width: 10),
                    Expanded(child: _typeButton('Income', true)),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  decoration:
                      fieldDecoration('Description', Icons.edit_rounded),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a description' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: fieldDecoration(
                    'Amount (₹)',
                    Icons.currency_rupee_rounded,
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || n <= 0 ? 'Enter a valid amount' : null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration:
                      fieldDecoration('Category', Icons.category_rounded),
                  items: _available
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                  validator: (v) => v == null ? 'Select a category' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: fieldDecoration(
                    'Account',
                    Icons.account_balance_rounded,
                  ),
                  items: widget.accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _accountId = v),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration:
                      fieldDecoration('Frequency', Icons.repeat_rounded),
                  items: _frequencyLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _frequency = v ?? 'monthly'),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 17),
                  label: Text(
                    'Starts ${DateFormat('dd MMM yyyy').format(_startDate)}',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeButton(String label, bool income) {
    final selected = _income == income;
    return InkWell(
      onTap: () => setState(() {
        _income = income;
        final list = _available;
        _categoryId = list.isEmpty ? null : list.first.id;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lavender : Colors.white,
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selected ? AppTheme.primary : AppTheme.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SETTINGS PAGE
// ---------------------------------------------------------

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(profileProvider);
    ref.invalidate(categoriesProvider);
    await ref.read(categoriesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return FeatureScaffold(
      onRefresh: () => _refresh(ref),
      children: [
        const PageHeader(
          title: 'Settings',
          subtitle: 'Your profile and categories.',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: cardDecoration(),
          child: profileAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text(
              ApiClient.errorMessage(e),
              style: const TextStyle(color: AppTheme.red, fontSize: 12),
            ),
            data: (profile) => Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.lavender,
                  child: Text(
                    profile.fullName.isEmpty
                        ? '?'
                        : profile.fullName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        style:
                            const TextStyle(fontSize: 12, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Categories',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addCategory(context, ref),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        categoriesAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => AsyncStatePanel(
            title: 'Unable to load categories',
            message: ApiClient.errorMessage(e),
            onRetry: () => _refresh(ref),
          ),
          data: (categories) {
            final income =
                categories.where((c) => c.transactionType == 'income').toList();
            final expense = categories
                .where((c) => c.transactionType == 'expense')
                .toList();
            return Column(
              children: [
                _categoryGroup(context, ref, 'Income', income, AppTheme.green),
                const SizedBox(height: 14),
                _categoryGroup(context, ref, 'Expense', expense, AppTheme.red),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _categoryGroup(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<FinanceCategory> items,
    Color accent,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((c) {
              final color = parseHexColor(c.color, fallback: accent);
              return InputChip(
                backgroundColor: color.withValues(alpha: 0.10),
                side: BorderSide(color: color.withValues(alpha: 0.3)),
                label: Text(
                  c.name,
                  style: const TextStyle(fontSize: 12, color: AppTheme.text),
                ),
                avatar: CircleAvatar(backgroundColor: color, radius: 6),
                onDeleted: () => _deleteCategory(context, ref, c),
                deleteIcon: const Icon(Icons.close_rounded, size: 15),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _CategoryEditorDialog(),
    );
    if (saved == true) {
      ref.invalidate(categoriesProvider);
      ref.invalidate(expenseCategoriesProvider);
      ref.invalidate(incomeCategoriesProvider);
      if (context.mounted) showMessage(context, 'Category added.');
    }
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    FinanceCategory c,
  ) async {
    try {
      await ref.read(financeServiceProvider).deleteCategory(c.id);
      ref.invalidate(categoriesProvider);
      ref.invalidate(expenseCategoriesProvider);
      ref.invalidate(incomeCategoriesProvider);
      if (context.mounted) showMessage(context, 'Category deleted.');
    } catch (e) {
      if (context.mounted) {
        showMessage(context, ApiClient.errorMessage(e), isError: true);
      }
    }
  }
}

class _CategoryEditorDialog extends ConsumerStatefulWidget {
  const _CategoryEditorDialog();

  @override
  ConsumerState<_CategoryEditorDialog> createState() =>
      _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends ConsumerState<_CategoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _type = 'expense';
  String _color = '#7C6CF2';
  bool _saving = false;

  static const _palette = [
    '#635BDB', '#23B58A', '#EFAC4B', '#EF6B78',
    '#3B82F6', '#A855F7', '#EC4899', '#0EA5E9',
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeServiceProvider).createCategory(
            name: _name.text.trim(),
            type: _type,
            color: _color,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, ApiClient.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Category',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  decoration: fieldDecoration('Name', Icons.label_rounded),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: fieldDecoration('Type', Icons.swap_vert_rounded),
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('Expense')),
                    DropdownMenuItem(value: 'income', child: Text('Income')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'expense'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Color',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _palette.map((hex) {
                    final color = parseHexColor(hex);
                    final selected = _color == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _color = hex),
                      child: Container(
                        height: 32,
                        width: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? AppTheme.text : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 17,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
