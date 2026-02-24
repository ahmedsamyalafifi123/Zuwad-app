import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Helper class for timezone conversions.
/// All schedules are stored in Egypt time (Africa/Cairo) on the server.
/// This helper converts Egypt time to the device's local timezone.
class TimezoneHelper {
  static bool _isInitialized = false;
  static late tz.Location _egyptLocation;

  /// Initialize timezone data. Call this once at app startup.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();
      _egyptLocation = tz.getLocation('Africa/Cairo');

      _isInitialized = true;

      if (kDebugMode) {
        print('TimezoneHelper initialized:');
        print('  Egypt timezone: ${_egyptLocation.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing timezone: $e');
      }
      // Fallback: use Egypt timezone as local
      _egyptLocation = tz.getLocation('Africa/Cairo');
      _isInitialized = true;
    }
  }

  /// Convert a DateTime from Egypt time to local device time.
  /// [egyptDateTime] is assumed to be in Egypt time (Africa/Cairo).
  /// Returns the equivalent DateTime in the device's local timezone.
  static DateTime egyptToLocal(DateTime egyptDateTime) {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('TimezoneHelper not initialized, returning original time');
      }
      return egyptDateTime;
    }

    try {
      // Create a TZDateTime in Egypt timezone
      final egyptTZ = tz.TZDateTime(
        _egyptLocation,
        egyptDateTime.year,
        egyptDateTime.month,
        egyptDateTime.day,
        egyptDateTime.hour,
        egyptDateTime.minute,
        egyptDateTime.second,
      );

      // Convert to local timezone using Dart's native .toLocal()
      final result = egyptTZ.toLocal();

      if (kDebugMode) {
        print('Timezone conversion:');
        print('  Egypt time: $egyptDateTime');
        print('  Local time: $result');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error converting timezone: $e');
      }
      return egyptDateTime;
    }
  }

  /// Convert a DateTime from local device time to Egypt time.
  /// [localDateTime] is assumed to be in device's local timezone.
  /// Returns the equivalent DateTime in Egypt time (Africa/Cairo).
  static DateTime localToEgypt(DateTime localDateTime) {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('TimezoneHelper not initialized, returning original time');
      }
      return localDateTime;
    }

    try {
      // Create a TZDateTime from the local DateTime to the Egypt timezone
      final egyptTZ = tz.TZDateTime.from(localDateTime, _egyptLocation);

      // Return as regular DateTime
      return DateTime(
        egyptTZ.year,
        egyptTZ.month,
        egyptTZ.day,
        egyptTZ.hour,
        egyptTZ.minute,
        egyptTZ.second,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error converting to Egypt timezone: $e');
      }
      return localDateTime;
    }
  }

  /// Get the current time in Egypt timezone
  static DateTime nowInEgypt() {
    return localToEgypt(DateTime.now());
  }

  /// Check if timezone helper is initialized
  static bool get isInitialized => _isInitialized;

  /// Get device timezone offset in hours (e.g., +3 for Saudi Arabia)
  static int get deviceTimezoneOffsetHours {
    return DateTime.now().timeZoneOffset.inHours;
  }

  /// Get Egypt timezone offset in hours (typically +2 or +3 with DST)
  static int get egyptTimezoneOffsetHours {
    if (!_isInitialized) return 2;
    final now = tz.TZDateTime.now(_egyptLocation);
    return now.timeZoneOffset.inHours;
  }
}
