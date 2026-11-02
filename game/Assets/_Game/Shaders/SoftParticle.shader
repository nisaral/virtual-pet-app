// Texture-free particle: a soft round dot (or a 4-point sparkle) coloured by vertex colour.
// _Additive 1 = glow (fireflies, sparks), 0 = alpha (dust, petals, rain).
Shader "LuminaVale/SoftParticle"
{
    Properties
    {
        _Shape ("Shape (0 dot, 1 sparkle, 2 streak)", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst", Float) = 10
    }

    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" }
        Blend [_SrcBlend] [_DstBlend]
        ZWrite Off
        Cull Off

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _Shape;
                float _SrcBlend;
                float _DstBlend;
            CBUFFER_END

            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; half4 color : COLOR; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; half4 color : COLOR; };

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv * 2 - 1;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float r = length(i.uv);
                float a;
                if (_Shape < 0.5) a = smoothstep(1.0, 0.35, r);
                else if (_Shape < 1.5)
                {
                    float star = max(1 - abs(i.uv.x) * 6 - abs(i.uv.y), 1 - abs(i.uv.y) * 6 - abs(i.uv.x));
                    a = saturate(star) + smoothstep(0.45, 0.0, r);
                }
                else if (_Shape < 2.5) a = smoothstep(1.0, 0.2, abs(i.uv.x) * 4) * smoothstep(1.0, 0.6, abs(i.uv.y));
                else a = 1; // shape 3: vertex colour/alpha only (blob shadows)
                return half4(i.color.rgb, i.color.a * saturate(a));
            }
            ENDHLSL
        }
    }
}
