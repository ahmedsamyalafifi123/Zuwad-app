import 'package:flutter/foundation.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../../../core/services/database_service.dart';
import '../../domain/models/notification.dart';

/// Repository for managing notification data.
class NotificationRepository {
  final WordPressApi _api = WordPressApi();
  final DatabaseService _databaseService = DatabaseService();

  // Cache for notifications
  List<AppNotification>? _cachedNotifications;
  DateTime? _lastFetchTime;
  static const _cacheValidityDuration = Duration(minutes: 5);

  /// Get all notifications with optional pagination.
  /// Merges local DB data with API data (sync strategy).
  Future<List<AppNotification>> getNotifications({
    int page = 1,
    int perPage = 50,
    bool forceRefresh = false,
  }) async {
    // 1. Fetch from Local DB first (fastest)
    final localNotifications = await _databaseService.getNotifications();

    // 2. If force refresh or empty, try to sync from API
    if (forceRefresh || localNotifications.isEmpty) {
      try {
        final apiData =
            await _api.getNotifications(page: page, perPage: perPage);
        final apiNotifications =
            apiData.map((json) => AppNotification.fromJson(json)).toList();

        // Save new API notifications to DB
        for (var n in apiNotifications) {
          await _databaseService.insertNotification(n);
        }

        // Return the fresh cached data
        // We ideally fetch again from DB to ensure consistency,
        // OR just return the apiNotifications if they are valid.
        // Returning API notifications is faster for UI response.
        return await _databaseService.getNotifications();
      } catch (e) {
        if (kDebugMode) print('Error fetching API notifications: $e');
        // Fallback to local if API fails
        return localNotifications;
      }
    }

    return localNotifications;
  }

  /// Get count of unread notifications.
  Future<int> getUnreadCount() async {
    try {
      // Prioritize local Unread count as it reflects what user hasn't seen locally
      return await _databaseService.getUnreadCount();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting unread count: $e');
      }
      return 0;
    }
  }

  /// Mark a single notification as read.
  Future<bool> markAsRead(int notificationId) async {
    try {
      // Mark locally
      await _databaseService.markAsRead(notificationId);

      // Also try to mark on server (best effort)
      // Note: This might fail if the ID is local-only, but that's fine.
      _api.markNotificationAsRead(notificationId);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
      return false;
    }
  }

  /// Mark all notifications as read.
  Future<bool> markAllAsRead() async {
    try {
      // Mark locally
      await _databaseService.markAllAsRead();

      // Mark on server
      await _api.markAllNotificationsAsRead();

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error marking all notifications as read: $e');
      }
      return false;
    }
  }

  /// Clear the cache.
  void clearCache() {
    _cachedNotifications = null;
    _lastFetchTime = null;
  }
}
