package com.zuwad;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.os.Vibrator;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

public class AlarmReceiver extends BroadcastReceiver {
    private static final String CHANNEL_ID = "alarm_notifications";
    private static final int NOTIFICATION_ID = 1000;

    @Override
    public void onReceive(Context context, Intent intent) {
        android.util.Log.d("AlarmReceiver", "onReceive called!");
        android.util.Log.d("AlarmReceiver", "Action: " + intent.getAction());
        android.util.Log.d("AlarmReceiver", "Extras: " + intent.getExtras());

        // Acquire wake lock to ensure device stays awake for notification
        PowerManager.WakeLock wakeLock = null;
        try {
            PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (pm != null) {
                wakeLock = pm.newWakeLock(
                        PowerManager.FULL_WAKE_LOCK |
                        PowerManager.ACQUIRE_CAUSES_WAKEUP |
                        PowerManager.ON_AFTER_RELEASE,
                        "zuwad:alarm_wake_lock"
                );
                wakeLock.acquire(10 * 1000L); // Keep awake for 10 seconds
                android.util.Log.d("AlarmReceiver", "WakeLock acquired");
            }

            // Get alarm details from intent
            int alarmId = intent.getIntExtra("alarm_id", 0);
            String title = intent.getStringExtra("title");
            String body = intent.getStringExtra("body");

            android.util.Log.d("AlarmReceiver", "Alarm ID: " + alarmId);
            android.util.Log.d("AlarmReceiver", "Title: " + title);
            android.util.Log.d("AlarmReceiver", "Body: " + body);

            if (title == null) title = "منبه الحصة";
            if (body == null) body = "حان وقت الحصة";

            // Create notification channel for Android O+
            createNotificationChannel(context);

            // Create and show notification
            Notification notification = createNotification(context, title, body, alarmId);
            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
            notificationManager.notify(NOTIFICATION_ID + alarmId, notification);

            android.util.Log.d("AlarmReceiver", "Notification shown");

            // Play sound and vibrate
            playAlarmSound(context);
            vibrateDevice(context);

        } catch (Exception e) {
            android.util.Log.e("AlarmReceiver", "Error in onReceive", e);
            e.printStackTrace();
        } finally {
            if (wakeLock != null && wakeLock.isHeld()) {
                wakeLock.release();
                android.util.Log.d("AlarmReceiver", "WakeLock released");
            }
        }
    }

    private void createNotificationChannel(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "منبهات الحصة",
                    NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("إشعارات منبهات الحصص");
            channel.enableVibration(true);
            channel.enableLights(true);

            NotificationManager manager = context.getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    private Notification createNotification(Context context, String title, String body, int alarmId) {
        Intent notificationIntent = new Intent(context, MainActivity.class);
        notificationIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        notificationIntent.putExtra("alarm_id", alarmId);

        PendingIntent pendingIntent = PendingIntent.getActivity(
                context,
                alarmId,
                notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        // Create stop intent
        Intent stopIntent = new Intent(context, AlarmReceiver.class);
        stopIntent.setAction("STOP_ALARM");
        stopIntent.putExtra("alarm_id", alarmId);
        PendingIntent stopPendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId,
                stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(false)
                .setOngoing(true)
                .setContentIntent(pendingIntent)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "إيقاف", stopPendingIntent)
                .setVibrate(new long[]{0, 500, 200, 500})
                .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION));

        return builder.build();
    }

    private void playAlarmSound(Context context) {
        try {
            Uri alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM);
            if (alarmUri == null) {
                alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
            }

            Ringtone ringtone = RingtoneManager.getRingtone(context, alarmUri);
            if (ringtone != null) {
                ringtone.play();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void vibrateDevice(Context context) {
        try {
            Vibrator vibrator = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
            if (vibrator != null) {
                // Vibrate pattern: 0ms delay, 500ms vibrate, 200ms pause, 500ms vibrate
                long[] pattern = {0, 500, 200, 500};
                vibrator.vibrate(pattern, -1); // -1 = don't repeat
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
