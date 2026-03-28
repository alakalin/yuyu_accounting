import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../core/utils/icon_util.dart';

class AddRecordScreen extends ConsumerStatefulWidget {
  const AddRecordScreen({super.key});

  @override
  ConsumerState<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends ConsumerState<AddRecordScreen> {
  int _selectedType = 0; // 0: 支出, 1: 收入
  int? _selectedCategoryId;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _saveRecord() {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入金额并选择一个分类'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效的金额格式'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final record = TransactionRecord(
      amount: amount,
      type: _selectedType,
      categoryId: _selectedCategoryId!,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      note: _noteController.text.trim(),
    );

    ref.read(transactionListProvider.notifier).addTransaction(record).then((_) {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsyncValue = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('记一笔')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 选择收支类型
              Center(
                child: SegmentedButton<int>(
                  style: SegmentedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('支出', style: TextStyle(fontSize: 16)),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('收入', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() {
                      _selectedType = newSelection.first;
                      _selectedCategoryId = null; // 重置分类
                    });
                  },
                ),
              ),
              const SizedBox(height: 32),

              // 金额输入框
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  labelText: '金额',
                  prefixText: '? ',
                  prefixStyle: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 分类选择网格区
              const Text(
                '选择分类',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              categoriesAsyncValue.when(
                data: (categories) {
                  final filteredCategories = categories
                      .where((c) => c.type == _selectedType)
                      .toList();

                  if (filteredCategories.isEmpty) {
                    return const Text(
                      '暂无相关分类记录。',
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: filteredCategories.map((category) {
                      final isSelected = _selectedCategoryId == category.id;
                      final iconData = IconUtil.getCategoryIcon(category.name);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryId = category.id;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                iconData,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('加载失败: $e'),
              ),

              const SizedBox(height: 32),

              // 备注输入框
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: '添加备注（选填）',
                  prefixIcon: const Icon(Icons.edit_note),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 保存按钮
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _saveRecord,
                  child: const Text(
                    '保存记录',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
