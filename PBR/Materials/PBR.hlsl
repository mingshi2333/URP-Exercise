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