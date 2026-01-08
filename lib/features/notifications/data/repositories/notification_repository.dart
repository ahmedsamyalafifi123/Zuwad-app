import 'package:flutter/foundation.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../../../core/services/database_service.dart';
import '../../domain/models/notification.dart';

/// Repository for managing notification data.
class NotificationRepository {
  final WordPressApi _api = WordPressApi();
  final DatabaseService _databaseService = DatabaseService();

  /// Get all notifications with optional pagination.
  /// Merges local DB data with API data (sync strategy).
  Future<List<AppNotification>> getNotifications({
    int page = 1,
    int perPage = 50,
    bool forceRefresh = false,
    int? studentId,
  }) async {
    // 1. Fetch from Local DB first (fastest)
    // Now with studentId filtering support
    final localNotifications =
        await _databaseService.getNotifications(studentId: studentId);

    // 2. If force refresh or empty, try to sync from API
    // Always sync if studentId is provided to ensure we get that student's specific data
    // (though logic below handles merging)
    if (forceRefresh || localNotifications.isEmpty || studentId != null) {
      try {
        final apiData = await _api.getNotifications(
          page: page,
          perPage: perPage,
          studentId: studentId,
        );
        final apiNotifications =
            apiData.map((json) => AppNotification.fromJson(json)).toList();

        // Save new API notifications to DB
        for (var n in apiNotifications) {
          // Pass studentId to insert helper if available, to ensure association
          await _databaseService.insertNotification(n, studentId: studentId);
        }

        // Return the fresh cached data from DB
        // This ensures checking local DB for 'read' status even if API returns 'unread'
        return await _databaseService.getNotifications(studentId: studentId);
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
}
