// File: db_helper.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/historical_figure.dart';
import '../models/user_model.dart';

class DBHelper {
  // ================== SINGLETON ==================
  DBHelper._privateConstructor();
  static final DBHelper instance = DBHelper._privateConstructor();

  static Database? _db;
  static const _dbName = "in_old_days.db";
  static const _dbVersion = 33
  ;

  // ================== INITIALIZATION ==================
  static Future<void> prepareDatabaseFromAssets() async {
    try {
      if (_db != null && _db!.isOpen) await _db!.close();
      _db = await _initDB();
      debugPrint("✅ DB khởi tạo thành công!");
    } catch (e, st) {
      debugPrint("❌ Lỗi init DB: $e");
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  static Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbDir = await getDatabasesPath();
    final path = join(dbDir, _dbName);
    final file = File(path);

    bool shouldForceCopy = false;

    if (!(await file.exists())) {
      debugPrint("⏳ Copy DB lần đầu...");
      shouldForceCopy = true;
    } else {
      try {
        Database tempDb = await openReadOnlyDatabase(path);
        final oldVersion = await tempDb.getVersion();
        await tempDb.close();

        if (oldVersion < _dbVersion) {
          debugPrint("⚡ Upgrade DB $oldVersion → $_dbVersion");
        }
      } catch (e) {
        debugPrint("⚠️ Lỗi đọc DB: $e → copy lại từ assets để sửa lỗi");
        shouldForceCopy = true;
      }
    }

    if (shouldForceCopy) {
      await _copyDBFromAssets(path, force: true);
    }

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onOpen: (db) async {
        await _checkUserTableColumns(db);
        await _syncEventsWithLocations(db);
      },
      onUpgrade: (db, oldV, newV) async {
        debugPrint("✨ [onUpgrade] Cập nhật schema nếu cần ($oldV → $newV)");

        if (oldV < 15) {
          await _safeAddColumn(db, 'users', 'full_name', 'TEXT');
          await _safeAddColumn(db, 'users', 'created_at', 'TEXT');
          await _safeAddColumn(db, 'users', 'updated_at', 'TEXT');
        }

        if (oldV < 16) {
          await _safeAddColumn(db, 'users', 'avatar_url', 'TEXT');
          await _safeAddColumn(db, 'users', 'role', 'INTEGER DEFAULT 1');
        }

        // Add further upgrades here when needed
      },
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  // ================== HELPER ==================
  static Future<void> _safeAddColumn(Database db, String table, String column, String type) async {
    try {
      final cols = await db.rawQuery("PRAGMA table_info($table)");
      final names = cols.map((c) => c['name'] as String).toList();
      if (!names.contains(column)) {
        await db.execute("ALTER TABLE $table ADD COLUMN $column $type;");
        debugPrint("✅ Thêm cột '$column' vào bảng '$table'");
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi khi thêm cột $column vào $table: $e");
    }
  }

  static Future<void> _copyDBFromAssets(String path, {bool force = false}) async {
    final file = File(path);
    if (force && await file.exists()) {
      await file.delete(recursive: true);
      debugPrint("🔄 Xoá DB cũ, copy lại từ assets...");
    }

    await Directory(dirname(path)).create(recursive: true);
    final data = await rootBundle.load("assets/$_dbName");
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await file.writeAsBytes(bytes, flush: true);
    debugPrint("✅ Copy DB hoàn tất → $path");
  }

  // ================== CREATE TABLES ==================
  static Future<void> _onCreate(Database db, int version) async {
    debugPrint("🧱 [onCreate] Tạo bảng mới...");

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        full_name TEXT,
        avatar_url TEXT,
        role INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS locations (
        location_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        region TEXT,
        latitude REAL,
        longitude REAL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        event_id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        description TEXT,
        date TEXT,
        year INTEGER,
        location_id INTEGER,
        image_url TEXT,
        source TEXT,
        locationName TEXT,
        FOREIGN KEY (location_id) REFERENCES locations(location_id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS historical_figures (
        figure_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        dob TEXT,
        dod TEXT,
        image_url TEXT
      );
    ''');

    // Use the table name that matches your DB: figure_events (has id column in your DB)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS figure_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        figure_id INTEGER NOT NULL,
        event_id INTEGER NOT NULL,
        role TEXT,
        FOREIGN KEY (figure_id) REFERENCES historical_figures(figure_id) ON DELETE CASCADE,
        FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        favorite_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        event_id INTEGER,
        created_at TEXT
      );
    ''');
  }

  static Future<void> _checkUserTableColumns(Database db) async {
    try {
      final cols = await db.rawQuery("PRAGMA table_info(users)");
      final colNames = cols.map((c) => c['name'] as String).toList();

      Future<void> addIfMissing(String col, String type) async {
        if (!colNames.contains(col)) {
          await db.execute("ALTER TABLE users ADD COLUMN $col $type;");
        }
      }

      await addIfMissing('full_name', 'TEXT');
      await addIfMissing('created_at', 'TEXT');
      await addIfMissing('updated_at', 'TEXT');
      await addIfMissing('avatar_url', 'TEXT');
      await addIfMissing('role', 'INTEGER DEFAULT 1');
    } catch (e) {
      debugPrint("⚠️ Lỗi kiểm tra cột users: $e");
    }
  }

  // ================== QUERIES ==================
  static Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? args]) async {
    final db = await database;
    return await db.rawQuery(sql, args);
  }

  static Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = await database;
    return await db.insert(table, values);
  }

  // ================== USERS ==================
  static Future<Map<String, dynamic>?> authenticateUser(String email, String password) async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT * FROM users WHERE email = ? AND password_hash = ? LIMIT 1",
      [email, password],
    );
    return res.isNotEmpty ? res.first : null;
  }

  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final res = await db.query('users', where: 'email = ?', whereArgs: [email], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  static Future<UserModel?> getUserById(int userId) async {
    final db = await database;
    final res = await db.query('users', where: 'user_id = ?', whereArgs: [userId], limit: 1);
    return res.isNotEmpty ? UserModel.fromMap(res.first) : null;
  }

  /// Update user
  static Future<int> updateUser(UserModel user) async {
    final db = await database;
    final data = user.toDbMap();
    data.removeWhere((key, value) => value == null);
    return await db.update(
      'users',
      data,
      where: 'user_id = ?',
      whereArgs: [user.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ================== EVENTS ==================
  static Future<List<Map<String, dynamic>>> getAllEvents() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.*, l.latitude, l.longitude, l.name AS location_name, l.region
      FROM events e
      LEFT JOIN locations l ON e.location_id = l.location_id
      ORDER BY e.date ASC
    ''');
  }

  static Future<Map<String, dynamic>?> getEventById(int id) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT e.*, l.latitude, l.longitude, l.name AS location_name, l.region
      FROM events e
      LEFT JOIN locations l ON e.location_id = l.location_id
      WHERE e.event_id = ?
    ''', [id]);
    return res.isNotEmpty ? res.first : null;
  }

  /// Truy vấn theo ngày (so khớp phần ngày)
  static Future<List<Map<String, dynamic>>> eventsOfDay(DateTime date) async {
    final db = await database;
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    return await db.rawQuery(
      '''
      SELECT e.*, l.latitude, l.longitude, l.name AS location_name, l.region
      FROM events e
      LEFT JOIN locations l ON e.location_id = l.location_id
      WHERE date(e.date) = ?
      ORDER BY e.date DESC
      ''',
      [dateString],
    );
  }

  /// 🆕 Truy vấn theo Ngày và Tháng (bỏ qua Năm)
  static Future<List<Map<String, dynamic>>> eventsByDayAndMonth(int month, int day) async {
    final db = await database;
    // Định dạng MM-DD
    final monthDayString = '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    return await db.rawQuery(
      '''
      SELECT e.*, l.latitude, l.longitude, l.name AS location_name, l.region
      FROM events e
      LEFT JOIN locations l ON e.location_id = l.location_id
      WHERE strftime('%m-%d', e.date) = ?
      ORDER BY e.date DESC
      ''',
      [monthDayString],
    );
  }

  /// Truy vấn theo năm (sử dụng strftime để bền định dạng)
  static Future<List<Map<String, dynamic>>> eventsOfYear(int year) async {
    final db = await database;
    final yearString = year.toString();
    return await db.rawQuery('''
      SELECT e.*, l.latitude, l.longitude, l.name AS location_name, l.region
      FROM events e
      LEFT JOIN locations l ON e.location_id = l.location_id
      WHERE strftime('%Y', e.date) = ?
      ORDER BY e.date ASC
    ''', [yearString]);
  }

  /// Truy vấn theo tháng trong năm (sử dụng strftime)
  static Future<List<Map<String, dynamic>>> eventsOfMonth(int year, int month) async {
    final db = await database;
    final yearString = year.toString();
    final monthString = month.toString().padLeft(2, '0');
    return await db.rawQuery(
      '''
      SELECT e.*, l.latitude, l.longitude, l.name AS location_name, l.region
      FROM events e
      LEFT JOIN locations l ON e.location_id = l.location_id
      WHERE strftime('%Y', e.date) = ? AND strftime('%m', e.date) = ?
      ORDER BY e.date ASC
      ''',
      [yearString, monthString],
    );
  }

  /// Lấy events theo ID nhân vật (dùng bảng figure_events)
// ...
  /// Lấy events theo ID nhân vật (dùng bảng figure_events)
  static Future<List<Map<String, dynamic>>> getEventsByFigureId(int figureId) async {
    final db = await database;
    final rawResults = await db.rawQuery('''
      SELECT e.*, l.latitude, l.longitude, l.name AS location_name, l.region
      FROM events e
      JOIN figure_events fe ON e.event_id = fe.event_id
      LEFT JOIN locations l ON e.location_id = l.location_id
      WHERE fe.figure_id = ?
      ORDER BY e.date DESC
    ''', [figureId]);

    // 🌟 KHẮC PHỤC: Loại bỏ các sự kiện có event_id trùng lặp
    final Set<int> seenEventIds = {};
    final List<Map<String, dynamic>> uniqueEvents = [];

    for (var event in rawResults) {
      final eventId = event['event_id'] as int?;
      if (eventId != null && !seenEventIds.contains(eventId)) {
        seenEventIds.add(eventId);
        uniqueEvents.add(event);
      }
    }

    return uniqueEvents; // Trả về danh sách đã được làm sạch
  }
// ...
  // ================== FIGURES ==================
  static Future<List<HistoricalFigure>> getAllFigures() async {
    final db = await database;
    final maps = await db.query('historical_figures', orderBy: 'name ASC');
    return maps.map((m) => HistoricalFigure.fromMap(m)).toList();
  }

  // ================== FAVORITES ==================
  static Future<void> addFavorite(int eventId, {required int userId}) async {
    final db = await database;
    await db.insert(
      'favorites',
      {'user_id': userId, 'event_id': eventId, 'created_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<void> removeFavorite(int eventId, {required int userId}) async {
    final db = await database;
    await db.delete('favorites', where: 'event_id = ? AND user_id = ?', whereArgs: [eventId, userId]);
  }

  static Future<bool> isFavorite(int eventId, {required int userId}) async {
    final db = await database;
    final res = await db.query('favorites', where: 'event_id = ? AND user_id = ?', whereArgs: [eventId, userId]);
    return res.isNotEmpty;
  }

  static Future<List<Map<String, dynamic>>> getFavoriteEvents({required int userId}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.*, l.latitude, l.longitude, l.name AS location_name, l.region, f.created_at AS favorited_at
      FROM favorites f
      JOIN events e ON f.event_id = e.event_id
      LEFT JOIN locations l ON e.location_id = l.location_id
      WHERE f.user_id = ?
      ORDER BY f.created_at DESC
    ''', [userId]);
  }

  static Future<List<int>> getUserFavoriteIds({required int userId}) async {
    final db = await database;
    final res = await db.query('favorites', columns: ['event_id'], where: 'user_id = ?', whereArgs: [userId]);
    return res.map((m) => m['event_id'] as int).toList();
  }

  // ================== UTILITIES & DEBUG ==================
  static Future<void> debugPrintAllImages() async {
    final db = await database;
    final res = await db.rawQuery("SELECT event_id, image_url FROM events LIMIT 1000");
    for (var row in res) {
      debugPrint("📷 Event ${row['event_id']}: ${row['image_url']}");
    }
  }

  static Future<void> debugCheckFigureEvents(int figureId) async {
    final db = await database;

    final figureResult = await db.query('historical_figures', where: 'figure_id = ?', whereArgs: [figureId]);
    if (figureResult.isEmpty) {
      debugPrint('🚨 DB DEBUG ($figureId): Nhân vật (figure_id=$figureId) KHÔNG TỒN TẠI trong bảng historical_figures.');
      return;
    }
    debugPrint('✅ DB DEBUG ($figureId): Nhân vật "${figureResult.first['name']}" (ID=$figureId) ĐÃ TỒN TẠI.');

    final totalLinks = await db.query('figure_events', where: 'figure_id = ?', whereArgs: [figureId]);
    debugPrint('🔗 DB DEBUG ($figureId): Số lượng liên kết tìm thấy trong figure_events: ${totalLinks.length}');

    if (totalLinks.isEmpty) {
      debugPrint('❌ DB DEBUG ($figureId): KHÔNG CÓ liên kết nào trong bảng figure_events. Vấn đề nằm ở DỮ LIỆU CỦA FILE DB GỐC.');
      return;
    }

    final results = await getEventsByFigureId(figureId);
    debugPrint('🔎 DB DEBUG ($figureId): Kết quả truy vấn getEventsByFigureId(): ${results.length} sự kiện.');

    if (results.isNotEmpty) {
      debugPrint('🎉 DB DEBUG ($figureId): Đã tìm thấy sự kiện, chúng sẽ được hiển thị!');
    } else {
      debugPrint('⚠️ DB DEBUG ($figureId): Truy vấn chính bị rỗng dù có liên kết. Có thể event_id trong figure_events không tồn tại trong bảng events.');
    }
  }

  static Future<void> _syncEventsWithLocations(Database db) async {
    try {
      await db.execute('''
        UPDATE events 
        SET location_id = (
          SELECT l.location_id FROM locations l
          WHERE l.name = events.locationName
        )
        WHERE locationName IS NOT NULL
          AND EXISTS (SELECT 1 FROM locations l WHERE l.name = events.locationName);
      ''');
      debugPrint("🔗 Đồng bộ events.location_id hoàn tất");
    } catch (e) {
      debugPrint("⚠️ Lỗi sync events & locations: $e");
    }
  }

  // ================== EXTRA HELPERS / ALIASES ==================
  static Future<List<Map<String, dynamic>>> getEventsByYear(int year) => eventsOfYear(year);
  static Future<List<Map<String, dynamic>>> getEventsByMonth(int year, int month) => eventsOfMonth(year, month);

  static Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final res = await db.query('users');
    return res.map((row) => UserModel.fromMap(row)).toList();
  }
}