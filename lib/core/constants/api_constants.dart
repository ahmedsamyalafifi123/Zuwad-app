class ApiConstants {
  static const String baseUrl = 'https://system.zuwad-academy.com'; // Updated to match the URL in WordPressApi
  
  // API endpoints
  static const String loginEndpoint = '/wp-json/jwt-auth/v1/token';
  static const String validateTokenEndpoint = '/wp-json/jwt-auth/v1/token/validate';
  static const String studentProfileEndpoint = '/wp-json/zuwad/v1/student-profile';
  static const String studentSchedulesEndpoint = '/wp-json/zuwad/v1/student-schedules';
  static const String studentReportsEndpoint = '/wp-json/zuwad/v1/student-reports';
}
