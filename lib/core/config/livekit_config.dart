class LiveKitConfig {
  // LiveKit server configuration
  static const String livekitUrl = 'wss://tajruba-rkrmuadd.livekit.cloud';
  static const String apiKey = 'APIjTeJvsRwm8Fb';
  static const String apiSecret = '1QiaedSSZBeQukQPB1FB6dYeg2EePzsq1lWlmIrw9tNA';
  
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
