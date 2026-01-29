import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart' as alarm_pkg;

/// Native alarm service that uses Android's AlarmManager directly
/// This ensures alarms work even when app is terminated
class NativeAlarmService {
  static const MethodChannel _channel = MethodChannel('com.zuwad/native_alarm');

  static bool _isInitialized = false;

  /// Initialize the native alarm service
  static Future<void> initialize() async {
    if (!Platform.isAndroid || _isInitialized) {
      return;
    }

    try {
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
      if (kDebugMode) {
        print('NativeAlarmService: Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NativeAlarmService: Error initializing: $e');
      }
    }
  }

  /// Schedule a native alarm
  static Future<bool> scheduleAlarm({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid) {
      // Fallback to alarm package for non-Android platforms
      return false;
    }

    try {
      final result = await _channel.invokeMethod('scheduleAlarm', {
        'alarm_id': id,
        'timestamp': dateTime.millisecondsSinceEpoch,
        'title': title,
        'body': body,
      });

      if (kDebugMode) {
        print('NativeAlarmService: Scheduled alarm $id for $dateTime');
      }

      return result == true;
    } catch (e) {
      if (kDebugMode) {
        print('NativeAlarmService: Error scheduling alarm: $e');
      }
      return false;
    }
  }

  /// Cancel a specific alarm
  static Future<void> cancelAlarm(int id) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod('cancelAlarm', {'alarm_id': id});
      if (kDebugMode) {
        print('NativeAlarmService: Cancelled alarm $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NativeAlarmService: Error cancelling alarm: $e');
      }
    }
  }

  /// Cancel all alarms
  static Future<void> cancelAllAlarms() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod('cancelAllAlarms');
      if (kDebugMode) {
        print('NativeAlarmService: Cancelled all alarms');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NativeAlarmService: Error cancelling all alarms: $e');
      }
    }
  }
}
