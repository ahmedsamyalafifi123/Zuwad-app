package com.zuwad;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import androidx.core.app.NotificationCompat;
import android.content.pm.ServiceInfo;

public class AlarmForegroundService extends Service {
    private static final String CHANNEL_ID = "alarm_foreground_channel";
    private static final int NOTIFICATION_ID = 9999;

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ (API 34+) requires specifying service type
            startForeground(NOTIFICATION_ID, createNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC | ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ (API 30+)
            startForeground(NOTIFICATION_ID, createNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
        } else {
            // Android 10 and below
            startForeground(NOTIFICATION_ID, createNotification());
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Keep service alive
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "Alarm Service",
                    NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Keeps alarm service running in background");
            channel.setShowBadge(false);
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    private Notification createNotification() {
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
        );

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("منبهات الحصة")
                .setContentText("المنبهات نشطة في الخلفية")
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_SERVICE);

        return builder.build();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        // Restart service if killed
        Intent restartIntent = new Intent(getApplicationContext(), AlarmForegroundService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(restartIntent);
        } else {
            startService(restartIntent);
        }
    }
}
