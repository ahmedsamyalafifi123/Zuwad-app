import 'dart:async';
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
    print('Alarm title: ${alarmSettings.notificationSettings?.title}');
    print('Alarm body: ${alarmSettings.notificationSettings?.body}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS DEBUG: show a plain screen immediately to confirm Flutter runs at all
  if (Platform.isIOS) {
    runApp(const _IOSDebugApp());
    return;
  }

  // ── Android / other platforms ─────────────────────────────────────────────
  bool crashlyticsReady = false;

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    crashlyticsReady = true;
  } catch (e) {
    if (kDebugMode) print('Firebase initialization error: $e');
  }

  if (!kIsWeb && Platform.isAndroid) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      if (kDebugMode) print('FCM background handler setup error: $e');
    }
  }

  try { await NotificationService().initialize(); } catch (e, s) {
    if (crashlyticsReady) FirebaseCrashlytics.instance.recordError(e, s, reason: 'notification_service_init');
  }
  try { await AlarmService.initialize(); } catch (e, s) {
    if (crashlyticsReady) FirebaseCrashlytics.instance.recordError(e, s, reason: 'alarm_service_init');
  }
  try { Alarm.ringStream.stream.listen(onAlarmRinging); } catch (e, s) {
    if (crashlyticsReady) FirebaseCrashlytics.instance.recordError(e, s, reason: 'alarm_stream_setup');
  }
  try { await TimezoneHelper.initialize(); } catch (e, s) {
    if (crashlyticsReady) FirebaseCrashlytics.instance.recordError(e, s, reason: 'timezone_helper_init');
  }

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (_) {}

  runApp(const MyApp());
}

/// ── iOS debug stub ────────────────────────────────────────────────────────
/// Shows a plain screen with NO Firebase / plugins / services.
/// If THIS crashes → the problem is in a native plugin registration.
/// If this shows → Flutter runs fine, problem was in our Dart init code.
class _IOSDebugApp extends StatelessWidget {
  const _IOSDebugApp();
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF8b0628),
        body: Center(
          child: Text(
            'Flutter is running on iOS ✅',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      ),
    );
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
        builder: (context, widget) {
          ErrorWidget.builder = (FlutterErrorDetails details) {
            if (kDebugMode) return ErrorWidget(details.exception);
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    const Text('حدث خطأ غير متوقع',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('يرجى إعادة تشغيل التطبيق',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
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
