package com.zuwad;

import android.os.Build;
import android.os.Bundle;
import android.app.PictureInPictureParams;
import android.util.Rational;
import androidx.annotation.NonNull;
import androidx.core.view.WindowCompat;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.zuwad/pip";
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
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
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