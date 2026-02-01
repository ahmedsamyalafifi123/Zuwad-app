import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// Service for managing lesson alarms with custom sound
class AlarmService {
  static const String _keyAlarmEnabled = 'alarm_enabled';
  static const String _keyAlarmHours = 'alarm_hours';
  static const String _keyAlarmMinutes = 'alarm_minutes';
  static const String _keyRepeatForAll = 'alarm_repeat_for_all';
  static const String _keyMultipleAlarms = 'alarm_multiple_times';

  /// Initialize the alarm service
  static Future<void> initialize() async {
    try {
      await Alarm.init();

      // Initialize native alarm service for Android
      if (Platform.isAndroid) {
        await _requestBatteryOptimizationExemption();
      }

      if (kDebugMode) {
        print('AlarmService: Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlarmService: Error initializing: $e');
      }
    }
  }

  /// Request battery optimization exemption for Android
  static Future<void> _requestBatteryOptimizationExemption() async {
    try {
      // Check if we can request ignore battery optimizations
      final status = await Permission.ignoreBatteryOptimizations.status;

      if (!status.isGranted) {
        if (kDebugMode) {
          print('AlarmService: Requesting battery optimization exemption...');
        }

        // Request the permission
        await Permission.ignoreBatteryOptimizations.request();

        if (kDebugMode) {
          final newStatus = await Permission.ignoreBatteryOptimizations.status;
          print(
              'AlarmService: Battery optimization exemption granted: ${newStatus.isGranted}');
        }
      } else {
        if (kDebugMode) {
          print('AlarmService: Battery optimization exemption already granted');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            'AlarmService: Error requesting battery optimization exemption: $e');
      }
    }
  }

  /// Save alarm settings to SharedPreferences
  static Future<void> saveAlarmSettings({
    required bool enabled,
    required int hours,
    required int minutes,
    required bool repeatForAll,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAlarmEnabled, enabled);
      await prefs.setInt(_keyAlarmHours, hours);
      await prefs.setInt(_keyAlarmMinutes, minutes);
      await prefs.setBool(_keyRepeatForAll, repeatForAll);

      if (kDebugMode) {
        print(
          'AlarmService: Saved settings - enabled: $enabled, hours: $hours, minutes: $minutes, repeatForAll: $repeatForAll',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlarmService: Error saving settings: $e');
      }
    }
  }

  /// Save multiple alarm settings to SharedPreferences
  static Future<void> saveMultipleAlarmSettings({
    required List<Map<String, int>> alarmTimes,
    required bool repeatForAll,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAlarmEnabled, alarmTimes.isNotEmpty);
      await prefs.setBool(_keyRepeatForAll, repeatForAll);

      // Save alarm times as JSON string
      final alarmsJson = jsonEncode(alarmTimes);
      await prefs.setString(_keyMultipleAlarms, alarmsJson);

      // Also save the first alarm for backwards compatibility
      if (alarmTimes.isNotEmpty) {
        await prefs.setInt(_keyAlarmHours, alarmTimes[0]['hours'] ?? 0);
        await prefs.setInt(_keyAlarmMinutes, alarmTimes[0]['minutes'] ?? 15);
      }

      if (kDebugMode) {
        print(
          'AlarmService: Saved ${alarmTimes.length} alarm times, repeatForAll: $repeatForAll',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlarmService: Error saving multiple alarm settings: $e');
      }
    }
  }

  /// Get alarm settings from SharedPreferences
  static Future<Map<String, dynamic>> getAlarmSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'enabled': prefs.getBool(_keyAlarmEnabled) ?? false,
        'hours': prefs.getInt(_keyAlarmHours) ?? 0,
        'minutes': prefs.getInt(_keyAlarmMinutes) ?? 15,
        'repeatForAll': prefs.getBool(_keyRepeatForAll) ?? false,
      };
    } catch (e) {
      if (kDebugMode) {
        print('AlarmService: Error getting settings: $e');
      }
      return {
        'enabled': false,
        'hours': 0,
        'minutes': 15,
        'repeatForAll': false,
      };
    }
  }

  /// Get multiple alarm settings from SharedPreferences
  static Future<Map<String, dynamic>> getMultipleAlarmSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getString(_keyMultipleAlarms);

      List<Map<String, int>> alarmTimes = [];
      if (alarmsJson != null && alarmsJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(alarmsJson) as List;
          alarmTimes = decoded
              .map(
                (item) => {
                  'hours': (item['hours'] as num?)?.toInt() ?? 0,
                  'minutes': (item['minutes'] as num?)?.toInt() ?? 15,
                },
              )
              .toList();
        } catch (e) {
          if (kDebugMode) {
            print('AlarmService: Error parsing alarm times JSON: $e');
          }
        }
      }

      // Fallback to single alarm if no multiple alarms saved
      if (alarmTimes.isEmpty) {
        alarmTimes = [
          {
            'hours': prefs.getInt(_keyAlarmHours) ?? 0,
            'minutes': prefs.getInt(_keyAlarmMinutes) ?? 15,
          },
        ];
      }

      return {
        'enabled': prefs.getBool(_keyAlarmEnabled) ?? false,
        'alarmTimes': alarmTimes,
        'repeatForAll': prefs.getBool(_keyRepeatForAll) ?? false,
      };
    } catch (e) {
      if (kDebugMode) {
        print('AlarmService: Error getting multiple alarm settings: $e');
      }
      return {
        'enabled': false,
        'alarmTimes': [
          {'hours': 0, 'minutes': 15},
        ],
        'repeatForAll': false,
      };
    }
  }

  /// Schedule an alarm for a specific lesson
  static Future<bool> scheduleAlarm({
    required DateTime lessonDateTime,
    required int hoursBeforeLesson,
    required int minutesBeforeLesson,
    required String lessonName,
    required String teacherName,
  }) async {
    try {
      // Check for exact alarm permission on Android 12+
      if (defaultTargetPlatform == TargetPlatform.android) {
        if (await Permission.scheduleExactAlarm.isDenied) {
          if (kDebugMode) {
            print(
                'AlarmService: Schedule Exact Alarm permission denied, requesting...');
          }
          final status = await Permission.scheduleExactAlarm.request();
          if (!status.isGranted) {
            if (kDebugMode) {
              print(
                  'AlarmService: Schedule Exact Alarm permission NOT granted');
            }
            return false;
          }
        }
      }
      // Calculate alarm time
      final alarmTime = lessonDateTime.subtract(
        Duration(hours: hoursBeforeLesson, minutes: minutesBeforeLesson),
      );

      if (kDebugMode) {
        print('AlarmService: Lesson time: $lessonDateTime');
        print('AlarmService: Alarm time: $alarmTime');
        print(
          'AlarmService: Hours before: $hoursBeforeLesson, Minutes before: $minutesBeforeLesson',
        );
      }

      // Check if alarm time is in the future
      final now = DateTime.now();
      if (alarmTime.isBefore(now)) {
        if (kDebugMode) {
          print(
            'AlarmService: Alarm time is in the past (now: $now), skipping',
          );
        }
        return false;
      }

      // Generate unique ID for this alarm
      final alarmId = alarmTime.millisecondsSinceEpoch % 2147483647;

      if (kDebugMode) {
        print('AlarmService: Creating alarm with ID: $alarmId');
      }

      if (kDebugMode) {
        print('AlarmService: Setting alarm...');
      }

      // Create notification body
      final notificationBody =
          'الحصة مع $teacherName - $lessonName\nستبدأ بعد ${hoursBeforeLesson > 0 ? "$hoursBeforeLesson ساعة و" : ""}$minutesBeforeLesson دقيقة';

      // Schedule with alarm package
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: alarmTime,
        assetAudioPath: 'assets/audio/alarm.ogg',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: const Duration(seconds: 3),
        ),
        notificationSettings: NotificationSettings(
          title: 'منبه الحصة',
          body: notificationBody,
          stopButton: 'إيقاف',
          icon: '@mipmap/launcher_icon',
        ),
        warningNotificationOnKill: true,
      );

      // Set the alarm with timeout
      await Alarm.set(alarmSettings: alarmSettings).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) {
            print('AlarmService: Alarm.set() timed out');
          }
          throw TimeoutException('Alarm.set() timed out after 5 seconds');
        },
      );

      if (kDebugMode) {
        print(
          'AlarmService: Successfully scheduled alarm $alarmId for ${alarmTime.toString()}',
        );
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('AlarmService: Error scheduling alarm: $e');
      }
      return false;
    }
  }

  /// Cancel all alarms
  static Future<void> cancelAllAlarms() async {
    try {
      if (kDebugMode) {
        print('AlarmService: Attempting to cancel all alarms');
      }

      // Cancel native Android alarms

      // Add timeout to prevent hanging
      await Alarm.stopAll().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) {
            print('AlarmService: stopAll() timed out, continuing anyway');
          }
        },
      );

      if (kDebugMode) {
        print('AlarmService: Cancelled all alarms');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlarmService: Error cancelling alarms: $e');
      }
      // Don't rethrow - continue even if cancel fails
    }
  }

  /// Cancel a specific alarm by ID
  static Future<void> cancelAlarm(int alarmId) async {
    try {
      await Alarm.stop(alarmId);
      if (kDebugMode) {
        print('AlarmService: Cancelled alarm $alarmId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlarmService: Error cancelling alarm: $e');
      }
    }
  }

  /// Get all scheduled alarms
  static Future<List<AlarmSettings>> getScheduledAlarms() async {
    try {
      return Alarm.getAlarms();
    } catch (e) {
      if (kDebugMode) {
        print('AlarmService: Error getting alarms: $e');
      }
      return [];
    }
  }

  /// Check if there are any active alarms
  static Future<bool> hasActiveAlarms() async {
    try {
      final alarms = await getScheduledAlarms();
      return alarms.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('AlarmService: Error checking active alarms: $e');
      }
      return false;
    }
  }
}
