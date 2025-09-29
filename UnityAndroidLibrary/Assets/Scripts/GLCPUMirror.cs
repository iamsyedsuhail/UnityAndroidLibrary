using System;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class GLCPUMirror : MonoBehaviour {
    public Camera sourceCamera;
    public RenderTexture rt;
    public int width = 640;
    public int height = 360;

    byte[] _buffer;
    bool _createdRT;
    bool _inFlight;
    float _next;
    AndroidJavaObject _activity;

    void Awake() {
        if (rt == null) {
            rt = new RenderTexture(width, height, 0, RenderTextureFormat.ARGB32);
            rt.graphicsFormat = UnityEngine.Experimental.Rendering.GraphicsFormat.R8G8B8A8_UNorm;
            rt.useMipMap = false;
            rt.autoGenerateMips = false;
            rt.Create();
            _createdRT = true;
        }
        if (sourceCamera != null) sourceCamera.targetTexture = rt;
    }

    void OnDestroy() {
        if (sourceCamera != null) sourceCamera.targetTexture = null;
        if (_createdRT && rt != null) rt.Release();
    }

    void OnRenderImage(RenderTexture src, RenderTexture dst) {
        Graphics.Blit(src, dst);
        if (rt == null) return;
        if (Application.platform != RuntimePlatform.Android) return;
        if (Time.unscaledTime < _next) return;
        if (_inFlight) return;
        _inFlight = true;
        _next = Time.unscaledTime + 1f / 30f;
        AsyncGPUReadback.Request(rt, 0, TextureFormat.RGBA32, OnReadback);
    }

    void EnsureActivity() {
        if (_activity != null) return;
        var cls = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
        _activity = cls.GetStatic<AndroidJavaObject>("currentActivity");
    }

    void OnReadback(AsyncGPUReadbackRequest req) {
        if (req.hasError) { _inFlight = false; return; }
        NativeArray<byte> data = req.GetData<byte>();
        int needed = rt.width * rt.height * 4;
        if (_buffer == null || _buffer.Length != needed) _buffer = new byte[needed];
        data.CopyTo(_buffer);
        EnsureActivity();
        _activity?.Call("onUnityFrameRGBA", _buffer, rt.width, rt.height, rt.width * 4);
        _inFlight = false;
    }
}
