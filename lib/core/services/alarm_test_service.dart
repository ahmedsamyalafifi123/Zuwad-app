import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Test service to verify alarm behavior
class AlarmTestService {
  static const MethodChannel _channel = MethodChannel('com.zuwad/alarm_test');

  /// Trigger a test alarm immediately
  static Future<void> triggerTestAlarm() async {
    if (!Platform.isAndroid) {
      if (kDebugMode) {
        print('AlarmTestService: Test alarms only supported on Android');
      }
      return;
    }

    try {
      await _channel.invokeMethod('triggerTestAlarm');
      if (kDebugMode) {
        print('AlarmTestService: Test alarm triggered');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlarmTestService: Error: $e');
      }
    }
  }
}
