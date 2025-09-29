Shader "Custom/CustomSkyBox"
{
    Properties
    {
        _SunRadius("Sun Radius", float) = 0.03
        _SunColor("Sun Color", Color) = (1,1,1,1)
        _MoonRadius("Moon Radius", float) = 0.04
        _MoonOffset("Moon Offset", float) = 0.04
        _MoonColor("Moon Color", Color) = (1,1,1,1)

        [Space]
        _DayTopCol("Day Top Color", Color) = (1,1,1,1)
        _DayMidCol("Day Mid Color", Color) = (1,1,1,1)
        _DayBottomCol("Day Bottom Color", Color) = (1,1,1,1)
        [Space]
        _NightTopCol("Night Top Color", Color) = (0,0,0,0)
        _NightMidCol("Night Mid Color", Color) = (0,0,0,0)
        _NightBottomCol("Night Bottom Color", Color) = (0,0,0,0)

        [Space]
        _StarTex("Star Texture", 2D) = "white"{}
        _ClusterTex("Star Cluster", 2D) = "white"{}

        [Space]
        _EarthCenter("Earth Center", Vector) = (0,-100,0,0)
        _EarthRadius("Earth Radius", float) = 100
        _AtmosphereRadius("Atmosphere Radius", float) = 100
        _DecayRayleigh("Rayleigh Decay", float) = 100
        _DecayMie("Mie Decay", float) = 100
        RayleighColor("RayleighColor", Color) = (1,1,1,1)
        MieColor("Mie Color", Color) = (1,1,1,1)
        MieWeight("Mie Weight", float) = 1.2
    }

        SubShader
        {

            Tags {"RenderPipeline" = "UniversalRenderPipeline" "Queue" = "Background"  "RenderType" = "Opaque" }
            Cull Off ZWrite Off ZTest Less

            Pass
            {
                HLSLPROGRAM
                //     #pragma exclude_renderers gles gles3 glcore
                //#pragma target 4.5



                    #pragma vertex vert
                    #pragma fragment frag
                    // make fog work
                    #pragma multi_compile_fog

                    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
                    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

                //    #define PI  3.1415926536
                    #define OUT_SCATTER_COUNT 6
                    #define IN_SCATTER_COUNT  100

                    float _SunRadius;
            float _MoonRadius;
            float _MoonOffset;

                    float4 _DayTopCol;
                    float4 _DayMidCol;
                    float4 _DayBottomCol;
                    float4 _SunColor;
                    float4 _MoonColor;

                    float4 _NightTopCol;
                    float4 _NightMidCol;
                    float4 _NightBottomCol;

                half4 _EarthCenter;
                half _EarthRadius;
                half _AtmosphereRadius;
                half _DecayRayleigh;
                half _DecayMie;
                half4 RayleighColor;
                half4 MieColor;
                half MieWeight;


                TEXTURE2D(_StarTex);
                SAMPLER(sampler_StarTex);

                TEXTURE2D(_ClusterTex);
                SAMPLER(sampler_ClusterTex);

                struct appdata
                {
                    float4 vertex : POSITION;
                    float3 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float3 uv : TEXCOORD0;
                    float3 camPosWS: TEXCOORD1;
                    float3 viewDirWS: TEXCOORD2;
                    float4 vertex : SV_POSITION;
                };

                v2f vert(appdata v)
                {
                    v2f o;
                    o.vertex = TransformObjectToHClip(v.vertex.xyz);
                    o.uv = v.uv;
                    //o.uv = normalize(TransformObjectToWorld(v.vertex.xyz));
                    o.camPosWS = GetCameraPositionWS();
                    o.viewDirWS = normalize(TransformObjectToWorld(v.vertex.xyz) - o.camPosWS);
                    return o;
                }

                half Mie_HenyeyGreenstein(half g, half cosTheta)
                {
                    float g2 = g * g;
                    return pow(abs((1 - g2) / (4 * PI * (1 + g2 - 2 * g * cosTheta))), 1.5);
                }

                half RayLeigh(float cosTheta)
                {
                    return (0.1875 / PI) * (1.0 + cosTheta * cosTheta);
                }

                half Density(half h, half H)
                {
                    return exp(-max(0, h) / H);
                }

                float2 RaySphereIntersection(float3 rayOrigin, float3 rayDir, float3 sphereCenter, float sphereRadius) {

                    rayOrigin -= sphereCenter;

                    float a = dot(rayDir, rayDir);
                    float b = 2.0 * dot(rayOrigin, rayDir);
                    float c = dot(rayOrigin, rayOrigin) - (sphereRadius * sphereRadius);

                    float d = b * b - 4 * a * c;

                    if (d < 0) {
                        return -1;
                    }
                    else {
                        d = sqrt(d);
                        return float2(-b - d, -b + d) / (2 * a);
                    }
                }

                float OutScatterMarch(float3 Origin, float3 target, float decay) {

                    float sum = 0.0;

                    float3 marchLen = (target - Origin) / float(OUT_SCATTER_COUNT);
                    float3 marchPos = Origin;

                    for (int i = 0; i < OUT_SCATTER_COUNT; i++) {
                        sum += Density(length(marchPos - _EarthCenter.xyz) - _EarthRadius, decay);
                        marchPos += marchLen;
                    }

                    sum *= length(marchLen);
                    return sum;
                }

                half3 InScatterRayMarch(half3 camPosWS, half3 viewDir, half3 lightDir)
                {
                    half3 rayleigh = 0;
                    half3 mie = 0;

                    half2 intersection = RaySphereIntersection(camPosWS, viewDir, _EarthCenter.xyz, _AtmosphereRadius);
                    half marchLen = abs(max(0, intersection.y) - max(0, intersection.x)) / half(IN_SCATTER_COUNT);

                    half3 marchPos = camPosWS + viewDir * intersection.x;

                    half accRayleighDen = 0;
                    half accMieDen = 0;
                    UNITY_LOOP
                    for (int i = 0; i < IN_SCATTER_COUNT; i++)
                    {
                        half densityRayleigh = Density(length(marchPos - _EarthCenter.xyz) - _EarthRadius, _DecayRayleigh) * marchLen;
                        half densityMie = Density(length(marchPos - _EarthCenter.xyz) - _EarthRadius, _DecayMie) * marchLen;

                        half2 intersectionLight = RaySphereIntersection(marchPos, lightDir, _EarthCenter.xyz, _AtmosphereRadius);

                        accRayleighDen += densityRayleigh;
                        accMieDen += densityMie;

                        half outScatterRayleigh = OutScatterMarch(marchPos, marchPos + lightDir * intersectionLight.y, _DecayRayleigh);
                        half outScatterMie = OutScatterMarch(marchPos, marchPos + lightDir * intersectionLight.y, _DecayMie);

                        half3 attribute = exp(-(accMieDen + outScatterMie) * length(MieColor) * MieWeight /*- (accRayleighDen + outScatterRayleigh) * RayleighColor*/);
                        half3 attributeRayleigh = exp(-(accRayleighDen + outScatterRayleigh) * length(RayleighColor));
                        rayleigh += accRayleighDen * (attributeRayleigh);
                        mie += accMieDen * attribute;

                        marchPos += marchLen * viewDir;
                    }
                    //return rayleigh * 100;
                    //rayleigh = 0;
                    half cos = dot(-lightDir, viewDir);
                    return (Mie_HenyeyGreenstein(0.88, cos) * mie * MieColor.rgb + rayleigh * RayLeigh(cos) * RayleighColor.rgb * 200) * 0.2;
                }

                half4 frag(v2f i) : SV_Target
                {
                    if (i.uv.y < -0.2)
                        return 0;

                    Light light = GetMainLight();

                    //sun
                    float sun = distance(i.uv.xyz, light.direction);
                    float3 sunCol = 1 - (sun / _SunRadius);
                    sunCol = saturate(sunCol) * _SunColor.rgb;

                    // moon
                    float moon = distance(i.uv.xyz, -light.direction); //日月方向相反
                    float moonCol = 1 - (moon / _MoonRadius);
                    moonCol = saturate(moonCol * 20);

                    float crescentMoon = distance(float3(i.uv.x + _MoonOffset, i.uv.yz), -light.direction);
                    float crescentMoonDisc = 1 - (crescentMoon / _MoonRadius);
                    crescentMoonDisc = saturate(crescentMoonDisc * 20);

                    moonCol = length(saturate(moonCol - crescentMoonDisc) * _MoonColor);


                    float sunNightStep = lerp(0.5,1, light.direction.y);
                    //DAY NIGHT
                    float4 bottom = float4(0, 0, 0, 1);

                    float3 gradientDay = lerp(_DayBottomCol, _DayMidCol, saturate(i.uv.y)).rgb /** step(0,-i.uv.y)*/
                                        + lerp(_DayMidCol, _DayTopCol, saturate(i.uv.y)).rgb /** step(0,i.uv.y)*/;
                    float3 gradientNight = lerp(_NightBottomCol, _NightMidCol, saturate(i.uv.y)).rgb
                                        + lerp(_NightMidCol, _NightTopCol, saturate(i.uv.y)).rgb;
                    float3 skyGradients = lerp(gradientNight, gradientDay,sunNightStep) + sunCol + moonCol;


                    float3 stars;
                    //if(i.uv.y>0.4)
                        stars = SAMPLE_TEXTURE2D(_StarTex, sampler_StarTex, i.uv.xz * 2.8).rgb * pow(abs(SAMPLE_TEXTURE2D(_ClusterTex,sampler_ClusterTex,i.uv.xz).r),0.3);

                    skyGradients += lerp(stars, 0, sunNightStep);

                    ////HORIZONTAL
                    //float horWidth = lerp(_NightHorWidth, _DayHorWidth,sunNightStep);
                    //float horStrenth = lerp(_NightHorStrenth, _DayHorStrenth,sunNightStep);
                    //float horLineMask = smoothstep(-horWidth,0,i.uv.y) * smoothstep(-horWidth,0,-i.uv.y);
                    //float3 horLineGradients = lerp(_NightHorColor, _DayHorColor,sunNightStep);

                    //return half4(i.viewDirWS,1);

                    // sun


                    return half4(skyGradients + pow(abs(InScatterRayMarch(i.camPosWS, i.viewDirWS, normalize(-GetMainLight().direction.xyz))),0.48),1);



                    //return /col;
                }
                ENDHLSL
            }
        }
}
