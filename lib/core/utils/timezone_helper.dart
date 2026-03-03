import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Helper class for timezone conversions.
/// All schedules are stored in Egypt time (Africa/Cairo) on the server.
/// This helper converts Egypt time to the device's local timezone.
class TimezoneHelper {
  static bool _isInitialized = false;
  static late tz.Location _egyptLocation;
  static String? _userTimezone;
  static bool _useApiConversion = false;

  /// Initialize timezone data. Call this once at app startup.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();
      _egyptLocation = tz.getLocation('Africa/Cairo');

      // On web, detect timezone from browser offset and use API
      if (kIsWeb) {
        _userTimezone = _detectTimezoneFromOffset();
        _useApiConversion = _userTimezone != null;
      }

      _isInitialized = true;

      if (kDebugMode) {
        print('TimezoneHelper initialized:');
        print('  Egypt timezone: ${_egyptLocation.name}');
        print('  User timezone: $_userTimezone');
        print('  Using API conversion: $_useApiConversion');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing timezone: $e');
      }
      _egyptLocation = tz.getLocation('Africa/Cairo');
      _isInitialized = true;
    }
  }

  /// Detect user's timezone name from browser offset
  static String? _detectTimezoneFromOffset() {
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

    // Map common offsets to IANA timezone names
    final offsetToTz = <int, String>{
      -720: 'Etc/GMT+12',
      -660: 'Pacific/Niue',
      -600: 'Pacific/Honolulu',
      -540: 'America/Anchorage',
      -480: 'America/Los_Angeles',
      -420: 'America/Denver',
      -360: 'America/Chicago',
      -300: 'America/New_York',
      -240: 'America/Caracas',
      -180: 'America/Sao_Paulo',
      -120: 'Atlantic/South_Georgia',
      -60: 'Atlantic/Azores',
      0: 'Europe/London',
      60: 'Europe/Paris',
      120: 'Africa/Cairo',
      180: 'Europe/Moscow',
      210: 'Asia/Tehran',
      240: 'Asia/Dubai', // UAE, Oman
      270: 'Asia/Kabul',
      300: 'Asia/Karachi',
      330: 'Asia/Kolkata',
      345: 'Asia/Kathmandu',
      360: 'Asia/Dhaka',
      390: 'Asia/Yangon',
      420: 'Asia/Bangkok',
      480: 'Asia/Shanghai',
      540: 'Asia/Tokyo',
      570: 'Australia/Adelaide',
      600: 'Australia/Sydney',
      660: 'Pacific/Noumea',
      720: 'Pacific/Auckland',
      780: 'Pacific/Tongatapu',
      840: 'Pacific/Kiritimati',
    };

    return offsetToTz[offsetMinutes];
  }

  /// Convert timezone via OpenTimezone API
  static Future<DateTime?> _convertViaApi(
    DateTime dateTime,
    String fromTimezone,
    String toTimezone,
  ) async {
    try {
      final dateTimeStr =
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}T'
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

      final response = await http.post(
        Uri.parse('https://api.opentimezone.com/convert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'dateTime': dateTimeStr,
          'fromTimezone': fromTimezone,
          'toTimezone': toTimezone,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final convertedStr = data['dateTime'] as String?;
        if (convertedStr != null) {
          final converted = DateTime.parse(convertedStr);
          if (kDebugMode) {
            print('API timezone conversion:');
            print('  From ($fromTimezone): $dateTimeStr');
            print('  To ($toTimezone): $convertedStr');
          }
          return converted;
        }
      } else {
        if (kDebugMode) {
          print('API conversion failed: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error calling timezone API: $e');
      }
    }
    return null;
  }

  /// Manual timezone conversion using offset calculation (fallback)
  static DateTime _manualConversion(DateTime egyptDateTime) {
    try {
      final egyptTZ = tz.TZDateTime(
        _egyptLocation,
        egyptDateTime.year,
        egyptDateTime.month,
        egyptDateTime.day,
        egyptDateTime.hour,
        egyptDateTime.minute,
        egyptDateTime.second,
      );

      final deviceOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
      final egyptOffsetMinutes = egyptTZ.timeZoneOffset.inMinutes;
      final offsetDiffMinutes = deviceOffsetMinutes - egyptOffsetMinutes;

      final localTime = DateTime(
        egyptDateTime.year,
        egyptDateTime.month,
        egyptDateTime.day,
        egyptDateTime.hour,
        egyptDateTime.minute,
        egyptDateTime.second,
      ).add(Duration(minutes: offsetDiffMinutes));

      if (kDebugMode) {
        print('Manual timezone conversion:');
        print('  Egypt time: $egyptDateTime');
        print('  Device offset: ${deviceOffsetMinutes ~/ 60}h');
        print('  Local time: $localTime');
      }

      return localTime;
    } catch (e) {
      if (kDebugMode) {
        print('Error in manual conversion: $e');
      }
      return egyptDateTime;
    }
  }

  /// Convert a DateTime from Egypt time to local device time (async).
  /// Uses API on web, manual calculation on native.
  static Future<DateTime> egyptToLocalAsync(DateTime egyptDateTime) async {
    if (!_isInitialized) return egyptDateTime;

    // Use API on web
    if (_useApiConversion && _userTimezone != null) {
      final result = await _convertViaApi(egyptDateTime, 'Africa/Cairo', _userTimezone!);
      if (result != null) return result;
    }

    // Fallback to manual
    return _manualConversion(egyptDateTime);
  }

  /// Convert a DateTime from Egypt time to local device time (sync).
  /// Uses manual calculation only.
  static DateTime egyptToLocal(DateTime egyptDateTime) {
    if (!_isInitialized) return egyptDateTime;
    return _manualConversion(egyptDateTime);
  }

  /// Convert a DateTime from local device time to Egypt time (async).
  static Future<DateTime> localToEgyptAsync(DateTime localDateTime) async {
    if (!_isInitialized) return localDateTime;

    if (_useApiConversion && _userTimezone != null) {
      final result = await _convertViaApi(localDateTime, _userTimezone!, 'Africa/Cairo');
      if (result != null) return result;
    }

    return _manualLocalToEgypt(localDateTime);
  }

  /// Convert a DateTime from local device time to Egypt time (sync).
  static DateTime localToEgypt(DateTime localDateTime) {
    if (!_isInitialized) return localDateTime;
    return _manualLocalToEgypt(localDateTime);
  }

  static DateTime _manualLocalToEgypt(DateTime localDateTime) {
    try {
      final egyptTZ = tz.TZDateTime.from(localDateTime, _egyptLocation);
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
  static DateTime nowInEgypt() => localToEgypt(DateTime.now());

  /// Check if timezone helper is initialized
  static bool get isInitialized => _isInitialized;

  /// Get user's detected timezone name
  static String? get userTimezone => _userTimezone;

  /// Get device timezone offset in hours
  static int get deviceTimezoneOffsetHours => DateTime.now().timeZoneOffset.inHours;

  /// Get Egypt timezone offset in hours
  static int get egyptTimezoneOffsetHours {
    if (!_isInitialized) return 2;
    return tz.TZDateTime.now(_egyptLocation).timeZoneOffset.inHours;
  }
}