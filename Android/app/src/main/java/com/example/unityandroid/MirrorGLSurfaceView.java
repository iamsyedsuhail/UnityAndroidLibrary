package com.example.unityandroid;

import android.content.Context;
import android.opengl.GLES20;
import android.opengl.GLSurfaceView;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.concurrent.atomic.AtomicBoolean;
import android.util.Log;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MirrorGLSurfaceView extends GLSurfaceView {
    private final MirrorRenderer renderer = new MirrorRenderer();

    public MirrorGLSurfaceView(Context ctx) {
        super(ctx);
        setEGLContextClientVersion(2);
        setRenderer(renderer);
        setRenderMode(RENDERMODE_WHEN_DIRTY);
    }

    public void updateFrame(byte[] rgba, int w, int h, int stride) {
        renderer.updateFrame(rgba, w, h);
        requestRender();
    }

    private static class MirrorRenderer implements Renderer {
        private int texId = 0, prog = 0, aPos = -1, aUV = -1, uTex = -1;
        private int vpW = 0, vpH = 0, width = 0, height = 0;
        private ByteBuffer pixelBuf;
        private final AtomicBoolean hasNew = new AtomicBoolean(false);
        private FloatBuffer quad;
        private long lastFpsTime = 0;
        private int frameCount = 0;
        void updateFrame(byte[] data, int w, int h) {
            if (pixelBuf == null || w != width || h != height) {
                width = w; height = h;
                pixelBuf = ByteBuffer.allocateDirect(w * h * 4).order(ByteOrder.nativeOrder());
            }
            pixelBuf.position(0);
            pixelBuf.put(data, 0, w * h * 4);
            hasNew.set(true);
        }

        @Override public void onSurfaceCreated(GL10 gl, EGLConfig config) {
            String vs =
                    "attribute vec2 aPos;" +
                            "attribute vec2 aUV;" +
                            "varying vec2 vUV;" +
                            "void main(){ vUV=aUV; gl_Position=vec4(aPos,0.0,1.0); }";
            String fs =
                    "precision mediump float;" +
                            "varying vec2 vUV;" +
                            "uniform sampler2D uTex;" +
                            "void main(){ gl_FragColor = texture2D(uTex, vUV); }";
            prog = link(vs, fs);
            aPos = GLES20.glGetAttribLocation(prog, "aPos");
            aUV  = GLES20.glGetAttribLocation(prog, "aUV");
            uTex = GLES20.glGetUniformLocation(prog, "uTex");

            int[] t = new int[1];
            GLES20.glGenTextures(1, t, 0);
            texId = t[0];
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE);
            GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1);

            float[] quadData = {
                    -1f,-1f,  0f,1f,
                    1f,-1f,  1f,1f,
                    -1f, 1f,  0f,0f,
                    1f, 1f,  1f,0f
            };
            quad = ByteBuffer.allocateDirect(quadData.length * 4)
                    .order(ByteOrder.nativeOrder()).asFloatBuffer();
            quad.put(quadData).position(0);
            GLES20.glClearColor(0f,0f,0f,1f);
        }

        @Override public void onSurfaceChanged(GL10 gl, int w, int h) {
            vpW = w; vpH = h;
            GLES20.glViewport(0, 0, w, h);
        }

        @Override
        public void onDrawFrame(GL10 gl) {
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT);

            if (hasNew.compareAndSet(true, false)) {
                pixelBuf.position(0);
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId);
                GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA,
                        width, height, 0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, pixelBuf);
            }

            GLES20.glUseProgram(prog);
            quad.position(0);
            GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 16, quad);
            GLES20.glEnableVertexAttribArray(aPos);
            quad.position(2);
            GLES20.glVertexAttribPointer(aUV, 2, GLES20.GL_FLOAT, false, 16, quad);
            GLES20.glEnableVertexAttribArray(aUV);
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId);
            GLES20.glUniform1i(uTex, 0);
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4);

            // --- FPS logging ---
            frameCount++;
            long now = System.currentTimeMillis();
            if (lastFpsTime == 0) lastFpsTime = now;
            if (now - lastFpsTime >= 1000) {
                android.util.Log.d("MirrorRenderer", "FPS = " + frameCount);
                frameCount = 0;
                lastFpsTime = now;
            }
        }

        private static int link(String vsSrc, String fsSrc) {
            int vs = compile(GLES20.GL_VERTEX_SHADER, vsSrc);
            int fs = compile(GLES20.GL_FRAGMENT_SHADER, fsSrc);
            int p = GLES20.glCreateProgram();
            GLES20.glAttachShader(p, vs);
            GLES20.glAttachShader(p, fs);
            GLES20.glLinkProgram(p);
            GLES20.glDeleteShader(vs);
            GLES20.glDeleteShader(fs);
            return p;
        }

        private static int compile(int type, String src) {
            int s = GLES20.glCreateShader(type);
            GLES20.glShaderSource(s, src);
            GLES20.glCompileShader(s);
            return s;
        }
    }
}
