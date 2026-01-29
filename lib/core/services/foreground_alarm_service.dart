import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to keep the app alive in the background using Android foreground service
/// This is necessary for alarms to trigger reliably when the app is minimized or closed
class ForegroundAlarmService {
  static const MethodChannel _channel = MethodChannel('com.zuwad/foreground_alarm');
  static bool _isInitialized = false;

  /// Initialize the foreground service to keep app alive
  static Future<void> initialize() async {
    if (!Platform.isAndroid || _isInitialized) {
      return;
    }

    try {
      await _channel.invokeMethod('startForegroundService');
      _isInitialized = true;
      if (kDebugMode) {
        print('ForegroundAlarmService: Started successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ForegroundAlarmService: Error starting service: $e');
      }
    }
  }

  /// Stop the foreground service
  static Future<void> stop() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod('stopForegroundService');
      _isInitialized = false;
      if (kDebugMode) {
        print('ForegroundAlarmService: Stopped successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ForegroundAlarmService: Error stopping service: $e');
      }
    }
  }

  /// Check if the service is running
  static bool get isRunning => _isInitialized;
}
