import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class MovementsDatabase {
  static final MovementsDatabase _instance = MovementsDatabase._internal();
  factory MovementsDatabase() => _instance;
  MovementsDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'movements.db'); // Отдельный файл!

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Таблица для хранения ВСЕХ движений из 1С
    await db.execute('''
      CREATE TABLE movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_uuid TEXT NOT NULL,
        change REAL NOT NULL,
        type TEXT NOT NULL,
        stock_after REAL NOT NULL,
        date TEXT NOT NULL,
        created_at TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_movements_product_date ON movements(product_uuid, date)');
    print('✅ Таблица movements создана в movements.db');
  }

  // Сохраняем все движения из 1С
  Future<void> saveMovements(List<dynamic> movements) async {
    if (movements.isEmpty) return;

    final db = await database;
    await db.transaction((txn) async {
      int saved = 0;
      for (var movement in movements) {
        final productUuid = movement['uuid'];
        final date = movement['date'];
        final change = (movement['change'] as num?)?.toDouble() ?? 0.0;
        final type = movement['type'] ?? 'Расход';
        final stockAfter = (movement['stock'] as num?)?.toDouble() ?? 0.0;

        await txn.insert(
          'movements',
          {
            'product_uuid': productUuid,
            'change': change,
            'type': type,
            'stock_after': stockAfter,
            'date': date,
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        saved++;
      }
      print('✅ Сохранено движений в movements.db: $saved');
    });
  }

  // Получение всех движений для товара за период
  Future<List<Map<String, dynamic>>> getMovements({
    required String productUuid,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;

    String formatDate(DateTime date) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    final startStr = formatDate(startDate);
    final endStr = formatDate(endDate);

    print('🔍 MovementsDatabase запрос:');
    print('   UUID: $productUuid');
    print('   Период: $startStr - $endStr');

    final result = await db.query(
      'movements',
      where: 'product_uuid = ? AND date >= ? AND date <= ?',
      whereArgs: [productUuid, startStr, endStr],
      orderBy: 'date ASC',
    );

    print('   Найдено записей: ${result.length}');
    return result;
  }

  // Получить все движения для товара (без фильтра по дате)
  Future<List<Map<String, dynamic>>> getAllMovementsForProduct(String productUuid) async {
    final db = await database;
    return await db.query(
      'movements',
      where: 'product_uuid = ?',
      whereArgs: [productUuid],
      orderBy: 'date ASC',
    );
  }

  // Очистить все движения
  Future<void> clearAllMovements() async {
    final db = await database;
    await db.delete('movements');
    print('✅ Все движения удалены из movements.db');
  }

  // Получить количество движений для товара
  Future<int> getMovementsCount(String productUuid) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM movements WHERE product_uuid = ?',
      [productUuid],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}