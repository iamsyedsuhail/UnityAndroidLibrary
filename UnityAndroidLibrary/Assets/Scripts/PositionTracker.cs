using UnityEngine;

public class PositionTracker : MonoBehaviour
{
    public Camera cam;                   // leave empty to use Camera.main
    public bool use2D = false;           // true = Physics2D.Raycast, false = Physics.Raycast

    void Start()
    {
        if (!cam) cam = Camera.main;
    }

    void Update()
    {
        if (!cam) return;

        bool overWater = false;
        Vector3 hitPos = Vector3.zero;

        if (use2D)
        {
            Vector2 mouseWorld = cam.ScreenToWorldPoint(Input.mousePosition);
            RaycastHit2D hit = Physics2D.Raycast(mouseWorld, Vector2.zero);
            if (hit.collider != null)
            {
                hitPos = hit.point;
            }
        }
        else
        {
            Ray ray = cam.ScreenPointToRay(Input.mousePosition);
            if (Physics.Raycast(ray, out RaycastHit hit))
            {
                hitPos = hit.point;
            }
        }
        Debug.Log(hitPos);
        transform.position = hitPos;
    }
}
