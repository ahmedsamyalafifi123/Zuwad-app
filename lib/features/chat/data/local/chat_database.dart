import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Initialize database factory
void initializeDatabaseFactory() {
  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }
}

class ChatDatabase {
  static final ChatDatabase instance = ChatDatabase._init();
  static Database? _database;

  ChatDatabase._init() {
    initializeDatabaseFactory();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const boolType = 'INTEGER NOT NULL'; // 0 or 1

    await db.execute('''
    CREATE TABLE messages (
      id $idType,
      content $textType,
      sender_id $textType,
      sender_name $textType,
      recipient_id $textType,
      timestamp $textType,
      is_read $boolType,
      is_pending $boolType,
      conversation_id $textType
    )
    ''');

    // Index for faster conversation queries
    await db.execute(
      'CREATE INDEX idx_conversation ON messages(conversation_id, timestamp)',
    );
  }

  Future<String> createConversationId(String userId1, String userId2) async {
    // Always create conversation ID with smaller ID first for consistency
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // This method is no longer used as we're not storing messages locally
  Future<void> insertMessage(ChatMessage message, String recipientId) async {
    // No-op as we're not using local database for messages anymore
    return;
  }

  // This method is no longer used as we're not storing messages locally
  Future<List<ChatMessage>> getMessages(String userId1, String userId2) async {
    // Return empty list as we're not using local database anymore
    return [];
  }

  // This method is no longer used as we're not storing messages locally
  Future<void> markMessageAsRead(String messageId) async {
    // No-op as we're not using local database for messages anymore
    return;
  }

  // This method is no longer used as we're not storing messages locally
  Future<void> markAllMessagesAsRead(String conversationId) async {
    // No-op as we're not using local database for messages anymore
    return;
  }

  // This method is no longer used as we're not storing messages locally
  Future<void> deleteMessage(String messageId) async {
    // No-op as we're not using local database for messages anymore
    return;
  }

  // This method is no longer used as we're not storing messages locally
  Future<void> deleteConversation(String userId1, String userId2) async {
    // No-op as we're not using local database for messages anymore
    return;
  }

  // This method is no longer used as we're not storing messages locally
  Future<void> updateMessagePendingStatus(String messageId, bool isPending) async {
    // No-op as we're not using local database for messages anymore
    return;
  }

  // This method is no longer used as we're not storing messages locally
  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    // Return empty list as we're not using local database anymore
    return [];
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
