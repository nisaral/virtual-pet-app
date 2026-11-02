// Stylised water: depth-graded colour, shoreline foam band, drifting toon glints, gentle swell.
// Needs "Depth Texture" enabled on the URP asset (LuminaSetup does this).
Shader "LuminaVale/ToonWater"
{
    Properties
    {
        _ShallowColor ("Shallow", Color) = (0.45, 0.86, 0.92, 0.7)
        _DeepColor ("Deep", Color) = (0.12, 0.42, 0.72, 0.92)
        _DepthRange ("Depth Range", Float) = 1.6
        _FoamColor ("Foam", Color) = (1, 1, 1, 1)
        _FoamDistance ("Foam Distance", Float) = 0.35
        _GlintScale ("Glint Scale", Float) = 1.4
        _WaveHeight ("Wave Height", Float) = 0.04
    }

    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent-10" "RenderPipeline" = "UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Back

        Pass
        {
            Name "Water"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _ShallowColor;
                half4 _DeepColor;
                float _DepthRange;
                half4 _FoamColor;
                float _FoamDistance;
                float _GlintScale;
                float _WaveHeight;
            CBUFFER_END

            struct Attributes { float4 positionOS : POSITION; };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half fog : TEXCOORD1;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                float3 p = TransformObjectToWorld(v.positionOS.xyz);
                p.y += (sin(_Time.y * 1.4 + p.x * 0.9) + cos(_Time.y * 1.1 + p.z * 0.7)) * _WaveHeight;
                o.positionWS = p;
                o.positionCS = TransformWorldToHClip(p);
                o.fog = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            float Hash(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

            float Noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3 - 2 * f);
                return lerp(lerp(Hash(i), Hash(i + float2(1, 0)), f.x), lerp(Hash(i + float2(0, 1)), Hash(i + 1), f.x), f.y);
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 screenUV = i.positionCS.xy / _ScaledScreenParams.xy;
                float sceneEye = LinearEyeDepth(SampleSceneDepth(screenUV), _ZBufferParams);
                float surfaceEye = i.positionCS.w;
                float depth = max(0, sceneEye - surfaceEye);

                half4 col = lerp(_ShallowColor, _DeepColor, saturate(depth / _DepthRange));

                float2 uv = i.positionWS.xz * _GlintScale;
                float n = Noise(uv + _Time.y * float2(0.25, 0.18)) * 0.6 + Noise(uv * 2.3 - _Time.y * 0.3) * 0.4;
                float foamLine = saturate(depth / _FoamDistance);
                float foam = step(foamLine, n * 0.9 + 0.05);
                float glint = step(0.78, n) * (1 - foam) * 0.5;

                Light light = GetMainLight();
                col.rgb *= lerp(0.75, 1.0, saturate(light.color.r));
                col.rgb = lerp(col.rgb, _FoamColor.rgb, saturate(foam + glint));
                col.a = saturate(col.a + foam * 0.5);
                col.rgb = MixFog(col.rgb, i.fog);
                return col;
            }
            ENDHLSL
        }
    }
}
