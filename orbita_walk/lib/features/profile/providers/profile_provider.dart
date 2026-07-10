import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/services/api_service.dart';

final transactionsProvider = FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final api = ref.read(apiServiceProvider);
  try {
    final res = await api.getWalletTransactions();
    if (res.data['success'] == true) {
      final list = res.data['transactions'] as List;
      return list.map((item) => TransactionModel.fromJson(item)).toList();
    }
  } catch (e) {
    // Return empty on error
  }
  return [];
});
