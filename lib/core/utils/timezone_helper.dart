import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Helper class for timezone conversions.
/// All schedules are stored in Egypt time (Africa/Cairo) on the server.
/// This helper converts Egypt time to the device's local timezone.
class TimezoneHelper {
  static bool _isInitialized = false;
  static late tz.Location _egyptLocation;
  static late tz.Location _localLocation;

  /// Initialize timezone data. Call this once at app startup.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();
      _egyptLocation = tz.getLocation('Africa/Cairo');

      // Get device's local timezone
      final now = DateTime.now();
      final offset = now.timeZoneOffset;

      // Find the location that matches the device's timezone offset
      _localLocation = _findLocationByOffset(offset);

      _isInitialized = true;

      if (kDebugMode) {
        print('TimezoneHelper initialized:');
        print('  Egypt timezone: ${_egyptLocation.name}');
        print('  Local timezone: ${_localLocation.name}');
        print('  Device offset: ${offset.inHours}h ${offset.inMinutes % 60}m');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing timezone: $e');
      }
      // Fallback: use Egypt timezone as local
      _egyptLocation = tz.getLocation('Africa/Cairo');
      _localLocation = _egyptLocation;
      _isInitialized = true;
    }
  }

  /// Find a timezone location that matches the given offset
  static tz.Location _findLocationByOffset(Duration offset) {
    // Try common timezones first based on offset hours
    final offsetHours = offset.inHours;
    final commonTimezones = {
      -12: 'Pacific/Fiji',
      -11: 'Pacific/Pago_Pago',
      -10: 'Pacific/Honolulu',
      -9: 'America/Anchorage',
      -8: 'America/Los_Angeles',
      -7: 'America/Denver',
      -6: 'America/Chicago',
      -5: 'America/New_York',
      -4: 'America/Caracas',
      -3: 'America/Sao_Paulo',
      -2: 'Atlantic/South_Georgia',
      -1: 'Atlantic/Azores',
      0: 'UTC',
      1: 'Europe/London',
      2: 'Africa/Cairo', // Egypt
      3: 'Asia/Riyadh', // Saudi Arabia, Kuwait, etc.
      4: 'Asia/Dubai', // UAE
      5: 'Asia/Karachi',
      6: 'Asia/Dhaka',
      7: 'Asia/Bangkok',
      8: 'Asia/Singapore',
      9: 'Asia/Tokyo',
      10: 'Australia/Sydney',
      11: 'Pacific/Noumea',
      12: 'Pacific/Auckland',
    };

    try {
      final tzName = commonTimezones[offsetHours];
      if (tzName != null) {
        return tz.getLocation(tzName);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Could not find timezone for offset $offsetHours: $e');
      }
    }

    // Fallback to Egypt timezone
    return tz.getLocation('Africa/Cairo');
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

      // Convert to local timezone
      final localTZ = tz.TZDateTime.from(egyptTZ, _localLocation);

      // Return as regular DateTime
      final result = DateTime(
        localTZ.year,
        localTZ.month,
        localTZ.day,
        localTZ.hour,
        localTZ.minute,
        localTZ.second,
      );

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
      // Create a TZDateTime in local timezone
      final localTZ = tz.TZDateTime(
        _localLocation,
        localDateTime.year,
        localDateTime.month,
        localDateTime.day,
        localDateTime.hour,
        localDateTime.minute,
        localDateTime.second,
      );

      // Convert to Egypt timezone
      final egyptTZ = tz.TZDateTime.from(localTZ, _egyptLocation);

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
