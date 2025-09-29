using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

namespace WaterDragonXu
{
    [VolumeComponentMenu("Custom/DistanceBlur")]
    public class DistanceBlurVolume : VolumeComponent, IPostProcessComponent
    {
        public BoolParameter isActive = new BoolParameter(false);
        public FloatParameter SurfaceHeight = new FloatParameter(1f);
        public FloatParameter BlurDistance = new FloatParameter(20);

        public IntParameter BlurLoop = new IntParameter(3);
        public bool IsActive()
        {
            return isActive.value;
        }

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}