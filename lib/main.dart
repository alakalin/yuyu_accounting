import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'views/home/home_screen.dart';
import 'views/statistics/statistics_screen.dart';
import 'views/settings/settings_screen.dart';
import 'core/services/auto_bookkeeping_service.dart';
import 'providers/transaction_provider.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '清简记账',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  static const _autoImportKey = 'auto_import_enabled_v21';
  static const _autoImportIntervalKey = 'auto_import_interval_seconds_v21';

  int _currentIndex = 0;
  bool _isImportingAuto = false;
  Timer? _autoImportTimer;
  StreamSubscription<String>? _recordEventSubscription;
  bool _autoImportEnabled = false;
  int _autoImportIntervalSeconds = 12;

  final List<Widget> _pages = [
    const HomeScreen(),
    const StatisticsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenAutoRecordEvents();
    _reloadAutoImportConfig();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoImportTimer?.cancel();
    _recordEventSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Ensure UI reflects records inserted by native service while app was backgrounded.
      ref.invalidate(transactionListProvider);
      _reloadAutoImportConfig();
      _tryImportAutoRecords();
    }
  }

  void _listenAutoRecordEvents() {
    _recordEventSubscription?.cancel();
    _recordEventSubscription =
        AutoBookkeepingService.autoRecordEvents.listen((_) async {
      ref.invalidate(transactionListProvider);
      await _tryImportAutoRecords();
    });
  }

  Future<void> _reloadAutoImportConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_autoImportKey) ?? false;
    final interval = prefs.getInt(_autoImportIntervalKey) ?? 12;
    final safeInterval = (interval > 0 && interval <= 300) ? interval : 12;

    if (_autoImportEnabled == enabled &&
        _autoImportIntervalSeconds == safeInterval &&
        _autoImportTimer != null) {
      return;
    }

    _autoImportEnabled = enabled;
    _autoImportIntervalSeconds = safeInterval;

    _autoImportTimer?.cancel();
    if (!_autoImportEnabled) return;

    _autoImportTimer = Timer.periodic(
      Duration(seconds: _autoImportIntervalSeconds),
      (_) async => _tryImportAutoRecords(),
    );
  }

  Future<void> _tryImportAutoRecords() async {
    if (_isImportingAuto) return;

    final permissionEnabled =
        await AutoBookkeepingService.isNotificationListenerEnabled();
    if (!permissionEnabled) return;

    _isImportingAuto = true;
    try {
      final records = await AutoBookkeepingService.fetchPendingRecords();
      if (records.isEmpty) {
        // Fallback refresh for native-direct inserts with no pending queue items.
        ref.invalidate(transactionListProvider);
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

      ref.invalidate(transactionListProvider);
    } catch (_) {
      // Silent by design: avoid interrupting normal navigation flow.
    } finally {
      _isImportingAuto = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) async {
          setState(() {
            _currentIndex = index;
          });
          await _reloadAutoImportConfig();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long), label: '账单'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: '统计'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
