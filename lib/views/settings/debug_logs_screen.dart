import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';

class DebugLogsScreen extends StatefulWidget {
  const DebugLogsScreen({Key? key}) : super(key: key);

  @override
  State<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends State<DebugLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final db = await DatabaseHelper.instance.database;
      // create table just in case it doesn't exist yet
      await db.execute(
          "CREATE TABLE IF NOT EXISTS debug_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, time INTEGER, pkg TEXT, title TEXT, content TEXT, reason TEXT)");
      final result = await db.rawQuery('SELECT * FROM debug_logs ORDER BY time DESC LIMIT 200');
      setState(() {
        _logs = result;
        _loading = false;
      });
    } catch (e) {
      print(e);
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.execute('DELETE FROM debug_logs');
      _loadLogs();
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知捕获日志 (进阶排查)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Text(
                    '暂无日志记录\n\n请在屏幕锁定、熄屏，或者App在后台时，\n接收一笔含有金额的微信支付/转账，\n再回到这里点击右上角刷新查看。',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: _logs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final time = DateTime.fromMillisecondsSinceEpoch(log['time'] as int);
                    return ListTile(
                      title: Text(
                        '[${log['reason']}]',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: log['reason'].toString().startsWith('SUCCESS') ? Colors.green : Colors.red),
                      ),
                      subtitle: SelectableText(
                        'Time: $time\nApp: ${log['pkg']}\nTitle: ${log['title']}\nContent: ${log['content']}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
    );
  }
}
