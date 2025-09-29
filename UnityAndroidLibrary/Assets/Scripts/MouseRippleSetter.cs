using UnityEngine;

public class MouseRippleSetter : MonoBehaviour
{
    public Camera cam;                // leave empty → Camera.main
    public string waterTag = "Water"; // tag your water object(s)
    public bool use2D = false;        // true = Physics2D, false = 3D
    public bool onlyOnClick = false;  // set true if you want ripples only when LMB held

    // Optional: expose params so you can tweak without opening the graph
    public float rippleStrength = 1.0f;

    MaterialPropertyBlock _mpb;

    void Awake()
    {
        if (!cam) cam = Camera.main;
        _mpb = new MaterialPropertyBlock();
    }

    void Update()
    {
        if (onlyOnClick && !Input.GetMouseButton(0)) return;

        if (use2D)
        {
            Vector2 p = cam.ScreenToWorldPoint(Input.mousePosition);
            var hit = Physics2D.Raycast(p, Vector2.zero);
            if (hit.collider && hit.collider.CompareTag(waterTag))
            {
                ApplyTo(hit.collider.GetComponent<Renderer>(), hit.point);
            }
        }
        else
        {
            Ray ray = cam.ScreenPointToRay(Input.mousePosition);
            if (Physics.Raycast(ray, out RaycastHit hit) && hit.collider.CompareTag(waterTag))
            {
                ApplyTo(hit.collider.GetComponent<Renderer>(), hit.point);
            }
        }
    }

    void ApplyTo(Renderer r, Vector3 worldPos)
    {
        if (!r) return;
        r.GetPropertyBlock(_mpb);
        _mpb.SetVector("_RippleCenterWS", worldPos);
        _mpb.SetFloat("_RippleStrength", rippleStrength);
        r.SetPropertyBlock(_mpb);
    }
}
