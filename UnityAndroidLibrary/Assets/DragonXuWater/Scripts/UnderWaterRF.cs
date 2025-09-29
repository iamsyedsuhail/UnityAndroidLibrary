using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

namespace WaterDragonXu {
    public class UnderWaterRF : ScriptableRendererFeature {
        [System.Serializable]
        public class Settings {
            public RenderPassEvent InjectionPoint = RenderPassEvent.AfterRenderingOpaques;
            public Material blitMaterial = null;
            public BufferType sourceType = BufferType.CameraColor;
            public BufferType destinationType = BufferType.CameraColor;
            public string sourceTextureId = "_SourceTexture";
            public string destinationTextureId = "_DestinationTexture";
        }

        public Settings settings = new Settings();
        UnderWaterPass blitPass;

        public override void Create() {
            blitPass = new UnderWaterPass(name);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
            if (renderingData.cameraData.cameraType != CameraType.Game || !renderingData.cameraData.postProcessEnabled)
                return;

            if (settings.blitMaterial == null)
                return;

            blitPass.renderPassEvent = settings.InjectionPoint;
            blitPass.settings = settings;
            renderer.EnqueuePass(blitPass);
        }

        protected override void Dispose(bool disposing) {
            blitPass?.Dispose();
            blitPass = null;
        }
    }

    public class UnderWaterPass : ScriptableRenderPass {
        public FilterMode filterMode { get; set; }
        public UnderWaterRF.Settings settings;

        RTHandle source;
        RTHandle destination;
        RTHandle tempRT;
        RTHandle sourceRT;
        RTHandle destinationRT;

        bool isSourceAndDestinationSameTarget;
        string m_ProfilerTag;

        VolumeStack stack;
        UnderWaterVolume underWaterVolume;

        public UnderWaterPass(string tag) {
            m_ProfilerTag = tag;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;

            isSourceAndDestinationSameTarget =
                (settings.sourceType == settings.destinationType &&
                 (settings.sourceType == BufferType.CameraColor ||
                  settings.sourceTextureId == settings.destinationTextureId));

            var renderer = renderingData.cameraData.renderer;

            if (settings.sourceType == BufferType.CameraColor) {
                source = renderer.cameraColorTargetHandle;
            }
            else {
                RenderingUtils.ReAllocateIfNeeded(
                    ref sourceRT, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: settings.sourceTextureId);
                source = sourceRT;
            }

            if (isSourceAndDestinationSameTarget) {
                RenderingUtils.ReAllocateIfNeeded(
                    ref tempRT, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_TempRT");
                destination = tempRT;
            }
            else if (settings.destinationType == BufferType.CameraColor) {
                destination = renderer.cameraColorTargetHandle;
            }
            else {
                RenderingUtils.ReAllocateIfNeeded(
                    ref destinationRT, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: settings.destinationTextureId);
                destination = destinationRT;
            }
        }

        void SetMaterial(ref Material underWaterMat) {
            underWaterMat.SetColor("_CausticColor", underWaterVolume.CausticColor.value);
            underWaterMat.SetFloat("_SurfaceHeight", underWaterVolume.SurfaceHeight.value);
            underWaterMat.SetColor("_Color", underWaterVolume.WaterColor.value);
            underWaterMat.SetFloat("_Visibility", underWaterVolume.Visibility.value);
            underWaterMat.SetFloat("_CausticScale", underWaterVolume.CausticScale.value);
            underWaterMat.SetFloat("_CausticStrength", underWaterVolume.CausticStrength.value);
            underWaterMat.SetFloat("_CausticMaxDepth", underWaterVolume.CausticMaxDepth.value);
            underWaterMat.SetFloat("_FloatSpeed", underWaterVolume.FloatSpeed.value);
            underWaterMat.SetVector("_FlowDirection", underWaterVolume.FlowDirection.value);
            underWaterMat.SetFloat("_NoiseScale", underWaterVolume.NoiseScale.value);
            underWaterMat.SetFloat("_NoiseStrength", underWaterVolume.NoiseStrength.value);
            underWaterMat.SetMatrix("UNITY_MATRIX_I_V1", Camera.main.cameraToWorldMatrix);
            underWaterMat.SetInt("isUnderWater", Camera.main.transform.position.y >= underWaterVolume.SurfaceHeight.value || !underWaterVolume.isActive.value ? 0 : 1);
            underWaterMat.SetFloat("_BlurDistance", underWaterVolume.BlurDistance.value);
            underWaterMat.SetFloat("DistancePow", underWaterVolume.DistancePow.value);

            Vector2 offset = new Vector2(1.0f / Camera.main.pixelWidth, 1.0f / Camera.main.pixelHeight);
            underWaterMat.SetVector("texelSize", offset);
            underWaterMat.SetInt("onlyBlur", 0);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
            var cmd = CommandBufferPool.Get(m_ProfilerTag);

            stack = VolumeManager.instance.stack;
            underWaterVolume = stack.GetComponent<UnderWaterVolume>();
            SetMaterial(ref settings.blitMaterial);

            if (isSourceAndDestinationSameTarget) {
                Blitter.BlitCameraTexture(cmd, source, destination, settings.blitMaterial, 0);
                Blitter.BlitCameraTexture(cmd, destination, source);
                cmd.SetGlobalTexture("_GrabbedColorTex", source.nameID);
            }
            else {
                Blitter.BlitCameraTexture(cmd, source, destination, settings.blitMaterial, 0);
                cmd.SetGlobalTexture("_GrabbedColorTex", destination.nameID);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd) { }

        public void Dispose() {
            tempRT?.Release();
            sourceRT?.Release();
            destinationRT?.Release();
        }

    }
}
