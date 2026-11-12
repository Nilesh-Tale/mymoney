import '../core/api_client.dart';
import '../models/finance_models.dart';

class FinanceService {
  Future<List<FinanceAccount>> getAccounts() async {
    final response = await ApiClient.dio.get('/api/accounts');
    return (response.data as List)
        .map((item) =>
            FinanceAccount.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<FinanceCategory>> getCategories({String? type}) async {
    final response = await ApiClient.dio.get(
      '/api/categories',
      queryParameters: type == null ? null : {'transaction_type': type},
    );
    return (response.data as List)
        .map((item) =>
            FinanceCategory.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<FinanceTransaction>> getTransactions() async {
    final response = await ApiClient.dio.get('/api/transactions');
    final items = (response.data as List)
        .map((item) => FinanceTransaction.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
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
}
