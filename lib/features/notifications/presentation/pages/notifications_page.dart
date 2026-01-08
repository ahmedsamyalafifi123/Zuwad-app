import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/notification.dart';

/// Notifications page displaying all push notifications.
/// Matches the design style of the dashboard and other pages.
class NotificationsPage extends StatefulWidget {
  final int? studentId;
  const NotificationsPage({super.key, this.studentId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationRepository _repository = NotificationRepository();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Configure Arabic locale for timeago
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final notifications = await _repository.getNotifications(
        forceRefresh: forceRefresh,
        studentId: widget.studentId,
      );
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading notifications: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;

    final success = await _repository.markAsRead(notification.id);
    if (success && mounted) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification.copyWith(isRead: true);
        }
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    if (unreadCount == 0) return;

    final success = await _repository.markAllAsRead();
    if (success && mounted) {
      setState(() {
        _notifications =
            _notifications.map((n) => n.copyWith(isRead: true)).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تحديد جميع الإشعارات كمقروءة',
            style: TextStyle(fontFamily: 'Qatar'),
          ),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'lesson_reminder':
      case 'lesson':
        return Icons.school_rounded;
      case 'payment':
        return Icons.payment_rounded;
      case 'chat':
      case 'message':
        return Icons.chat_rounded;
      case 'schedule':
        return Icons.calendar_month_rounded;
      case 'report':
        return Icons.description_rounded;
      case 'competition':
        return Icons.emoji_events_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'lesson_reminder':
      case 'lesson':
        return const Color(0xFF2196F3);
      case 'payment':
        return const Color(0xFF4CAF50);
      case 'chat':
      case 'message':
        return const Color(0xFF9C27B0);
      case 'schedule':
        return const Color(0xFFF6C302);
      case 'report':
        return const Color(0xFFFF9800);
      case 'competition':
        return const Color(0xFFE91E63);
      default:
        return AppTheme.primaryColor;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    return timeago.format(dateTime, locale: 'ar');
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFF8b0628), // Deep Red Background
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromARGB(255, 255, 255, 255), // Warm cream white
                Color.fromARGB(255, 234, 234, 234), // Subtle gold tint
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(85, 0, 0, 0),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center: Title with badge
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'الإشعارات',
                        style: TextStyle(
                          fontFamily: 'Qatar',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF820c22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Qatar',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Right: Back Button (arrow_back for RTL)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color(0xFF8B0628), size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Left: Mark all as read button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _notifications.isNotEmpty && unreadCount > 0
                        ? IconButton(
                            onPressed: _markAllAsRead,
                            icon: const Icon(Icons.done_all_rounded),
                            color: const Color(0xFF4CAF50),
                            tooltip: 'تحديد الكل كمقروء',
                          )
                        : const SizedBox(width: 48),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF6C302),
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            const Text(
              'حدث خطأ في تحميل الإشعارات',
              style: TextStyle(
                fontFamily: 'Qatar',
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadNotifications(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontFamily: 'Qatar'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF6C302),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/images/Bell.json',
              width: 120,
              height: 120,
              animate: false,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد إشعارات',
              style: TextStyle(
                fontFamily: 'Qatar',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ستظهر الإشعارات الجديدة هنا',
              style: TextStyle(
                fontFamily: 'Qatar',
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotifications(forceRefresh: true),
      color: const Color(0xFFF6C302),
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          return _buildNotificationCard(_notifications[index]);
        },
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final iconColor = _getNotificationColor(notification.type);

    return GestureDetector(
      onTap: () => _markAsRead(notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: notification.isRead
                ? [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.85),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFF5F5F5),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: notification.isRead
              ? null
              : Border.all(color: const Color(0xFFF6C302), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getNotificationIcon(notification.type),
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 15,
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 13,
                            color: Colors.black.withOpacity(0.7),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getTimeAgo(notification.createdAt),
                              style: TextStyle(
                                fontFamily: 'Qatar',
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (!notification.isRead)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF820c22),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
