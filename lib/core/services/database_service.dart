import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../../features/notifications/domain/models/notification.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:convert';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  static bool _ffiInitialized = false;

  DatabaseService._internal() {
    _initializeFfi();
  }

  /// Initialize FFI for desktop platforms (Windows/Linux)
  void _initializeFfi() {
    if (_ffiInitialized) return;
    if (!kIsWeb) {
      if (Platform.isWindows || Platform.isLinux) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        if (kDebugMode) {
          print('DatabaseService: Initialized sqflite_common_ffi for desktop');
        }
      }
    }
    _ffiInitialized = true;
  }

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'zuwad_notifications.db');

    final db = await openDatabase(
      path,
      version: 3, // Bump version to force upgrade check
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Extra safety: active check if column exists (handles weird migration states)
    await _ensureSchema(db);

    return db;
  }

  Future<void> _ensureSchema(Database db) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info(notifications)');
      final hasStudentId = result.any((col) => col['name'] == 'student_id');

      if (!hasStudentId) {
        if (kDebugMode)
          print(
              'DatabaseService: student_id column missing, adding manually...');
        await db
            .execute('ALTER TABLE notifications ADD COLUMN student_id INTEGER');
        await db.execute(
            'CREATE INDEX idx_student_id ON notifications(student_id)');
      }
    } catch (e) {
      if (kDebugMode) print('Schema integrity check error: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        student_id INTEGER,
        title TEXT,
        body TEXT,
        type TEXT,
        is_read INTEGER,
        created_at TEXT,
        data TEXT
      )
    ''');
    // Add index for faster filtering
    await db
        .execute('CREATE INDEX idx_student_id ON notifications(student_id)');
  }

  /// Helper to upgrade DB - for dev/production safety
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Cover all versions < 3 (including 1 and potentially failed 2)
    if (oldVersion < 3) {
      try {
        // We use a try-catch block here because if version 2 'partially' ran or
        // if we are in a weird state, adding column might fail if it exists.
        // We rely on the error to skip if it exists, or one could check PRAGMA.
        // But _ensureSchema is the ultimate fallback now.
        await db
            .execute('ALTER TABLE notifications ADD COLUMN student_id INTEGER');
        await db.execute(
            'CREATE INDEX idx_student_id ON notifications(student_id)');
      } catch (e) {
        // Ignore "duplicate column" errors safely
        if (kDebugMode) print('Migration warning (likely column exists): $e');
      }
    }
  }

  // Insert a notification
  Future<int> insertNotification(AppNotification notification,
      {int? studentId}) async {
    final db = await database;
    try {
      // First, check if notification with this server_id already exists
      if (notification.id > 0) {
        final List<Map<String, dynamic>> existingById = await db.query(
          'notifications',
          where: 'server_id = ?',
          whereArgs: [notification.id],
        );

        if (existingById.isNotEmpty) {
          // Update existing record by server_id
          var newMap = _toDbMap(notification, studentId: studentId);

          // Preserve read status if already marked as read locally
          if (existingById.first['is_read'] == 1) {
            newMap['is_read'] = 1;
          }

          // Preserve existing student_id if not provided in update
          if (studentId == null && existingById.first['student_id'] != null) {
            newMap['student_id'] = existingById.first['student_id'];
          }

          return await db.update(
            'notifications',
            newMap,
            where: 'server_id = ?',
            whereArgs: [notification.id],
          );
        }
      }

      // Check for duplicate by title + body + student_id (prevents FCM + API sync duplicates)
      // This catches cases where FCM saved with server_id=0 and API tries to save with server_id>0
      String whereClause = 'title = ? AND body = ?';
      List<dynamic> whereArgs = [notification.title, notification.body];

      if (studentId != null) {
        whereClause += ' AND student_id = ?';
        whereArgs.add(studentId);
      }

      final List<Map<String, dynamic>> existingByContent = await db.query(
        'notifications',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (existingByContent.isNotEmpty) {
        final existing = existingByContent.first;
        final existingCreatedAt = DateTime.parse(existing['created_at']);
        final timeDiff = DateTime.now().difference(existingCreatedAt).inMinutes;

        // If same content exists within last 5 minutes, it's a duplicate
        if (timeDiff < 5) {
          if (kDebugMode) {
            print(
                'Duplicate notification detected (title: ${notification.title}), updating existing record');
          }

          // Update the existing record with server_id if we have one
          var updateMap = <String, dynamic>{};

          // Update server_id if the new notification has one and existing doesn't
          if (notification.id > 0 &&
              (existing['server_id'] == null || existing['server_id'] == 0)) {
            updateMap['server_id'] = notification.id;
          }

          // Update student_id if provided and not already set
          if (studentId != null && existing['student_id'] == null) {
            updateMap['student_id'] = studentId;
          }

          if (updateMap.isNotEmpty) {
            await db.update(
              'notifications',
              updateMap,
              where: 'id = ?',
              whereArgs: [existing['id']],
            );
          }

          return 0; // Skip duplicate insert
        }
      }

      // No duplicate found, insert new notification
      return await db.insert(
        'notifications',
        _toDbMap(notification, studentId: studentId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) print('Error inserting notification: $e');
      return -1;
    }
  }

  // Get all notifications
  Future<List<AppNotification>> getNotifications({int? studentId}) async {
    final db = await database;
    try {
      String? whereClause;
      List<dynamic> whereArgs = [];

      if (studentId != null) {
        whereClause = 'student_id = ?';
        whereArgs = [studentId];
      }

      final List<Map<String, dynamic>> maps = await db.query(
        'notifications',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );

      return List.generate(maps.length, (i) {
        return _fromDbMap(maps[i]);
      });
    } catch (e) {
      if (kDebugMode) print('Error getting notifications: $e');
      return [];
    }
  }

  // Get unread count
  Future<int> getUnreadCount({int? studentId}) async {
    final db = await database;
    try {
      String whereClause = 'is_read = 0';
      List<dynamic> whereArgs = [];

      if (studentId != null) {
        whereClause += ' AND student_id = ?';
        whereArgs.add(studentId);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notifications WHERE $whereClause',
        whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      if (kDebugMode) print('Error getting unread count: $e');
      return 0;
    }
  }

  // Mark as read
  Future<void> markAsRead(int id) async {
    final db = await database;
    try {
      await db.update(
        'notifications',
        {'is_read': 1},
        where: 'id = ? OR server_id = ?',
        whereArgs: [id, id],
      );
    } catch (e) {
      if (kDebugMode) print('Error marking as read: $e');
    }
  }

  // Mark all as read
  Future<void> markAllAsRead({int? studentId}) async {
    final db = await database;
    try {
      String whereClause = 'is_read = 0';
      List<dynamic> whereArgs = [];

      if (studentId != null) {
        whereClause += ' AND student_id = ?';
        whereArgs.add(studentId);
      }

      await db.update(
        'notifications',
        {'is_read': 1},
        where: whereClause,
        whereArgs: whereArgs,
      );
    } catch (e) {
      if (kDebugMode) print('Error marking all as read: $e');
    }
  }

  // Helper to convert AppNotification to DB Map
  Map<String, dynamic> _toDbMap(AppNotification n, {int? studentId}) {
    final map = {
      'server_id': n.id, // Store official server ID
      'title': n.title,
      'body': n.body,
      'type': n.type,
      'is_read': n.isRead ? 1 : 0,
      'created_at': n.createdAt.toIso8601String(),
      'data': n.data != null ? jsonEncode(n.data) : null,
    };

    if (studentId != null) {
      map['student_id'] = studentId;
    }

    return map;
  }

  // Helper to convert DB Map to AppNotification
  AppNotification _fromDbMap(Map<String, dynamic> map) {
    // Prefer server_id (if > 0) so that API operations like 'mark as read' work with the correct ID.
    // If server_id is missing or 0 (local only), fallback to local auto-increment id.
    final int effectiveId = (map['server_id'] != null && map['server_id'] > 0)
        ? map['server_id']
        : map['id'];

    return AppNotification(
      id: effectiveId,
      title: map['title'],
      body: map['body'],
      type: map['type'] ?? 'general',
      isRead: map['is_read'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      data: map['data'] != null ? jsonDecode(map['data']) : null,
    );
  }
}
