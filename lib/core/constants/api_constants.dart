import '../config/env_config.dart';

/// Centralized API constants for the app.
///
/// All URLs and endpoints should be defined here as the single source of truth.
class ApiConstants {
  // Base URLs - use EnvConfig for environment-aware configuration
  static String get baseUrl => EnvConfig.baseUrl;
  static String get apiBaseUrl => EnvConfig.apiBaseUrl;

  // API endpoints
  static const String loginEndpoint = '/custom/v1/student-login';
  static const String validateTokenEndpoint = '/jwt-auth/v1/token/validate';
  static const String userMetaEndpoint = '/custom/v1/user-meta';
  static const String studentProfileEndpoint = '/zuwad/v1/student-profile';
  static const String studentSchedulesEndpoint = '/zuwad/v1/student-schedules';
  static const String studentReportsEndpoint = '/zuwad/v1/student-reports';
  static const String createPostponedEventEndpoint =
      '/zuwad/v1/create-postponed-event';
  static const String createStudentReportEndpoint =
      '/zuwad/v1/create-student-report';

  // Chat endpoints
  static const String chatMessagesEndpoint = '/zuwad/v1/chat/messages';
  static const String chatSendEndpoint = '/zuwad/v1/chat/send';
  static const String chatMarkReadEndpoint = '/zuwad/v1/chat/mark-read';
}
