package com.zuwad;

import android.os.Build;
import android.os.Bundle;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.app.PictureInPictureParams;
import android.util.Rational;
import android.content.Intent;
import androidx.annotation.NonNull;
import androidx.core.view.WindowCompat;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL_PIP = "com.zuwad/pip";
    private static final String CHANNEL_FOREGROUND = "com.zuwad/foreground_alarm";
    private static final String CHANNEL_NATIVE_ALARM = "com.zuwad/native_alarm";
    private boolean isPipEnabled = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Enable edge-to-edge display
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // For Android 11+ (API 30+)
            WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        }

        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        // Handle alarm notification tap
        if (intent != null && intent.getExtras() != null) {
            Bundle extras = intent.getExtras();
            if (extras.containsKey("alarm_id")) {
                // Alarm was triggered, notify Flutter
                // This will be handled by the alarm plugin
            }
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // PiP Method Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_PIP)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "enablePip":
                        isPipEnabled = true;
                        updatePipParams(true);
                        result.success(true);
                        break;
                    case "disablePip":
                        isPipEnabled = false;
                        updatePipParams(false);
                        result.success(true);
                        break;
                    case "enterPip":
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            PictureInPictureParams.Builder builder = new PictureInPictureParams.Builder()
                                .setAspectRatio(new Rational(16, 9));
                            enterPictureInPictureMode(builder.build());
                            result.success(true);
                        } else {
                            result.success(false);
                        }
                        break;
                    default:
                        result.notImplemented();
                        break;
                }
            });

        // Foreground Alarm Service Method Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_FOREGROUND)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("startForegroundService")) {
                    startAlarmForegroundService();
                    result.success(true);
                } else if (call.method.equals("stopForegroundService")) {
                    stopAlarmForegroundService();
                    result.success(true);
                } else {
                    result.notImplemented();
                }
            });

        // Native Alarm Method Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_NATIVE_ALARM)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("initialize")) {
                    result.success(true);
                } else if (call.method.equals("scheduleAlarm")) {
                    int alarmId = call.argument("alarm_id");
                    long timestamp = call.argument("timestamp");
                    String title = call.argument("title");
                    String body = call.argument("body");

                    boolean success = scheduleNativeAlarm(alarmId, timestamp, title, body);
                    result.success(success);
                } else if (call.method.equals("cancelAlarm")) {
                    int alarmId = call.argument("alarm_id");
                    cancelNativeAlarm(alarmId);
                    result.success(null);
                } else if (call.method.equals("cancelAllAlarms")) {
                    cancelAllNativeAlarms();
                    result.success(null);
                } else {
                    result.notImplemented();
                }
            });
    }

    private void startAlarmForegroundService() {
        Intent serviceIntent = new Intent(this, AlarmForegroundService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent);
        } else {
            startService(serviceIntent);
        }
    }

    private void stopAlarmForegroundService() {
        Intent serviceIntent = new Intent(this, AlarmForegroundService.class);
        stopService(serviceIntent);
    }

    private boolean scheduleNativeAlarm(int alarmId, long timestamp, String title, String body) {
        try {
            android.util.Log.d("MainActivity", "Scheduling native alarm:");
            android.util.Log.d("MainActivity", "  ID: " + alarmId);
            android.util.Log.d("MainActivity", "  Timestamp: " + timestamp);
            android.util.Log.d("MainActivity", "  Time: " + new java.util.Date(timestamp));
            android.util.Log.d("MainActivity", "  Title: " + title);
            android.util.Log.d("MainActivity", "  Body: " + body);

            AlarmManager alarmManager = (AlarmManager) getSystemService(ALARM_SERVICE);
            Intent intent = new Intent("com.zuwad.ALARM_TRIGGER");
            intent.setClass(this, AlarmReceiver.class);
            intent.putExtra("alarm_id", alarmId);
            intent.putExtra("title", title);
            intent.putExtra("body", body);

            android.util.Log.d("MainActivity", "Intent created: " + intent.toString());

            PendingIntent pendingIntent = PendingIntent.getBroadcast(
                    this,
                    alarmId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );

            android.util.Log.d("MainActivity", "PendingIntent created");

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ requires exact alarm permission
                boolean canSchedule = alarmManager.canScheduleExactAlarms();
                android.util.Log.d("MainActivity", "Android 12+, canScheduleExactAlarms: " + canSchedule);

                if (canSchedule) {
                    alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            timestamp,
                            pendingIntent
                    );
                    android.util.Log.d("MainActivity", "Used setExactAndAllowWhileIdle");
                } else {
                    // Fallback to setAlarmClock if exact alarm not allowed
                    alarmManager.setAlarmClock(
                            new AlarmManager.AlarmClockInfo(timestamp, pendingIntent),
                            pendingIntent
                    );
                    android.util.Log.d("MainActivity", "Used setAlarmClock (exact alarm not allowed)");
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Android 6-11
                alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        timestamp,
                        pendingIntent
                );
                android.util.Log.d("MainActivity", "Used setExactAndAllowWhileIdle (Android 6-11)");
            } else {
                // Android 5 and below
                alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        timestamp,
                        pendingIntent
                );
                android.util.Log.d("MainActivity", "Used setExact (Android 5)");
            }

            android.util.Log.d("MainActivity", "Alarm scheduled successfully");
            return true;
        } catch (Exception e) {
            android.util.Log.e("MainActivity", "Error scheduling native alarm", e);
            e.printStackTrace();
            return false;
        }
    }

    private void cancelNativeAlarm(int alarmId) {
        try {
            AlarmManager alarmManager = (AlarmManager) getSystemService(ALARM_SERVICE);
            Intent intent = new Intent("com.zuwad.ALARM_TRIGGER");
            intent.setClass(this, AlarmReceiver.class);

            PendingIntent pendingIntent = PendingIntent.getBroadcast(
                    this,
                    alarmId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );

            alarmManager.cancel(pendingIntent);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void cancelAllNativeAlarms() {
        try {
            AlarmManager alarmManager = (AlarmManager) getSystemService(ALARM_SERVICE);
            Intent intent = new Intent("com.zuwad.ALARM_TRIGGER");
            intent.setClass(this, AlarmReceiver.class);

            PendingIntent pendingIntent = PendingIntent.getBroadcast(
                    this,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );

            alarmManager.cancel(pendingIntent);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void updatePipParams(boolean autoEnter) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PictureInPictureParams.Builder builder = new PictureInPictureParams.Builder()
                .setAutoEnterEnabled(autoEnter)
                .setAspectRatio(new Rational(16, 9));
            setPictureInPictureParams(builder.build());
        }
    }

    @Override
    public void onUserLeaveHint() {
        super.onUserLeaveHint();
        // Only auto-enter PiP when enabled (i.e., when on meeting page)
        if (isPipEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PictureInPictureParams.Builder builder = new PictureInPictureParams.Builder()
                .setAspectRatio(new Rational(16, 9));
            enterPictureInPictureMode(builder.build());
        }
    }
}