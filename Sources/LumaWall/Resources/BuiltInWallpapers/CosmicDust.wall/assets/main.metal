
#include <metal_stdlib>
using namespace metal;
struct LumaWallUniforms {
  float time; float resolutionX; float resolutionY; float mouseX; float mouseY;
  float audioLevel; float audioBass; float audioMid; float audioTreble;
  float4 property0; float4 property1; float4 property2; float4 property3;
};

float h(float2 p){return fract(sin(dot(p,float2(12.9898,78.233)))*43758.5453);}
fragment float4 lumawall_fragment(float4 position [[position]], constant LumaWallUniforms& u [[buffer(0)]]) {
  float2 res=float2(max(u.resolutionX,1.0),max(u.resolutionY,1.0));
  float2 p=(position.xy-.5*res)/res.y;
  float speed=max(.05,u.property0.x), density=max(.1,u.property0.y);
  float3 accent=u.property0.zwx; if(length(accent)<.05) accent=float3(.25,.6,1);
  float3 col=float3(.002,.003,.01);
  for(int layer=0;layer<7;layer++){
    float f=float(layer);
    float scale=18.0+f*12.0;
    float2 q=p*scale+float2(u.time*speed*(.15+f*.02),sin(u.time*.2+f)*2.0);
    float2 id=floor(q), gv=fract(q)-.5;
    float rnd=h(id+f*11.0);
    float star=smoothstep(.05*density*(.4+rnd),0.0,length(gv))*step(.6,rnd);
    col+=mix(float3(.7,.8,1),accent,rnd)*star*(.25+f*.11)*(1.0+u.audioTreble*.5);
  }
  float neb=exp(-length(p-float2((u.mouseX-.5)*.35,(u.mouseY-.5)*.18))*1.8);
  col+=accent*neb*.07*(1.0+u.audioBass);
  return float4(col,1);
}