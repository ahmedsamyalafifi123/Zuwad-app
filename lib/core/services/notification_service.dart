import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/wordpress_api.dart';

/// Top-level function to handle background FCM messages
/// Must be a top-level function (not a class method)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
    print('Message data: ${message.data}');
  }
  // Local notifications are handled automatically by FCM for background messages
}

/// Centralized notification service for managing push and local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final WordPressApi _api = WordPressApi();

  bool _isInitialized = false;

  /// Android notification channel for high importance notifications
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'zuwad_high_importance',
    'إشعارات زواد',
    description: 'إشعارات مهمة من أكاديمية زواد',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permission
      await _requestPermission();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Create Android notification channel
      await _createAndroidChannel();

      // Set up FCM message handlers
      _setupFCMHandlers();

      // Get and store FCM token
      await getDeviceToken();

      _isInitialized = true;
      if (kDebugMode) {
        print('NotificationService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing NotificationService: $e');
      }
    }
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('Notification permission status: ${settings.authorizationStatus}');
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Create Android notification channel
  Future<void> _createAndroidChannel() async {
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  /// Set up FCM message handlers
  void _setupFCMHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Check if app was opened from a notification
    _checkInitialMessage();
  }

  /// Handle foreground FCM message
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Received foreground message: ${message.messageId}');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');
    }

    // Show local notification for foreground messages
    final notification = message.notification;
    if (notification != null) {
      showLocalNotification(
        title: notification.title ?? 'إشعار جديد',
        body: notification.body ?? '',
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handle notification tap when app is opened from background/terminated
  void _handleNotificationOpen(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification opened: ${message.messageId}');
      print('Data: ${message.data}');
    }

    // Navigate based on notification type
    _navigateBasedOnPayload(message.data);
  }

  /// Check if app was opened from a notification
  Future<void> _checkInitialMessage() async {
    final message = await _firebaseMessaging.getInitialMessage();
    if (message != null) {
      if (kDebugMode) {
        print('App opened from terminated state via notification');
      }
      _navigateBasedOnPayload(message.data);
    }
  }

  /// Navigate based on notification payload
  void _navigateBasedOnPayload(Map<String, dynamic> data) {
    // TODO: Implement navigation based on notification type
    // Example:
    // if (data['type'] == 'chat') {
    //   // Navigate to chat
    // } else if (data['type'] == 'lesson_reminder') {
    //   // Navigate to dashboard
    // }
    if (kDebugMode) {
      print('Navigate based on payload: $data');
    }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Local notification tapped: ${response.payload}');
    }

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateBasedOnPayload(data);
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing notification payload: $e');
        }
      }
    }
  }

  /// Get FCM device token
  Future<String?> getDeviceToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }

      // Store token locally
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print('FCM Token refreshed: $newToken');
        }
        _onTokenRefresh(newToken);
      });

      return token;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    // Re-register token with backend API
    await registerTokenWithBackend();
  }

  /// Register device token with backend API
  /// Call this after user logs in
  Future<bool> registerTokenWithBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');

      if (token == null) {
        if (kDebugMode) {
          print('No FCM token to register');
        }
        return false;
      }

      final platform = Platform.isAndroid ? 'android' : 'ios';
      final result = await _api.registerDeviceToken(token, platform: platform);

      if (kDebugMode) {
        print('Device token registration result: $result');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error registering token with backend: $e');
      }
      return false;
    }
  }

  /// Show a local notification immediately
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    final notificationId = id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );

    if (kDebugMode) {
      print('Showed local notification: $title - $body');
    }
  }

  /// Schedule a lesson reminder notification
  /// Schedules notifications at specified intervals before the lesson
  Future<void> scheduleLessonReminder({
    required DateTime lessonTime,
    required String lessonName,
    required String teacherName,
    int? lessonId,
  }) async {
    final now = DateTime.now();
    final id = lessonId ?? lessonTime.millisecondsSinceEpoch ~/ 1000;

    // Cancel any existing reminders for this lesson
    await cancelLessonReminder(id);

    // Define reminder intervals (before lesson starts)
    final reminders = [
      {
        'hours': 6,
        'suffix': '6h',
        'message': 'درسك مع $teacherName بعد 6 ساعات'
      },
      {
        'hours': 1,
        'suffix': '1h',
        'message': 'درسك مع $teacherName بعد ساعة واحدة'
      },
      {
        'minutes': 15,
        'suffix': '15m',
        'message': 'درسك مع $teacherName يبدأ بعد 15 دقيقة!'
      },
    ];

    for (final reminder in reminders) {
      Duration beforeLesson;
      if (reminder.containsKey('hours')) {
        beforeLesson = Duration(hours: reminder['hours'] as int);
      } else {
        beforeLesson = Duration(minutes: reminder['minutes'] as int);
      }

      final scheduledTime = lessonTime.subtract(beforeLesson);

      // Only schedule if the time is in the future
      if (scheduledTime.isAfter(now)) {
        final notificationId =
            _generateNotificationId(id, reminder['suffix'] as String);

        // Calculate delay from now
        final delay = scheduledTime.difference(now);

        // Schedule using a delayed future (simpler than timezone-based scheduling)
        _scheduleDelayedNotification(
          id: notificationId,
          title: 'تذكير بالدرس - $lessonName',
          body: reminder['message'] as String,
          delay: delay,
          payload: jsonEncode({
            'type': 'lesson_reminder',
            'lesson_id': id,
            'lesson_time': lessonTime.toIso8601String(),
          }),
        );

        if (kDebugMode) {
          print(
              'Scheduled reminder: ${reminder['suffix']} before lesson at $scheduledTime');
        }
      }
    }

    // Store scheduled notification IDs
    await _storeScheduledNotificationIds(
        id, reminders.map((r) => r['suffix'] as String).toList());
  }

  /// Schedule a notification with a delay
  void _scheduleDelayedNotification({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    String? payload,
  }) {
    Timer(delay, () async {
      await showLocalNotification(
        id: id,
        title: title,
        body: body,
        payload: payload,
      );
    });
  }

  /// Generate a unique notification ID based on lesson ID and suffix
  int _generateNotificationId(int lessonId, String suffix) {
    // Create a unique ID by combining lesson ID with suffix hash
    return lessonId * 10 + suffix.hashCode % 10;
  }

  /// Store scheduled notification IDs for later cancellation
  Future<void> _storeScheduledNotificationIds(
      int lessonId, List<String> suffixes) async {
    final prefs = await SharedPreferences.getInstance();
    final ids =
        suffixes.map((s) => _generateNotificationId(lessonId, s)).toList();
    await prefs.setString('scheduled_notifications_$lessonId', jsonEncode(ids));
  }

  /// Cancel all reminders for a lesson
  Future<void> cancelLessonReminder(int lessonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedIds = prefs.getString('scheduled_notifications_$lessonId');

      if (storedIds != null) {
        final ids = (jsonDecode(storedIds) as List).cast<int>();
        for (final id in ids) {
          await _localNotifications.cancel(id);
        }
        await prefs.remove('scheduled_notifications_$lessonId');
      }

      // Also cancel by known patterns
      final suffixes = ['6h', '1h', '15m'];
      for (final suffix in suffixes) {
        await _localNotifications
            .cancel(_generateNotificationId(lessonId, suffix));
      }

      if (kDebugMode) {
        print('Cancelled reminders for lesson: $lessonId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling lesson reminder: $e');
      }
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    if (kDebugMode) {
      print('Cancelled all notifications');
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}
