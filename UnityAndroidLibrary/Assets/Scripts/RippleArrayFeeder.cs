using UnityEngine;

[RequireComponent(typeof(Renderer))]
public class RippleArrayFeeder : MonoBehaviour {
    public Transform positionSource;        // your PositionTracker (moves to hitPos)

    [Header("Emission")]
    public float spawnInterval = 0.06f;     // seconds between drops
    public bool onlyWhenMoving = true;
    public float minMoveDistance = 0.01f;   // meters to consider movement

    [Header("Speed -> Expansion")]
    public bool speedBasedExpansion = true; // scales _RippleSpeedMul by motion speed
    public float speedToMul = 4f;           // higher = needs more speed to reach mul=1
    public float minMul = 0.6f, maxMul = 2.0f;

    [Header("Buffer")]
    public int maxRipples = 64;             // must be <= RIPPLE_MAX in shader

    [Header("Match material")]
    public float rippleDuration = 1.6f;     // should equal material _RippleDuration

    Renderer _r;
    MaterialPropertyBlock _mpb;

    Vector4[] _centers;   // xyz = world pos
    float[] _ages;      // seconds since spawn; <0 means inactive
    float[] _mul;       // per ripple multiplier
    int _count, _head;
    float _timer;
    Vector3 _lastPos;

    static readonly int ID_Center = Shader.PropertyToID("_RippleCenter");
    static readonly int ID_Times = Shader.PropertyToID("_RippleTimes");
    static readonly int ID_Mul = Shader.PropertyToID("_RippleSpeedMul");
    static readonly int ID_Max = Shader.PropertyToID("_MaxRippleCount");

    void Awake() {
        _r = GetComponent<Renderer>();
        _mpb = new MaterialPropertyBlock();

        maxRipples = Mathf.Clamp(maxRipples, 1, 64);
        _centers = new Vector4[maxRipples];
        _ages = new float[maxRipples];
        _mul = new float[maxRipples];

        for (int i = 0; i < maxRipples; i++) _ages[i] = -1f;

        _r.GetPropertyBlock(_mpb);
        _mpb.SetInt(ID_Max, 0);
        _mpb.SetVectorArray(ID_Center, _centers);
        _mpb.SetFloatArray(ID_Times, _ages);
        _mpb.SetFloatArray(ID_Mul, _mul);
        _r.SetPropertyBlock(_mpb);

        if (positionSource) _lastPos = positionSource.position;
    }

    void Update() {
        if (!positionSource) return;

        // age & cull
        for (int i = 0; i < _count; i++) {
            if (_ages[i] >= 0f) {
                _ages[i] += Time.deltaTime;
                if (_ages[i] > rippleDuration + 0.25f) _ages[i] = -1f;
            }
        }

        _timer += Time.deltaTime;
        if (_timer >= spawnInterval) {
            Vector3 p = positionSource.position;
            float moved = (p - _lastPos).magnitude;

            if (!onlyWhenMoving || moved >= minMoveDistance) {
                float mul = 1f;
                if (speedBasedExpansion) {
                    float speed = moved / Mathf.Max(Time.deltaTime, 1e-5f);
                    mul = Mathf.Clamp(speed / Mathf.Max(speedToMul, 1e-3f), minMul, maxMul);
                }
                Spawn(p, mul);
                _lastPos = p;
            }
            _timer = 0f;
        }

        // push to material
        _r.GetPropertyBlock(_mpb);
        _mpb.SetInt(ID_Max, _count);
        _mpb.SetVectorArray(ID_Center, _centers);
        _mpb.SetFloatArray(ID_Times, _ages);
        _mpb.SetFloatArray(ID_Mul, _mul);
        _r.SetPropertyBlock(_mpb);
    }

    void Spawn(Vector3 worldPos, float mul) {
        _centers[_head] = new Vector4(worldPos.x, worldPos.y, worldPos.z, 0f);
        _ages[_head] = 0f;
        _mul[_head] = mul;

        _head = (_head + 1) % maxRipples;
        if (_count < maxRipples) _count++;
    }
}
