            float3 ACESToneMapping(float3 x)
            {
                float a = 2.51f;
                float b = 0.03f;
                float c = 2.43f;
                float d = 0.59f;
                float e = 0.14f;
                return saturate((x*(a*x+b))/(x*(c*x+d)+e));
            }
float DistributionGGX(float NoH,float roughness )
{
    float a2 = roughness*roughness;
    float NoH2 = NoH*NoH;
    float denominator = (NoH2*(a2-1)+1.0);
    denominator = PI*denominator*denominator;
    return a2/max(denominator,0.000001);
}


float3 F_FrenelSchlick(float HoV,float3 F0)
{
    return F0 +(1 - F0)*pow(1-HoV,5);//UE4做法
    //return lerp(pow(1-HV,5),1,F0);
}

float3 IndirFresnelSchlick(float NoV, float3 F0, float roughness)
{
    return F0 + (max(float3(1, 1, 1) * (1 - roughness), F0) - F0) * pow(1.0 - NoV, 5.0);
}

float GeometrySchlickGGX1(float NoV,float k)
{
    return NoV/max((NoV)*(1.0-k)+k,0.000001);
}

float GeometrySchlickGGX2(float NoL,float k)
{
    return NoL/max(NoL*(1-k)+k,0.000001);
}
float GeometrySmith(float NoV, float NoL, float k)
{
    float ggx1 = GeometrySchlickGGX1(NoV, k);
    float ggx2 = GeometrySchlickGGX2(NoL, k);
    return (ggx1 * ggx2);
}

float2 EnvBRDFApprox(float Roughness,float NoV)
{
    // [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
    // Adaptation to fit our G term.
    const float4 c0 = { -1, -0.0275, -0.572, 0.022 };
    const float4 c1 = { 1, 0.0425, 1.04, -0.04 };
    float4 r = Roughness * c0 + c1;
    float a004 = min( r.x * r.x, exp2( -9.28 * NoV ) ) * r.x + r.y;
    float2 AB = float2( -1.04, 1.04 ) * a004 + r.zw;
    return AB;
}
float3 SpecularIndirect(float3 N,float3 V,float Roughness,float3 F0)
            {
                //Specular
                float3 R = reflect(-V,N);
                float NV = dot(N,V);
                float3 F_IndirectLight = IndirFresnelSchlick(NV,F0,Roughness);
                // return F_IndirectLight.xyzz;
                // float3 F_IndirectLight = F_FrenelSchlick(NV,F0);
                float mip = Roughness * (1.7 - 0.7 * Roughness) * UNITY_SPECCUBE_LOD_STEPS ;
                float4 rgb_mip = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0,samplerunity_SpecCube0,R,mip);

                //间接光镜面反射采样的预过滤环境贴图
                float3 EnvSpecularPrefilted = DecodeHDREnvironment(rgb_mip, unity_SpecCube0_HDR);
               
                //LUT采样
                // float2 env_brdf = tex2D(_BRDFLUTTex, float2(NV, Roughness)).rg; //0.356
                // float2 env_brdf = tex2D(_BRDFLUTTex, float2(lerp(0, 0.99, NV), lerp(0, 0.99, Roughness))).rg;
             
                //数值近似
                float2 env_brdf = EnvBRDFApprox(Roughness,NV);
                float3 Specular_Indirect = EnvSpecularPrefilted  * (F_IndirectLight * env_brdf.r + env_brdf.g);
                return Specular_Indirect;
            }