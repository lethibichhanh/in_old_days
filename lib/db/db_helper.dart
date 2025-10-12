import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../models/historical_figure.dart';
import '../models/user_model.dart';

class DBHelper {
  // ================== SINGLETON ==================
  DBHelper._privateConstructor();
  static final DBHelper instance = DBHelper._privateConstructor();

  static Database? _db;
  static const _dbName = "in_old_days.db";
  // ✅ Tăng version lên 16 để đảm bảo các thay đổi schema (thêm role/avatar_url) được áp dụng
  static const _dbVersion = 23;

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

    // Biến kiểm tra xem có cần force copy không
    bool shouldForceCopy = false;

    if (!(await file.exists())) {
      debugPrint("⏳ Copy DB lần đầu...");
      shouldForceCopy = true; // Lần đầu thì phải copy
    } else {
      // Kiểm tra version hiện tại của DB
      try {
        Database tempDb = await openReadOnlyDatabase(path);
        final oldVersion = await tempDb.getVersion();
        await tempDb.close();

        if (oldVersion < _dbVersion) {
          debugPrint("⚡ Upgrade DB $oldVersion → $_dbVersion");
          // Nếu phiên bản cũ hơn, ta thực hiện force copy để áp dụng các thay đổi trong file DB assets
          // HOẶC logic onUpgrade sẽ chạy.
          // Ta TẮT force copy ở đây và TIN TƯỞNG vào onUpgrade để giữ dữ liệu cũ (nếu có).
          // Nếu bạn muốn LÀM MỚI DATABASE MỖI KHI TĂNG VERSION, hãy bỏ comment dòng dưới:
          // shouldForceCopy = true;
        }
      } catch (e) {
        debugPrint("⚠️ Lỗi đọc DB: $e → copy lại từ assets để sửa lỗi");
        shouldForceCopy = true;
      }
    }

    if (shouldForceCopy) {
      await _copyDBFromAssets(path, force: true);
    }

    // Mở DB với onCreate/onUpgrade
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onOpen: (db) async {
        // Sau khi DB được mở, ta chạy lại logic kiểm tra cột, đề phòng onUpgrade bị miss.
        await _checkUserTableColumns(db);
        await _syncEventsWithLocations(db);
      },
      onUpgrade: (db, oldV, newV) async {
        debugPrint("✨ [onUpgrade] Cập nhật schema nếu cần ($oldV → $newV)");

        // Luôn chạy an toàn các lần nâng cấp trước
        if (oldV < 15) {
          await _safeAddColumn(db, 'users', 'full_name', 'TEXT');
          await _safeAddColumn(db, 'users', 'created_at', 'TEXT');
          await _safeAddColumn(db, 'users', 'updated_at', 'TEXT');
        }

        // 🔴 LOGIC THÊM CHO VERSION 16: Thêm role và avatar_url
        if (oldV < 16) {
          await _safeAddColumn(db, 'users', 'avatar_url', 'TEXT');
          // Cột role có thể gây lỗi mismatch, ta thêm nó với giá trị mặc định (DEFAULT 1)
          // nếu cơ sở dữ liệu cho phép (SQLite không thực sự cần kiểu TEXT/INTEGER cho phép NULL)
          // Để tránh lỗi datatype mismatch, ta dùng INTEGER với DEFAULT 1 (user thường)
          await _safeAddColumn(db, 'users', 'role', 'INTEGER DEFAULT 1');
        }
      },
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  // Helper để thêm cột một cách an toàn
  static Future<void> _safeAddColumn(Database db, String tableName, String columnName, String columnType) async {
    try {
      final cols = await db.rawQuery("PRAGMA table_info($tableName)");
      final colNames = cols.map((c) => c['name'].toString()).toList();
      if (!colNames.contains(columnName)) {
        await db.execute("ALTER TABLE $tableName ADD COLUMN $columnName $columnType;");
        debugPrint("✅ Thêm cột '$columnName' vào bảng '$tableName'");
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi khi thêm cột '$columnName' vào '$tableName': $e");
    }
  }

  static Future<void> _copyDBFromAssets(String path, {bool force = false}) async {
    final file = File(path);
    if (force && await file.exists()) {
      await file.delete(recursive: true);
      debugPrint("🔄 Xoá DB cũ, copy lại từ assets...");
    }

    // Đảm bảo thư mục tồn tại trước khi ghi file
    await Directory(dirname(path)).create(recursive: true);

    ByteData data = await rootBundle.load("assets/$_dbName");
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await file.writeAsBytes(bytes, flush: true);
    debugPrint("✅ Copy DB vào $path");
  }

  // ================== CREATION ==================
  static Future<void> _onCreate(Database db, int version) async {
    debugPrint("🧱 [onCreate] Tạo bảng mới...");

    // 🔴 ĐÃ SỬA: Thay 'id' thành 'user_id' và THÊM 'avatar_url' và 'role' để đồng bộ
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

    // ... (Giữ nguyên các bảng khác)

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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_figures (
        event_id INTEGER NOT NULL,
        figure_id INTEGER NOT NULL,
        PRIMARY KEY (event_id, figure_id),
        FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE,
        FOREIGN KEY (figure_id) REFERENCES historical_figures(figure_id) ON DELETE CASCADE
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
      final colNames = cols.map((c) => c['name'].toString()).toList();
      // Đảm bảo các cột cần thiết cho phiên bản mới có sẵn
      if (!colNames.contains('full_name')) {
        await db.execute("ALTER TABLE users ADD COLUMN full_name TEXT;");
      }
      if (!colNames.contains('created_at')) {
        await db.execute("ALTER TABLE users ADD COLUMN created_at TEXT;");
      }
      if (!colNames.contains('updated_at')) {
        await db.execute("ALTER TABLE users ADD COLUMN updated_at TEXT;");
      }
      // 🔴 THÊM KIỂM TRA CHO CÁC CỘT MỚI: avatar_url và role
      if (!colNames.contains('avatar_url')) {
        await db.execute("ALTER TABLE users ADD COLUMN avatar_url TEXT;");
      }
      if (!colNames.contains('role')) {
        await db.execute("ALTER TABLE users ADD COLUMN role INTEGER DEFAULT 1;");
      }
    } catch (e) {
      debugPrint("⚠️ Không thể kiểm tra bảng users: $e");
    }
  }

  // ================== CRUD ==================
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
    // 🔴 LƯU Ý: Nếu tên bảng cũ là 'users_id', bạn cần đổi thành 'users' trong code,
    // hoặc đổi tên bảng trong DB assets/onCreate. Tôi sửa lại thành 'users' theo logic chung.
    final res = await db.rawQuery(
      "SELECT * FROM users WHERE email = ? AND password_hash = ? LIMIT 1",
      [email, password],
    );
    // Trả về Map<String, dynamic> chứa tất cả thông tin người dùng
    return res.isNotEmpty ? res.first : null;
  }

  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    // 🔴 LƯU Ý: Tên bảng ở đây cũng được sửa thành 'users'
    final res = await db.query('users', where: 'email = ?', whereArgs: [email], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }
  static Future<UserModel?> getUserById(int userId) async {
    final db = await database;
    final res = await db.query(
      'users', // ✅ Đổi từ userTable sang chuỗi 'users'
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (res.isNotEmpty) {
      return UserModel.fromMap(res.first);
    }
    return null;
  }

  /// Cập nhật thông tin người dùng trong bảng `users`
  static Future<int> updateUser(UserModel user) async {
    final db = await database;

    // ✅ Dùng toDbMap() để chuyển đúng định dạng cột DB
    final data = user.toDbMap();

    // ⚙️ Loại bỏ các giá trị null (tránh override cột bằng null)
    data.removeWhere((key, value) => value == null);

    // ✅ Thực hiện update theo user_id
    return await db.update(
      'users',
      data,
      where: 'user_id = ?',
      whereArgs: [user.id],
      conflictAlgorithm: ConflictAlgorithm.replace, // đảm bảo không lỗi ghi đè
    );
  }

  // ... (Giữ nguyên các hàm khác)
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

  static Future<List<Map<String, dynamic>>> eventsOfYear(int year) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.*, l.latitude, l.longitude, l.name AS location_name, l.region
      FROM events e
      LEFT JOIN locations l ON e.location_id = l.location_id
      WHERE e.year = ? 
      ORDER BY e.date ASC
    ''', [year]);
  }

  static Future<List<Map<String, dynamic>>> eventsOfMonth(int year, int month) async {
    final db = await database;
    final start = "$year-${month.toString().padLeft(2, '0')}-01";
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final end = "$nextYear-${nextMonth.toString().padLeft(2, '0')}-01";

    return await db.rawQuery(
      '''
      SELECT e.*, l.latitude, l.longitude, l.name AS location_name, l.region
      FROM events e
      LEFT JOIN locations l ON e.location_id = l.location_id
      WHERE date(e.date) >= ? AND date(e.date) < ? 
      ORDER BY e.date ASC
      ''',
      [start, end],
    );
  }

  // Hàm chính để lấy sự kiện theo ID nhân vật
  static Future<List<Map<String, dynamic>>> getEventsByFigureId(int figureId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.*, l.latitude, l.longitude, l.name AS location_name, l.region
      FROM events e
      JOIN event_figures ef ON e.event_id = ef.event_id
      LEFT JOIN locations l ON e.location_id = l.location_id
      WHERE ef.figure_id = ?
      ORDER BY e.date DESC
    ''', [figureId]);
  }

  // ================== FIGURES ==================
  static Future<List<HistoricalFigure>> getAllFigures() async {
    final db = await database;
    final maps = await db.query('historical_figures', orderBy: 'name ASC');
    return maps.map((m) => HistoricalFigure.fromMap(m)).toList();
  }

  // ================== FAVORITES ==================
  // 💡 ĐÃ SỬA: Yêu cầu userId bắt buộc và loại bỏ '?? 1'
  static Future<void> addFavorite(int eventId, {required int userId}) async {
    final db = await database;
    await db.insert(
      'favorites',
      {'user_id': userId, 'event_id': eventId, 'created_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // 💡 ĐÃ SỬA: Yêu cầu userId bắt buộc và loại bỏ '?? 1'
  static Future<void> removeFavorite(int eventId, {required int userId}) async {
    final db = await database;
    await db.delete('favorites', where: 'event_id = ? AND user_id = ?', whereArgs: [eventId, userId]);
  }

  // 💡 ĐÃ SỬA: Yêu cầu userId bắt buộc và loại bỏ '?? 1'
  static Future<bool> isFavorite(int eventId, {required int userId}) async {
    final db = await database;
    final res = await db.query('favorites', where: 'event_id = ? AND user_id = ?', whereArgs: [eventId, userId]);
    return res.isNotEmpty;
  }

  // 💡 ĐÃ SỬA: Yêu cầu userId bắt buộc và loại bỏ '?? 1'
  static Future<List<Map<String, dynamic>>> getFavoriteEvents({required int userId}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.*, f.created_at AS favorited_at
      FROM favorites f
      JOIN events e ON f.event_id = e.event_id
      WHERE f.user_id = ?
      ORDER BY f.created_at DESC
    ''', [userId]);
  }

  // Hàm lấy ID sự kiện yêu thích
  static Future<List<int>> getUserFavoriteIds({required int userId}) async {
    final db = await database;
    final res = await db.query('favorites', columns: ['event_id'], where: 'user_id = ?', whereArgs: [userId]);
    // Trả về danh sách các event_id (int)
    return res.map((m) => m['event_id'] as int).toList();
  }


  // ================== UTILITIES ==================

  static Future<void> debugPrintAllImages() async {
    final db = await database;
    final res = await db.rawQuery("SELECT event_id, image_url FROM events LIMIT 378");
    for (var row in res) {
      debugPrint("📷 Event ${row['event_id']}: ${row['image_url']}");
    }
  }

  static Future<void> debugCheckFigureEvents(int figureId) async {
    final db = await database;

    // 1. Kiểm tra ID nhân vật có tồn tại không
    final figureResult = await db.query('historical_figures', where: 'figure_id = ?', whereArgs: [figureId]);
    if (figureResult.isEmpty) {
      debugPrint('🚨 DB DEBUG ($figureId): Nhân vật (figure_id=$figureId) KHÔNG TỒN TẠI trong bảng historical_figures.');
      return;
    }
    debugPrint('✅ DB DEBUG ($figureId): Nhân vật "${figureResult.first['name']}" (ID=$figureId) ĐÃ TỒN TẠI.');

    // 2. Kiểm tra liên kết trong bảng trung gian (event_figures)
    final totalLinks = await db.query('event_figures', where: 'figure_id = ?', whereArgs: [figureId]);
    debugPrint('🔗 DB DEBUG ($figureId): Số lượng liên kết tìm thấy trong event_figures: ${totalLinks.length}');

    if (totalLinks.isEmpty) {
      debugPrint('❌ DB DEBUG ($figureId): KHÔNG CÓ liên kết nào trong bảng event_figures. Vấn đề nằm ở DỮ LIỆU CỦA FILE DB GỐC.');
      return;
    }

    // 3. Kiểm tra kết quả truy vấn cuối cùng (hàm chính)
    final results = await getEventsByFigureId(figureId);
    debugPrint('🔎 DB DEBUG ($figureId): Kết quả truy vấn getEventsByFigureId(): ${results.length} sự kiện.');

    if (results.isNotEmpty) {
      debugPrint('🎉 DB DEBUG ($figureId): Đã tìm thấy sự kiện, chúng sẽ được hiển thị!');
    } else {
      debugPrint('⚠️ DB DEBUG ($figureId): Trưy vấn chính bị rỗng dù có liên kết. Có thể event_id trong event_figures không tồn tại trong bảng events.');
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

  // ================== USERS (EXTENSIONS) ==================
  static Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final res = await db.query('users');
    return res.map((row) => UserModel.fromMap(row)).toList();
  }

  // ================== ALIASES ==================
  static Future<List<Map<String, dynamic>>> getEventsByYear(int year) => eventsOfYear(year);
  static Future<List<Map<String, dynamic>>> getEventsByMonth(int year, int month) => eventsOfMonth(year, month);
}