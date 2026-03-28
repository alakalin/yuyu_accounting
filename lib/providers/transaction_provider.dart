import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/db/database_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';

part 'transaction_provider.g.dart';

/// 分类状态管理
@riverpod
class CategoryList extends _$CategoryList {
  @override
  FutureOr<List<Category>> build() async {
    return _fetchCategories();
  }

  Future<List<Category>> _fetchCategories() async {
    return await DatabaseHelper.instance.getAllCategories();
  }

  /// 额外添加分类的功能（预留扩展）
  Future<void> addCategory(Category category) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.insertCategory(category);
      return _fetchCategories();
    });
  }
}

/// 交易记录状态管理
@riverpod
class TransactionList extends _$TransactionList {
  @override
  FutureOr<List<TransactionRecord>> build() async {
    return _fetchTransactions();
  }

  Future<List<TransactionRecord>> _fetchTransactions() async {
    return await DatabaseHelper.instance.getAllTransactions();
  }

  /// 记一笔（新增交易）
  Future<void> addTransaction(TransactionRecord transaction) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.insertTransaction(transaction);
      return _fetchTransactions();
    });
  }

  /// 修改一笔交易
  Future<void> updateTransaction(TransactionRecord transaction) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.updateTransaction(transaction);
      return _fetchTransactions();
    });
  }

  /// 删除一笔交易
  Future<void> deleteTransaction(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.deleteTransaction(id);
      return _fetchTransactions();
    });
  }
}
