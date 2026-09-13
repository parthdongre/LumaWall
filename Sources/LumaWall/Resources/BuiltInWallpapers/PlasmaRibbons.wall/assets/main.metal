
#include <metal_stdlib>
using namespace metal;
struct LumaWallUniforms {
  float time; float resolutionX; float resolutionY; float mouseX; float mouseY;
  float audioLevel; float audioBass; float audioMid; float audioTreble;
  float4 property0; float4 property1; float4 property2; float4 property3;
};

fragment float4 lumawall_fragment(float4 position [[position]], constant LumaWallUniforms& u [[buffer(0)]]) {
  float2 res=float2(max(u.resolutionX,1.0),max(u.resolutionY,1.0));
  float2 p=(position.xy-.5*res)/res.y;
  float speed=max(.1,u.property0.x), energy=max(.1,u.property0.y);
  float3 accent=u.property0.zwx; if(length(accent)<.05) accent=float3(1,.15,.8);
  float t=u.time*speed;
  float3 col=float3(.004,.002,.014);
  for(int i=0;i<6;i++){
    float fi=float(i);
    float wave=sin(p.x*(4.0+fi*.8)+t*(.7+fi*.09)+sin(p.x*2.0-t)*1.4)*(.16+fi*.008);
    wave+=cos(p.x*2.0-t*.55+fi)*.07;
    float d=abs(p.y-wave+(fi-2.5)*.055);
    float glow=.012/max(d,.004);
    float3 c=mix(accent,float3(.15,.6,1.0),fi/5.0);
    col+=c*glow*.23*energy*(1.0+u.audioMid*.7);
  }
  float mouse=exp(-length(p-float2((u.mouseX-.5)*res.x/res.y,u.mouseY-.5))*5.0);
  col+=accent*mouse*.12;
  return float4(col,1);
}