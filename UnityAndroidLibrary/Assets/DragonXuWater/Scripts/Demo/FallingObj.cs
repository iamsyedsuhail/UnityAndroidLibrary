using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace WaterDragonXu
{
    public class FallingObj : MonoBehaviour
    {
        public float fallDuration = 2f;
        private Vector3 startPosition;
        private float timer = 0f;
        private bool isFalling = true;

        void Start()
        {

            startPosition = transform.position;
        }

        void Update()
        {
            timer += Time.deltaTime;

            if (isFalling)
            {

                float gravity = -9.81f;
                float fallDistance = 0.5f * gravity * Mathf.Pow(timer, 2);
                transform.position = startPosition + new Vector3(0, fallDistance, 0);


                if (timer >= fallDuration)
                {
                    isFalling = false;
                    timer = 0f;
                }
            }
            else
            {
                transform.position = startPosition;


                isFalling = true;

            }
        }
    }
}