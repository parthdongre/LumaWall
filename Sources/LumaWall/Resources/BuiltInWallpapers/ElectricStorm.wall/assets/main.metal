
#include <metal_stdlib>
using namespace metal;
struct LumaWallUniforms {
  float time; float resolutionX; float resolutionY; float mouseX; float mouseY;
  float audioLevel; float audioBass; float audioMid; float audioTreble;
  float4 property0; float4 property1; float4 property2; float4 property3;
};

float n(float2 p){return fract(sin(dot(p,float2(41.3,289.1)))*43758.54);}
float noise(float2 p){float2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(n(i),n(i+float2(1,0)),f.x),mix(n(i+float2(0,1)),n(i+1.0),f.x),f.y);}
fragment float4 lumawall_fragment(float4 position [[position]], constant LumaWallUniforms& u [[buffer(0)]]) {
  float2 res=float2(max(u.resolutionX,1.0),max(u.resolutionY,1.0));
  float2 p=(position.xy-.5*res)/res.y;
  float speed=max(.1,u.property0.x), power=max(.1,u.property0.y);
  float3 accent=u.property0.zwx; if(length(accent)<.05) accent=float3(.55,.48,1);
  float t=u.time*speed;
  float bolt=0.0;
  for(int i=0;i<3;i++){
    float fi=float(i);
    float x=.18*sin(t*.7+fi*2.1)+.11*(noise(float2(p.y*5.0,t*.6+fi))-0.5);
    float d=abs(p.x-x-(fi-1.0)*.32);
    bolt+=.004/max(d,.002)*smoothstep(.6,-.45,p.y);
  }
  float cloud=noise(p*2.3+float2(t*.08,0))*noise(p*4.1-float2(t*.04,0));
  float flash=pow(max(0.0,sin(t*1.9)*sin(t*.73)),16.0)*(1.0+u.audioTreble*2.0);
  float3 col=float3(.008,.01,.025)+float3(.05,.06,.11)*cloud;
  col+=accent*bolt*power*(.65+u.audioLevel);
  col+=accent*flash*.3;
  return float4(col,1);
}