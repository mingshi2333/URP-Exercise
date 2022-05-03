Shader "URP/Bloom"
{
    Properties
    {
        [HDR]_MainTex("Main Tex", 2D)="white"{}
        [HDR]_Bloom("Bloom", 2D)="black"{}
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }
        HLSLINCLUDE
        #pragma multi_compile_local _ _USE_RGBM
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        

        CBUFFER_START(UnityPerMaterial)
			float _BlurSize;
			float4 _MainTex_TexelSize;
            float _LuminanceThreshold;
		CBUFFER_END
        TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);
        TEXTURE2D(_BloomTex);
        SAMPLER(sampler_BloomTex);

        half4 EncodeHDR(half3 color)
        {
        #if _USE_RGBM
            half4 outColor = EncodeRGBM(color);
        #else
            half4 outColor = half4(color, 1.0);
        #endif

        #if UNITY_COLORSPACE_GAMMA
            return half4(sqrt(outColor.xyz), outColor.w); // linear to γ
        #else
            return outColor;
        #endif
        }

        half3 DecodeHDR(half4 color)
        {
        #if UNITY_COLORSPACE_GAMMA
            color.xyz *= color.xyz; // γ to linear
        #endif

        #if _USE_RGBM
            return DecodeRGBM(color);
        #else
            return color.xyz;
        #endif
        }
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
            o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
            o.uv = v.uv;
            return o;
        }

        half luminance(half3 color)
        {
            return 0.2125*color.r+0.7154*color.g+0.0721*color.b;
        }

        half4 vertExtractBright(v2f i) : SV_TARGET
        {
            half3 c = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv)).xyz;
            half val = clamp(luminance(c)-_LuminanceThreshold,0.0,1.0);
            return EncodeHDR(c*val);
        }
        half4 FragBlurH(v2f i) : SV_TARGET
        {
            half3 c0 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*4.0,0.0)*_BlurSize));
            half3 c1 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*3.0,0.0)*_BlurSize));
            half3 c2 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*2.0,0.0)*_BlurSize));
            half3 c3 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*1.0,0.0)*_BlurSize));
            half3 c4 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv                                               ));
            half3 c5 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*1.0,0.0)*_BlurSize));
            half3 c6 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*2.0,0.0)*_BlurSize));
            half3 c7 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*3.0,0.0)*_BlurSize));
            half3 c8 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*4.0,0.0)*_BlurSize));
            half3 color = c0 * 0.01621622 + c1 * 0.05405405 + c2 * 0.12162162 + c3 * 0.19459459
                        + c4 * 0.22702703
                        + c5 * 0.19459459 + c6 * 0.12162162 + c7 * 0.05405405 + c8 * 0.01621622;
            return EncodeHDR(color);

        }
        half4 FragBlurV(v2f i) : SV_TARGET
        {
            half3 c0 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(0.0,_MainTex_TexelSize.y*2.0)*_BlurSize));
            half3 c1 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(0.0,_MainTex_TexelSize.y*1.0)*_BlurSize));
            half3 c2 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv                                               ));
            half3 c3 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(0.0,_MainTex_TexelSize.y*1.0)*_BlurSize));
            half3 c4 = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(0.0,_MainTex_TexelSize.y*2.0)*_BlurSize));
            half3 color = c0 * 0.07027027 + c1 * 0.31621622
                        + c2 * 0.22702703
                        + c3 * 0.31621622 + c4 * 0.07027027;
            return EncodeHDR(color);
        }
        half4 FragBloom(v2f i) : SV_TARGET
        {
            half3 base = DecodeHDR(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv)).xyz;
            half3 bloom = (SAMPLE_TEXTURE2D(_BloomTex,sampler_BloomTex,i.uv)).xyz;
            half3 color = base+bloom;
            return EncodeHDR(color);

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
			#pragma fragment vertExtractBright
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
			#pragma fragment FragBloom
            ENDHLSL
        }

    }
 
}
