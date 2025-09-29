package com.example.unityandroid;

import android.os.Bundle;
import android.widget.FrameLayout;
import com.unity3d.player.UnityPlayerActivity;

public class MyUnityActivity extends UnityPlayerActivity {
    private MirrorGLSurfaceView glView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        FrameLayout unityRoot = (FrameLayout) mUnityPlayer.getFrameLayout();

        glView = new MirrorGLSurfaceView(this);

        FrameLayout container = new FrameLayout(this);
        container.addView(unityRoot, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        container.addView(glView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        setContentView(container);
    }

    public void onUnityFrameRGBA(byte[] data, int w, int h, int stride) {
        if (glView != null) glView.updateFrame(data, w, h, stride);
    }

    @Override protected void onPause() { super.onPause(); if (glView != null) glView.onPause(); }
    @Override protected void onResume() { super.onResume(); if (glView != null) glView.onResume(); }
}
