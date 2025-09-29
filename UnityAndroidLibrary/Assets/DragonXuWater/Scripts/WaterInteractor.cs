using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace WaterDragonXu
{


    public class WaterInteractor : MonoBehaviour
    {
        
        public bool UseSharedMaterial;

                                        

        public float StaticRippleInterval = 0.5f;
        public float MinRippleInterval = 0.05f;

        public bool EmittingRipple = true;

        private List<Water> EnteredWaterList;

        public float InitialRippleRadius = 0.5f, RippleGenerationAcceleration = 4, RippleSpreadAcceleration = 4;


        private Vector3 prevPos;
        private float speed;
        void Start()
        {
            EnteredWaterList = new List<Water>();

            StartCoroutine(EmitRipple());

            prevPos = transform.position;
        }       

        private void OnTriggerEnter(Collider other)
        {
            
            if(other.TryGetComponent<Water>(out Water w))
            {
                if(!EnteredWaterList.Contains(w))
                {
                    EnteredWaterList.Add(w);

                    AddRipple(w);
                }                                
            }
            
        }

        private void OnTriggerExit(Collider other)
        {
            
            if (other.TryGetComponent<Water>(out Water w))
            {
                if (EnteredWaterList.Contains(w))
                {
                    EnteredWaterList.Remove(w);
                    
                }
                if(EnteredWaterList.Count == 0)
                {                    
                }                
            }
        }

        private void AddRipple()
        {
            foreach (var item in EnteredWaterList)
            {
                AddRipple(item);
            }
        }
        private void AddRipple(Water water)
        {                        
            WaterManager.manager.AddRipple(water, new Vector4(transform.position.x, transform.position.y, transform.position.z, 1), InitialRippleRadius, 1 + speed * RippleSpreadAcceleration);
        }
        IEnumerator EmitRipple()
        {            
            while(true)
            {
                float t = Mathf.Lerp(StaticRippleInterval, MinRippleInterval,(Mathf.Clamp(speed * RippleGenerationAcceleration, 0, 1)));
                yield return new WaitForSeconds(t);

                if (!EmittingRipple)
                    continue;

                AddRipple();
            }            
        }

        private void Update()
        {
            speed = Vector3.Distance(transform.position, prevPos) / Time.deltaTime;
            prevPos = transform.position;
        }
    }

}
