import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../features/notifications/domain/models/notification.dart';
import 'database_service.dart';
import 'chat_event_service.dart';
import 'secure_storage_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../firebase_options.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart' show navigatorKey;
import '../../features/chat/presentation/pages/chat_page.dart';
import '../api/wordpress_api.dart';

/// Top-level function to handle background FCM messages
/// Must be a top-level function (not a class method)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Save to local database (skip chat messages - they have their own system)
  final notificationType = message.data['type']?.toString() ?? '';
  if (notificationType == 'chat_message') {
    if (kDebugMode) print('Chat notification - skipping DB save');
    return;
  }

  try {
    if (message.notification != null) {
      final notification = AppNotification(
        // Try to get server ID from data payload
        id: int.tryParse(message.data['id']?.toString() ?? '0') ??
            int.tryParse(message.data['notification_id']?.toString() ?? '0') ??
            0,
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
        type: message.data['type'] ?? 'general',
        isRead: false,
        createdAt: DateTime.now(),
        data: message.data,
      );

      // Try to get student_id from data payload
      int? studentId;
      if (message.data.containsKey('student_id')) {
        studentId = int.tryParse(message.data['student_id'].toString());
      } else if (message.data.containsKey('studentId')) {
        studentId = int.tryParse(message.data['studentId'].toString());
      }

      await DatabaseService()
          .insertNotification(notification, studentId: studentId);
      if (kDebugMode) print('Background notification saved to DB');
    }
  } catch (e) {
    if (kDebugMode) print('Error saving background notification to DB: $e');
  }
}

/// Top-level function to handle background local notification taps
/// Must be a top-level function (not a class method)
@pragma('vm:entry-point')
void _handleBackgroundNotificationResponse(NotificationResponse details) {
  if (kDebugMode) {
    print('=== Background Local Notification Tapped ===');
    print('Payload: ${details.payload}');
  }
  // Background taps will be handled when app opens via initial message check
}

/// Centralized notification service for managing push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final WordPressApi _api = WordPressApi();
  final DatabaseService _databaseService = DatabaseService();
  final ChatEventService _chatEventService = ChatEventService();

  // Only initialize FirebaseMessaging on supported platforms
  FirebaseMessaging? _firebaseMessaging;

  bool _isInitialized = false;

  /// Check if FCM is supported on the current platform
  /// FCM is NOT supported on Windows and Linux desktop
  bool get _isFcmSupported {
    if (kIsWeb) return true; // Web supports FCM
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize local notifications (works on all platforms)
      await _initializeLocalNotifications();

      // FCM is only supported on mobile and macOS
      if (_isFcmSupported) {
        _firebaseMessaging = FirebaseMessaging.instance;

        // Request permission
        await _requestPermission();

        // Set up FCM message handlers
        _setupFCMHandlers();

        // Get and store FCM token
        await getDeviceToken();
      } else {
        if (kDebugMode) {
          print(
              'NotificationService: FCM not supported on this platform (Windows/Linux). Push notifications disabled.');
        }
      }

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
  /// Skips initialization on Windows/Linux as they require additional setup
  Future<void> _initializeLocalNotifications() async {
    // Skip on Windows/Linux as flutter_local_notifications requires additional setup
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      if (kDebugMode) {
        print('Skipping local notifications initialization on desktop');
      }
      return;
    }

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
        if (kDebugMode) {
          print('=== Local Notification Tapped ===');
          print('Payload: ${details.payload}');
          print('Action ID: ${details.actionId}');
          print(
              'Notification Response Type: ${details.notificationResponseType}');
        }
        if (details.payload != null && details.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(details.payload!);
            if (kDebugMode) {
              print('Parsed payload data: $data');
            }
            _navigateBasedOnPayload(data);
          } catch (e) {
            if (kDebugMode) print('Error parsing payload: $e');
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          _handleBackgroundNotificationResponse,
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
    if (_firebaseMessaging == null) return;

    final settings = await _firebaseMessaging!.requestPermission(
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

  final _notificationsStreamController = StreamController<void>.broadcast();
  Stream<void> get onNotificationReceived =>
      _notificationsStreamController.stream;

  /// Handle foreground FCM message
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Received foreground message: ${message.messageId}');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');
    }

    RemoteNotification? notification = message.notification;

    // Save to local database (skip chat messages - they have their own system)
    final notificationType = message.data['type']?.toString() ?? '';
    if (notificationType == 'chat_message') {
      if (kDebugMode) {
        print('Chat notification - skipping DB save, notifying chat listeners');
      }
      // Notify ChatListPage to refresh when a chat message notification arrives
      final senderId = message.data['sender_id']?.toString();
      _chatEventService.notifyMessageReceived(
        senderId: senderId ?? '',
        message: notification?.body,
      );
    } else if (notification != null) {
      final appNotification = AppNotification(
        // Try to get server ID from data payload to avoid duplicates when syncing with API
        id: int.tryParse(message.data['id']?.toString() ?? '0') ??
            int.tryParse(message.data['notification_id']?.toString() ?? '0') ??
            0,
        title: notification.title ?? '',
        body: notification.body ?? '',
        type: message.data['type'] ?? 'general',
        isRead: false,
        createdAt: DateTime.now(),
        data: message.data,
      );

      // Try to get student_id from data payload
      int? studentId;
      if (message.data.containsKey('student_id')) {
        studentId = int.tryParse(message.data['student_id'].toString());
      } else if (message.data.containsKey('studentId')) {
        studentId = int.tryParse(message.data['studentId'].toString());
      }

      _databaseService
          .insertNotification(appNotification, studentId: studentId)
          .then((_) {
        if (kDebugMode) print('Foreground notification saved to DB');
        _notificationsStreamController.add(null); // Notify listeners
      });
    }
    // Show local notification if valid notification data exists
    // Show on both Android and iOS
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            icon: '@mipmap/launcher_icon',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
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
    if (_firebaseMessaging == null) return;

    final message = await _firebaseMessaging!.getInitialMessage();
    if (message != null) {
      if (kDebugMode) {
        print('App opened from terminated state via notification');
      }
      _navigateBasedOnPayload(message.data);
    }
  }

  /// Navigate based on notification payload
  void _navigateBasedOnPayload(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('=== _navigateBasedOnPayload called ===');
      print('Full payload data: $data');
      print('Data type: ${data['type']}');
    }

    final type = data['type']?.toString();

    // Handle chat message notifications
    if (type == 'chat_message' || type == 'chat' || type == 'message') {
      if (kDebugMode) print('Detected chat notification, calling handler...');
      _handleChatNotification(data);
    }
    // If no type but has sender_id and conversation_id, assume it's a chat
    else if (data.containsKey('sender_id') &&
        data.containsKey('conversation_id')) {
      if (kDebugMode) print('No type but has chat fields, treating as chat...');
      _handleChatNotification(data);
    } else {
      if (kDebugMode) print('Unknown notification type: $type, ignoring...');
    }
  }

  /// Handle chat notification - navigate to conversation
  void _handleChatNotification(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('=== _handleChatNotification called ===');
      print('Data: $data');
    }

    final conversationId = data['conversation_id']?.toString();
    final senderId = data['sender_id']?.toString();
    final senderName = data['sender_name']?.toString() ?? '';
    // Also check alternative field names
    final altSenderId = data['senderId']?.toString();
    final altConversationId = data['conversationId']?.toString();

    final finalSenderId = senderId ?? altSenderId;
    final finalConversationId = conversationId ?? altConversationId;

    if (kDebugMode) {
      print(
          'ConversationId: $finalConversationId, SenderId: $finalSenderId, SenderName: $senderName');
    }

    if (finalConversationId == null || finalSenderId == null) {
      if (kDebugMode) {
        print('ERROR: Chat notification missing required data!');
        print(
            'conversation_id: $finalConversationId, sender_id: $finalSenderId');
      }
      return;
    }

    // Get sender role for proper display (supervisor should show as خدمة العملاء)
    final senderRole = data['sender_role']?.toString() ?? '';

    // Use a longer delay to ensure navigator is fully initialized
    Future.delayed(const Duration(milliseconds: 300), () {
      if (kDebugMode) {
        print('Executing navigation to chat...');
      }
      _navigateToChat(
        conversationId: finalConversationId,
        recipientId: finalSenderId,
        recipientName: senderName,
        senderRole: senderRole,
        studentIdFromPayload: data['student_id']?.toString(),
      );
    });
  }

  /// Navigate to chat page using global navigator key
  void _navigateToChat({
    required String conversationId,
    required String recipientId,
    required String recipientName,
    String? senderRole,
    String? studentIdFromPayload,
  }) async {
    try {
      if (kDebugMode) {
        print('=== _navigateToChat called ===');
        print('StudentId from payload: $studentIdFromPayload');
      }

      // Import navigatorKey dynamically to avoid circular imports
      final navigatorKey = await _getNavigatorKey();
      if (navigatorKey?.currentState == null) {
        if (kDebugMode) {
          print('Navigator not available for chat navigation');
        }
        return;
      }

      // Get current user info from SharedPreferences
      // Try multiple possible keys
      final prefs = await SharedPreferences.getInstance();

      if (kDebugMode) {
        print('All SharedPreferences keys: ${prefs.getKeys()}');
      }

      String studentId = studentIdFromPayload ?? '';
      String studentName = '';

      // Try various possible key names
      if (studentId.isEmpty) {
        studentId = prefs.getString('user_id') ??
            prefs.getString('student_id') ??
            prefs.getString('userId') ??
            prefs.getString('studentId') ??
            prefs.getString('logged_in_user_id') ??
            '';
      }

      studentName = prefs.getString('user_name') ??
          prefs.getString('student_name') ??
          prefs.getString('userName') ??
          prefs.getString('studentName') ??
          prefs.getString('logged_in_user_name') ??
          '';

      if (kDebugMode) {
        print('Resolved studentId: $studentId, studentName: $studentName');
      }

      if (studentId.isEmpty) {
        if (kDebugMode) {
          print('User not logged in, cannot navigate to chat');
        }
        return;
      }

      // Check if this recipient is a known supervisor/mini-visor
      String? roleToPass = senderRole;
      try {
        final secureStorage = SecureStorageService();
        final knownSupervisors = await secureStorage.getKnownSupervisors();
        if (kDebugMode) {
          print(
              'Checking recipient $recipientId against known supervisors: $knownSupervisors');
        }

        if (knownSupervisors.contains(recipientId)) {
          roleToPass = 'supervisor';
          if (kDebugMode) {
            print('Recipient recognized as supervisor from cache!');
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error checking known supervisors: $e');
      }

      // Dynamic import of ChatPage to avoid circular dependencies
      navigatorKey!.currentState!.push(
        MaterialPageRoute(
          builder: (context) => _buildChatPage(
            conversationId: conversationId,
            recipientId: recipientId,
            recipientName: recipientName,
            recipientRole: roleToPass,
            studentId: studentId,
            studentName: studentName,
          ),
        ),
      );

      if (kDebugMode) {
        print(
            'Navigated to chat: conversation=$conversationId, sender=$recipientName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error navigating to chat: $e');
      }
    }
  }

  /// Get navigator key - uses the global key from main.dart
  Future<GlobalKey<NavigatorState>?> _getNavigatorKey() async {
    // Return the imported navigatorKey from main.dart
    return navigatorKey;
  }

  /// Build ChatPage widget for notification navigation
  Widget _buildChatPage({
    required String conversationId,
    required String recipientId,
    required String recipientName,
    String? recipientRole,
    required String studentId,
    required String studentName,
  }) {
    // Override name for supervisor
    final bool isSupervisor = recipientRole?.toLowerCase() == 'supervisor';
    final displayName = isSupervisor
        ? 'خدمة العملاء'
        : (recipientName.isNotEmpty ? recipientName : 'مستخدم');

    return ChatPage(
      conversationId: conversationId,
      recipientId: recipientId,
      recipientName: displayName,
      studentId: studentId,
      studentName: studentName,
      recipientRole: isSupervisor ? 'supervisor' : recipientRole,
    );
  }

  /// Get FCM device token
  Future<String?> getDeviceToken() async {
    if (!_isFcmSupported || _firebaseMessaging == null) {
      if (kDebugMode) {
        print('FCM not supported on this platform, skipping token retrieval');
      }
      return null;
    }

    try {
      final token = await _firebaseMessaging!.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }

      // Store token locally
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
      }

      // Listen for token refresh
      _firebaseMessaging!.onTokenRefresh.listen((newToken) {
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
    // Skip on unsupported platforms (Windows/Linux)
    if (!_isFcmSupported) {
      if (kDebugMode) {
        print(
            'FCM not supported on this platform, skipping token registration');
      }
      return false;
    }

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
        token = await _firebaseMessaging?.getToken();
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
    if (!_isFcmSupported || _firebaseMessaging == null) {
      return false; // Not supported on this platform
    }
    final settings = await _firebaseMessaging!.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}
