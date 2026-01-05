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
}

/// Centralized notification service for managing push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final WordPressApi _api = WordPressApi();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permission
      await _requestPermission();

      // Initialize Local Notifications
      await _initializeLocalNotifications();

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

  /// Initialize Local Notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!);
            _navigateBasedOnPayload(data);
          } catch (e) {
            if (kDebugMode) print('Error parsing payload: $e');
          }
        }
      },
    );

    // Create a high priority channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
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

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // Show local notification if valid notification data exists
    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            icon: '@mipmap/launcher_icon',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
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
      if (kDebugMode) {
        print('=== Starting device token registration ===');
      }

      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('fcm_token');

      // If no token in prefs, try to get it directly
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('No FCM token in prefs, trying to get directly...');
        }
        token = await _firebaseMessaging.getToken();
        if (token != null) {
          await prefs.setString('fcm_token', token);
          if (kDebugMode) {
            print('Got FCM token directly: ${token.substring(0, 20)}...');
          }
        }
      }

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('ERROR: No FCM token available to register');
        }
        return false;
      }

      if (kDebugMode) {
        print('FCM Token to register: ${token.substring(0, 20)}...');
      }

      final platform = Platform.isAndroid ? 'android' : 'ios';
      if (kDebugMode) {
        print('Platform: $platform');
        print('Calling API to register device token...');
      }

      final result = await _api.registerDeviceToken(token, platform: platform);

      if (kDebugMode) {
        print('=== Device token registration result: $result ===');
      }

      return result;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('ERROR registering token with backend: $e');
        print('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}
