Shader "URP/SSAO"
{
    Properties
    {
        _MainTex("Source",2D) = "white" {}
    }
    SubShader {
        
        ZTest Always ZWrite Off Cull Off
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        HLSLINCLUDE
            #pragma shader_feature _AO_DEBUG
            #pragma shader_feature _Blur

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)

            float4 _MainTex_TexelSize;
            float4x4 CustomProjMatrix;
            float4x4 CustomInvProjMatrix;
            float _Atten;
            float _Contrast;
            float _SampleRadius;
            int _SampleCount;
            float _BlurSize;
            CBUFFER_END
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_AOTex);
            SAMPLER(sampler_AOTex);
            // float _BlurSize = 1;
            struct a2v
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct v2f
            {
                float4 positionCS  : SV_POSITION;
                float2 uv          : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            v2f Vert(a2v i)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.positionCS = TransformObjectToHClip(i.positionOS);
                o.uv         = i.uv;
                return o;
            }

            float Random (float2 st) {
                return frac(sin(dot(st,float2(12.9898,78.233)))*43758.5453123);//2D random
            }

            float Random(float x){
                return frac(sin(x)* 43758.5453123);//1D random
            }
            float3 RandomSampleOffset(float2 uv,float index){
                float2 alphaBeta = float2(Random(uv) * PI * 2,Random(index) * PI);
                float2 sin2;
                float2 cos2;
                sincos(alphaBeta,sin2,cos2);
                return float3(cos2.y * cos2.x, sin2.y, cos2.y * sin2.x);
            }
            float2 ReProjectToUV(float3 positionVS){
                float4 positionHS = mul(CustomProjMatrix,float4(positionVS,1));
                return (positionHS.xy / positionHS.w + 1) * 0.5;
            }
            float3 ReconstructPositionVS(float2 uv,float depth){
                float4 positionInHS = float4(uv * 2 - 1,depth,1);
                float4 positionVS = mul(CustomInvProjMatrix,positionInHS);
                positionVS /= positionVS.w;
                return positionVS.xyz;
            }
            float SampleDepth(float2 uv){
                return LOAD_TEXTURE2D_X(_CameraDepthTexture, _MainTex_TexelSize.zw * uv).x;//在屏幕空间坐标上获得深度
            }
            float3x3 CreateTBN(float3 normal,float3 tangent){
                float3 bitangent = cross(normal, tangent);
                return float3x3(tangent,bitangent,normal);
            }


        ENDHLSL
        Pass 
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            float4 Frag(v2f i) : SV_Target
            {
                float2 uv = i.uv;
                float4 color = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex,uv);
                float depth = SampleDepth(uv);
                ///根据深度和UV信息，重建像素的世界坐标。先从屏幕坐标换到ndc空间，之后通过摄像机中获得的矩阵重建视图空间
                float3 positionVS = ReconstructPositionVS(uv,depth);

                float3 tangentVS = normalize(ddx(positionVS));//归一化单一方向的切线
                //重建法线
                float3 normalVS = normalize(cross(ddy(positionVS),ddx(positionVS)));

                float3x3 TBN = CreateTBN(normalVS,tangentVS);

                float ao = 0;
                float radius = _SampleRadius;
                float sampleCount = _SampleCount;
                float rcpSampleCount = rcp(sampleCount);
                for(int i = 0; i < int(sampleCount); i ++){
                    float3 offset = RandomSampleOffset(uv,i);
                    offset = mul(TBN,offset);
                    float3 samplePositionVS = positionVS + offset * radius *  (1 + i) * rcpSampleCount;
                    float2 sampleUV = ReProjectToUV(samplePositionVS);
                    float sampleDepth = SampleDepth(sampleUV);
                    float3 hitPositionVS = ReconstructPositionVS(sampleUV,sampleDepth);
                    float3 hitOffset = hitPositionVS - positionVS;
                    float a = max(0,dot(hitOffset,normalVS) - 0.001); //0~radius
                    float b = dot(hitOffset,hitOffset) + 0.001; //0~ radius^2
                    ao += a * rcp(b); // 0 ~ 1/radius
                }
                ao *= radius * rcpSampleCount;
                ao = PositivePow(ao * _Atten, _Contrast);
                ao = 1 - saturate(ao);
                //#if __AO_DEBUG__ || _Blur
                return float4(ao,ao,ao,1);
                // #else
                //return float4(depth,depth,depth,1);
                // #endif
            }
            ENDHLSL
        }
        Pass{
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragBlurH
            half4 FragBlurH(v2f i) : SV_TARGET
                {
                    
                    half3 c0 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*4.0,0.0)*_BlurSize));
                    half3 c1 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*3.0,0.0)*_BlurSize));
                    half3 c2 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*2.0,0.0)*_BlurSize));
                    half3 c3 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(_MainTex_TexelSize.x*1.0,0.0)*_BlurSize));
                    half3 c4 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv                                               ));
                    half3 c5 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*1.0,0.0)*_BlurSize));
                    half3 c6 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*2.0,0.0)*_BlurSize));
                    half3 c7 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*3.0,0.0)*_BlurSize));
                    half3 c8 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(_MainTex_TexelSize.x*4.0,0.0)*_BlurSize));
                    half3 color = c0 * 0.01621622 + c1 * 0.05405405 + c2 * 0.12162162 + c3 * 0.19459459
                                + c4 * 0.22702703
                                + c5 * 0.19459459 + c6 * 0.12162162 + c7 * 0.05405405 + c8 * 0.01621622;
                    return half4(color,1);

                }
            ENDHLSL
        }
        Pass 
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragBlurV
            half4 FragBlurV(v2f i) : SV_TARGET
            {
                    half3 c0 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(0.0,_MainTex_TexelSize.y*2.0)*_BlurSize));
                    half3 c1 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv-float2(0.0,_MainTex_TexelSize.y*1.0)*_BlurSize));
                    half3 c2 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv                                               ));
                    half3 c3 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(0.0,_MainTex_TexelSize.y*1.0)*_BlurSize));
                    half3 c4 = (SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv+float2(0.0,_MainTex_TexelSize.y*2.0)*_BlurSize));
                    half3 color = c0 * 0.07027027 + c1 * 0.31621622
                                + c2 * 0.22702703
                                + c3 * 0.31621622 + c4 * 0.07027027;
                    return half4(color,1);
            }
            ENDHLSL

        }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragAdd
            float4 FragAdd(v2f i) : SV_TARGET
            {
                float4 color = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex,i.uv);
                float ao = SAMPLE_TEXTURE2D_X(_AOTex,sampler_AOTex,i.uv+float2(0.002,0.002));
                #if _AO_DEBUG
                    return float4(ao,ao,ao,1);
                #else
                    return color*ao;
                #endif

            }
            ENDHLSL

        }
    }
}