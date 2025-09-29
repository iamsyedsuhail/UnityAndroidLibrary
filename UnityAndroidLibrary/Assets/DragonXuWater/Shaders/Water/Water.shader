Shader "Custom/Water_Gerstner_SSR"
{
    Properties
    {        
        [Toggle(_UnderWaterSurface)]_UnderWaterSurface("Under Water Surface",Float) = 0.0

        [MainColor] _ShallowColor("Shallow Color", Color) = (1,1,1,1)
        _DeepColor("Deep Color", Color) = (1,1,1,1)

        _SurfaceRoughness("Surface Roughness",  Range(0.0, 0.1)) = 0.02
        _DepthFactor("Depth Factor", float) = 1

        _WaterNormal("Water Normal Tex", 2D) = "bump"{}      //法线贴图
        _Normal("Normal Intensity", Range(0,1)) = 1.0
        _NormalTiling("Normal Tiling", float) = 1.0
        // Gerstner wave
        _MaxWaveLength("Max Wave Length", float) = 0.2
       
        _WaveCount("WaveCount", float) = 10
        _WaveAmplitude("Wave Amplitude", float) = 1.0
        _WindDir("Wind Direction", Vector) = (1.0,1.0,0,0)
        _DirectionRandomization("Direction Randomization", Range(0.0, 1.0)) =0.5
        _FloatSpeed("Floating Speed", float) = 0.2

        _ReflectionStrength("Reflection Strength", Range(0,1)) = 1
        
        _RippleNormalMap("Ripple Height Map", 2D) = "black"
        _RippleStrength("RippleStrength", float) = 10

        /*_BubbleTex("BubbleTex", 2D) = "white"
        _FoamScale("Foam Scale", float) = 0.2*/

        _SkyBoxCubeMap("SkyBox", Cube) = ""{}

        _EnvRotation("EnvRotation",Range(0.0,360.0)) = 0.0


        _NoiseTex("Noise Texture", 2D) = "black"{}
        _NoiseScale("Noise Scale", float) = 1
        _NoiseStrength("Noise Strength", float) = 1


        
        [Toggle(_DIFFUSE_OFF)] _DIFFUSE_OFF("DIFFUSE OFF",Float) = 0.0
        [Toggle(_SPECULAR_OFF)] _SPECULAR_OFF("SPECULAR OFF",Float) = 0.0
        [Toggle(_SH_OFF)] _SH_OFF("SH OFF",Float) = 0.0
        [Toggle(_IBL_OFF)] _IBL_OFF("IBL OFF",Float) = 0.0
        [Toggle(_SSR_OFF)] _SSR_OFF("SSR OFF",Float) = 0.0
        [Toggle(_VERTEX_ANIM_OFF)] _VERTEX_ANIM_OFF("VERTEX ANIMATION OFF",Float) = 0.0


        _Ior("Index of Refraction",  Range(1,4)) = 1.5
    }

    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel" = "4.5"}
        LOD 300
        // ------------------------------------------------------------------
        //  Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Tags{"LightMode" = "UniversalForward"}

            //Blend [_SrcBlend][_DstBlend]
            ZWrite on
            Blend srcAlpha oneMinusSrcAlpha

            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

        // -------------------------------------
        // Material Keywords
        #pragma shader_feature_local_fragment _ALPHATEST_ON
        #pragma shader_feature_local_fragment _DIFFUSE_OFF
        #pragma shader_feature_local_fragment _SPECULAR_OFF
        #pragma shader_feature_local_fragment _SH_OFF
        #pragma shader_feature_local_fragment _IBL_OFF            
        #pragma shader_feature_local_vertex _VERTEX_ANIM_OFF
        #pragma shader_feature_local_fragment _SCREEN_SPACE_REFLECTION_ON
        #pragma shader_feature_local_fragment _ _UnderWaterSurface
        // -------------------------------------
        // Universal Pipeline keywords
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
        #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
        #pragma multi_compile_fragment _ _SHADOWS_SOFT
        #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION


        //--------------------------------------
        // GPU Instancing
        #pragma multi_compile_instancing
        #pragma instancing_options renderinglayer
        #pragma multi_compile _ DOTS_INSTANCING_ON

        #pragma vertex vert
        #pragma fragment frag

        //不支持合批是因为后面的Pass用的cbuffer中的内容不一致，此处仅为了演示PBR效果故不更改

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "waterLitInclude.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Hashes.hlsl"
        // NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
        CBUFFER_START(UnityPerMaterial)            
                
                float4 _BaseMap_ST;
                half4 _ShallowColor;
                half4 _DeepColor;
                float _DepthFactor;
                //float4 _BubblesColor;
                //float _BubbleDepth;
                
                half _Cutoff;
                half _EnvRotation;
                float _Ior;
                float4 _EmissionColor;

                // matrices for SSR calculation
                float4x4 _InverseProjectionMatrix;
                float4x4 _InverseViewMatrix;
                float4x4 _VM;
                float4x4 _PV;
                float4x4 _Camera_INV_VP;

                float _MaxWaveLength;
               
                float _WaveCount;
                float _WaveAmplitude;
                float2 _WindDir;
                float _DirectionRandomization;
                float _FloatSpeed;

                float _Normal;
                float _NormalTiling;

                float _ReflectionStrength;

                uniform float4 _RippleCenter[1000];   
                uniform float _RippleTimes[1000];     
                uniform float _RippleSpeedMul[1000];
                float _RippleSpeed;   
                float _RippleDuration;
                float _RippleScale;   
                int _MaxRippleCount;

                float _RippleStrength;

                float _SurfaceRoughness;

                float _NoiseScale;
                float _NoiseStrength;
                /*float _FoamScale;*/
            CBUFFER_END
           
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURECUBE(_SkyBoxCubeMap);
            SAMPLER(sampler_SkyBoxCubeMap);

            TEXTURE2D(_WaterNormal);
            SAMPLER(sampler_WaterNormal);

            TEXTURE2D(_RippleNormalMap);
            SAMPLER(sampler_RippleNormalMap);

            TEXTURE2D(_BubbleTex);
            SAMPLER(sampler_BubbleTex);

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            #include "SSR_include.hlsl"
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionOS   : TEXCOORD1;
                float3 positionWS   : TEXCOORD2;
                float3 normalWS     : TEXCOORD3;
                half4  tangentWS    : TEXCOORD4;
                float4 shadowCoord  : TEXCOORD5;
                float4 positionCS   : SV_POSITION;                
                float3 positionVS   : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            float Random(int seed)
            {
                return frac(sin(dot(float2(seed, 2), float2(12.9898, 78.233)))) * 2 - 1;
            }

            Varyings vert(Attributes i)
            {
                Varyings o;

                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_TRANSFER_INSTANCE_ID(i, o);

                o.uv = TRANSFORM_TEX(i.texcoord, _BaseMap);
                o.uv = i.texcoord;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(i.positionOS);
                VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS, i.tangentOS);

                o.normalWS = normalInput.normalWS;

                real sign = i.tangentOS.w * GetOddNegativeScale();
                half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);

                o.tangentWS = tangentWS;

                o.shadowCoord = GetShadowCoord(vertexInput);

                o.positionOS = i.positionOS;
                o.positionCS = vertexInput.positionCS;
                o.positionWS = vertexInput.positionWS;
                o.positionVS = vertexInput.positionVS;

                float3 positionWS = vertexInput.positionWS;

#ifndef _VERTEX_ANIM_OFF
                float3 T = 0;
                float3 B = 0;
                float3 N = 0;
                UNITY_LOOP
                    for (int j = 0; j < _WaveCount; j++)
                    {
                        float2 randomedDir = lerp(_WindDir, float2(Random(j), Random(2 * j)), _DirectionRandomization);
                        float val = 2 * PI / lerp(_MaxWaveLength / _WaveCount, _MaxWaveLength, j / _WaveCount) * dot(randomedDir, positionWS.xz) - _Time.y * lerp(_FloatSpeed / _WaveCount, _FloatSpeed, j / _WaveCount);

                        float amplitude = lerp(_WaveAmplitude / _WaveCount, _WaveAmplitude, j / _WaveCount) / _WaveCount;
                        positionWS += float3 (amplitude * cos(val) * randomedDir.x,
                            amplitude * sin(val),
                            amplitude * cos(val) * randomedDir.y);

                    }
                o.positionCS = TransformWorldToHClip(positionWS);
#else
               
#endif
                return o;
            }

            

            void LightDataInitialization(Varyings i, out lightDatas o)
            {
                o = (lightDatas)0;
                o.positionWS = i.positionWS;
                o.V = GetWorldSpaceNormalizeViewDir(o.positionWS);
                o.N = normalize(i.normalWS);
                o.T = i.tangentWS.xyz;
                o.B = normalize(cross(o.N, o.T) * i.tangentWS.w);
                o.screenUV = GetNormalizedScreenSpaceUV(i.positionCS);
            }

            float4 CombineNormals(float4 normal1, float4 normal2)
            {

                normal1 = normalize(normal1 * 2.0 - 1.0); 
                normal2 = normalize(normal2 * 2.0 - 1.0);
                float4 combinedNormal;
                combinedNormal.xy = normal1.xy + normal2.xy;
                combinedNormal.z = sqrt(max(0.0, 1.0 - dot(combinedNormal.xy, combinedNormal.xy))); 

                return normalize((normal1 + normal2) * 0.5 + 0.5);
            }


            float SampleHeight(float2 uv) {
                return SAMPLE_TEXTURE2D(_RippleNormalMap, sampler_RippleNormalMap, uv).r;
            }
        
            float3 Simple_NormalFromHeight_TangentSpace(float In, float Strength)
            {                
                float dHdx = ddx(In);
                float dHdy = ddy(In);

                float3 surfGrad;
                surfGrad.x = -dHdx * Strength;
                surfGrad.y = -dHdy * Strength;
                surfGrad.z = 1.0;
                
                return normalize(surfGrad);
            }            

            void SurfaceDataInitialization(Varyings i, out surfaceDatas o)
            {
                o = (surfaceDatas)0;
                half4 color = half4(1, 1, 1, 1);
                
                o.albedo = color.rgb;
                o.alpha = color.a;
#if defined(_ALPHATEST_ON)
                clip(o.alpha - _Cutoff);
#endif
                o.specular = (half3)1;                
                o.metallic = 1;                                                                
                o.roughness = _SurfaceRoughness;


                 //Interaction========================================================================                
                float4 rippleNormal = 0;
                float hasRipple = 0;
                UNITY_LOOP
                    for (int j = 0; j < _MaxRippleCount; j++)
                    {
                        float2 rippleCenter = _RippleCenter[j].xz;
                        float rippleTime = _RippleTimes[j];
                        float rSpeed = _RippleSpeed * _RippleSpeedMul[j];
                        
                        if ((rippleTime > _RippleDuration) || (rippleTime < -0.1))
                            continue;
                        
                        float rippleRadius = rSpeed * rippleTime;

                        float2 uvOffset = i.positionWS.xz - rippleCenter;
                        float distance = length(uvOffset);

                        if (distance < rippleRadius)
                        {                            

                            float2 rippleUV = (uvOffset / rippleRadius) * 0.5 + 0.5;

                            float h = SampleHeight(rippleUV);

                            rippleNormal = float4(Simple_NormalFromHeight_TangentSpace(SampleHeight(rippleUV), _RippleStrength), 1);                            
                            if (rippleNormal.r != -1)
                                hasRipple = 1;
                            else
                                rippleNormal = 0;
                            
                            float influence = smoothstep(rippleRadius, rippleRadius * 0.9, distance);
                             
                            rippleNormal= CombineNormals(rippleNormal, rippleNormal);

                        }

                    }
                rippleNormal= normalize(rippleNormal);
                //Interaction========================================================================                

                float2 noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, ((i.positionWS.xz + i.positionWS.y) % _NormalTiling) / _NormalTiling).rg * _NoiseStrength;

                float4 normalTS = SAMPLE_TEXTURE2D(_WaterNormal, sampler_WaterNormal, ((i.positionWS.xz+noise + _WindDir.xy*_Time.y * _FloatSpeed) % _NormalTiling) / _NormalTiling);
                if (hasRipple==0)
                {
                    
                    o.normalTS = UnpackNormalScale(normalTS, _Normal);
                }                
                else
                    o.normalTS = UnpackNormalScale(float4(normalize(rippleNormal.xy+normalTS.xy), normalTS.b, normalTS.a), _Normal);

            }

            

            float4 frag(Varyings i):SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);                 

                lightDatas _lightDatas;
                surfaceDatas _surfaceDatas;
                LightDataInitialization(i, _lightDatas);
                SurfaceDataInitialization(i, _surfaceDatas);
            
                float3 positionWS = i.positionWS;

                float3 T = 0;
                float3 B = 0;
                float3 N = 0;

               
                float height = 0;
                UNITY_LOOP
                for (int j = 0; j < _WaveCount; j++)
                {
                    float2 randomedDir = lerp(_WindDir, float2(Random(j+1), Random(2*j+1)), _DirectionRandomization);
                    float k = 2 * PI / lerp(_MaxWaveLength / _WaveCount, _MaxWaveLength, j / _WaveCount);
                    //float k = 2 * PI / lerp(_MaxWaveLength , _MaxWaveLength / _WaveCount, j / _WaveCount);
                    float val =  k * dot(randomedDir, positionWS.xz) -_Time.y * _FloatSpeed/*lerp(_FloatSpeed/ _WaveCount, _FloatSpeed,j/_WaveCount)*/;

                    float amplitude = lerp(_WaveAmplitude / _WaveCount, _WaveAmplitude, j / _WaveCount)/ _WaveCount;

                    float sinVal = sin(val);
                    float cosVal = cos(val);

                    //float amplitude = _WaveAmplitude / _WaveCount;
                    positionWS+= float3 (amplitude * cosVal * randomedDir.x,
                        amplitude * sinVal,
                        amplitude * cosVal * randomedDir.y);
                    //positionWS.z += i.positionWS.z + _WaveAmplitude * cos(val);
                    //positionWS.y += i.positionWS.y + _WaveAmplitude * sin(val);

                    B.x += -randomedDir.y * amplitude * k * sinVal * randomedDir.x;
                    B.z +=  - randomedDir.y * amplitude * k * sinVal * randomedDir.y;
                    B.y += randomedDir.y * amplitude * k * cosVal;

                    T.x +=  - randomedDir.x * amplitude * k * sinVal * randomedDir.x;
                    T.z += -randomedDir.x * amplitude * k * sinVal * randomedDir.y;
                    T.y += randomedDir.x * amplitude * k * cosVal;

                    height += sinVal;
                }
                B = float3(B.x, B.y, B.z + 1);
                T = float3(T.x + 1, T.y, T.z);
                N= normalize(cross(B, T));



                half3x3 TBN = half3x3(T, B, N);
                float3 normal = normalize(mul(_surfaceDatas.normalTS, TBN));                

                _surfaceDatas.normalWS = normal;
                _lightDatas.N = normal;
                _lightDatas.T = T;
                _lightDatas.B = B;

                

                float4 ssr = 0;

                SSRdata ssrData;
                ssrData.positionWS = positionWS;
                ssrData.positionOS = i.positionOS;
                ssrData.normalWS = _surfaceDatas.normalWS;

                ssr = float4(SSR(ssrData),0);
                
                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, ViewPosToCS(ssrData.posVS).xy).r;
                                                                
                depth = (ssrData.posVS.z + LinearEyeDepth(depth, _ZBufferParams)) /_DepthFactor;

                float4 depthCol = lerp(_ShallowColor, _DeepColor, saturate(depth))/*+ float4(_surfaceDatas.specular,0)-1*/;


                _surfaceDatas.albedo = depthCol.rgb;
                float4 litRes = StandardLit(_lightDatas, _surfaceDatas, positionWS, i.shadowCoord, _EnvRotation, _Ior) + float4(_EmissionColor.xyz, pow(_surfaceDatas.alpha, 2) * _ShallowColor.a);              

                float4 res = 0;
#if defined(_UnderWaterSurface)
                if (dot(ssrData.res, ssrData.res) > 0.01)
                    res = float4(lerp(litRes.rgb + ssr.rgb * depthCol, ssrData.res, _ReflectionStrength), _DepthFactor);
                else
                    res = float4((litRes.rgb + ssr.rgb * depthCol), _DepthFactor);

#else                               
                if(dot(ssrData.res, ssrData.res)>0.01)
                    res = float4(lerp(litRes.rgb + ssr.rgb * depthCol, ssrData.res, _ReflectionStrength), saturate(0.4+depth));
                else
                    res = float4((litRes.rgb + ssr.rgb * depthCol), saturate(0.4 + depth));
#endif
                return res;                
            }                        

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly" "RenderType" = "Opaque"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #ifndef SG_DEPTH_ONLY_PASS_INCLUDED
#define SG_DEPTH_ONLY_PASS_INCLUDED

PackedVaryings vert(Attributes input)
{
    Varyings output = (Varyings)0;
    output = BuildVaryings(input);
    PackedVaryings packedOutput = (PackedVaryings)0;
    packedOutput = PackVaryings(output);
    return packedOutput;
}

half4 frag(PackedVaryings packedInput) : SV_TARGET
{
    Varyings unpacked = UnpackVaryings(packedInput);
    UNITY_SETUP_INSTANCE_ID(unpacked);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(unpacked);

    SurfaceDescriptionInputs surfaceDescriptionInputs = BuildSurfaceDescriptionInputs(unpacked);
    SurfaceDescription surfaceDescription = SurfaceDescriptionFunction(surfaceDescriptionInputs);

    #if _AlphaClip
        clip(surfaceDescription.Alpha - surfaceDescription.AlphaClipThreshold);
    #endif

    float4 outColor = 0;
    #ifdef SCENESELECTIONPASS
    // We use depth prepass for scene selection in the editor, this code allow to output the outline correctly
    outColor = float4(_ObjectId, _PassValue, 1.0, 1.0);
    #elif defined(SCENEPICKINGPASS)
        outColor = _SelectionID;
    #endif

    return outColor;
}

#endif

            ENDHLSL
        }

            // This pass is used when drawing to a _CameraNormalsTexture texture
            Pass
            {
                Name "DepthNormals"
                Tags{"LightMode" = "DepthNormals" "RenderType" = "Opaque"}

                ZWrite On
                Cull[_Cull]

                HLSLPROGRAM
                #pragma exclude_renderers gles gles3 glcore
                #pragma target 4.5

                #pragma vertex DepthNormalsVertex
                #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }
        }
}