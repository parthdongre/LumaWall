
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
  float t=u.time*max(.1,u.property0.x);
  float shine=max(.1,u.property0.y);
  float3 tint=u.property0.zwx; if(length(tint)<.05) tint=float3(.45,.9,1);
  p+=float2((u.mouseX-.5)*.08,(u.mouseY-.5)*.08);
  float v=sin(p.x*5.0+t)+sin(p.y*6.0-t*.7)+sin((p.x+p.y)*8.0+t*.45);
  v+=sin(length(p)*15.0-t*1.3)*.7;
  float ridge=pow(.5+.5*cos(v*1.8),8.0);
  float shade=.45+.35*sin(v+p.x*3.0);
  float3 col=mix(float3(.025,.03,.04),tint,shade*.35);
  col+=float3(.8,.95,1.0)*ridge*shine*(.35+u.audioTreble*.8);
  col+=tint*exp(-length(p)*2.0)*.08;
  return float4(col,1);
}