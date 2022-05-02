Shader "URP/DualURPKawaseBlur"
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
		struct v2fDown
		{
			float4 positionCS: SV_POSITION;
			float2 uv[5]: TEXCOORD;
		};
		struct v2fUp
		{
			float4 positionCS: SV_POSITION;
			float2 uv[8]: TEXCOORD;
		};

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
			v2fDown Vert(a2v v)
			{
				v2fDown o;
				o.positionCS = TransformObjectToHClip(v.positionOS);
				o.uv[0] = v.uv;
				o.uv[1] = v.uv + float2(-1,-1) * _BlurSize * _MainTex_TexelSize.xy;
				o.uv[2] = v.uv + float2(-1, 1) * _BlurSize * _MainTex_TexelSize.xy;
				o.uv[3] = v.uv + float2(1, -1) * _BlurSize * _MainTex_TexelSize.xy;
				o.uv[4] = v.uv + float2(1,  1) * _BlurSize * _MainTex_TexelSize.xy;
				return o;
			}
			half4 Frag(v2fDown i): SV_Target
			{
				half4 color = 0;
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[0])*4;
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[1]);
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[2]);
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[3]);
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[4]);
				color*=0.125;
				return color;
			}

			#pragma fragment Frag
			ENDHLSL
		}

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

			v2fUp Vert(a2v v)
			{
				v2fUp o;
				o.positionCS = TransformObjectToHClip(v.positionOS);
				o.uv[0] = v.uv + float2(-1,-1) * _BlurSize * _MainTex_TexelSize.xy;
				o.uv[1] = v.uv + float2(-1, 1) * _BlurSize * _MainTex_TexelSize.xy;
				o.uv[2] = v.uv + float2(1, -1) * _BlurSize * _MainTex_TexelSize.xy;
				o.uv[3] = v.uv + float2(1,  1) * _BlurSize * _MainTex_TexelSize.xy;
				o.uv[4] = v.uv + float2(-2, 0) * _BlurSize * _MainTex_TexelSize.xy;
				o.uv[5] = v.uv + float2(0, -2) * _BlurSize * _MainTex_TexelSize.xy;
				o.uv[6] = v.uv + float2(2,  0) * _BlurSize * _MainTex_TexelSize.xy;
				o.uv[7] = v.uv + float2(0,  2) * _BlurSize * _MainTex_TexelSize.xy;
				return o;
			}
			half4 Frag(v2fUp i):SV_Target
			{
				half4 color = 0;
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[0])*2;
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[1])*2;
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[2])*2;
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[3])*2;
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[4]);
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[5]);
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[6]);
				color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[7]);
				color*=0.0833;
				return color;
			}
			ENDHLSL
		}
	}
}
