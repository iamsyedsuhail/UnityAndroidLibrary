using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
namespace WaterDragonXu
{
    [ExecuteAlways]
    public class DemoLoadPipeline : MonoBehaviour
    {
        public UniversalRenderPipelineAsset pipelineAsset;
        private void OnEnable()
        {
            UpdatePipeline();
        }

        void UpdatePipeline()
        {
            if (pipelineAsset)
            {
                GraphicsSettings.defaultRenderPipeline = pipelineAsset;
            }
        }


    }

}
