
#include <metal_stdlib>
using namespace metal;
struct LumaWallUniforms {
  float time; float resolutionX; float resolutionY; float mouseX; float mouseY;
  float audioLevel; float audioBass; float audioMid; float audioTreble;
  float4 property0; float4 property1; float4 property2; float4 property3;
};

float h21(float2 p){p=fract(p*float2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
fragment float4 lumawall_fragment(float4 position [[position]], constant LumaWallUniforms& u [[buffer(0)]]) {
  float2 res=float2(max(u.resolutionX,1.0),max(u.resolutionY,1.0));
  float2 uv=(position.xy-.5*res)/res.y;
  uv-=float2((u.mouseX-.5)*.15,(u.mouseY-.5)*.1);
  float speed=max(.1,u.property0.x)*(1.0+u.audioLevel*.4);
  float density=max(.2,u.property0.y);
  float3 tint=u.property0.zwx; if(length(tint)<.05) tint=float3(.5,.3,1);
  float3 col=float3(.002,.003,.012);
  for(int layer=0;layer<5;layer++){
    float depth=fract(float(layer)*.173+u.time*.10*speed);
    float scale=mix(4.0,18.0,depth)*density;
    float2 gv=fract(uv*scale)-.5;
    float2 id=floor(uv*scale);
    float rnd=h21(id+float(layer)*17.0);
    float size=mix(.025,.11,depth)*(0.35+rnd);
    float d=length(gv-float2(h21(id+3.1)-.5,h21(id+7.7)-.5)*.75);
    float star=smoothstep(size,0.0,d)*mix(.3,1.7,depth);
    float streak=smoothstep(size*.7,0.0,abs(gv.x))*smoothstep(.48,0.0,abs(gv.y))*depth*.12*speed;
    col+=(float3(.8,.9,1.0)+tint*rnd*.7)*(star+streak);
  }
  float neb=pow(max(0.0,1.0-length(uv*.55)),3.0);
  col+=tint*neb*.08*(1.0+u.audioBass);
  return float4(col,1);
}