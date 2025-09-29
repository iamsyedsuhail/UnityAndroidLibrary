using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

namespace WaterDragonXu
{
    [VolumeComponentMenu("Custom/UnderWater")]
    public class UnderWaterVolume : VolumeComponent, IPostProcessComponent
    {
        public BoolParameter isActive = new BoolParameter(false);
        public FloatParameter SurfaceHeight = new FloatParameter(1f);
        public ColorParameter WaterColor = new ColorParameter(UnityEngine.Color.blue);
        public ColorParameter CausticColor = new ColorParameter(UnityEngine.Color.white);
        public FloatParameter Visibility = new FloatParameter(3);
        public FloatParameter DistancePow = new FloatParameter(1);
        public FloatParameter CausticScale = new FloatParameter(7);
        public FloatParameter CausticStrength = new FloatParameter(1);
        public FloatParameter CausticMaxDepth = new FloatParameter(2);
        public FloatParameter FloatSpeed = new FloatParameter(1);
        public Vector2Parameter FlowDirection = new Vector2Parameter(new UnityEngine.Vector2(1, 1));
        public FloatParameter NoiseScale = new FloatParameter(1);
        public FloatParameter NoiseStrength = new FloatParameter(1);
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