Shader "URP/URPKawaseBlur"
{
	Properties
	{
		_MainTex("Main Tex", 2D)="white"{}
	}

	SubShader
	{
		Tags
		{
			"RenderPipeline"="UniversalRenderPipeline"
		}

		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

		CBUFFER_START(UnityPerMaterial)
			float _BlurSize;
			float4 _MainTex_TexelSize;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);

		struct a2v{
			float4 positionOS: POSITION;
			float2 uv: TEXCOORD0;
		};
		struct v2f
		{
			float4 positionCS: SV_POSITION;
			float2 uv: TEXCOORD0;
		};

		half4 KawaseBlur(float2 uv, float2 texelSize)
		{
			half4 o = 0;
			o += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
			o += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(+0.5, +0.5) * texelSize *_BlurSize);
			o += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-0.5, +0.5) * texelSize *_BlurSize);
			o += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-0.5, -0.5) * texelSize *_BlurSize);
			o += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(+0.5, -0.5) * texelSize *_BlurSize);
			return o * 0.2;
		}
		v2f Vert(a2v v)
		{
			v2f o;
			o.positionCS = TransformObjectToHClip(v.positionOS);
			o.uv = v.uv;
			return o;
		}
		half4 Frag(v2f i): SV_Target
		{
			return KawaseBlur(i.uv, _MainTex_TexelSize.xy);
		}

		ENDHLSL

		Pass
		{
			Tags{
				"LightMode"="UniversalForward"
			}
			Cull Off
			ZWrite Off
			ZTest Always

			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag
			ENDHLSL
		}
	}
}
