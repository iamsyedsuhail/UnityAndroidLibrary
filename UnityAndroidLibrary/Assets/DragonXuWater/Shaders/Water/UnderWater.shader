Shader "Custom/UnderWater" {
    Properties{
        _Color("Color", Color) = (0,0,1,1)
        _SurfaceHeight("Surface Height", float) = 0
        _Visibility("Visibility", float) = 40
        _CausticTex("Caustic Texture", 2D) = "black"
        //_CausticColor("Caustic Color", color) = (1,1,1,1)
        _CausticScale("Caustic Scale", float) = 1
        _CausticStrength("Caustic Strength", float) = 1
        _CausticMaxDepth("Caustic Max Depth", float) = 1
        _FlowSpeed("Flow Speed", float) = 1
        _FlowDirection("Flow Direction", Vector) = (1.0,1.0,0,0)

        _NoiseTex("Noise Texture", 2D)="black"
        _NoiseScale("Noise Scale", float) = 1
        _NoiseStrength("Noise Strength", float) = 1
    }
        SubShader{

            Tags { "RenderPipeline" = "UniversalPipeline"  "Queue" = "Transparent-499" "DisableBatching" = "True"}
        ZTest Always Cull Off ZWrite Off
        //Blend One Zero
            Pass {                

            Name "UnderWater"
                HLSLPROGRAM
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"        
                 #pragma vertex Vert
                #pragma fragment frag
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS                  
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE    
                #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
                #pragma multi_compile _ _SHADOWS_SOFT                        
                TEXTURE2D(_GrabbedColorTex);
                SAMPLER(sampler_GrabbedColorTex);

                TEXTURE2D(_TEMP);
                SAMPLER(sampler_TEMP);

                TEXTURE2D(_GrabbedDepthTex);
                SAMPLER(sampler_GrabbedDepthTex);
                
                TEXTURE2D(_CausticTex);
                SAMPLER(sampler_CausticTex);
                
                TEXTURE2D(_NoiseTex);
                SAMPLER(sampler_NoiseTex);

                TEXTURE2D(_CameraDepthTexture);
                SAMPLER(sampler_CameraDepthTexture);

                CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float _SurfaceHeight;
                float _Visibility;
                float4 _CausticColor;
                float _CausticScale;
                float _CausticStrength;
                float _FlowSpeed;
                float2 _FlowDirection;
                float _NoiseScale;
                float _NoiseStrength;
                float _CausticMaxDepth;
                int isUnderWater;
                float _BlurDistance;
                float4x4 UNITY_MATRIX_I_V1;
                float2 texelSize;

                int onlyBlur;
                float DistancePow;
                CBUFFER_END

                struct Attributes {
                    float4 positionOS : POSITION;
                    float2 uv : TEXCOORD0;
                    
                };

                float4 GetWorldPos(float2 ScreenUV, float Depth)
                {

                    float3 ScreenPos = float3(ScreenUV, Depth);                               
                    float4 normalScreenPos = float4(ScreenPos * 2.0 - 1, 1.0);                
                    normalScreenPos.z = Depth;
                    float4 ndcPos = mul(unity_CameraInvProjection, normalScreenPos);          
                    ndcPos = float4(ndcPos.xyz / ndcPos.w, 1.0);

                    float4 scenePos = mul(unity_CameraToWorld, ndcPos * float4(1, 1, -1, 1)); 
                    scenePos = float4(scenePos.xyz/ scenePos.w, 1.0);
                    return scenePos;
                }
                
                struct Varyings {
                    float2 uv : TEXCOORD0;
                    float4 vertex : SV_POSITION;
                    float3 positionWS : TEXCOORD1;
                    float3 viewRay:TEXCOORD2;
                    UNITY_VERTEX_OUTPUT_STEREO
                };

                Varyings Vert(Attributes input) {
                    Varyings output = (Varyings)0;                    
                    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                    output.vertex = vertexInput.positionCS;
                    output.positionWS = vertexInput.positionWS;
                    output.uv = input.uv;

                    float zFar = _ProjectionParams.z;

                    

                    float4 viewRay4 = float4(float3((output.uv.x * 2.0 - 1.0), ((1 - output.uv.y) * 2.0 - 1.0), 1.0) * zFar, zFar);

                    viewRay4 = mul(UNITY_MATRIX_I_P, viewRay4);

                    output.viewRay = viewRay4.xyz;
                
                    return output;
                }     

                float GetShadow(float3 posWorld)
                {
                    float4 shadowCoord = TransformWorldToShadowCoord(posWorld);
                    float shadow = MainLightRealtimeShadow(shadowCoord);

                    return shadow;
                }

                half4 frag(Varyings i) : SV_Target{
                    
                    float4 col = SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv);

                    float depth = SAMPLE_DEPTH_TEXTURE(_GrabbedDepthTex, sampler_GrabbedDepthTex, i.uv).r;

                    float linearDepth = LinearEyeDepth(depth, _ZBufferParams);

                    float depth01 = Linear01Depth(depth, _ZBufferParams);
                    float4 viewPos = float4(depth01 * i.viewRay, 1);

                    float4 worldPos = mul(UNITY_MATRIX_I_V1, viewPos);
                    worldPos /= worldPos.w;

                    float2 screenUV = GetNormalizedScreenSpaceUV(TransformWorldToHClip(worldPos));                    
                    
                    //if (_BlurDistance <= linearDepth && abs(worldPos.y - _SurfaceHeight) <= 0.001)
                    //{                        
                    //    float4 blurColor = 0.0;

                    
                    //    float2 offset = texelSize * linearDepth / _BlurDistance; 
                    //    blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(-offset.x, -offset.y));
                    //    blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(0.0, -offset.y));
                    //    blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(offset.x, -offset.y));
                    //    blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(-offset.x, 0.0));
                    //    blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv);
                    //    blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(offset.x, 0.0));
                    //    blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(-offset.x, offset.y));
                    //    blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(0.0, offset.y));
                    //    blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(offset.x, offset.y));

                    
                    //    blurColor /= 9.0;

                    
                    //    col = blurColor;
                    //}

                    //if (onlyBlur != 0)
                    //{
                    //    if (_BlurDistance <= linearDepth && abs(worldPos.y - _SurfaceHeight) <= 0.001)
                    //    {
                    //        float4 blurColor = 0.0;

                    
                    //        float2 offset = texelSize * linearDepth / _BlurDistance;  
                    //        blurColor += SAMPLE_TEXTURE2D(_TEMP, sampler_TEMP, i.uv + float2(-offset.x, -offset.y));
                    //        blurColor += SAMPLE_TEXTURE2D(_TEMP, sampler_TEMP, i.uv + float2(0.0, -offset.y));
                    //        blurColor += SAMPLE_TEXTURE2D(_TEMP, sampler_TEMP, i.uv + float2(offset.x, -offset.y));
                    //        blurColor += SAMPLE_TEXTURE2D(_TEMP, sampler_TEMP, i.uv + float2(-offset.x, 0.0));
                    //        blurColor += SAMPLE_TEXTURE2D(_TEMP, sampler_TEMP, i.uv);
                    //        blurColor += SAMPLE_TEXTURE2D(_TEMP, sampler_TEMP, i.uv + float2(offset.x, 0.0));
                    //        blurColor += SAMPLE_TEXTURE2D(_TEMP, sampler_TEMP, i.uv + float2(-offset.x, offset.y));
                    //        blurColor += SAMPLE_TEXTURE2D(_TEMP, sampler_TEMP, i.uv + float2(0.0, offset.y));
                    //        blurColor += SAMPLE_TEXTURE2D(_TEMP, sampler_TEMP, i.uv + float2(offset.x, offset.y));

                    
                    //        blurColor /= 9.0;

                    
                    //        col = blurColor;
                    //    }
                    //    //return float4(1, 0, 0, 1);
                    //    return col;
                    //}

                    if (isUnderWater && worldPos.y < _SurfaceHeight + 0.001&& Linear01Depth(depth, _ZBufferParams) != 1)
                    {
                        float2 causticUV = float2(((worldPos.x + worldPos.y) % _CausticScale) / _CausticScale, ((worldPos.z + worldPos.y )% _CausticScale) / _CausticScale);

                        float time = _Time.y * _FlowSpeed;
                        float2 flowOffset = time * _FlowDirection;

                        float2 noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, ((worldPos.xz+ worldPos.y) % _NoiseScale) / _NoiseScale).rg * _NoiseStrength;
                        causticUV += flowOffset + noise;
                        
                        depth = pow(linearDepth / _Visibility, DistancePow);

                        float3 caustic = 0;
                        if(worldPos.y < _SurfaceHeight - 0.001)
                            caustic = SAMPLE_TEXTURE2D(_CausticTex, sampler_CausticTex, causticUV).rgb * (1 - depth);                        

                        float4 res = float4(lerp(col.rgb, _Color.rgb, saturate(depth)),1);
                        res += float4(saturate(_CausticColor * caustic * _CausticStrength * saturate(1 - (_SurfaceHeight - worldPos.y) / _CausticMaxDepth)),0) * GetShadow(worldPos);
                        return res;
                    }
                    else
                    {
                        return col;
                        
                    }
                }
                ENDHLSL
            }


    }
}