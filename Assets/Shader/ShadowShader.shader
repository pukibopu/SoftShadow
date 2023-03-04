// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'

Shader "Unlit/ShadowShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _AmbientStrength("Ambient Streghth",Range(0,1))=1
        _DiffuseStrength("Diffuse Strength",Range(0,1))=1
        _SpecularStrength("Specular Strength",Range(0,5))=5
        _SpecularPow("Specular Pow",Range(0,256))=64
        _ShadowColor("Shadow Color",Color)=(0,0,0 ,1)
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_shadowcaster

            #include "UnityCG.cginc"

            struct v2f
            {
                V2F_SHADOW_CASTER;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                return o;
            }

            float4 frag(v2f i): SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG

        }

        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }



            CGPROGRAM
            #pragma multi_compile_fwdbase
            #pragma shader_feature _PCFSoftShadow
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "HLSLSupport.cginc"
            #include "Lighting.cginc"
            


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal:NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;

                float4 pos : SV_POSITION;

                float3 worldNormal:NORMAL;
                float3 worldViewDir:TEXCOORD1;
                float3 wordlLightDIr:TEXCOORD2;
                float4 _ShadowCoord:TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float _AmbientStrength;
            float _DiffuseStrength;
            float _SpecularStrength;
            float _SpecularPow;
            //float4x4 _lightMatrix;
            float4 _ShadowColor;
            float4x4 unity_WorldToLight;
            //Texture2D<float4> _ShadowMapTexture;
            //UNITY_DECLARE_TEX2D(_ShadowMapTexture);
           UNITY_DECLARE_SHADOWMAP(_ShadowMapTexture);

            float4 _ShadowMapTexture_TexelSize;

            float4 ComputeShadowCoord(float4 worldPos, float4 lightPos, float4x4 lightMatrix)
            {
                float4 shadowCoord = mul(lightMatrix, worldPos);
                shadowCoord.xyz /= shadowCoord.w;
                shadowCoord.xyz = shadowCoord.xyz * 0.5f + 0.5f;
                shadowCoord.y = 1.0f - shadowCoord.y;
                return shadowCoord;
            }

            // float SampleShadowMap(float3 xyz)
            // {
            //     return UNITY_SAMPLE_SHADOW(_ShadowMapTexture, xyz);
            // }

            // float PCF3x3Shadow(float3 xyz)
            // {
            //     float offsetX = _ShadowMapTexture_TexelSize.x * 0.5;
            //     float offsetY = _ShadowMapTexture_TexelSize.y * 0.5;
            //
            //     float lt = SampleShadowMap(float3(xyz.x - offsetX, xyz.y + offsetY, xyz.z));
            //     float rt = SampleShadowMap(float3(xyz.x + offsetX, xyz.y + offsetY, xyz.z));
            //     float lb = SampleShadowMap(float3(xyz.x - offsetX, xyz.y - offsetY, xyz.z));
            //     float rb = SampleShadowMap(float3(xyz.x + offsetX, xyz.y - offsetY, xyz.z));
            //
            //     return (lt + rt + lb + rb) * 0.25;
            // }


            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldViewDir = normalize(_WorldSpaceCameraPos.xyz - mul(unity_ObjectToWorld, v.vertex).xyz);
                o.wordlLightDIr = normalize(_WorldSpaceLightPos0.xyz - mul(unity_ObjectToWorld, v.vertex).xyz);

               
                float4 texCoord = mul(unity_WorldToLight, o.pos);
                texCoord /= texCoord.w;
                texCoord.xyz = texCoord.xyz * 0.5 + 0.5;
                texCoord.y = 1.0 - texCoord.y;


                o._ShadowCoord = texCoord;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

                //float4 screenpos = ComputeScreenPos(i._ShadowCoord);
                //float4 shadow = UNITY_SAMPLE_TEX2D(_ShadowMapTexture, screenpos.xy);
                //float4 shadow = _ShadowMapTexture.Sample(sampler_ShadowMapTexture, i.pos.xy/i.pos.w *0.5 + 0.5);

                //float shadow = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, ComputeScreenPos(i.pos));//PCF3x3Shadow(i._ShadowCoord);
                float shadow = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, i._ShadowCoord);
                float3 ambient = _AmbientStrength * _LightColor0;

                float3 diff = dot(i.worldNormal, i.wordlLightDIr) * _DiffuseStrength * _LightColor0;

                float3 halfDir = normalize(i.worldViewDir + i.wordlLightDIr);

                float3 spec = pow(saturate(dot(halfDir, i.worldNormal)), _SpecularPow) * _SpecularStrength *
                    _LightColor0;


                fixed4 final_Col = fixed4(((spec + diff) * shadow + ambient), 1) * col;

                return shadow;
            }
            ENDCG
        }

    }
}