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
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Track whether Firebase initialized successfully
  bool firebaseInitialized = false;

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;

    // Initialize Crashlytics after Firebase is initialized
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      if (kDebugMode) {
        print('Crashlytics initialized successfully');
      }
    }
  } catch (e, stack) {
    if (kDebugMode) {
      print('Firebase initialization error: $e');
      print('Stack: $stack');
    }
    // Continue without Firebase - app will still work
  }

  // Set up FCM background message handler (only on supported platforms)
  if (_isFcmSupported) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      if (kDebugMode) {
        print('FCM background handler setup error: $e');
      }
    }
  }

  // Initialize notification service with error handling
  try {
    await NotificationService().initialize();
  } catch (e, stack) {
    if (kDebugMode) {
      print('NotificationService initialization error: $e');
    }
    if (firebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'notification_service_init');
      } catch (_) {}
    }
  }

  // Initialize alarm service with error handling
  try {
    await AlarmService.initialize();
  } catch (e, stack) {
    if (kDebugMode) {
      print('AlarmService initialization error: $e');
    }
    if (firebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'alarm_service_init');
      } catch (_) {}
    }
  }

  // Set up alarm callback for background/terminated state
  try {
    // ignore: deprecated_member_use
    Alarm.ringStream.stream.listen((alarmSettings) {
      onAlarmRinging(alarmSettings);
    });
  } catch (e, stack) {
    if (kDebugMode) {
      print('Alarm ring stream setup error: $e');
    }
    if (firebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'alarm_stream_setup');
      } catch (_) {}
    }
  }

  // Initialize timezone helper for schedule time conversions
  try {
    await TimezoneHelper.initialize();
  } catch (e, stack) {
    if (kDebugMode) {
      print('TimezoneHelper initialization error: $e');
    }
    if (firebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'timezone_helper_init');
      } catch (_) {}
    }
  }

  // Allow both portrait and landscape orientations
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } catch (e, stack) {
    if (kDebugMode) {
      print('SystemChrome orientation error: $e');
    }
    if (firebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'system_chrome_orientation');
      } catch (_) {}
    }
  }

  // Set system UI overlay style for edge-to-edge display
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    // Enable edge-to-edge display
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  } catch (e, stack) {
    if (kDebugMode) {
      print('SystemChrome UI mode error: $e');
    }
    if (firebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'system_chrome_ui_mode');
      } catch (_) {}
    }
  }

  // Run the app
  runApp(const MyApp());
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
