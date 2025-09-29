Shader "Izanami/URP/WaterRipple_Android"
{
    Properties
    {
        _BaseMap("Base (optional)", 2D) = "white" {}
        _Tint("Tint", Color) = (0.55,0.8,1,1)

        _DistortionStrength("UV Distortion", Range(0,0.05)) = 0.015
        _NormalScale("Normal Scale", Range(0,3)) = 1.0

        _RippleAmplitude("Ripple Amplitude", Range(0,1)) = 0.35
        _RippleFrequency("Ripple Frequency", Range(1,100)) = 24
        _RippleSpeed("Ripple Speed", Range(0,20)) = 8
        _RippleDecay("Ripple Decay", Range(0,10)) = 2.5
    }

        SubShader
        {
            Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            ZWrite Off

            Pass
            {
                HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma target 3.0
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

                TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
                float4 _BaseMap_ST;
                float4 _Tint;

                float _DistortionStrength;
                float _NormalScale;

                float _RippleAmplitude;
                float _RippleFrequency;
                float _RippleSpeed;
                float _RippleDecay;

                // ring buffer of ripples: (world xyz, startTime)
                // set from script via SetVectorArray("_Ripples", ...)
                // Mobile-safe: fixed max, dynamic count
                #define MAX_RIPPLES 16
                float4 _Ripples[MAX_RIPPLES];
                float _RippleCount; // set as float from script

                struct Attributes
                {
                    float4 positionOS : POSITION;
                    float2 uv         : TEXCOORD0;
                    float4 color      : COLOR;
                };
                struct Varyings
                {
                    float4 positionHCS : SV_POSITION;
                    float2 uv           : TEXCOORD0;
                    float4 color        : COLOR;
                    float3 posOS        : TEXCOORD1; // object-space for stable math (handles scaling)
                };

                Varyings vert(Attributes v)
                {
                    Varyings o;
                    o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                    o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                    o.color = v.color;
                    o.posOS = v.positionOS.xyz;
                    return o;
                }

                float2 rippleSlopeOS(float2 P, float3 rippleWorldPos, float startTime, float t)
                {
                    // convert center world → object space
                    float3 Cw = rippleWorldPos;
                    float3 Co = TransformWorldToObject(Cw);
                    // assume plane lies in XZ (Unity built-in Plane). If your mesh is different, adjust axes.
                    float2 C = Co.xz;
                    float2 dP = P - C;
                    float d = length(dP);
                    d = max(d, 1e-4);

                    float phase = d * _RippleFrequency - (t - startTime) * _RippleSpeed;
                    float env = exp(-_RippleDecay * d);
                    float a = _RippleAmplitude * env;

                    // radial derivative → slope direction ~ normalized(dP) * cos(phase) * freq * amplitude
                    float2 dir = dP / d;
                    float s = cos(phase) * _RippleFrequency * a;
                    return dir * s; // slope in object XZ
                }

                float3 slopeToNormal(float2 slopeXZ)
                {
                    // build pseudo normal from slope (dz/dx, dz/dy) mapped XZ → normal
                    float3 n = normalize(float3(-slopeXZ.x * _NormalScale, 1.0, -slopeXZ.y * _NormalScale));
                    return n;
                }

                float4 frag(Varyings i) : SV_Target
                {
                    float t = _TimeParameters.y;

                // accumulate slopes from all active ripples
                float2 slope = 0;
                [unroll]
                for (int k = 0; k < MAX_RIPPLES; k++)
                {
                    if (k >= (int)_RippleCount) break;
                    slope += rippleSlopeOS(i.posOS.xz, _Ripples[k].xyz, _Ripples[k].w, t);
                }

                float2 uv = i.uv + slope * _DistortionStrength;

                float4 baseCol = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                float3 n = slopeToNormal(slope);

                // cheap single light for a bit of pop
                float3 L = normalize(float3(-0.4, 0.8, 0.4));
                float ndl = saturate(dot(n, L));
                float3 col = baseCol.rgb * _Tint.rgb * (0.6 + 0.4 * ndl);
                return float4(col, baseCol.a * _Tint.a);
            }
            ENDHLSL
        }
        }
}
