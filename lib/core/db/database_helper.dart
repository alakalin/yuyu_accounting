import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('accounting.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // 升级数据库 Version 从 1 升至 2 以保证能加载更全的分类列表
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS transactions');
      await db.execute('DROP TABLE IF EXISTS categories');
      await _createDB(db, newVersion);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''


      CREATE TABLE categories (


        id INTEGER PRIMARY KEY AUTOINCREMENT,


        name TEXT NOT NULL,


        type INTEGER NOT NULL


      )


    ''');

    await db.execute('''


      CREATE TABLE transactions (


        id INTEGER PRIMARY KEY AUTOINCREMENT,


        amount REAL NOT NULL,


        type INTEGER NOT NULL,


        categoryId INTEGER NOT NULL,


        timestamp INTEGER NOT NULL,


        note TEXT,


        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE CASCADE


      )


    ''');

    await _insertInitialCategories(db);
  }

  Future<void> _insertInitialCategories(Database db) async {
    final initialCategories = [
      // 支出类别 (0)
      Category(name: '餐饮', type: 0),
      Category(name: '交通', type: 0),
      Category(name: '购物', type: 0),
      Category(name: '娱乐', type: 0),
      Category(name: '住房', type: 0),
      Category(name: '日常', type: 0),
      Category(name: '医疗', type: 0),
      Category(name: '教育', type: 0),
      // 收入类别 (1)
      Category(name: '工资', type: 1),
      Category(name: '兼职', type: 1),
      Category(name: '理财', type: 1),
      Category(name: '礼金', type: 1),
      Category(name: '其他', type: 1),
    ];

    for (final category in initialCategories) {
      await db.insert('categories', category.toMap());
    }
  }

  Future<int> insertCategory(Category category) async {
    final db = await instance.database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories');
    return result.map((map) => Category.fromMap(map)).toList();
  }

  Future<int?> getCategoryIdByNameAndType(String name, int type) async {
    final db = await instance.database;
    final result = await db.query(
      'categories',
      where: 'name = ? AND type = ?',
      whereArgs: [name, type],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }
    return result.first['id'] as int;
  }

  Future<int> insertTransaction(TransactionRecord transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<bool> hasPotentialDuplicateAutoTransaction({
    required double amount,
    required int type,
    required int timestamp,
  }) async {
    final db = await instance.database;
    final minTs = timestamp - 60000;
    final maxTs = timestamp + 60000;

    final result = await db.query(
      'transactions',
      where:
          'amount = ? AND type = ? AND timestamp BETWEEN ? AND ? AND note LIKE ?',
      whereArgs: [amount, type, minTs, maxTs, '%通知自动识别%'],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<List<TransactionRecord>> getAllTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'timestamp DESC');
    return result.map((map) => TransactionRecord.fromMap(map)).toList();
  }

  Future<int> updateTransaction(TransactionRecord transaction) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
