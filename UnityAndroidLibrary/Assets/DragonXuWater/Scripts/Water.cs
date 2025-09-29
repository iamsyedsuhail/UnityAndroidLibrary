using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
namespace WaterDragonXu
{
    public class Water : MonoBehaviour
    {        
        private Renderer _renderer;
        public bool useSharedMaterial = false;

        public Volume volume;
        private UnderWaterVolume underWaterVolume;
        private DistanceBlurVolume blurVol;
        private List<Vector4> rippleCenters;
        private List<float> rippleTimes;
        private List<float> rippleSpeed;

        public float RippleSpeed = 1,RippleDuration = 1,RippleScale = 1;
        public int MaxRippleCount = 10;

        private Material _instanceMaterial;

        private void InitInstancedMaterial()
        {
            _instanceMaterial = new Material(_renderer.sharedMaterial);
            _renderer.material = _instanceMaterial;
        }

        private void InitVolume()
        {
            if (volume == null)
                return;
            foreach (var item in volume.profile.components)
            {
                if (item is UnderWaterVolume)
                    underWaterVolume = item as UnderWaterVolume;
            }
            
            Volume[] volumes = FindObjectsOfType<Volume>();

            foreach (Volume volume in volumes)
            {                
                if (volume.isGlobal)
                {                    
                    if (volume.profile.TryGet(out DistanceBlurVolume distanceBlurVolume))
                    {
                        blurVol = distanceBlurVolume;
                    }
                }
            }
            //blurVol = VolumeManager.instance.stack.GetComponent<DistanceBlurVolume>();
        }
        private void Start()
        {
            _renderer = GetComponent<Renderer>();

            InitVolume();

            InitInstancedMaterial();
        }
        private void SetSurfaceHeight()
        {
            if(underWaterVolume!=null)
                underWaterVolume.SurfaceHeight.SetValue(new FloatParameter(transform.position.y));
            //blurVol = VolumeManager.instance.stack.GetComponent<DistanceBlurVolume>();
            
            Volume[] volumes = FindObjectsOfType<Volume>();
            foreach (Volume volume in volumes)
            {                
                if (volume.isGlobal)
                {                    
                    if (volume.profile.TryGet(out DistanceBlurVolume distanceBlurVolume))
                    {
                        blurVol = distanceBlurVolume;
                    }
                }
            }
            if(blurVol!=null)
            blurVol.SurfaceHeight.SetValue(new FloatParameter(transform.position.y));

        }
        private void SetRippleParams()
        {
            if (rippleCenters == null)
                return;
            if(useSharedMaterial)
            {
                _renderer.sharedMaterial.SetFloat("_RippleSpeed", RippleSpeed);
                _renderer.sharedMaterial.SetFloat("_RippleDuration", RippleDuration);
                _renderer.sharedMaterial.SetFloat("_RippleScale", RippleScale);
                _renderer.sharedMaterial.SetInt("_MaxRippleCount", rippleCenters.Count);
                if (rippleCenters!=null&&rippleCenters.Count > 0)
                    _renderer.sharedMaterial.SetVectorArray("_RippleCenter", rippleCenters.ToArray());
                if (rippleTimes != null&&rippleTimes.Count > 0)
                    _renderer.sharedMaterial.SetFloatArray("_RippleTimes", rippleTimes.ToArray());
                if (rippleSpeed != null&& rippleSpeed.Count > 0)
                    _renderer.sharedMaterial.SetFloatArray("_RippleSpeedMul", rippleSpeed.ToArray());
            }
            else
            {
                _instanceMaterial.SetFloat("_RippleSpeed", RippleSpeed);
                _instanceMaterial.SetFloat("_RippleDuration", RippleDuration);
                _instanceMaterial.SetFloat("_RippleScale", RippleScale);
                _instanceMaterial.SetInt("_MaxRippleCount", rippleCenters.Count);

                if (rippleCenters != null && rippleCenters.Count > 0)
                    _instanceMaterial.SetVectorArray("_RippleCenter", rippleCenters.ToArray());
                if (rippleCenters != null && rippleTimes.Count > 0)
                    _instanceMaterial.SetFloatArray("_RippleTimes", rippleTimes.ToArray());
                if (rippleSpeed != null && rippleSpeed.Count > 0)
                    _instanceMaterial.SetFloatArray("_RippleSpeedMul", rippleSpeed.ToArray());

                _renderer.material = _instanceMaterial;
            }

        }
        public void SetMaterialArrays(List<Vector4>RippleCenters, List<float>RippleTimes, List<float> RippleSpeed)
        {

            rippleCenters = RippleCenters;
            
            rippleTimes = RippleTimes;

            rippleSpeed = RippleSpeed;

            //**********************************************************************************************************************************************8
            //The array length can't be changed once it has been added to the block.
            //If you subsequently try to set a longer array into the same property,
            //the length will be capped to the original length and the extra items you tried to assign will be ignored.
            //If you set a shorter array than the original length,
            //your values will be assigned but the original values will remain for the array elements beyond the length of your new shorter array.

            while (rippleCenters.Count < MaxRippleCount)
            {
                rippleCenters.Add(Vector4.zero);
            }

            while (rippleTimes.Count < MaxRippleCount)
            {
                rippleTimes.Add(-1f);
            }

            while (rippleSpeed.Count < MaxRippleCount)
            {
                rippleSpeed.Add(1f);
            }
        }
        private void Update()
        {
            SetSurfaceHeight();

            SetRippleParams();

            Camera camera = Camera.main;

            if (camera && (camera.cameraType == CameraType.Game || camera.cameraType == CameraType.SceneView))
            {
                Matrix4x4 vp = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false) * camera.worldToCameraMatrix;
                Matrix4x4 inv_vp = vp.inverse;

                Shader.SetGlobalMatrix("_Camera_INV_VP", inv_vp);
                

                if (useSharedMaterial)
                {
                    _renderer.sharedMaterial.SetMatrix("_VM", camera.worldToCameraMatrix * _renderer.localToWorldMatrix);
                    _renderer.sharedMaterial.SetMatrix("_PV", vp);
                }
                else
                {
                    _renderer.material.SetMatrix("_VM", camera.worldToCameraMatrix * _renderer.localToWorldMatrix);
                    _renderer.material.SetMatrix("_PV", vp);
                }
            }

            
        }
        void OnDestroy()
        {
            if (_instanceMaterial != null)
            {
                Destroy(_instanceMaterial);
            }
        }
    }
}