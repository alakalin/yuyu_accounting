import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/transaction_provider.dart';
import '../../core/services/auto_bookkeeping_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _autoImportKey = 'auto_import_enabled_v21';
  static const _autoImportIntervalKey = 'auto_import_interval_seconds_v21';
  static const _intervalOptions = [8, 12, 20, 30, 60];
  static const _authorName = 'alakalin';
  static const _githubUrl = 'https://github.com/alakalin/yuyu_accounting';

  bool _isExporting = false;
  bool _isImportingAuto = false;
  bool _notificationEnabled = false;
  bool _autoImportEnabled = false;
  int _autoImportIntervalSeconds = 12;
  Timer? _autoImportTimer;
  StreamSubscription<String>? _recordEventSubscription;

  @override
  void initState() {
    super.initState();
    _refreshNotificationPermission();
    _loadAutoImportSetting();
    _listenAutoRecordEvents();
  }

  @override
  void dispose() {
    _autoImportTimer?.cancel();
    _recordEventSubscription?.cancel();
    super.dispose();
  }

  void _listenAutoRecordEvents() {
    _recordEventSubscription?.cancel();
    _recordEventSubscription =
        AutoBookkeepingService.autoRecordEvents.listen((_) async {
      if (!mounted || !_notificationEnabled) return;
      await _importAutoRecords(silent: true);
    });
  }

  Future<void> _loadAutoImportSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_autoImportKey) ?? false;
    final interval = prefs.getInt(_autoImportIntervalKey) ?? 12;
    final safeInterval = _intervalOptions.contains(interval) ? interval : 12;
    if (!mounted) return;
    setState(() {
      _autoImportEnabled = enabled;
      _autoImportIntervalSeconds = safeInterval;
    });
    _restartAutoImportTimer();
  }

  Future<void> _setAutoImportEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoImportKey, enabled);
    if (!mounted) return;
    setState(() {
      _autoImportEnabled = enabled;
    });
    _restartAutoImportTimer();
  }

  Future<void> _setAutoImportInterval(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoImportIntervalKey, seconds);
    if (!mounted) return;
    setState(() {
      _autoImportIntervalSeconds = seconds;
    });
    _restartAutoImportTimer();
  }

  void _restartAutoImportTimer() {
    _autoImportTimer?.cancel();
    if (!_autoImportEnabled) return;

    _autoImportTimer = Timer.periodic(
      Duration(seconds: _autoImportIntervalSeconds),
      (_) async {
        if (!mounted || !_notificationEnabled) return;
        await _importAutoRecords(silent: true);
      },
    );
  }

  Future<void> _refreshNotificationPermission() async {
    final enabled =
        await AutoBookkeepingService.isNotificationListenerEnabled();
    if (!mounted) return;
    setState(() {
      _notificationEnabled = enabled;
    });
    _restartAutoImportTimer();
  }

  Future<void> _openNotificationSettings() async {
    await AutoBookkeepingService.openNotificationListenerSettings();
    // Give user a moment to return from settings.
    await Future.delayed(const Duration(milliseconds: 500));
    await _refreshNotificationPermission();
  }

  Future<void> _importAutoRecords({bool silent = false}) async {
    if (_isImportingAuto) return;
    _isImportingAuto = true;
    if (!silent) {
      setState(() {});
    }

    try {
      final records = await AutoBookkeepingService.fetchPendingRecords();
      if (records.isEmpty) {
        if (mounted && !silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('当前没有可导入的自动记账通知'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      for (final record in records) {
        await ref.read(transactionListProvider.notifier).addAutoTransaction(
              amount: record.amount,
              type: record.type,
              categoryName: record.category,
              timestamp: record.timestamp,
              note: record.note,
            );
      }

      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('自动导入成功：已写入 ${records.length} 条账单'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('自动导入失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _isImportingAuto = false);
      }
      _isImportingAuto = false;
    }
  }

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

  Future<void> _copyGithubUrl() async {
    await Clipboard.setData(const ClipboardData(text: _githubUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GitHub 链接已复制'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          _buildSectionHeader('自动记账（V2）'),
          _buildCardWrapper(
            Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.notifications,
                        color: Colors.purple.shade600),
                  ),
                  title: const Text(
                    '通知监听权限',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    _notificationEnabled
                        ? '已开启，可自动识别微信/支付宝通知'
                        : '未开启，点击前往系统设置开启',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: _notificationEnabled
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _openNotificationSettings,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.sync, color: Colors.indigo.shade600),
                  ),
                  title: const Text(
                    '前台自动轮询导入（V2.1）',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '应用打开时每 $_autoImportIntervalSeconds 秒自动拉取通知入账',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _autoImportEnabled,
                  onChanged: (value) => _setAutoImportEnabled(value),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.timer, color: Colors.teal.shade600),
                  ),
                  title: const Text(
                    '轮询间隔',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    '仅对前台轮询生效，通知触发导入始终开启',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: DropdownButton<int>(
                    value: _autoImportIntervalSeconds,
                    underline: const SizedBox.shrink(),
                    items: _intervalOptions
                        .map(
                          (e) => DropdownMenuItem<int>(
                            value: e,
                            child: Text('$e秒'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _setAutoImportInterval(value);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(Icons.auto_awesome, color: Colors.orange.shade700),
                  ),
                  title: const Text(
                    '导入自动记账通知',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    '将通知识别结果写入账单',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: _isImportingAuto
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _isImportingAuto ? null : () => _importAutoRecords(),
                ),
              ],
            ),
          ),
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
            Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(Icons.info_outline, color: Colors.blue.shade600),
                  ),
                  title: const Text(
                    '清简记账',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle:
                      const Text('版本 2.2.0', style: TextStyle(fontSize: 12)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(Icons.person, color: Colors.deepPurple.shade400),
                  ),
                  title: const Text(
                    '作者',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle:
                      const Text(_authorName, style: TextStyle(fontSize: 12)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.link),
                  ),
                  title: const Text(
                    'GitHub 项目',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    _githubUrl,
                    style: TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.copy, color: Colors.grey),
                  onTap: _copyGithubUrl,
                ),
              ],
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
