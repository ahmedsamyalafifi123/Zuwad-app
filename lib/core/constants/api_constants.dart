import '../config/env_config.dart';

/// Centralized API constants for the app.
///
/// All URLs and endpoints should be defined here as the single source of truth.
/// Updated for Zuwad REST API v2.
class ApiConstants {
  // Base URLs - use EnvConfig for environment-aware configuration
  static String get baseUrl => EnvConfig.baseUrl;
  static String get apiBaseUrl => EnvConfig.apiBaseUrl;

  // API Version
  static const String apiVersion = 'v2';
  static String get v2BaseUrl => '$apiBaseUrl/zuwad/$apiVersion';

  // ============================================
  // Authentication Endpoints
  // ============================================
  static String get loginEndpoint => '$v2BaseUrl/auth/login';
  static String get refreshTokenEndpoint => '$v2BaseUrl/auth/refresh';
  static String get verifyTokenEndpoint => '$v2BaseUrl/auth/verify';
  static String get logoutEndpoint => '$v2BaseUrl/auth/logout';
  static String get changePasswordEndpoint => '$v2BaseUrl/auth/change-password';

  // ============================================
  // Students Endpoints
  // ============================================
  static String get studentsEndpoint => '$v2BaseUrl/students';
  static String studentByIdEndpoint(int id) => '$v2BaseUrl/students/$id';
  static String studentReportsEndpoint(int studentId) =>
      '$v2BaseUrl/students/$studentId/reports';
  static String studentSchedulesEndpoint(int studentId) =>
      '$v2BaseUrl/students/$studentId/schedules';
  static String studentWalletEndpoint(int studentId) =>
      '$v2BaseUrl/students/$studentId/wallet';
  static String studentFamilyEndpoint(int studentId) =>
      '$v2BaseUrl/students/$studentId/family';
  static String studentUploadImageEndpoint(int studentId) =>
      '$v2BaseUrl/students/$studentId/upload-image';

  // ============================================
  // Teachers Endpoints
  // ============================================
  static String get teachersEndpoint => '$v2BaseUrl/teachers';
  static String teacherByIdEndpoint(int id) => '$v2BaseUrl/teachers/$id';
  static String teacherStudentsEndpoint(int teacherId) =>
      '$v2BaseUrl/teachers/$teacherId/students';
  static String teacherCalendarEndpoint(int teacherId) =>
      '$v2BaseUrl/teachers/$teacherId/calendar';
  static String teacherFreeSlotsEndpoint(int teacherId) =>
      '$v2BaseUrl/teachers/$teacherId/free-slots';
  static String teacherStatisticsEndpoint(int teacherId) =>
      '$v2BaseUrl/teachers/$teacherId/statistics';

  // ============================================
  // Schedules Endpoints
  // ============================================
  static String get schedulesEndpoint => '$v2BaseUrl/schedules';
  static String get scheduleConflictsEndpoint =>
      '$v2BaseUrl/schedules/check-conflicts';
  static String get schedulePostponeEndpoint => '$v2BaseUrl/schedules/postpone';

  // ============================================
  // Reports Endpoints
  // ============================================
  static String get reportsEndpoint => '$v2BaseUrl/reports';
  static String get reportUploadImageEndpoint =>
      '$v2BaseUrl/reports/upload-image';
  static String get reportSessionNumberEndpoint =>
      '$v2BaseUrl/reports/session-number';

  // ============================================
  // Payments Endpoints
  // ============================================
  static String get paymentsEndpoint => '$v2BaseUrl/payments';
  static String paymentDetailsEndpoint(int studentId) =>
      '$v2BaseUrl/payments/$studentId';
  static String paymentStatusEndpoint(int studentId) =>
      '$v2BaseUrl/payments/$studentId/status';
  static String paymentReminderEndpoint(int studentId) =>
      '$v2BaseUrl/payments/$studentId/reminder';
  static String paymentSendReminderEndpoint(int studentId) =>
      '$v2BaseUrl/payments/$studentId/send-reminder';

  // ============================================
  // Chat Endpoints
  // ============================================
  static String get chatConversationsEndpoint =>
      '$v2BaseUrl/chat/conversations';
  static String chatMessagesEndpoint(String conversationId) =>
      '$v2BaseUrl/chat/conversations/$conversationId/messages';
  static String chatReadEndpoint(String conversationId) =>
      '$v2BaseUrl/chat/conversations/$conversationId/read';
  static String get chatUnreadCountEndpoint => '$v2BaseUrl/chat/unread-count';

  // ============================================
  // Wallet Endpoints
  // ============================================
  static String walletFamilyEndpoint(int familyId) =>
      '$v2BaseUrl/wallet/family/$familyId';
  static String walletStudentEndpoint(int studentId) =>
      '$v2BaseUrl/wallet/student/$studentId';
  static String walletTransactionsEndpoint(int familyId) =>
      '$v2BaseUrl/wallet/family/$familyId/transactions';
  static String walletAddEndpoint(int familyId) =>
      '$v2BaseUrl/wallet/family/$familyId/add';
  static String walletDeductEndpoint(int familyId) =>
      '$v2BaseUrl/wallet/family/$familyId/deduct';

  // ============================================
  // Notifications Endpoints
  // ============================================
  static String get notificationsEndpoint => '$v2BaseUrl/notifications';
  static String notificationReadEndpoint(int id) =>
      '$v2BaseUrl/notifications/$id/read';
  static String get notificationMarkAllReadEndpoint =>
      '$v2BaseUrl/notifications/mark-all-read';
  static String get notificationCountEndpoint =>
      '$v2BaseUrl/notifications/count';
  static String get teacherNotificationsEndpoint =>
      '$v2BaseUrl/teacher/notifications';
  static String get teacherNotificationCountEndpoint =>
      '$v2BaseUrl/teacher/notifications/count';

  // ============================================
  // Competition Endpoints
  // ============================================
  static String get competitionsEndpoint => '$v2BaseUrl/competitions';
  static String competitionByIdEndpoint(int id) =>
      '$v2BaseUrl/competitions/$id';
  static String competitionStudentsEndpoint(int id) =>
      '$v2BaseUrl/competitions/$id/students';
  static String competitionRegisterEndpoint(int id) =>
      '$v2BaseUrl/competitions/$id/register';
  static String competitionLeaderboardEndpoint(int id) =>
      '$v2BaseUrl/competitions/$id/leaderboard';
  static String competitionReportsEndpoint(int id) =>
      '$v2BaseUrl/competitions/$id/reports';
  static String competitionAnalyticsEndpoint(int id) =>
      '$v2BaseUrl/competitions/$id/analytics';

  // ============================================
  // Analytics Endpoints
  // ============================================
  static String get analyticsDashboardEndpoint =>
      '$v2BaseUrl/analytics/dashboard';
  static String get analyticsStudentsEndpoint =>
      '$v2BaseUrl/analytics/students';
  static String get analyticsTeachersEndpoint =>
      '$v2BaseUrl/analytics/teachers';
  static String get analyticsRevenueEndpoint => '$v2BaseUrl/analytics/revenue';
  static String get analyticsLessonsEndpoint => '$v2BaseUrl/analytics/lessons';
  static String get analyticsPaymentStatusEndpoint =>
      '$v2BaseUrl/analytics/payment-status';

  // ============================================
  // Options Endpoints (Dropdown/Lookup data)
  // ============================================
  static String get optionsPaymentStatusesEndpoint =>
      '$v2BaseUrl/options/payment-statuses';
  static String get optionsCurrenciesEndpoint =>
      '$v2BaseUrl/options/currencies';
  static String get optionsCountriesEndpoint => '$v2BaseUrl/options/countries';
  static String get optionsCoursesEndpoint => '$v2BaseUrl/options/courses';
  static String get optionsAttendanceTypesEndpoint =>
      '$v2BaseUrl/options/attendance-types';
  static String get optionsLeadStatusesEndpoint =>
      '$v2BaseUrl/options/lead-statuses';
  static String get optionsPlatformsEndpoint => '$v2BaseUrl/options/platforms';
  static String get optionsDaysEndpoint => '$v2BaseUrl/options/days';
  static String get optionsEvaluationGradesEndpoint =>
      '$v2BaseUrl/options/evaluation-grades';

  // ============================================
  // Leads/CRM Endpoints
  // ============================================
  static String get leadsEndpoint => '$v2BaseUrl/leads';
  static String get leadsBoardEndpoint => '$v2BaseUrl/leads/board';
  static String leadByIdEndpoint(int id) => '$v2BaseUrl/leads/$id';
  static String leadStatusEndpoint(int id) => '$v2BaseUrl/leads/$id/status';
  static String leadConvertEndpoint(int id) => '$v2BaseUrl/leads/$id/convert';

  // ============================================
  // Suspended Students Endpoints
  // ============================================
  static String get suspendedStudentsEndpoint =>
      '$v2BaseUrl/suspended-students';
  static String get suspendedStudentsAnalyticsEndpoint =>
      '$v2BaseUrl/suspended-students/analytics';
  static String suspendedStudentReactivateEndpoint(int id) =>
      '$v2BaseUrl/suspended-students/$id/reactivate';
  static String studentSuspendEndpoint(int id) =>
      '$v2BaseUrl/students/$id/suspend';

  // ============================================
  // Other Endpoints
  // ============================================
  static String get supervisorsEndpoint => '$v2BaseUrl/supervisors';
  static String get cacheClearEndpoint => '$v2BaseUrl/cache/clear';
  static String get statusEndpoint => '$v2BaseUrl/status';

  // ============================================
  // Legacy endpoints (kept for backward compatibility)
  // ============================================
  @Deprecated('Use v2 endpoints instead')
  static const String legacyLoginEndpoint = '/custom/v1/student-login';
  @Deprecated('Use v2 endpoints instead')
  static const String legacyUserMetaEndpoint = '/custom/v1/user-meta';
}
