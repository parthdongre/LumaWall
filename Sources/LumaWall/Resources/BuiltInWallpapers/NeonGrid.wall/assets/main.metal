
#include <metal_stdlib>
using namespace metal;
struct LumaWallUniforms {
  float time; float resolutionX; float resolutionY; float mouseX; float mouseY;
  float audioLevel; float audioBass; float audioMid; float audioTreble;
  float4 property0; float4 property1; float4 property2; float4 property3;
};

fragment float4 lumawall_fragment(float4 position [[position]], constant LumaWallUniforms& u [[buffer(0)]]) {
  float2 res=float2(max(u.resolutionX,1.0),max(u.resolutionY,1.0));
  float2 uv=position.xy/res;
  float2 p=(uv-.5)*float2(res.x/res.y,1.0);
  float speed=max(.1,u.property0.x), glow=max(.1,u.property0.y);
  float3 accent=u.property0.zwx; if(length(accent)<.05) accent=float3(0,.9,1);
  float z=1.0/(abs(p.y+.38)+.12);
  float2 q=float2(p.x*z, z+u.time*.65*speed);
  float gx=pow(max(0.0,1.0-abs(fract(q.x*2.2)-.5)*20.0),2.0);
  float gy=pow(max(0.0,1.0-abs(fract(q.y*.35)-.5)*18.0),2.0);
  float horizon=exp(-abs(p.y+.38)*18.0);
  float mouse=exp(-length(p-float2((u.mouseX-.5)*1.4,(u.mouseY-.5)))*4.0);
  float line=(gx+gy)*z*.11*glow + horizon*.6 + u.audioBass*.18 + mouse*.08;
  float3 col=float3(.003,.006,.018)+accent*line;
  col+=float3(.35,.05,.7)*pow(max(0.0,1.0-length(p-float2(0,.1))*1.2),4.0)*.2;
  return float4(col,1);
}