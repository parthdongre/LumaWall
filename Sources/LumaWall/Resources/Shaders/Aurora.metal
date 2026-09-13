#include <metal_stdlib>
using namespace metal;

struct LumaWallUniforms {
    float time;
    float resolutionX;
    float resolutionY;
    float mouseX;
    float mouseY;
    float audioLevel;
    float audioBass;
    float audioMid;
    float audioTreble;
    float4 property0;
    float4 property1;
    float4 property2;
    float4 property3;
};

fragment float4 lumawall_fragment(float4 position [[position]],
                                  constant LumaWallUniforms& u [[buffer(0)]]) {
    float2 res = float2(max(u.resolutionX, 1.0), max(u.resolutionY, 1.0));
    float2 uv = position.xy / res;
    float2 p = (uv - 0.5) * float2(res.x / res.y, 1.0);
    float2 mouse = float2(u.mouseX - 0.5, u.mouseY - 0.5);

    float speed = max(0.1, u.property0.x);
    float intensity = max(0.1, u.property0.y);
    float3 accent = float3(u.property0.z, u.property0.w, u.property1.x);
    if (length(accent) < 0.05) accent = float3(0.15, 0.85, 0.65);

    float wave = sin(p.x * 7.0 + u.time * 0.7 * speed) * 0.18;
    wave += sin(p.x * 13.0 - u.time * 0.45 * speed) * 0.08;
    wave += sin(p.x * 20.0 + u.time * 0.3) * u.audioBass * 0.08;
    float glow = 0.035 / max(abs(p.y - wave - mouse.y * 0.25), 0.01);

    float3 base = float3(0.015, 0.02, 0.04);
    float3 aurora = accent * glow * intensity * (1.0 + u.audioLevel * 1.7);
    aurora += float3(0.25, 0.2, 0.9) * glow * 0.45 * (1.0 + u.audioMid);
    return float4(base + aurora, 1.0);
}
