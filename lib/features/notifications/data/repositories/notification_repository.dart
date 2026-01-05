import 'package:flutter/foundation.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../domain/models/notification.dart';

/// Repository for managing notification data.
class NotificationRepository {
  final WordPressApi _api = WordPressApi();

  // Cache for notifications
  List<AppNotification>? _cachedNotifications;
  DateTime? _lastFetchTime;
  static const _cacheValidityDuration = Duration(minutes: 5);

  /// Get all notifications with optional pagination.
  Future<List<AppNotification>> getNotifications({
    int page = 1,
    int perPage = 50,
    bool forceRefresh = false,
  }) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh &&
        _cachedNotifications != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheValidityDuration) {
      return _cachedNotifications!;
    }

    try {
      final data = await _api.getNotifications(page: page, perPage: perPage);
      final notifications =
          data.map((json) => AppNotification.fromJson(json)).toList();

      // Update cache
      _cachedNotifications = notifications;
      _lastFetchTime = DateTime.now();

      return notifications;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching notifications: $e');
      }
      // Return cached data on error if available
      return _cachedNotifications ?? [];
    }
  }

  /// Get count of unread notifications.
  Future<int> getUnreadCount() async {
    try {
      return await _api.getUnreadNotificationCount();
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
      final success = await _api.markNotificationAsRead(notificationId);
      if (success) {
        // Update cache
        if (_cachedNotifications != null) {
          final index =
              _cachedNotifications!.indexWhere((n) => n.id == notificationId);
          if (index != -1) {
            _cachedNotifications![index] =
                _cachedNotifications![index].copyWith(isRead: true);
          }
        }
      }
      return success;
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
      final success = await _api.markAllNotificationsAsRead();
      if (success) {
        // Update cache
        if (_cachedNotifications != null) {
          _cachedNotifications = _cachedNotifications!
              .map((n) => n.copyWith(isRead: true))
              .toList();
        }
      }
      return success;
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
