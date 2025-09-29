using UnityEngine;
using System.Collections.Generic;

[RequireComponent(typeof(Renderer))]
public class RippleTrailEmitter : MonoBehaviour {
    public Transform positionSource;      // your PositionTracker (moves to hitPos)
    public int maxRipples = -1;          // <= your shader array limit
    public float spawnEveryMeters = 0.05f;// distance along path between ripple points
    public float speedToMul = 4f;         // velocity→_RippleSpeedMul scaler
    public float duration = 1.5f;         // must match material _RippleDuration

    Renderer _r;
    MaterialPropertyBlock _mpb;

    Vector4[] centers;
    float[] ages;
    float[] speedMul;
    int count, head;

    Vector3 lastPos;
    float pathAccumulate;
    Vector3 lastVel;

    void Awake() {
        _r = GetComponent<Renderer>();
        _mpb = new MaterialPropertyBlock();
        centers = new Vector4[maxRipples];
        ages = new float[maxRipples];
        speedMul = new float[maxRipples];

        _r.GetPropertyBlock(_mpb);
        _mpb.SetInt("_MaxRippleCount", 0);
        _mpb.SetVectorArray("_RippleCenter", centers);
        _mpb.SetFloatArray("_RippleTimes", ages);
        _mpb.SetFloatArray("_RippleSpeedMul", speedMul);
        _r.SetPropertyBlock(_mpb);

        if (positionSource) lastPos = positionSource.position;
    }

    void Update() {
        if (!positionSource) return;

        Vector3 p = positionSource.position;
        Vector3 v = (p - lastPos) / Mathf.Max(Time.deltaTime, 1e-5f);
        float speed = v.magnitude;
        lastVel = v;

        // age existing ripples & prune expired
        for (int i = 0; i < count; i++) {
            ages[i] += Time.deltaTime;
        }

        // advance along path and drop points every X meters while moving
        float step = (p - lastPos).magnitude;
        pathAccumulate += step;

        if (pathAccumulate >= spawnEveryMeters && speed > 0.01f) {
            pathAccumulate = 0f;
            AddRipple(p, Mathf.Clamp(speed / speedToMul, 0.5f, 2f));
        }

        lastPos = p;

        // write to material
        _r.GetPropertyBlock(_mpb);
        _mpb.SetInt("_MaxRippleCount", count);
        _mpb.SetVectorArray("_RippleCenter", centers);
        _mpb.SetFloatArray("_RippleTimes", ages);
        _mpb.SetFloatArray("_RippleSpeedMul", speedMul);
        _r.SetPropertyBlock(_mpb);
    }

    void AddRipple(Vector3 worldPos, float mul) {
        centers[head] = new Vector4(worldPos.x, worldPos.y, worldPos.z, 0f);
        ages[head] = 0f;
        speedMul[head] = mul;

        head = (head + 1) % maxRipples;
        if (count < maxRipples) count++;

        // drop the oldest if beyond duration (optional hard prune)
        for (int i = 0; i < count; i++) {
            if (ages[i] > duration) ages[i] = -1f; // shader skips negatives
        }
    }
}
