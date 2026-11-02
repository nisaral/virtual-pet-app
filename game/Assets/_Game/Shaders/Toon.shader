// Lumina Vale cel shader: 2-band toon ramp + soft highlight band, tinted shade colour,
// rim light, inverted-hull outline with screen-constant width, optional foliage wind.
Shader "LuminaVale/Toon"
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _ShadeColor ("Shade Tint", Color) = (0.64, 0.6, 0.8, 1)
        _ShadeThreshold ("Shade Threshold", Range(-1, 1)) = 0.02
        _ShadeSoftness ("Shade Softness", Range(0.001, 0.5)) = 0.05
        _HighlightThreshold ("Highlight Threshold", Range(0, 1)) = 0.72
        _HighlightStrength ("Highlight Strength", Range(0, 0.5)) = 0.08
        _RimColor ("Rim Color", Color) = (1, 0.96, 0.86, 1)
        _RimPower ("Rim Power", Range(1, 10)) = 4
        _RimStrength ("Rim Strength", Range(0, 1)) = 0.3
        _EmissionColor ("Emission", Color) = (0, 0, 0, 0)
        _UseVertexColor ("Use Vertex Color", Range(0, 1)) = 0
        _OutlineColor ("Outline Color", Color) = (0.2, 0.13, 0.17, 1)
        _OutlineWidth ("Outline Width (px)", Range(0, 8)) = 1.8
        _WindStrength ("Wind Strength", Range(0, 0.5)) = 0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half4 _ShadeColor;
            half _ShadeThreshold;
            half _ShadeSoftness;
            half _HighlightThreshold;
            half _HighlightStrength;
            half4 _RimColor;
            half _RimPower;
            half _RimStrength;
            half4 _EmissionColor;
            half _UseVertexColor;
            half4 _OutlineColor;
            half _OutlineWidth;
            half _WindStrength;
        CBUFFER_END

        TEXTURE2D(_BaseMap);
        SAMPLER(sampler_BaseMap);

        float3 ApplyWind(float3 positionWS, float3 positionOS)
        {
            float weight = saturate(positionOS.y) * _WindStrength;
            float t = _Time.y;
            positionWS.x += sin(t * 1.7 + positionWS.x * 0.6 + positionWS.z * 0.4) * weight * 0.25;
            positionWS.z += cos(t * 1.3 + positionWS.z * 0.5) * weight * 0.18;
            return positionWS;
        }

        half4 Albedo(float2 uv, half4 vertexColor)
        {
            half4 c = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;
            c.rgb *= lerp(half3(1, 1, 1), vertexColor.rgb, _UseVertexColor);
            return c;
        }
        ENDHLSL

        Pass
        {
            Name "ToonForward"
            Tags { "LightMode" = "UniversalForward" }
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                half4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                half fog : TEXCOORD3;
                half4 color : COLOR;
            };

            Varyings vert(Attributes v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
                Varyings o;
                float3 positionWS = ApplyWind(TransformObjectToWorld(v.positionOS.xyz), v.positionOS.xyz);
                o.positionWS = positionWS;
                o.positionCS = TransformWorldToHClip(positionWS);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                o.color = v.color;
                o.fog = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            half Step(half value, half threshold)
            {
                return smoothstep(threshold - _ShadeSoftness, threshold + _ShadeSoftness, value);
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 albedo = Albedo(i.uv, i.color);
                float3 n = normalize(i.normalWS);
                float3 viewDir = GetWorldSpaceNormalizeViewDir(i.positionWS);

                Light mainLight = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half ndl = dot(n, mainLight.direction);
                half lit = Step(ndl, _ShadeThreshold);
                lit = min(lit, smoothstep(0.35, 0.65, mainLight.shadowAttenuation));
                half highlight = Step(ndl, _HighlightThreshold) * lit;

                half3 shade = albedo.rgb * _ShadeColor.rgb;
                half3 color = lerp(shade, albedo.rgb, lit) * mainLight.color;
                color += albedo.rgb * highlight * _HighlightStrength * mainLight.color;

                // Ambient from the SH probe, flattened so it reads as fill, not as 3D shading.
                color += albedo.rgb * SampleSH(float3(0, 1, 0)) * 0.45;

                #if defined(_ADDITIONAL_LIGHTS)
                uint count = GetAdditionalLightsCount();
                for (uint li = 0u; li < count; ++li)
                {
                    Light light = GetAdditionalLight(li, i.positionWS, half4(1, 1, 1, 1));
                    half band = Step(dot(n, light.direction), 0.1) * light.distanceAttenuation * light.shadowAttenuation;
                    color += albedo.rgb * light.color * band;
                }
                #endif

                half rim = pow(1.0 - saturate(dot(n, viewDir)), _RimPower) * _RimStrength;
                color += _RimColor.rgb * rim * (0.35 + 0.65 * lit) * mainLight.color;
                color += _EmissionColor.rgb;

                color = MixFog(color, i.fog);
                return half4(color, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                half4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half fog : TEXCOORD1;
                half4 color : COLOR;
            };

            Varyings vert(Attributes v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
                Varyings o;
                float3 positionWS = ApplyWind(TransformObjectToWorld(v.positionOS.xyz), v.positionOS.xyz);
                float4 cs = TransformWorldToHClip(positionWS);
                float3 normalWS = TransformObjectToWorldNormal(v.normalOS);
                float2 normalCS = mul((float3x3)UNITY_MATRIX_VP, normalWS).xy;
                float len = max(length(normalCS), 1e-4);
                // Pixel-constant width: offset in NDC, scaled back by w.
                cs.xy += (normalCS / len) * (_OutlineWidth * 2.0 / _ScreenParams.xy) * cs.w;
                o.positionCS = cs;
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                o.color = v.color;
                o.fog = ComputeFogFactor(cs.z);
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                if (_OutlineWidth <= 0.01) discard;
                half3 albedo = Albedo(i.uv, i.color).rgb;
                half3 color = lerp(_OutlineColor.rgb, albedo * _OutlineColor.rgb * 1.6, 0.45);
                return half4(MixFog(color, i.fog), 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            float4 vert(Attributes v) : SV_POSITION
            {
                UNITY_SETUP_INSTANCE_ID(v);
                float3 positionWS = ApplyWind(TransformObjectToWorld(v.positionOS.xyz), v.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(v.normalOS);
                float4 cs = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                #if UNITY_REVERSED_Z
                cs.z = min(cs.z, UNITY_NEAR_CLIP_VALUE);
                #else
                cs.z = max(cs.z, UNITY_NEAR_CLIP_VALUE);
                #endif
                return cs;
            }

            half4 frag() : SV_Target { return 0; }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            struct Attributes
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            float4 vert(Attributes v) : SV_POSITION
            {
                UNITY_SETUP_INSTANCE_ID(v);
                return TransformWorldToHClip(ApplyWind(TransformObjectToWorld(v.positionOS.xyz), v.positionOS.xyz));
            }

            half4 frag() : SV_Target { return 0; }
            ENDHLSL
        }
    }
}
