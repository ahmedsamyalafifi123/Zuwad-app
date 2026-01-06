import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../features/notifications/domain/models/notification.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'zuwad_notifications.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        title TEXT,
        body TEXT,
        type TEXT,
        is_read INTEGER,
        created_at TEXT,
        data TEXT
      )
    ''');
  }

  // Insert a notification
  Future<int> insertNotification(AppNotification notification) async {
    final db = await database;
    try {
      // Check if notification with this server_id already exists
      if (notification.id > 0) {
        final List<Map<String, dynamic>> existing = await db.query(
          'notifications',
          where: 'server_id = ?',
          whereArgs: [notification.id],
        );

        if (existing.isNotEmpty) {
          // Update existing notification if needed (e.g. read status changed on server)
          // For now, we prefer local state for is_read if strictly syncing,
          // but if we want to sync read status FROM server, we should update.
          // Let's update everything except maybe is_read if local is already read?
          // Simpler approach: Overwrite with server data to ensure sync.
          return await db.update(
            'notifications',
            _toDbMap(notification),
            where: 'server_id = ?',
            whereArgs: [notification.id],
          );
        }
      }

      return await db.insert(
        'notifications',
        _toDbMap(notification),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) print('Error inserting notification: $e');
      return -1;
    }
  }

  // Get all notifications
  Future<List<AppNotification>> getNotifications() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'notifications',
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
  Future<int> getUnreadCount() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notifications WHERE is_read = 0',
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
      // We try to match by server_id first (preferred) or local id
      // Since UI usually uses the model's ID which we mapped to server_id if available...
      // Wait, _fromDbMap uses 'id' (local) as the model ID?
      // Let's check _fromDbMap.
      // If the model ID is the local DB ID, then we should match by 'id'.
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
  Future<void> markAllAsRead() async {
    final db = await database;
    try {
      await db.update(
        'notifications',
        {'is_read': 1},
        where: 'is_read = 0',
      );
    } catch (e) {
      if (kDebugMode) print('Error marking all as read: $e');
    }
  }

  // Helper to convert AppNotification to DB Map
  Map<String, dynamic> _toDbMap(AppNotification n) {
    return {
      'server_id': n.id, // Store official server ID
      'title': n.title,
      'body': n.body,
      'type': n.type,
      'is_read': n.isRead ? 1 : 0,
      'created_at': n.createdAt.toIso8601String(),
      'data': n.data != null ? jsonEncode(n.data) : null,
    };
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
