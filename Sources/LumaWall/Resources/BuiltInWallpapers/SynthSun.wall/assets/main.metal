
#include <metal_stdlib>
using namespace metal;
struct LumaWallUniforms {
  float time; float resolutionX; float resolutionY; float mouseX; float mouseY;
  float audioLevel; float audioBass; float audioMid; float audioTreble;
  float4 property0; float4 property1; float4 property2; float4 property3;
};

fragment float4 lumawall_fragment(float4 position [[position]], constant LumaWallUniforms& u [[buffer(0)]]) {
  float2 res=float2(max(u.resolutionX,1.0),max(u.resolutionY,1.0));
  float2 uv=position.xy/res, p=(uv-.5)*float2(res.x/res.y,1.0);
  float speed=max(.1,u.property0.x), sunGlow=max(.1,u.property0.y);
  float3 accent=u.property0.zwx; if(length(accent)<.05) accent=float3(1,.25,.55);
  float3 col=mix(float3(.01,.01,.08),float3(.16,.02,.2),uv.y);
  float2 sunPos=float2((u.mouseX-.5)*.18,.18+(u.mouseY-.5)*.06);
  float sd=length(p-sunPos);
  float sun=smoothstep(.22,.205,sd);
  float stripes=.55+.45*step(.5,fract((p.y-sunPos.y)*18.0));
  col+=mix(accent,float3(1,.65,.1),.5)*sun*stripes*sunGlow;
  float horizon=-.12;
  if(p.y<horizon){
    float z=1.0/max(.03,horizon-p.y);
    float2 g=float2(p.x*z,z+u.time*speed);
    float grid=(smoothstep(.48,.5,abs(fract(g.x*.25)-.5))+smoothstep(.48,.5,abs(fract(g.y*.13)-.5)))*.45;
    col+=accent*grid*min(1.0,z*.05)*(1.0+u.audioBass*.4);
  }
  float mountain=smoothstep(.015,0.0,abs(p.y-(horizon+.06*sin(p.x*7.0)+.035*sin(p.x*15.0))));
  col+=float3(.15,.02,.22)*mountain;
  return float4(col,1);
}