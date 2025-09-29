using UnityEngine;

[RequireComponent(typeof(Renderer))]
public class WaterRippleController : MonoBehaviour {
    public Renderer waterRenderer;          // water mesh renderer using the shader above
    public Transform positionSource;        // assign your PositionTracker GameObject (it moves to hitPos)

    public int maxRipples = 16;             // must match MAX_RIPPLES in shader
    public float spawnInterval = 0.08f;     // seconds between ripples
    public bool onlyWhenMoving = false;     // optional: only drop a ripple if source moved

    MaterialPropertyBlock _mpb;
    Vector4[] _ripples;
    int _count, _head;
    float _accum;
    Vector3 _lastPos;

    void Awake() {
        if (!waterRenderer) waterRenderer = GetComponent<Renderer>();
        _mpb = new MaterialPropertyBlock();
        _ripples = new Vector4[Mathf.Clamp(maxRipples, 1, 64)];
        _count = 0; _head = 0; _accum = 0;
        _lastPos = positionSource ? positionSource.position : Vector3.zero;

        waterRenderer.GetPropertyBlock(_mpb);
        _mpb.SetFloat("_RippleCount", 0);
        _mpb.SetVectorArray("_Ripples", _ripples);
        waterRenderer.SetPropertyBlock(_mpb);
    }

    void Update() {
        if (!positionSource || !waterRenderer) return;

        _accum += Time.deltaTime;
        if (_accum < spawnInterval) return;

        Vector3 p = positionSource.position;
        if (onlyWhenMoving && (p - _lastPos).sqrMagnitude < 1e-6f) return;

        _accum = 0f;
        _lastPos = p;

        _ripples[_head] = new Vector4(p.x, p.y, p.z, Time.time);
        _head = (_head + 1) % _ripples.Length;
        _count = Mathf.Min(_count + 1, _ripples.Length);

        waterRenderer.GetPropertyBlock(_mpb);
        _mpb.SetFloat("_RippleCount", _count);
        _mpb.SetVectorArray("_Ripples", _ripples);
        waterRenderer.SetPropertyBlock(_mpb);
    }
}
