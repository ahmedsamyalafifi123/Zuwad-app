import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/splash_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      // In debug mode, print the error
      FlutterError.dumpErrorToConsole(details);
    } else {
      // In release mode, log to a service (e.g., Crashlytics)
      // For now, just record that an error occurred
      Zone.current.handleUncaughtError(
          details.exception, details.stack ?? StackTrace.empty);
    }
  };

  // Handle async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      print('Async error: $error');
      print('Stack trace: $stack');
    }
    // Return true to prevent the error from propagating
    return true;
  };

  // Allow both portrait and landscape orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Set system UI overlay style for edge-to-edge display
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

  // Run the app within an error zone
  runZonedGuarded(
    () => runApp(const MyApp()),
    (error, stack) {
      if (kDebugMode) {
        print('Caught error in zone: $error');
        print('Stack trace: $stack');
      }
      // In production, send to error reporting service
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(),
      child: MaterialApp(
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
