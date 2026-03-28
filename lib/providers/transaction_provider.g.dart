// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$categoryListHash() => r'163404b092e31e00d3c7813734a6adba396db09e';

/// 分类状态管理
///
/// Copied from [CategoryList].
@ProviderFor(CategoryList)
final categoryListProvider =
    AutoDisposeAsyncNotifierProvider<CategoryList, List<Category>>.internal(
      CategoryList.new,
      name: r'categoryListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$categoryListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CategoryList = AutoDisposeAsyncNotifier<List<Category>>;
String _$transactionListHash() => r'baf218371f30eaf23e58b3e47529fd498ddf0181';

/// 交易记录状态管理
///
/// Copied from [TransactionList].
@ProviderFor(TransactionList)
final transactionListProvider =
    AutoDisposeAsyncNotifierProvider<
      TransactionList,
      List<TransactionRecord>
    >.internal(
      TransactionList.new,
      name: r'transactionListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transactionListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TransactionList = AutoDisposeAsyncNotifier<List<TransactionRecord>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
