import 'package:flutter/foundation.dart';

/// Environment configuration for the app.
///
/// URLs can be overridden at build time using --dart-define:
/// flutter build apk --dart-define=BASE_URL=https://custom.url.com
///
/// For API keys/secrets that should NOT be in source code,
/// use environment variables or fetch from backend.
class EnvConfig {
  // Base URLs - can be overridden with --dart-define
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://system.zuwad-academy.com',
  );

  static const String wpJsonPath = '/wp-json';

  static String get apiBaseUrl => '$baseUrl$wpJsonPath';

  // LiveKit configuration
  static const String livekitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://livekit.zuwad-academy.com',
  );

  // Debug mode helper
  static bool get isDebugMode => kDebugMode;

  // Log helper that only logs in debug mode
  static void log(String message) {
    if (kDebugMode) {
      print('[Zuwad] $message');
    }
  }
}
