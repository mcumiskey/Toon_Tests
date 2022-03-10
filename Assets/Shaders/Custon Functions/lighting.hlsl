//Custom Lighting functions for Unity's Shadergraph 
//Made by Miles Cumiskey

#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

/*
-SOLUTION TO A WEIRD ERROR BY CYANLUX https://cyangamedev.wordpress.com/2020/09/22/custom-lighting/
*/
#ifndef SHADERGRAPH_PREVIEW
	#if VERSION_GREATER_EQUAL(9, 0)
		#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
		#if (SHADERPASS != SHADERPASS_FORWARD)
			#undef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
		#endif
	#else
		#ifndef SHADERPASS_FORWARD
			#undef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
		#endif
	#endif
#endif

void MainLight_float(float3 WorldPos, out float3 Direction, out float3 Color, out float DistanceAtten, out float ShadowAtten) {
#ifdef SHADERGRAPH_PREVIEW
    Direction = float3(0.5, 0.5, 0);
    Color = 1;

    DistanceAtten = 1;
    ShadowAtten = 1;
#else
	float4 shadowCoord = TransformWorldToShadowCoord(WorldPos);


    //distance atten and shadow atten are important for casting / recieving shadows
	#if !defined(_MAIN_LIGHT_SHADOWS) || defined(_RECEIVE_SHADOWS_OFF)
		ShadowAtten = 1.0h;
    #elif SHADOWS_SCREEN
        half4 clipPos = TransformWorldToHClip(WorldPos);
        shadowCoord = ComputeScreenPos(clipPos);
    #else
        shadowCoord = TransformWorldToShadowCoord(WorldPos);    
        ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
        float shadowStrength = GetMainLightShadowStrength();
        ShadowAtten = SampleShadowmap(shadowCoord, TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowSamplingData, shadowStrength, false);

    #endif

    Light mainLight = GetMainLight(shadowCoord);
    Direction = mainLight.direction;
    Color = mainLight.color;
    DistanceAtten = mainLight.distanceAttenuation;


#endif
}

void DirectSpecular_float(float3 Direction, float Smoothness, float3 WorldNormal, float3 WorldView, out float3 Out){
    WorldNormal = normalize(WorldNormal);
    WorldView = SafeNormalize(WorldView);
   
   //specular appears midway between light direction and camera direction
    float3 specPos = SafeNormalize(Direction + WorldView);

    //between 0 and 1. 
    half NdotH = saturate(dot(WorldNormal, specPos));

    //adjust smoothness and size
    Smoothness = exp2(10 * Smoothness + 1);
    //modifier large = smoother object, larger spec
    half mod = pow(NdotH, Smoothness);

    Out = mod;

}

void AdditionalLights_float(float3 SpecColor, float Smoothness, float3 WorldPosition, float3 WorldNormal, float3 WorldView, out float3 Diffuse, out float3 Specular)
{
    float3 diffuseColor = 0;
    float3 specularColor = 0;

    #ifndef SHADERGRAPH_PREVIEW
        Smoothness = exp2(10 * Smoothness + 1);
        WorldNormal = normalize(WorldNormal);
        WorldView = SafeNormalize(WorldView);
        int pixelLightCount = GetAdditionalLightsCount();
        for (int i = 0; i < pixelLightCount; ++i) {
            Light light = GetAdditionalLight(i, WorldPosition);
            half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
            diffuseColor += LightingLambert(attenuatedLightColor, light.direction, WorldNormal);
            specularColor += LightingSpecular(attenuatedLightColor, light.direction, WorldNormal, WorldView, float4(SpecColor, 0), Smoothness);
        }
    #endif

    Diffuse = diffuseColor;
    Specular = specularColor;
}

#endif