using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace WaterDragonXu
{


    public class WaterManager : MonoBehaviour
    {
        public static WaterManager manager;
        public List<Water> WaterList;            
    
        private Dictionary<Water, List<Vector4>> RippleCenters;
        private Dictionary<Water, List<float>> RippleTimes;
        private Dictionary<Water, List<float>> RippleSpeed;
        //private Dictionary<Water, float> RippleSpeed;
        private Dictionary<Water, float> RippleDuration;
        private Dictionary<Water, float> RippleScale;

        private Dictionary<Water, int> pfront;
        private void InitWaterList()
        {
            RippleDuration = new Dictionary<Water, float>() ;
            pfront = new Dictionary<Water, int>();
            WaterList = new List<Water>();
            RippleCenters = new Dictionary<Water, List<Vector4>>();
            RippleTimes = new Dictionary<Water, List<float>>();
            RippleSpeed = new Dictionary<Water, List<float>>();


            Water[] waters = FindObjectsOfType<Water>();
            //Debug.Log("total: " + waters.Length);
            foreach (var item in waters)
            {
                //Debug.Log(item.transform.name);
                
                WaterList.Add(item);
    
                RippleDuration.Add(item, item.RippleDuration);

                pfront.Add(item, 0);

                RippleCenters.Add(item, new List<Vector4>());

                RippleTimes.Add(item, new List<float>());

                RippleSpeed.Add(item, new List<float>());

                //r.material.SetFloat("_WaveScale", item.RippleScale);

            }
        }

        private void InitRippleParameters()
        {
            
            foreach(var item in WaterList)
            {
            
                //RippleDuration.Add(item, item.RippleDuration);
            }
        }

        void Start()
        {
            manager = this;
    
            InitWaterList();

            //InitRippleParameters();
        }

        
        private void SetMaterialParams(Water water)
        {
            water.SetMaterialArrays(RippleCenters[water], RippleTimes[water], RippleSpeed[water]);
            //waterMaterial.SetVectorArray("_WaveCenters", RippleCenters[waterMaterial]);
            //waterMaterial.SetFloatArray("_WaveTimes", RippleTimes[waterMaterial]);
            //waterMaterial.SetFloat("_WaveSpeed", RippleSpeed[waterMaterial]);
            //waterMaterial.SetFloat("_WaveDuration", RippleDuration[waterMaterial]);
            //waterMaterial.SetFloat("_WaveScale", RippleScale[waterMaterial]);
        }
    
        private void UpdateMaterials()
        {
            foreach (var item in WaterList)
            {
                SetMaterialParams(item);
            }
        }
    
        private void UpdateRipples()
        {
            foreach (var item in RippleCenters)
            {
                for (int i = 0; i < item.Value.Count; i++)
                {
                    if (RippleTimes[item.Key][i] > RippleDuration[item.Key] || RippleTimes[item.Key][i] <= 0)
                    {
                        // clear the ripple                        
                        RippleTimes[item.Key][i]= -1;

                    }
                    else
                        RippleTimes[item.Key][i] += Time.deltaTime;
                }
            }
        }
    
        private void Update()
        {
            UpdateMaterials();
    
            UpdateRipples();
        }
    
        public void AddRipple(Water water, Vector4 center, float initialRadius, float rippleSpeed)
        {
            float t = initialRadius / (water.RippleSpeed * rippleSpeed);
            if(RippleCenters[water].Count < water.MaxRippleCount)
            {
                RippleCenters[water].Add(center);
                RippleTimes[water].Add(t);
                RippleSpeed[water].Add(rippleSpeed);
            }
            else
            {
                RippleCenters[water][pfront[water]] = center;
                RippleTimes[water][pfront[water]] = t;
                RippleSpeed[water][pfront[water]] = rippleSpeed;

                pfront[water]++;
                if(pfront[water] >= water.MaxRippleCount)
                {
                    pfront[water] = 0;
                }
            }
        }
    }
}