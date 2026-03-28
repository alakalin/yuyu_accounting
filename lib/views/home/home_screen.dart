import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../core/utils/icon_util.dart';
import '../add/add_record_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsyncValue = ref.watch(transactionListProvider);
    final categoriesAsyncValue = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '账单明细',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: transactionsAsyncValue.when(
        data: (transactions) {
          double totalIncome = 0;
          double totalExpense = 0;
          for (var t in transactions) {
            if (t.type == 1) {
              totalIncome += t.amount;
            } else {
              totalExpense += t.amount;
            }
          }

          return Column(
            children: [
              _buildSummaryCard(context, totalIncome, totalExpense),
              Expanded(
                child: transactions.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无账单记录\n点击右下角记一笔吧',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, height: 1.5),
                        ),
                      )
                    : ListView.separated(
                        itemCount: transactions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, indent: 70),
                        itemBuilder: (context, index) {
                          final transaction = transactions[index];
                          final dateStr = DateFormat('MM-dd HH:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(
                              transaction.timestamp,
                            ),
                          );

                          final isIncome = transaction.type == 1;

                          return categoriesAsyncValue.when(
                            data: (categories) {
                              final categoryName =
                                  categories
                                      .where(
                                        (c) => c.id == transaction.categoryId,
                                      )
                                      .firstOrNull
                                      ?.name ??
                                  '未知';
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: isIncome
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  radius: 24,
                                  child: Icon(
                                    IconUtil.getCategoryIcon(categoryName),
                                    color: isIncome
                                        ? Colors.green.shade600
                                        : Colors.red.shade400,
                                  ),
                                ),
                                title: Text(
                                  categoryName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    transaction.note?.isNotEmpty == true
                                        ? '${transaction.note}  |  $dateStr'
                                        : dateStr,
                                  ),
                                ),
                                trailing: Text(
                                  '${isIncome ? '+' : '-'}${transaction.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: isIncome
                                        ? Colors.green.shade700
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                onLongPress: () => _deleteTransaction(
                                  context,
                                  ref,
                                  transaction.id!,
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (e, st) => const SizedBox.shrink(),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddRecordScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    double totalIncome,
    double totalExpense,
  ) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Colors.green.shade800,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSummaryItem(
              '本月收入',
              '+${totalIncome.toStringAsFixed(2)}',
              isBalance: false,
            ),
            _buildSummaryItem(
              '本月支出',
              '-${totalExpense.toStringAsFixed(2)}',
              isBalance: false,
            ),
            _buildSummaryItem(
              '总结余',
              (totalIncome - totalExpense).toStringAsFixed(2),
              isBalance: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String amount, {
    required bool isBalance,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          amount,
          style: TextStyle(
            fontSize: isBalance ? 22 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _deleteTransaction(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账单'),
        content: const Text('确定要删除这笔记录吗？该操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(transactionListProvider.notifier).deleteTransaction(id);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
