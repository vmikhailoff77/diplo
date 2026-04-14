import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'warehouse.db');

    return await openDatabase(
      path,
      version: 5, // Увеличиваем версию для добавления change и type
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Таблица товаров с полем stock
    await db.execute('''
      CREATE TABLE products(
        uuid TEXT PRIMARY KEY,
        cod TEXT,
        name TEXT,
        article TEXT,
        unit TEXT,
        price REAL,
        stock REAL DEFAULT 0,
        contractor TEXT,
        last_updated TEXT
      )
    ''');

    // Таблица контрагентов
    await db.execute('''
      CREATE TABLE contractors(
        uuid TEXT PRIMARY KEY,
        cod TEXT,
        name TEXT,
        last_updated TEXT
      )
    ''');

    // Таблица истории остатков (расширенная)
    await db.execute('''
      CREATE TABLE stock_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_uuid TEXT NOT NULL,
        stock REAL NOT NULL,
        change REAL DEFAULT 0,
        type TEXT DEFAULT 'Расход',
        date TEXT NOT NULL,
        created_at TEXT,
        FOREIGN KEY (product_uuid) REFERENCES products(uuid),
        UNIQUE(product_uuid, date)
      )
    ''');

    await db.execute('CREATE INDEX idx_product_article ON products(article)');
    await db.execute('CREATE INDEX idx_product_name ON products(name)');
    await db.execute('CREATE INDEX idx_contractor_name ON contractors(name)');
    await db.execute('CREATE INDEX idx_stock_history_product_date ON stock_history(product_uuid, date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Обновление базы с версии $oldVersion до $newVersion');

    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN price REAL DEFAULT 0');
        print('✅ Добавлена колонка price');
      } catch (e) {
        print('Ошибка при добавлении price: $e');
      }
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN stock REAL DEFAULT 0');
        print('✅ Добавлена колонка stock');
      } catch (e) {
        print('Ошибка при добавлении stock: $e');
      }
    }

    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_uuid TEXT NOT NULL,
            stock REAL NOT NULL,
            date TEXT NOT NULL,
            created_at TEXT,
            FOREIGN KEY (product_uuid) REFERENCES products(uuid),
            UNIQUE(product_uuid, date)
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_history_product_date ON stock_history(product_uuid, date)');
        print('✅ Таблица stock_history создана');
      } catch (e) {
        print('Ошибка при создании stock_history: $e');
      }
    }

    if (oldVersion < 5) {
      try {
        // Добавляем колонки change и type
        await db.execute('ALTER TABLE stock_history ADD COLUMN change REAL DEFAULT 0');
        await db.execute('ALTER TABLE stock_history ADD COLUMN type TEXT DEFAULT "Расход"');
        print('✅ Добавлены колонки change и type');
      } catch (e) {
        print('Ошибка при добавлении change/type: $e');
      }
    }
  }

  // ============ ТОВАРЫ ============

  Future<void> saveProducts(List<dynamic> products) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('products');
      final now = DateTime.now().toIso8601String();
      for (var product in products) {
        double priceValue = 0.0;
        final priceData = product['price'];
        if (priceData != null) {
          if (priceData is num) {
            priceValue = priceData.toDouble();
          } else if (priceData is String && priceData.isNotEmpty) {
            priceValue = double.tryParse(priceData) ?? 0.0;
          }
        }

        await txn.insert('products', {
          'uuid': product['Ссылка'] ?? product['uuid'] ?? '',
          'cod': product['cod'] ?? '',
          'name': product['name'] ?? '',
          'article': product['article'] ?? '',
          'unit': product['unit'] ?? '',
          'price': priceValue,
          'stock': 0.0,
          'contractor': product['contractor'] ?? '',
          'last_updated': now,
        });
      }
    });
  }

  Future<void> updateStock(List<dynamic> stockList) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var stock in stockList) {
        double stockValue = 0.0;
        final stockData = stock['stock'];
        if (stockData != null) {
          if (stockData is num) {
            stockValue = stockData.toDouble();
          } else if (stockData is String && stockData.isNotEmpty) {
            stockValue = double.tryParse(stockData) ?? 0.0;
          }
        }

        await txn.update(
          'products',
          {'stock': stockValue},
          where: 'uuid = ?',
          whereArgs: [stock['uuid']],
        );

        await saveStockHistory(txn, stock['uuid'], stockValue.toInt());
      }
    });
    print('✅ Обновлено остатков: ${stockList.length}');
  }

  // Сохранение истории из движений (приходы/расходы с change и type)
  Future<void> saveStockMovements(List<dynamic> movements) async {
    if (movements.isEmpty) return;

    final db = await database;
    await db.transaction((txn) async {
      for (var movement in movements) {
        final productUuid = movement['uuid'];
        final date = movement['date'];
        final stock = (movement['stock'] as num?)?.toDouble() ?? 0.0;
        final change = (movement['change'] as num?)?.toDouble() ?? 0.0;
        final type = movement['type'] ?? 'Расход';

        await txn.insert(
          'stock_history',
          {
            'product_uuid': productUuid,
            'stock': stock,
            'change': change,
            'type': type,
            'date': date,
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    print('✅ Сохранено движений: ${movements.length}');
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query('products', orderBy: 'name');
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await database;
    return await db.query(
      'products',
      where: 'article LIKE ? OR name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name',
    );
  }

  // ============ КОНТРАГЕНТЫ ============

  Future<void> saveContractors(List<dynamic> contractors) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('contractors');
      final now = DateTime.now().toIso8601String();
      for (var contractor in contractors) {
        await txn.insert('contractors', {
          'uuid': contractor['Ссылка'] ?? contractor['uuid'] ?? '',
          'cod': contractor['cod'] ?? '',
          'name': contractor['name'] ?? '',
          'last_updated': now,
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getContractors() async {
    final db = await database;
    return await db.query('contractors', orderBy: 'name');
  }

  Future<List<Map<String, dynamic>>> searchContractors(String query) async {
    final db = await database;
    return await db.query(
      'contractors',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name',
    );
  }

  // ============ ОБЩИЕ ============

  Future<int> getProductCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getContractorCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM contractors');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<DateTime?> getLastUpdateDate(String table) async {
    final db = await database;
    final result = await db.query(
      table,
      columns: ['last_updated'],
      orderBy: 'last_updated DESC',
      limit: 1,
    );
    if (result.isNotEmpty && result.first['last_updated'] != null) {
      return DateTime.parse(result.first['last_updated'] as String);
    }
    return null;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('products');
    await db.delete('contractors');
    await db.delete('stock_history');
  }

  Future<List<Map<String, dynamic>>> getAllProductsWithStock() async {
    final db = await database;
    return await db.query(
      'products',
      where: 'stock > 0',
      orderBy: 'stock DESC',
      columns: ['uuid', 'name', 'stock', 'unit', 'article', 'cod', 'price', 'contractor'],
    );
  }

  // Сохранение истории (простой вариант, только остаток)
  Future<void> saveStockHistory(Transaction txn, String productUuid, int stock) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    await txn.insert(
      'stock_history',
      {
        'product_uuid': productUuid,
        'stock': stock,
        'date': today,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Ручное добавление истории
  Future<void> insertStockHistory(String productUuid, int stock) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T').first;

    await db.insert(
      'stock_history',
      {
        'product_uuid': productUuid,
        'stock': stock,
        'date': today,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Получение истории остатков за период (только stock)
  Future<List<Map<String, dynamic>>> getStockHistory({
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

    return await db.query(
      'stock_history',
      where: 'product_uuid = ? AND date >= ? AND date <= ?',
      whereArgs: [productUuid, startStr, endStr],
      orderBy: 'date ASC',
    );
  }

  // Получение полной истории (со stock, change, type)
  Future<List<Map<String, dynamic>>> getFullStockHistory({
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

    return await db.query(
      'stock_history',
      where: 'product_uuid = ? AND date >= ? AND date <= ?',
      whereArgs: [productUuid, startStr, endStr],
      orderBy: 'date ASC',
    );
  }
  // Получение всех движений за период для аналитики
  Future<List<Map<String, dynamic>>> getAllMovements({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;

    String formatDate(DateTime date) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    final startStr = formatDate(startDate);
    final endStr = formatDate(endDate);

    return await db.query(
      'stock_history',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );
  }
  // Добавьте в класс DatabaseHelper
  Future<List<Map<String, dynamic>>> getAllMovementsForTest() async {
    final db = await database;
    return await db.query('stock_history', limit: 10);
  }
}