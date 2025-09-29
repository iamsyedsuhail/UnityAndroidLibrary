using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

namespace WaterDragonXu {
    public enum BufferType {
        CameraColor,
        Custom
    }

    public class DistanceBlurRF : ScriptableRendererFeature {
        [System.Serializable]
        public class Settings {
            public RenderPassEvent InjectionPoint = RenderPassEvent.AfterRenderingOpaques;
            public Material BlurMaterial = null;
            public int blurLoop = 1;
            public BufferType sourceType = BufferType.CameraColor;
            public BufferType destinationType = BufferType.CameraColor;
            public string sourceTextureId = "_SourceTexture";
            public string destinationTextureId = "_DestinationTexture";
        }

        public Settings settings = new Settings();
        DistanceBlurPass blitPass;

        public override void Create() {
            blitPass = new DistanceBlurPass(name);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
            if (renderingData.cameraData.cameraType != CameraType.Game || !renderingData.cameraData.postProcessEnabled)
                return;

            if (settings.BlurMaterial == null)
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

    public class DistanceBlurPass : ScriptableRenderPass {
        public FilterMode filterMode { get; set; }
        public DistanceBlurRF.Settings settings;

        RTHandle source;
        RTHandle destination;
        RTHandle sourceRT;
        RTHandle destinationRT;
        RTHandle rtA;
        RTHandle rtB;

        bool isSourceAndDestinationSameTarget;
        string m_ProfilerTag;

        VolumeStack stack;
        DistanceBlurVolume distanceBlurWaterVolume;

        public DistanceBlurPass(string tag) {
            m_ProfilerTag = tag;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;

            isSourceAndDestinationSameTarget =
                (settings.sourceType == settings.destinationType &&
                 (settings.sourceType == BufferType.CameraColor ||
                  settings.sourceTextureId == settings.destinationTextureId)) &&
                settings.blurLoop <= 1;

            var renderer = renderingData.cameraData.renderer;

            if (settings.sourceType == BufferType.CameraColor) {
                source = renderer.cameraColorTargetHandle;
            }
            else {
                RenderingUtils.ReAllocateIfNeeded(
                    ref sourceRT, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: settings.sourceTextureId);
                source = sourceRT;
            }

            if (settings.destinationType == BufferType.CameraColor) {
                destination = renderer.cameraColorTargetHandle;
            }
            else {
                RenderingUtils.ReAllocateIfNeeded(
                    ref destinationRT, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: settings.destinationTextureId);
                destination = destinationRT;
            }

            RenderingUtils.ReAllocateIfNeeded(
                ref rtA, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_TEMP1");
            RenderingUtils.ReAllocateIfNeeded(
                ref rtB, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_TEMP2");
        }

        void SetMaterial(ref Material blurMat) {
            Vector2 offset = new Vector2(1.0f / Camera.main.pixelWidth, 1.0f / Camera.main.pixelHeight);
            blurMat.SetVector("texelSize", offset);
            blurMat.SetFloat("_SurfaceHeight", distanceBlurWaterVolume.SurfaceHeight.value);
            blurMat.SetMatrix("UNITY_MATRIX_I_V1", Camera.main.cameraToWorldMatrix);
            blurMat.SetFloat("_BlurDistance", distanceBlurWaterVolume.BlurDistance.value);
            blurMat.SetVector("texelSize", offset);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
            var cmd = CommandBufferPool.Get(m_ProfilerTag);

            stack = VolumeManager.instance.stack;
            distanceBlurWaterVolume = stack.GetComponent<DistanceBlurVolume>();
            SetMaterial(ref settings.BlurMaterial);

            int loops = Mathf.Max(1, distanceBlurWaterVolume.BlurLoop.value);

            for (int i = 0; i < loops; i++) {
                Blitter.BlitCameraTexture(cmd, source, rtA, settings.BlurMaterial, 0);
                Blitter.BlitCameraTexture(cmd, rtA, rtB);
                cmd.SetGlobalTexture("_GrabbedColorTex", rtB.nameID);
            }

            Blitter.BlitCameraTexture(cmd, rtB, destination);
            cmd.SetGlobalTexture("_GrabbedColorTex", destination.nameID);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public void Dispose() {
            rtA?.Release();
            rtB?.Release();
            sourceRT?.Release();
            destinationRT?.Release();
        }
    }
}
