import 'dart:convert';
import 'package:flutter/services.dart';

class AutoBookkeepingRecord {
  final double amount;
  final int type;
  final String category;
  final String? note;
  final int timestamp;
  final String sourceApp;

  const AutoBookkeepingRecord({
    required this.amount,
    required this.type,
    required this.category,
    required this.timestamp,
    required this.sourceApp,
    this.note,
  });

  factory AutoBookkeepingRecord.fromMap(Map<String, dynamic> map) {
    return AutoBookkeepingRecord(
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as int,
      category: map['category'] as String,
      note: map['note'] as String?,
      timestamp: map['timestamp'] as int,
      sourceApp: map['sourceApp'] as String,
    );
  }
}

class AutoBookkeepingService {
  static const MethodChannel _channel = MethodChannel(
    'yuyu.auto_bookkeeping/channel',
  );
  static const EventChannel _eventChannel = EventChannel(
    'yuyu.auto_bookkeeping/events',
  );

  static Stream<String> get autoRecordEvents {
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => event?.toString() ?? 'new_record');
  }

  static Future<bool> openNotificationListenerSettings() async {
    final result = await _channel.invokeMethod<bool>(
      'openNotificationListenerSettings',
    );
    return result ?? false;
  }

  static Future<bool> isNotificationListenerEnabled() async {
    final result = await _channel.invokeMethod<bool>(
      'isNotificationListenerEnabled',
    );
    return result ?? false;
  }

  static Future<List<AutoBookkeepingRecord>> fetchPendingRecords() async {
    final raw =
        await _channel.invokeMethod<String>('fetchPendingAutoRecords') ?? '[]';
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((item) => AutoBookkeepingRecord.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList();
  }
}
