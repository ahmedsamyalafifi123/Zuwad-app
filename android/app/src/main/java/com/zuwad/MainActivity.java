package com.zuwad;

import android.os.Build;
import android.os.Bundle;
import androidx.core.view.WindowCompat;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
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
    protected void onStart() {
        super.onStart();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setPictureInPictureParams(new android.app.PictureInPictureParams.Builder()
                    .setAutoEnterEnabled(true)
                    .build());
        }
    }
}