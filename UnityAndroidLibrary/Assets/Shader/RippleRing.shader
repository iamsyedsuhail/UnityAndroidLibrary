Shader "Izanami/RippleRing_URP"
{
    Properties
    {
        _Tint ("Tint", Color) = (0.75, 0.9, 1, 0.9)
        _Thickness ("Ring Thickness", Range(0.001, 0.5)) = 0.12
        _Softness ("Edge Softness", Range(0.001, 0.5)) = 0.1
        _Refract ("Screen Distortion", Range(0,0.02)) = 0.006
        _NormalAmp ("Fake Normal Strength", Range(0,3)) = 1.2
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            float4 _Tint;
            float  _Thickness;
            float  _Softness;
            float  _Refract;
            float  _NormalAmp;

            struct appdata {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0; // expect a quad with 0..1 UV
                float4 color  : COLOR;
            };
            struct v2f {
                float4 pos          : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float4 color        : COLOR;
                float4 screenPos    : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.color = v.color;
                o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }

            // Soft circular ring mask (center at 0.5,0.5)
            float ringMask(float2 uv, float thickness, float softness, out float2 grad)
            {
                float2 p = uv - 0.5;
                float r = length(p);
                float inner = 0.5 - thickness * 0.5;
                float outer = 0.5 + thickness * 0.5;

                // band between inner..outer, softened
                float a = smoothstep(inner - softness, inner + softness, r);
                float b = 1.0 - smoothstep(outer - softness, outer + softness, r);
                float m = saturate(a * b);

                // gradient ∂mask/∂uv (approx)
                float dr = max(r, 1e-5);
                float band = (smoothstep(inner - softness, inner + softness, r) *
                              (1.0 - smoothstep(outer - softness, outer + softness, r)));
                float dMaskdr = band * (1.0/softness); // cheapish heuristic
                grad = (p / dr) * dMaskdr;
                return m;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 grad;
                float m = ringMask(i.uv, _Thickness, _Softness, grad);

                // fake normal from radial gradient → screen UV offset
                float2 offset = grad * _NormalAmp * _Refract;

                // Sample background (requires Opaque Texture in URP asset)
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float4 bg = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV + offset);

                float3 col = lerp(bg.rgb, _Tint.rgb, 0.35) * (0.5 + 0.5*m);
                float alpha = _Tint.a * m;

                return float4(col, alpha);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
