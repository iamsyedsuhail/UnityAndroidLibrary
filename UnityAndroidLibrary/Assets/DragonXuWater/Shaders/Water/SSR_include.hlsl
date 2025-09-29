#pragma shader_feature_local_fragment _SSR_OFF

float3 GetReflectRay(float3 inputRayDir, float3 planeDir)
{
	float3 ret = -(2 * dot(inputRayDir, planeDir) * planeDir - inputRayDir);
	return normalize(ret);
}

float2 ViewPosToCS(float3 vpos)
{
	float4 proj_pos = mul(unity_CameraProjection, float4(vpos, 1));
	float3 screenPos = proj_pos.xyz / proj_pos.w;
	return float2(screenPos.x, screenPos.y) * 0.5 + 0.5;
}

float compareWithDepth(float3 vpos)
{
	float2 uv = ViewPosToCS(vpos);
	float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
	depth = LinearEyeDepth(depth, _ZBufferParams);
	int isInside = uv.x > 0 && uv.x < 1 && uv.y > 0 && uv.y < 1;
	return lerp(0, vpos.z + depth, isInside);
}

bool rayMarching(float3 o, float3 r, out float2 hitUV)
{
	float3 end = o;
	float stepSize = 0.5;
	float thinkness = 0.1;
	float triveled = 0;
	int max_marching = 256;
	float max_distance = 500;

	UNITY_LOOP
		for (int i = 1; i <= max_marching; ++i)
		{
			end += r * stepSize;
			triveled += stepSize;

			if (triveled > max_distance)
				return false;

			float collied = compareWithDepth(end);
			if (collied < 0)
			{
				if (abs(collied) < thinkness)
				{
					hitUV = ViewPosToCS(end);
					return true;
				}

				//�ص���ǰ���
				end -= r * stepSize;
				triveled -= stepSize;
				//��������
				stepSize *= 0.5;
			}
		}
	return false;
}

struct SSRdata
{
	float4 positionOS;
	float3 positionWS;
	float3 normalWS;		
	float depthSampled;
	float3 posVS;

	float3 res;
};

float3 SSR(inout SSRdata i)
{
	float4 screenPos = mul(_PV, i.positionWS);
	screenPos = screenPos / screenPos.w;
	//float4 screenPos = i.positionCS;	

	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenPos.xy);

	i.depthSampled = depth;

	depth = Linear01Depth(depth, _ZBufferParams);

	/*float2 noiseTex = (SAMPLE_TEXTURE2D(_Noise, sampler_Noise, (i.uv * 5) + _Time.x).xy * 2 - 1) * 0.1;

	half3 N = normalize(i.normalWS);
	half3 T = i.tangentWS.xyz;
	half3 B = normalize(cross(N, T) * i.tangentWS.w);

	float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), _Normal);
	half3x3 TBN = half3x3(T, B, N);*/
	float3 wsNormal = i.normalWS;

	//float3 wsNormal = normalize(float3(noiseTex.x, 1, noiseTex.y));    //��������ϵ�µķ���
	float3 vsNormal = (TransformWorldToViewDir(wsNormal));    //��ת����view space

	/*float3 vsRayOrigin = (i.vsRay) * depth;*/
	float4 posVS = mul(_VM, i.positionOS);


	float3 vsRayOrigin = posVS / posVS.w;
	i.posVS = vsRayOrigin;

	float3 col = 0;

	float3 viewPosToWorld = normalize(i.positionWS.xyz - _WorldSpaceCameraPos.xyz);
	float3 reflectDir = reflect(viewPosToWorld, wsNormal);
	col = SAMPLE_TEXTURECUBE(_SkyBoxCubeMap, sampler_SkyBoxCubeMap, reflectDir);

#ifdef _SSR_OFF	
	i.res = 0;
	return col;
#endif


	float3 reflectionDir = normalize(reflect(vsRayOrigin, vsNormal));

	float2 hitUV = 0;
	// = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenPos.xy).xyz;
	if (rayMarching(vsRayOrigin, reflectionDir, hitUV))
	{
		float3 hitCol = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, hitUV).xyz;
		//i.res = hitCol * _ReflectionStrength + (1 - _ReflectionStrength) * SAMPLE_TEXTURECUBE(_SkyBoxCubeMap, sampler_SkyBoxCubeMap, reflectionDir);
		i.res = hitCol;
		//col = 0;
	}
	else {
		
		i.res = 0;
	}

	return col;
}