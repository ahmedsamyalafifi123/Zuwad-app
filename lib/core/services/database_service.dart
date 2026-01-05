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
      await db.update(
        'notifications',
        {'is_read': 1},
        // We use the local ID or server ID depending on what's available
        // For simplicity, let's assume we might pass local ID here,
        // but typically the UI operates on Notification models which have IDs.
        // If the 'id' passed is the local auto-increment ID:
        where: 'id = ?',
        whereArgs: [id],
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
      'server_id': n.id, // Store official server ID separately
      // If server_id is 0 (local generation), we just store it as 0
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
    return AppNotification(
      id: map['id'], // Use local ID for UI operations
      title: map['title'],
      body: map['body'],
      type: map['type'] ?? 'general',
      isRead: map['is_read'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      data: map['data'] != null ? jsonDecode(map['data']) : null,
    );
  }
}
