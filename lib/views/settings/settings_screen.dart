import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      final transactions = await ref.read(transactionListProvider.future);
      final categories = await ref.read(categoryListProvider.future);

      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('当前没有可以导出的记账数据'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add(["时间", "收支类型", "分类", "金额(元)", "备注"]);

      for (var t in transactions) {
        final dateStr = DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(DateTime.fromMillisecondsSinceEpoch(t.timestamp));
        final typeStr = t.type == 1 ? "收入" : "支出";

        final cateName =
            categories.where((c) => c.id == t.categoryId).firstOrNull?.name ??
            '未知';

        rows.add([dateStr, typeStr, cateName, t.amount, t.note ?? '']);
      }

      String csvData = const ListToCsvConverter().convert(rows);

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/清简记账_导出数据_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      // 添加 UTF-8 BOM 避免 Excel 乱码
      final bytes = [0xEF, 0xBB, 0xBF, ...csvData.codeUnits];
      await file.writeAsBytes(bytes);

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(path)],
          text: '我的记账数据导出',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          _buildSectionHeader('数据管理'),
          _buildCardWrapper(
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.file_download, color: Colors.green.shade600),
              ),
              title: const Text(
                '导出账单数据 (CSV)',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                '将记录导出至 Excel 查看',
                style: TextStyle(fontSize: 12),
              ),
              trailing: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: _isExporting ? null : _exportData,
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('关于应用'),
          _buildCardWrapper(
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_outline, color: Colors.blue.shade600),
              ),
              title: const Text(
                '清简记账',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text('版本 1.0.0', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildCardWrapper(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
