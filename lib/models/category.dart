class Category {
  final int? id;
  final String name;
  final int type; // 0: 支出, 1: 收入

  Category({this.id, required this.name, required this.type});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'type': type};
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as int,
    );
  }
}
