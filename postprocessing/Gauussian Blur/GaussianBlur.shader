Shader "URP/GaussianBlur"
{
    Properties
    {
        _MainTex("Main Tex", 2D)="white"{}
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
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
        v2f vert(a2v v)
        {
            v2f o;
            o.positionCS = TransformObjectToHClip(v.positionOS);
            o.uv = v.uv;
            return o;
        }
        half4 FragBlurH(v2f i) : SV_TARGET
        {
            half3 c0 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*4.0,0.0)*_BlurSize);
            half3 c1 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*3.0,0.0)*_BlurSize);
            half3 c2 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*2.0,0.0)*_BlurSize);
            half3 c3 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*1.0,0.0)*_BlurSize);
            half3 c4 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv                                              );
            half3 c5 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*1.0,0.0)*_BlurSize);
            half3 c6 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*2.0,0.0)*_BlurSize);
            half3 c7 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*3.0,0.0)*_BlurSize);
            half3 c8 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*4.0,0.0)*_BlurSize);
            half3 color = c0 * 0.01621622 + c1 * 0.05405405 + c2 * 0.12162162 + c3 * 0.19459459
                        + c4 * 0.22702703
                        + c5 * 0.19459459 + c6 * 0.12162162 + c7 * 0.05405405 + c8 * 0.01621622;
            return half4(color,1);

        }
        half4 FragBlurV(v2f i) : SV_TARGET
        {
            half3 c0 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(0.0,_MainTex_TexelSize.y*2.0)*_BlurSize);
            half3 c1 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(0.0,_MainTex_TexelSize.y*1.0)*_BlurSize);
            half3 c2 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv                                              );
            half3 c3 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(0.0,_MainTex_TexelSize.y*1.0)*_BlurSize);
            half3 c4 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(0.0,_MainTex_TexelSize.y*2.0)*_BlurSize);
            half3 color = c0 * 0.07027027 + c1 * 0.31621622
                        + c2 * 0.22702703
                        + c3 * 0.31621622 + c4 * 0.07027027;
            return half4(color,1);



        }

        ENDHLSL
        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Cull Off
            ZWrite Off
            ZTest Always
            HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment FragBlurH
            ENDHLSL
        }
        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Cull Off
            ZWrite Off
            ZTest Always
            HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment FragBlurV
            ENDHLSL
        }

    }
 
}
