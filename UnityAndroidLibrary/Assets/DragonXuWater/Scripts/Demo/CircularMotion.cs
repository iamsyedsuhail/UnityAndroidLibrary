using UnityEngine;

namespace WaterDragonXu
{
    public class CircularMotion : MonoBehaviour
    {
        public float speed = 1f;
        private Vector3 startPosition;
        private float angle = 0f;

        void Start()
        {

            startPosition = transform.position;
        }

        void Update()
        {

            angle += speed * Time.deltaTime;


            float x = startPosition.x + Mathf.Cos(angle) * 2f;
            float z = startPosition.z + Mathf.Sin(angle) * 2f;

            transform.position = new Vector3(x, transform.position.y, z);
        }
    }
}