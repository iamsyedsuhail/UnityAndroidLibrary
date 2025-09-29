Shader "Izanami/URP/WaterWake_Android"
{
    Properties
    {
        _BaseMap("Base (optional)", 2D) = "white" {}
        _Tint("Tint", Color) = (0.55,0.8,1,1)

        _BaseNormal("Base Normal", 2D) = "bump" {}
        _NormalScale("Normal Scale", Range(0,3)) = 1.0
        _NormalTiling("Normal Tiling", Float) = 1.0
        _NormalScroll("Normal Scroll Speed", Float) = 0.5

        _DistortionStrength("UV Distortion", Range(0,0.05)) = 0.015

            // Ripple params
            _RippleStrength("Ripple Strength", Range(0,1)) = 0.35
            _RippleWavelength("Ripple Wavelength (m)", Range(0.05,2)) = 0.6
            _RippleSpeed("Ripple Speed (m/s)", Range(0,20)) = 8
            _RippleDuration("Ripple Lifetime (s)", Range(0.2,4)) = 1.6
    }

        SubShader
        {
            Tags{ "Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            ZWrite Off

            Pass
            {
                HLSLPROGRAM
                #pragma vertex   vert
                #pragma fragment frag
                #pragma target 3.0
                #pragma multi_compile_instancing

                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

                TEXTURE2D(_BaseMap);     SAMPLER(sampler_BaseMap);
                TEXTURE2D(_BaseNormal);  SAMPLER(sampler_BaseNormal);

                float4 _BaseMap_ST;
                float4 _Tint;

                float  _NormalScale;
                float  _NormalTiling;
                float  _NormalScroll;
                float  _DistortionStrength;

                float  _RippleStrength;
                float  _RippleWavelength;
                float  _RippleSpeed;
                float  _RippleDuration;

                // Ripple ring buffer (set via MaterialPropertyBlock)
                // _Ripples[k] = float4(worldX, worldY, worldZ, startTime)
                // _RippleSpeedMul[k] = scalar multiplying _RippleSpeed per ripple (e.g., from movement speed)
                #define MAX_RIPPLES 64
                float4 _Ripples[MAX_RIPPLES];
                float  _RippleSpeedMul[MAX_RIPPLES];
                float  _RippleCount; // float for compatibility; cast to int in loop

                struct Attributes
                {
                    float4 positionOS : POSITION;
                    float2 uv         : TEXCOORD0;
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                };

                struct Varyings
                {
                    float4 positionHCS : SV_POSITION;
                    float2 uv          : TEXCOORD0;
                    float3 positionWS  : TEXCOORD1;
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                };

                Varyings vert(Attributes v)
                {
                    UNITY_SETUP_INSTANCE_ID(v);
                    Varyings o;
                    float3 posWS = TransformObjectToWorld(v.positionOS.xyz);
                    o.positionHCS = TransformWorldToHClip(posWS);
                    o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                    o.positionWS = posWS;
                    return o;
                }

                // Convert accumulated slope (∂h/∂x, ∂h/∂z) into a pseudo normal
                float3 SlopeToNormal(float2 slopeXZ, float scale)
                {
                    float3 n = normalize(float3(-slopeXZ.x * scale, 1.0, -slopeXZ.y * scale));
                    return n;
                }

                float4 frag(Varyings i) : SV_Target
                {
                    float t = _TimeParameters.y;

                // --- Accumulate analytic ring slopes in world XZ ---
                float2 slope = 0;
                int n = (int)_RippleCount;
                float k = (2.0 * PI) / max(_RippleWavelength, 1e-3); // wave number

                [loop]
                for (int j = 0; j < MAX_RIPPLES; j++)
                {
                    if (j >= n) break;

                    float3 Cw = _Ripples[j].xyz;
                    float  t0 = _Ripples[j].w;
                    float  age = t - t0;
                    if (age < 0.0 || age > _RippleDuration) continue;

                    float2 d = i.positionWS.xz - Cw.xz;
                    float  r = length(d);
                    r = max(r, 1e-4);

                    float speedMul = _RippleSpeedMul[j];
                    float radius = _RippleSpeed * speedMul * age;

                    float phase = (r - radius) * k;

                    // temporal + radial damping
                    float envT = exp(-age * 2.0 / max(_RippleDuration, 1e-3));
                    float envR = exp(-r * 0.5);
                    float amp = _RippleStrength * envT * envR;

                    // ∂h/∂r projected to XZ
                    float dhdr = cos(phase) * k * amp;
                    float2 dir = d / r;
                    slope += dir * dhdr;
                }

                // --- Base map + normals (optional) ---
                // Scroll normal map a bit for surface detail
                float2 nUV = i.positionWS.xz / max(_NormalTiling, 1e-4);
                nUV += _NormalScroll * t;
                float3 baseTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BaseNormal, sampler_BaseNormal, nUV), _NormalScale);

                // Convert ripple slope (world XZ) into a TS perturbation (plane assumption)
                float3 rippleTS = normalize(float3(-slope.x, -slope.y, 1.0));

                // Combine TS normals (cheap)
                float2 combXY = normalize(baseTS.xy + rippleTS.xy);
                float3 combTS = normalize(float3(combXY, baseTS.z));

                // Use slope as UV distortion for base color
                float2 uv = i.uv + slope * _DistortionStrength;
                float4 baseCol = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _Tint;

                // Cheap lighting: single directional-ish light from above-left
                float3 nWS = SlopeToNormal(slope, 1.2);
                float3 L = normalize(float3(-0.4, 0.8, 0.4));
                float ndl = saturate(dot(nWS, L));

                float3 col = baseCol.rgb * (0.6 + 0.4 * ndl);
                return float4(col, baseCol.a);
            }
            ENDHLSL
        }
        }
}
