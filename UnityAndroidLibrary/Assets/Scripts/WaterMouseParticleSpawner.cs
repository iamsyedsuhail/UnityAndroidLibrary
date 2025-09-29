using UnityEngine;

public class WaterMouseParticleActivator : MonoBehaviour
{
    public Camera cam;                   // leave empty to use Camera.main
    public bool use2D = false;           // true = Physics2D.Raycast, false = Physics.Raycast
    public string waterTag = "Water";    // objects must have this tag
    public GameObject particlePrefab;    // assign your particle prefab

    private GameObject particleInstance;

    void Start()
    {
        if (!cam) cam = Camera.main;

        if (particlePrefab != null)
        {
            // Create it once and keep disabled
            particleInstance = Instantiate(particlePrefab, Vector3.zero, Quaternion.identity, transform);
            particleInstance.SetActive(false);
        }
        else
        {
            Debug.LogWarning("[WaterMouseParticleActivator] No particlePrefab assigned.");
        }
    }

    void Update()
    {
        if (!particleInstance || !cam) return;

        bool overWater = false;
        Vector3 hitPos = Vector3.zero;

        if (use2D)
        {
            Vector2 mouseWorld = cam.ScreenToWorldPoint(Input.mousePosition);
            RaycastHit2D hit = Physics2D.Raycast(mouseWorld, Vector2.zero);
            if (hit.collider != null && hit.collider.CompareTag(waterTag))
            {
                overWater = true;
                hitPos = hit.point;
            }
        }
        else
        {
            Ray ray = cam.ScreenPointToRay(Input.mousePosition);
            if (Physics.Raycast(ray, out RaycastHit hit))
            {
                if (hit.collider.CompareTag(waterTag))
                {
                    overWater = true;
                    hitPos = hit.point;
                }
            }
        }

        if (overWater)
        {
            if (!particleInstance.activeSelf)
                particleInstance.SetActive(true);

            // move particle to follow mouse hit point
            particleInstance.transform.position = hitPos;
        }
        else
        {
            if (particleInstance.activeSelf)
                particleInstance.SetActive(false);
        }
    }
}
