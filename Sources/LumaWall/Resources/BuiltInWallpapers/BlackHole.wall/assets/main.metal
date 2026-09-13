
#include <metal_stdlib>
using namespace metal;
struct LumaWallUniforms {
  float time; float resolutionX; float resolutionY; float mouseX; float mouseY;
  float audioLevel; float audioBass; float audioMid; float audioTreble;
  float4 property0; float4 property1; float4 property2; float4 property3;
};

float hash21(float2 p){return fract(sin(dot(p,float2(127.1,311.7)))*43758.5453);}
fragment float4 lumawall_fragment(float4 position [[position]], constant LumaWallUniforms& u [[buffer(0)]]) {
  float2 res=float2(max(u.resolutionX,1.0),max(u.resolutionY,1.0));
  float2 p=(position.xy-.5*res)/res.y;
  p-=float2((u.mouseX-.5)*.08,(u.mouseY-.5)*.05);
  float spin=max(.01,u.property0.x), lens=max(.2,u.property0.y);
  float3 accent=u.property0.zwx; if(length(accent)<.05) accent=float3(1,.5,.05);
  float r=length(p), a=atan2(p.y,p.x);
  float ring=exp(-abs(r-.31)*42.0*lens);
  float disk=exp(-abs(p.y/(.12+.18*r))*8.0)*smoothstep(.72,.18,r)*smoothstep(.13,.23,r);
  float bands=.55+.45*sin(a*7.0-r*36.0-u.time*4.0*spin);
  float3 col=float3(.001,.001,.004);
  col+=accent*disk*(.35+bands*1.2)*(1.0+u.audioBass*.8);
  col+=float3(1,.85,.55)*ring*.9;
  col*=smoothstep(.15,.21,r);
  float stars=step(.997,hash21(floor(p*160.0)))*smoothstep(.25,.9,r);
  col+=stars*float3(.7,.8,1);
  float halo=exp(-r*3.0)*.08;
  col+=accent*halo;
  return float4(col,1);
}