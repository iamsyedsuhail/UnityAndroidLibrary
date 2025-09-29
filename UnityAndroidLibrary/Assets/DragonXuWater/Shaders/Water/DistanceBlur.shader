Shader "Custom/DistanceBlur" {
    Properties{
        _Color("Color", Color) = (0,0,1,1)
        _SurfaceHeight("Surface Height", float) = 0        
        
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
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS                    //接受阴影
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE            //产生阴影
                #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
                #pragma multi_compile _ _SHADOWS_SOFT                         //软阴影
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
                float _SurfaceHeight;
                float _BlurDistance;
                float4x4 UNITY_MATRIX_I_V1;
                float2 texelSize;

                int onlyBlur;
                CBUFFER_END

                struct Attributes {
                    float4 positionOS : POSITION;
                    float2 uv : TEXCOORD0;
                    
                };

                float4 GetWorldPos(float2 ScreenUV, float Depth)
                {

                    float3 ScreenPos = float3(ScreenUV, Depth);                                  // 获取屏幕空间位置
                    float4 normalScreenPos = float4(ScreenPos * 2.0 - 1, 1.0);                 // 映射到屏幕中心点
                    normalScreenPos.z = Depth;
                    float4 ndcPos = mul(unity_CameraInvProjection, normalScreenPos);             // 计算到ndc空间下的位置
                    ndcPos = float4(ndcPos.xyz / ndcPos.w, 1.0);

                    float4 scenePos = mul(unity_CameraToWorld, ndcPos * float4(1, 1, -1, 1));      // 反推世界空间位置
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

                half4 frag(Varyings i) : SV_Target{

                    //return float4(1,0,0,1);

                    float4 col = SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv);
                    //return col;
                    float depth = SAMPLE_DEPTH_TEXTURE(_GrabbedDepthTex, sampler_GrabbedDepthTex, i.uv).r;

                    float linearDepth = LinearEyeDepth(depth, _ZBufferParams);

                    float depth01 = Linear01Depth(depth, _ZBufferParams);
                    //return float4(pow(1-depth01,10), 0, 0, 1);
                    float4 viewPos = float4(depth01 * i.viewRay, 1);

                    float4 worldPos = mul(UNITY_MATRIX_I_V1, viewPos);
                    worldPos /= worldPos.w;

                    float2 screenUV = GetNormalizedScreenSpaceUV(TransformWorldToHClip(worldPos));                    
                                        
                        if (/*_BlurDistance <= linearDepth && */abs(worldPos.y - _SurfaceHeight) <= 0.01)
                        {
                            float4 blurColor = 0.0;

                            // 简单的3x3内核模糊
                            float2 offset = texelSize * linearDepth / _BlurDistance; // 根据需求调整偏移大小
                            blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(-offset.x, -offset.y));
                            blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(0.0, -offset.y));
                            blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(offset.x, -offset.y));
                            blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(-offset.x, 0.0));
                            blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv);
                            blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(offset.x, 0.0));
                            blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(-offset.x, offset.y));
                            blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(0.0, offset.y));
                            blurColor += SAMPLE_TEXTURE2D(_GrabbedColorTex, sampler_GrabbedColorTex, i.uv + float2(offset.x, offset.y));

                            // 取平均值，完成模糊
                            blurColor /= 9.0;

                            // 将模糊后的颜色应用到结果中
                            col = blurColor;
                        }
                        
                    return col;
                }
                ENDHLSL
            }


    }
}