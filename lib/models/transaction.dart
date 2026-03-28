class TransactionRecord {
  final int? id;
  final double amount;
  final int type; // 0: 支出, 1: 收入
  final int categoryId;
  final int timestamp;
  final String? note;

  TransactionRecord({
    this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.timestamp,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'categoryId': categoryId,
      'timestamp': timestamp,
      'note': note,
    };
  }

  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      id: map['id'] as int?,
      amount: map['amount'] as double,
      type: map['type'] as int,
      categoryId: map['categoryId'] as int,
      timestamp: map['timestamp'] as int,
      note: map['note'] as String?,
    );
  }
}
