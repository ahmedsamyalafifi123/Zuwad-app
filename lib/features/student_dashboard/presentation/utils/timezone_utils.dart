import 'package:intl/intl.dart';

class TimezoneUtils {
  /// Maps English day names (from DateFormat('EEEE')) to Arabic
  static final Map<String, String> _englishToArabicDays = {
    'Sunday': 'الأحد',
    'Monday': 'الاثنين',
    'Tuesday': 'الثلاثاء',
    'Wednesday': 'الأربعاء',
    'Thursday': 'الخميس',
    'Friday': 'الجمعة',
    'Saturday': 'السبت',
  };

  /// Maps weekday index (1=Monday ... 7=Sunday) to Arabic
  /// Note: DateTime.weekday returns 1 for Monday, 7 for Sunday.
  static final Map<int, String> _weekdayToArabic = {
    DateTime.sunday: 'الأحد',
    DateTime.monday: 'الاثنين', // 1
    DateTime.tuesday: 'الثلاثاء', // 2
    DateTime.wednesday: 'الأربعاء', // 3
    DateTime.thursday: 'الخميس', // 4
    DateTime.friday: 'الجمعة', // 5
    DateTime.saturday: 'السبت', // 6
  };

  /// Returns the Arabic day name for the given [date].
  static String getArabicDayName(DateTime date) {
    return _weekdayToArabic[date.weekday] ?? '';
  }

  /// Formats the time in 12-hour format with Arabic AM/PM (e.g., "01:30 PM" or "01:30 م").
  /// The design requested: "01:00 pm".
  static String formatTime(DateTime date) {
    // Format: hh:mm a
    final formatted = DateFormat('hh:mm a').format(date);
    // Optional: Convert AM/PM to Arabic if desired, but user example showed "pm"
    // Users request: "01:00 pm" (lowercase)
    return formatted.toLowerCase();
  }
}
