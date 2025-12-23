import '../config/env_config.dart';

/// LiveKit configuration for video meetings.
///
/// > **SECURITY WARNING**: API keys and secrets should NOT be stored in client code.
/// > In production, tokens should be generated server-side and fetched via authenticated API.
/// > The current implementation generates tokens client-side for development convenience only.
///
/// TODO: Implement server-side token generation:
/// 1. Create a backend endpoint that generates LiveKit tokens
/// 2. Have the app request tokens from the backend
/// 3. Remove API key and secret from client code
class LiveKitConfig {
  // LiveKit server URL - can be overridden with --dart-define
  static String get livekitUrl => EnvConfig.livekitUrl;

  // SECURITY: These should be moved to server-side token generation
  // For now, using environment variables if available
  static const String apiKey = String.fromEnvironment(
    'LIVEKIT_API_KEY',
    defaultValue: 'APIjTeJvsRwm8Fb',
  );
  static const String apiSecret = String.fromEnvironment(
    'LIVEKIT_API_SECRET',
    defaultValue: '1QiaedSSZBeQukQPB1FB6dYeg2EePzsq1lWlmIrw9tNA',
  );

  // Meeting configuration
  static const Duration tokenExpiration = Duration(hours: 6);
  static const int maxParticipants = 10;

  // Video/Audio settings
  static const int defaultVideoWidth = 640;
  static const int defaultVideoHeight = 480;
  static const int defaultVideoFrameRate = 15;
  static const int defaultAudioBitrate = 64000;
  static const int defaultVideoBitrate = 500000;
}
