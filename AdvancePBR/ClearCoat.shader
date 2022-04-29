Shader "ClearCoat"
{
	Properties
	{
		[NoScaleOffset]_MainTex("Texture", 2D) = "white" {}
		_Tint("Tint", Color) = (0.5 ,0.3 ,0.2 ,1)
        
		[Gamma] _Metallic("Metallic", Range(0, 1)) = 0 //金属度要经过伽马校正
		_Smoothness("Smoothness", Range(0, 1)) = 0.5
		[NoScaleOffset]_LUT("LUT", 2D) = "white" {}
        [NoScaleOffset]_NormalTex("NormalTex", 2D)="bump"{}

        //==========ClearCoat===============
        _ClearCoatColor("ClearCoatColor",Range(0,1)) = 1
        _ClearCoatColarRoughness("ClearCoatColarRoughness",Range(0,1))=1
	}

	SubShader
	{
		Tags {
		"RenderType" = "Opaque"
		"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Tags {
				"LightMode" = "UniversalForward"
			}

			HLSLPROGRAM
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "PBR.hlsl"

			CBUFFER_START(UnityPerMaterial)
                
				float4 _Tint;
				float _Metallic;
				float _Smoothness;
				float4 _MainTex_ST;
                float _ClearCoatColor;
                float _ClearCoatColarRoughness;
			CBUFFER_END

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			TEXTURE2D(_LUT);
			SAMPLER(sampler_LUT);
            TEXTURE2D(_NormalTex);
            SAMPLER(sampler_NormalTex);



			struct a2v
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
                float4 tangent : TANGENT;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
                float3 tangent : TEXCOORD3;
                float3 bitangent : TEXCOORD4;
			};
            


			v2f vert(a2v v)
			{
				v2f o;
				o.vertex = TransformObjectToHClip(v.vertex.xyz);
				o.worldPos = TransformObjectToWorld(v.vertex.xyz);
				o.uv = v.uv;
				o.normal = TransformObjectToWorldNormal(v.normal);
                o.tangent  = TransformObjectToWorldDir(v.tangent.xyz);
                o.bitangent = cross(o.tangent,o.normal);
				
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				Light mainLight = GetMainLight();
                //【参数】
				float3 position = i.worldPos;
				float3x3 TBN = {normalize(i.tangent),normalize(i.bitangent),normalize(i.normal)};
				float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv));
				
				float3 V = normalize(_WorldSpaceCameraPos.xyz-position);
				float3 N = normalize(mul(normalTS,TBN));
				float3 L = normalize(mainLight.direction);
				float3 H = normalize(V+L);
				float NoV = max(saturate(dot(N, V)), 0.000001);
                float NoL = max(saturate(dot(N, L)), 0.000001);
                float HoV = max(saturate(dot(H, V)), 0.000001);
                float NoH = max(saturate(dot(H, N)), 0.000001);
                float LoH = max(saturate(dot(H, L)), 0.000001);
				float perceptualRoughness = 1.0-(_Smoothness);//也就是线性值，给美术调的
				float roughness = perceptualRoughness*perceptualRoughness;//寒霜做法，因为其实当粗糙度很大的时候，调值变化没有那么明显
				float Metallic = _Metallic;
				roughness = lerp(0.002,1,roughness);
				float3 F0 = float3(0.04,0.04,0.04);
				 F0 = lerp(F0,_Tint.xyz,Metallic);

				float D = DistributionGGX(NoH,roughness);
				float3 F = F_FrenelSchlick(HoV,F0);
				float k_dir = pow(roughness*roughness+1,2)/8;
				float G = GeometrySmith(NoV, NoL, k_dir);
				
				float3 KS = F;
				float3 KD = 1-KS;
				KD *= 1-Metallic;

                //直接光部分
				//【diffuse】
				//float3 diffColor = KD*_Tint.xyz/PI
				float3 diffColor = KD*_Tint.xyz;
				//【special】
				float3 specColor = D*F*G/(4 * NoV * NoL);
				float3 DirectLightResult = (diffColor + specColor)*NoL*mainLight.color;
                //==================ClearCoat=========================
                float3 F_ClearCoat = F_FrenelSchlick(HoV,0.04)*_ClearCoatColor;
				float D_C = DistributionGGX(NoH,_ClearCoatColarRoughness);
				float k_CD = pow(_ClearCoatColarRoughness*_ClearCoatColarRoughness+1,2)/8;
				float G_C = GeometrySmith(NoV,NoL,k_CD);
				float3 dirClearCoat = D_C*F_ClearCoat*G_C/(4 * NoV * NoL)*_ClearCoatColor;
				float3 ClearCoatDirectLightResult = DirectLightResult*(1-F_ClearCoat)+dirClearCoat;


				
                //间接光部分
				float3 R = normalize(reflect(-V,N));
				
				float k_indir = roughness*roughness/2;
				//【special】
				float3 F_Indir = IndirFresnelSchlick(NoV,F0,roughness);
				float mip_level = roughness*(1.7-0.7*roughness)*UNITY_SPECCUBE_LOD_STEPS;
				float4 IndirSpecularBaseColor = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0,samplerunity_SpecCube0,R,mip_level);
				float3 iblSpecular = DecodeHDREnvironment(IndirSpecularBaseColor,unity_SpecCube0_HDR);

				float2 env_brdf =  EnvBRDFApprox(roughness,NoV);
				float3 Specular_Indirect = iblSpecular*(F_Indir*env_brdf.r+env_brdf.g);

				
				float3 KD_Indir = float3(1,1,1) - F_Indir;
				KD_Indir *= 1-Metallic;

				//【diffuse】
				float3 ambient_GI = SampleSH(N);
				//float3 iblDiffuseResult = ambient_GI*KD_Indir*_Tint.xyz/PI;
				float3 iblDiffuseResult = ambient_GI*KD_Indir*_Tint.xyz;

				float3 IndirectResult = iblDiffuseResult + Specular_Indirect;
				float3 Specular_Indirect_ClearCoat = SpecularIndirect(N,V,1-_ClearCoatColarRoughness,0.04)*_ClearCoatColor;
				float3 F_IndirectLight_ClearCoat = IndirFresnelSchlick(NoV,0.04,1-_ClearCoatColarRoughness)*_ClearCoatColor;
				float3 result = IndirectResult*(1-F_IndirectLight_ClearCoat)+Specular_Indirect_ClearCoat;
				result = result + ClearCoatDirectLightResult;

				result.rgb = ACESToneMapping(result.rgb);
				return float4(result.rgb,1);
			}

			ENDHLSL
		}
	}
}
