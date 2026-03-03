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

  /// Formats the time in 12-hour format with AM/PM (e.g., "01:30 pm").
  /// Uses direct DateTime access to avoid intl package timezone issues on desktop.
  static String formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;

    // Convert to 12-hour format
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final ampm = hour < 12 ? 'am' : 'pm';

    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
  }
}
