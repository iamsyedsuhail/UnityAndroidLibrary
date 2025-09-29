package com.example.unityandroid;

import android.os.Bundle;
import android.widget.FrameLayout;
import com.unity3d.player.UnityPlayerActivity;

public class MyUnityActivity extends UnityPlayerActivity {
    private MirrorGLSurfaceView glView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        FrameLayout content = findViewById(android.R.id.content);

        glView = new MirrorGLSurfaceView(this);
        // optional: make it overlay nicely while debugging
        // glView.setZOrderOnTop(true);
        // glView.getHolder().setFormat(android.graphics.PixelFormat.TRANSLUCENT);

        content.addView(glView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));
    }

    public void onUnityFrameRGBA(byte[] data, int w, int h, int stride) {
        if (glView != null) glView.updateFrame(data, w, h, stride);
    }

    @Override protected void onPause() { super.onPause(); if (glView != null) glView.onPause(); }
    @Override protected void onResume() { super.onResume(); if (glView != null) glView.onResume(); }
}
