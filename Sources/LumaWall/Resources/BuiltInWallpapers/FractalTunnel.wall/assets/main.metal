
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
  p-=float2((u.mouseX-.5)*.12,(u.mouseY-.5)*.08);
  float speed=max(.05,u.property0.x), detail=max(.2,u.property0.y);
  float3 accent=u.property0.zwx; if(length(accent)<.05) accent=float3(0,1,.7);
  float r=max(length(p),.001), a=atan2(p.y,p.x);
  float z=1.0/r + u.time*speed*.8;
  float rings=.5+.5*cos(z*7.0*detail);
  float spokes=.5+.5*cos(a*(8.0+4.0*detail)+z*1.6);
  float pattern=pow(rings*spokes,2.2);
  float glow=.03/max(abs(fract(z*.15)-.5),.05);
  float3 col=float3(.002,.004,.008)+accent*pattern*.55*(1.0+u.audioMid*.6);
  col+=mix(accent,float3(.3,.35,1),.5)*glow*.09;
  col*=smoothstep(0.0,.08,r);
  return float4(col,1);
}