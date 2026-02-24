import 'dart:io';
import 'dart:ui';
import 'package:alarm/alarm.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/notification_service.dart';
import 'core/services/alarm_service.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/timezone_helper.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/splash_screen.dart';
import 'firebase_options.dart';

/// Global navigator key for navigation from services (e.g., NotificationService)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Check if FCM is supported on the current platform
bool get _isFcmSupported {
  if (kIsWeb) return true;
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

/// Callback to handle alarm ringing when app is in background or terminated
@pragma('vm:entry-point')
void onAlarmRinging(AlarmSettings alarmSettings) {
  if (kDebugMode) {
    print('Alarm triggered: ${alarmSettings.id}');
    print('Alarm title: ${alarmSettings.notificationSettings.title}');
    print('Alarm body: ${alarmSettings.notificationSettings.body}');
  }

  // The alarm plugin will automatically show the notification
  // You can add custom logic here if needed (e.g., play custom sound, vibrate)
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Track whether Firebase initialized successfully
  bool firebaseInitialized = false;

  // 1. Firebase initialization
  // On iOS, Firebase is already initialized natively in AppDelegate.swift
  // On Android and other platforms, we need to initialize here
  try {
    // Check if Firebase is already initialized (hives on iOS when configured natively)
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    firebaseInitialized = true;

    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      if (kDebugMode) print('Crashlytics initialized successfully');
    }
  } catch (e, stack) {
    if (kDebugMode) {
      print('Firebase initialization error: $e');
      print('Stack: $stack');
    }
  }

  // 2. FCM background handler must be registered before runApp.
  if (_isFcmSupported) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      if (kDebugMode) print('FCM background handler setup error: $e');
    }
  }

  // 3. System UI — quick, no dialogs, safe to do before runApp.
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (_) {}

  // 4. Run the app immediately so the UI is visible before any
  //    permission dialogs appear (prevents black screen on macOS/iOS).
  runApp(const MyApp());

  // 5. Initialize the remaining services after the first frame is drawn.
  //    NotificationService requests permission — doing this after runApp
  //    means the dialog appears over the splash screen, not a black screen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initServicesInBackground(firebaseInitialized);
  });
}

/// Initializes services that may show permission dialogs or take time.
/// Called after the first frame so the UI is already visible.
Future<void> _initServicesInBackground(bool firebaseInitialized) async {
  // NotificationService — may trigger permission dialog on first launch
  try {
    await NotificationService().initialize();
  } catch (e, stack) {
    if (kDebugMode) print('NotificationService initialization error: $e');
    if (firebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'notification_service_init');
      } catch (_) {}
    }
  }

  // AlarmService
  try {
    await AlarmService.initialize();
  } catch (e, stack) {
    if (kDebugMode) print('AlarmService initialization error: $e');
    if (firebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'alarm_service_init');
      } catch (_) {}
    }
  }

  // Alarm ring stream
  try {
    // ignore: deprecated_member_use
    Alarm.ringStream.stream.listen((alarmSettings) {
      onAlarmRinging(alarmSettings);
    });
  } catch (e, stack) {
    if (kDebugMode) print('Alarm ring stream setup error: $e');
    if (firebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'alarm_stream_setup');
      } catch (_) {}
    }
  }

  // TimezoneHelper
  try {
    await TimezoneHelper.initialize();
  } catch (e, stack) {
    if (kDebugMode) print('TimezoneHelper initialization error: $e');
    if (firebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'timezone_helper_init');
      } catch (_) {}
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'أكاديمية زواد',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('ar', 'SA'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar', 'SA')],
        home: const SplashScreen(),
        // Add error widget customization for release mode
        builder: (context, widget) {
          // Customize error widget in release mode
          ErrorWidget.builder = (FlutterErrorDetails details) {
            if (kDebugMode) {
              return ErrorWidget(details.exception);
            }
            // In release mode, show a user-friendly error screen
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'حدث خطأ غير متوقع',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'يرجى إعادة تشغيل التطبيق',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          };
          return widget ?? const SizedBox.shrink();
        },
      ),
    );
  }
}
