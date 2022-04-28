Shader "URP/URPALL"
{
	Properties
	{
		//[NoScaleOffset]_BaseColor("_BaseColor",Color) = (0.5,0.3,0.2,1)
		[HDR]_Tint("Tint", Color) = (0.5 ,0.3 ,0.2 ,1)
		[Gamma] _Metallic("Metallic", Range(0, 1)) = 0 //金属度要经过伽马校正
		_Smoothness("Smoothness", Range(0, 1)) = 0.5
		//[NoScaleOffset]_LUT("LUT", 2D) = "white" {}
        [NoScaleOffset]_NormalTex("NormalTex", 2D)="bump"{}


		[NoScaleOffset]_BaseColorTex ("_BaseColorTex", 2D) = "white" {}
        [NoScaleOffset]_MetallicandGloss ("_MetallicandGloss", 2D) = "white" {}
        

        [HDR][NoScaleOffset]_EmissionTex ("_EmissionTex", 2D) = "white" {}
        [NoScaleOffset]_AOTex ("_AOTex", 2D) = "white" {}
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
				TEXTURE2D(_BaseColorTex);       SAMPLER(sampler_BaseColorTex);
				TEXTURE2D(_MetallicandGloss);       SAMPLER(sampler_MetallicandGloss);
				TEXTURE2D(_NormalTex);       SAMPLER(sampler_NormalTex);
				TEXTURE2D(_AOTex);       SAMPLER(sampler_AOTex);
				TEXTURE2D(_EmissionTex);       SAMPLER(sampler_EmissionTex);

			CBUFFER_END





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
				float3 MetalandGloss = SAMPLE_TEXTURE2D(_MetallicandGloss, sampler_MetallicandGloss, i.uv);
				float AO = SAMPLE_TEXTURE2D(_AOTex,sampler_AOTex,i.uv).r;
				float3 BaseColor = SAMPLE_TEXTURE2D(_BaseColorTex,sampler_BaseColorTex,i.uv);
				float Metallic = MetalandGloss.b;

				float gloss = MetalandGloss.g;
				gloss = MetalandGloss.g;
				
				float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv));
				normalTS.z = pow(1-pow(normalTS.x,2)-pow(normalTS.y,2),0.5);
				float3 Emission = SAMPLE_TEXTURE2D(_EmissionTex,sampler_EmissionTex,i.uv);
				
				float3 V = normalize(_WorldSpaceCameraPos.xyz-position);
				float3 N = normalize(mul(normalTS,TBN));
				float3 L = normalize(mainLight.direction);
				float3 H = normalize(V+L);
				float NoV = max(saturate(dot(N, V)), 0.000001);
                float NoL = max(saturate(dot(N, L)), 0.000001);
                float HoV = max(saturate(dot(H, V)), 0.000001);
                float NoH = max(saturate(dot(H, N)), 0.000001);
                float LoH = max(saturate(dot(H, L)), 0.000001);
				//float perceptualRoughness = 1.0-_Smoothness;//也就是线性值，给美术调的
				float perceptualRoughness = gloss;
				float roughness = perceptualRoughness*perceptualRoughness;//寒霜做法，因为其实当粗糙度很大的时候，调值变化没有那么明显
				roughness = lerp(0.002,1,roughness);
				//float Metallic = _Metallic;
				float3 F0 = float3(0.04,0.04,0.04);
				 //F0 = lerp(F0,_Tint.xyz,Metallic);
				 F0 = lerp(F0,BaseColor.xyz,Metallic);

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
				float3 diffColor = KD*BaseColor.xyz;
				//【special】
				float3 specColor = D*F*G/(4 * NoV * NoL);
				float3 DirectLightResult = (diffColor + specColor)*NoL*mainLight.color;
				
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
				float3 iblDiffuseResult = ambient_GI*KD_Indir*BaseColor.xyz;

				float3 IndirectResult = iblDiffuseResult + Specular_Indirect*AO;

				float4 result = float4( DirectLightResult+IndirectResult+Emission, 1);
				result.rbg = ACESToneMapping(result.rbg);
				return float4(result);
			}

			ENDHLSL
		}
		Pass //阴影Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}
            // URP LightMode Tags：
            // Tags{“LightMode” = “XXX”}
            // UniversalForward：前向渲染物件之用
            // ShadowCaster： 投射阴影之用
            // DepthOnly：只用来产生深度图
            // Mata：来用烘焙光照图之用
            // Universal2D ：做2D游戏用的，用来替代前向渲染
            // UniversalGBuffer ： 与延迟渲染相关，Geometry_Buffer（开发中）

            // HLSL数据类型1 – 基础数据
            // bool – true / false.
            // float – 32位浮点数，用在比如世界坐标，纹理坐标，复杂的函数计算
            // half – 16位浮点数，用于短向量、方向、颜色，模型空间位置
            // double – 64位浮点数，不能用于输入输出，要使用double，得声明为一对unit再用asuint把double打包到uint对中，再用asdouble函数解包
            // fixed – 只能用于内建管线，URP不支持，用half替代
            // real – 好像只用于URP，如果平台指定了用half（#define PREFER_HALF 0），否则就是float类型
            // int – 32位有符号整形
            // uint – 32位无符号整形(GLES2不支持，会用int替代)

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull off

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

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
	}
}
