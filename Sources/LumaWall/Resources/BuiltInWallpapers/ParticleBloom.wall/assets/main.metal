
#include <metal_stdlib>
using namespace metal;
struct LumaWallUniforms {
  float time; float resolutionX; float resolutionY; float mouseX; float mouseY;
  float audioLevel; float audioBass; float audioMid; float audioTreble;
  float4 property0; float4 property1; float4 property2; float4 property3;
};

float hash(float n){return fract(sin(n)*43758.5453123);}
fragment float4 lumawall_fragment(float4 position [[position]], constant LumaWallUniforms& u [[buffer(0)]]) {
  float2 res=float2(max(u.resolutionX,1.0),max(u.resolutionY,1.0));
  float2 p=(position.xy-.5*res)/res.y;
  float speed=max(.1,u.property0.x), amount=max(.1,u.property0.y);
  float3 accent=u.property0.zwx; if(length(accent)<.05) accent=float3(1,.35,.65);
  float3 col=float3(.003,.003,.012);
  float2 mouse=float2((u.mouseX-.5)*res.x/res.y,u.mouseY-.5);
  for(int i=0;i<28;i++){
    float fi=float(i), a=fi*2.39996+u.time*.14*speed;
    float rr=.08+.018*fi+.035*sin(u.time*.6+fi);
    float2 c=float2(cos(a),sin(a))*rr + mouse*.12;
    float d=length(p-c);
    float glow=.0045/max(d,.003);
    float tw=.5+.5*sin(u.time*2.0+fi*1.7);
    col+=mix(accent,float3(.45,.55,1),hash(fi))*glow*tw*amount*(1.0+u.audioMid*.7);
  }
  float core=.025/max(length(p-mouse*.08),.02);
  col+=accent*core*.25*(1.0+u.audioBass);
  return float4(col,1);
}