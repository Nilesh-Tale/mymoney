import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/finance_models.dart';
import '../providers/finance_providers.dart';
import '../services/finance_service.dart';

class _TransactionColors {
  static const primary = Color(0xFF635BDB);
  static const background = Color(0xFFF7F8FC);
  static const text = Color(0xFF20213A);
  static const muted = Color(0xFF9294A5);
  static const green = Color(0xFF23B58A);
  static const red = Color(0xFFEF6B78);
  static const border = Color(0xFFEDEEF4);
  static const lavender = Color(0xFFF0EEFF);
}

class TransactionManagementScreen extends ConsumerStatefulWidget {
  const TransactionManagementScreen({super.key});

  @override
  ConsumerState<TransactionManagementScreen> createState() =>
      _TransactionManagementScreenState();
}

class _TransactionManagementScreenState
    extends ConsumerState<TransactionManagementScreen> {
  final _searchController = TextEditingController();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  int _tab = 0; // 0 all, 1 income, 2 expense
  int? _categoryId;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(categoriesProvider);
    await Future.wait([
      ref.read(transactionsProvider.future),
      ref.read(accountsProvider.future),
      ref.read(categoriesProvider.future),
    ]);
  }

  Future<void> _openEditor({
    FinanceTransaction? transaction,
    required List<FinanceAccount> accounts,
    required List<FinanceCategory> categories,
  }) async {
    if (accounts.isEmpty) {
      _message('Create an account before adding a transaction.');
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransactionEditorDialog(
        accounts: accounts,
        categories: categories,
        transaction: transaction,
      ),
    );
    if (saved == true && mounted) {
      await _refresh();
      _message(
        transaction == null
            ? 'Transaction added successfully.'
            : 'Transaction updated successfully.',
      );
    }
  }

  Future<void> _delete(FinanceTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete transaction?'),
        content: Text(
          '“${transaction.description.isEmpty ? 'Untitled transaction' : transaction.description}” will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _TransactionColors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(financeServiceProvider).deleteTransaction(transaction.id);
      await _refresh();
      if (mounted) _message('Transaction deleted.');
    } catch (error) {
      if (mounted) _message(ApiClient.errorMessage(error), isError: true);
    }
  }

  void _message(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isError
              ? _TransactionColors.red
              : _TransactionColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return transactionsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _TransactionColors.primary),
      ),
      error: (error, _) => _StateMessage(
        title: 'Unable to load transactions',
        message: ApiClient.errorMessage(error),
        action: FilledButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
      data: (transactions) => accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _StateMessage(
          title: 'Unable to load accounts',
          message: ApiClient.errorMessage(error),
          action: FilledButton(onPressed: _refresh, child: const Text('Retry')),
        ),
        data: (accounts) => categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _StateMessage(
            title: 'Unable to load categories',
            message: ApiClient.errorMessage(error),
            action: FilledButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          ),
          data: (categories) =>
              _buildContent(transactions, accounts, categories),
        ),
      ),
    );
  }

  Widget _buildContent(
    List<FinanceTransaction> transactions,
    List<FinanceAccount> accounts,
    List<FinanceCategory> categories,
  ) {
    final accountNames = {for (final a in accounts) a.id: a.name};
    final categoryMap = {for (final c in categories) c.id: c};
    final filtered = transactions.where((t) {
      if (_tab == 1 && !t.isIncome) return false;
      if (_tab == 2 && t.isIncome) return false;
      if (_categoryId != null && t.categoryId != _categoryId) return false;
      if (_dateRange != null) {
        final day = DateTime(
          t.transactionDate.year,
          t.transactionDate.month,
          t.transactionDate.day,
        );
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final end = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
          23,
          59,
          59,
        );
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final category = categoryMap[t.categoryId]?.name ?? '';
        final account = accountNames[t.accountId] ?? '';
        if (!t.description.toLowerCase().contains(query) &&
            !category.toLowerCase().contains(query) &&
            !account.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList()..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    final income = filtered
        .where((t) => t.isIncome)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final expense = filtered
        .where((t) => !t.isIncome)
        .fold<double>(0, (sum, t) => sum + t.amount);

    return Container(
      color: _TransactionColors.background,
      child: RefreshIndicator(
        color: _TransactionColors.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              sliver: SliverToBoxAdapter(child: _header(accounts, categories)),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 600;
                    final children = [
                      _totalCard(
                        'Income',
                        income,
                        _TransactionColors.green,
                        Icons.south_west_rounded,
                      ),
                      _totalCard(
                        'Expenses',
                        expense,
                        _TransactionColors.red,
                        Icons.north_east_rounded,
                      ),
                      _totalCard(
                        'Net',
                        income - expense,
                        _TransactionColors.primary,
                        Icons.account_balance_wallet_rounded,
                      ),
                    ];
                    return compact
                        ? Column(
                            children: [
                              for (final card in children)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: card,
                                ),
                            ],
                          )
                        : Row(
                            children: [
                              for (var i = 0; i < children.length; i++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: i == 2 ? 0 : 12,
                                    ),
                                    child: children[i],
                                  ),
                                ),
                            ],
                          );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              sliver: SliverToBoxAdapter(child: _filters(categories)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              sliver: filtered.isEmpty
                  ? SliverToBoxAdapter(child: _emptyState(transactions.isEmpty))
                  : SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final transaction = filtered[index];
                        return _transactionTile(
                          transaction,
                          categoryMap[transaction.categoryId]?.name ?? 'Other',
                          accountNames[transaction.accountId] ?? 'Account',
                          () => _openEditor(
                            transaction: transaction,
                            accounts: accounts,
                            categories: categories,
                          ),
                          () => _delete(transaction),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(
    List<FinanceAccount> accounts,
    List<FinanceCategory> categories,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transactions',
              style: TextStyle(
                color: _TransactionColors.text,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Track and manage your income and expenses.',
              style: TextStyle(color: _TransactionColors.muted, fontSize: 13),
            ),
          ],
        );
        final button = FilledButton.icon(
          onPressed: () =>
              _openEditor(accounts: accounts, categories: categories),
          style: FilledButton.styleFrom(
            backgroundColor: _TransactionColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('Add Transaction'),
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 14), button],
              )
            : Row(
                children: [
                  Expanded(child: title),
                  button,
                ],
              );
      },
    );
  }

  Widget _totalCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _TransactionColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _TransactionColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _currency.format(amount),
                    style: TextStyle(
                      color: _TransactionColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(List<FinanceCategory> categories) {
    final shownCategories = _tab == 1
        ? categories.where((c) => c.transactionType == 'income').toList()
        : _tab == 2
        ? categories.where((c) => c.transactionType == 'expense').toList()
        : categories;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _TransactionColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _filterTab('All', 0),
              const SizedBox(width: 7),
              _filterTab('Income', 1),
              const SizedBox(width: 7),
              _filterTab('Expenses', 2),
            ],
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final search = TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search description, category or account',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: _TransactionColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              );
              final category = DropdownButtonFormField<int?>(
                key: ValueKey('category-$_tab-$_categoryId'),
                initialValue: _categoryId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: _TransactionColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All categories'),
                  ),
                  ...shownCategories.map(
                    (c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              );
              final dateButton = OutlinedButton.icon(
                onPressed: _chooseDateRange,
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(
                  _dateRange == null
                      ? 'Date range'
                      : '${DateFormat('dd MMM').format(_dateRange!.start)} – ${DateFormat('dd MMM').format(_dateRange!.end)}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
              if (compact) {
                return Column(
                  children: [
                    search,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: category),
                        const SizedBox(width: 9),
                        Flexible(child: dateButton),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: search),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: category),
                  const SizedBox(width: 10),
                  dateButton,
                ],
              );
            },
          ),
          if (_categoryId != null || _dateRange != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _categoryId = null;
                  _dateRange = null;
                }),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
                label: const Text('Clear filters'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterTab(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _tab = index;
          _categoryId = null;
        }),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _TransactionColors.lavender : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? _TransactionColors.primary
                    : _TransactionColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme
              .copyWith(primary: _TransactionColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  Widget _transactionTile(
    FinanceTransaction t,
    String category,
    String account,
    VoidCallback onEdit,
    VoidCallback onDelete,
  ) {
    final income = t.isIncome;
    final color = income ? _TransactionColors.green : _TransactionColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _TransactionColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              income ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.description.isEmpty
                      ? 'Untitled transaction'
                      : t.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TransactionColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$category • $account • ${DateFormat('dd MMM yyyy').format(t.transactionDate)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TransactionColors.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${income ? '+' : '−'}${_currency.format(t.amount)}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: _TransactionColors.red,
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

  Widget _emptyState(bool noTransactions) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _TransactionColors.border),
      ),
      child: Column(
        children: [
          Icon(
            noTransactions
                ? Icons.receipt_long_outlined
                : Icons.filter_list_off_rounded,
            size: 42,
            color: _TransactionColors.muted,
          ),
          const SizedBox(height: 12),
          Text(
            noTransactions ? 'No transactions yet' : 'No matching transactions',
            style: const TextStyle(
              color: _TransactionColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noTransactions
                ? 'Add your first income or expense to get started.'
                : 'Try changing your search or filters.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _TransactionColors.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionEditorDialog extends ConsumerStatefulWidget {
  const _TransactionEditorDialog({
    required this.accounts,
    required this.categories,
    this.transaction,
  });

  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;
  final FinanceTransaction? transaction;

  @override
  ConsumerState<_TransactionEditorDialog> createState() =>
      _TransactionEditorDialogState();
}

class _TransactionEditorDialogState
    extends ConsumerState<_TransactionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late bool _income;
  late int? _accountId;
  late int? _categoryId;
  late DateTime _date;
  bool _saving = false;

  List<FinanceCategory> get _availableCategories => widget.categories
      .where((c) => c.transactionType == (_income ? 'income' : 'expense'))
      .toList();

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _amountController = TextEditingController(
      text: t == null ? '' : t.amount.toStringAsFixed(2),
    );
    _income = t?.isIncome ?? false;
    _accountId = t?.accountId ?? widget.accounts.first.id;
    _date = t?.transactionDate ?? DateTime.now();
    final available = _availableCategories;
    _categoryId = available.any((c) => c.id == t?.categoryId)
        ? t!.categoryId
        : (available.isEmpty ? null : available.first.id);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 19),
    filled: true,
    fillColor: _TransactionColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _accountId == null ||
        _categoryId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final service = ref.read(financeServiceProvider);
      final args = {
        'accountId': _accountId!,
        'categoryId': _categoryId!,
        'type': _income ? 'income' : 'expense',
        'amount': double.parse(_amountController.text.trim()),
        'description': _descriptionController.text.trim(),
        'date': _date,
      };
      if (widget.transaction == null) {
        await service.createTransaction(
          accountId: args['accountId'] as int,
          categoryId: args['categoryId'] as int,
          type: args['type'] as String,
          amount: args['amount'] as double,
          description: args['description'] as String,
          date: args['date'] as DateTime,
        );
      } else {
        await service.updateTransaction(
          transactionId: widget.transaction!.id,
          accountId: args['accountId'] as int,
          categoryId: args['categoryId'] as int,
          type: args['type'] as String,
          amount: args['amount'] as double,
          description: args['description'] as String,
          date: args['date'] as DateTime,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.errorMessage(error)),
            backgroundColor: _TransactionColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.transaction != null;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470, maxHeight: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        editing ? 'Edit Transaction' : 'Add Transaction',
                        style: const TextStyle(
                          color: _TransactionColors.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _typeButton('Expense', false)),
                    const SizedBox(width: 10),
                    Expanded(child: _typeButton('Income', true)),
                  ],
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _decoration('Description', Icons.edit_rounded),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a description'
                      : null,
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoration(
                    'Amount (₹)',
                    Icons.currency_rupee_rounded,
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    return amount == null || !amount.isFinite || amount <= 0
                        ? 'Enter a valid positive amount'
                        : null;
                  },
                ),
                const SizedBox(height: 13),
                DropdownButtonFormField<int>(
                  key: ValueKey('editor-category-$_income-$_categoryId'),
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: _decoration('Category', Icons.category_rounded),
                  items: _availableCategories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? 'Select a category' : null,
                ),
                const SizedBox(height: 13),
                DropdownButtonFormField<int>(
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: _decoration(
                    'Payment account',
                    Icons.account_balance_rounded,
                  ),
                  items: widget.accounts
                      .map(
                        (a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _accountId = value),
                ),
                const SizedBox(height: 13),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                  icon: const Icon(Icons.calendar_today_rounded, size: 17),
                  label: Text(DateFormat('dd MMM yyyy').format(_date)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 47,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _TransactionColors.primary,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 19,
                            width: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(editing ? 'Save Changes' : 'Save Transaction'),
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
      onTap: _saving
          ? null
          : () => setState(() {
              _income = income;
              final list = _availableCategories;
              _categoryId = list.isEmpty ? null : list.first.id;
            }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? _TransactionColors.lavender : Colors.white,
          border: Border.all(
            color: selected
                ? _TransactionColors.primary
                : _TransactionColors.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? _TransactionColors.primary
                  : _TransactionColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.title,
    required this.message,
    required this.action,
  });

  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 42,
            color: _TransactionColors.muted,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _TransactionColors.text,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _TransactionColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          action,
        ],
      ),
    ),
  );
}
