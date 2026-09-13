# Creator API

## Web wallpapers

LumaWall injects `window.LumaWall` before page scripts execute.

```js
LumaWall.on("mouse", ({x, y, primaryDown, secondaryDown}) => {})
LumaWall.on("audio", ({level, bass, mid, treble, spectrum}) => {})
LumaWall.on("properties", values => {})
LumaWall.on("pause", () => {})
LumaWall.on("resume", () => {})
LumaWall.on("fps", fps => {})
LumaWall.on("scale", scale => {})
```

Equivalent DOM events are dispatched as `lumawall:mouse`, `lumawall:audio`, etc.

## Metal wallpapers

The fragment shader must export:

```metal
fragment float4 lumawall_fragment(float4 position [[position]],
                                  constant LumaWallUniforms& u [[buffer(0)]])
```

v0.2 uniform order:

```metal
struct LumaWallUniforms {
    float time;
    float resolutionX;
    float resolutionY;
    float mouseX;
    float mouseY;
    float audioLevel;
    float audioBass;
    float audioMid;
    float audioTreble;
    float4 property0;
    float4 property1;
    float4 property2;
    float4 property3;
};
```

Property values are flattened in manifest order. Number/toggle/dropdown occupy one float. A color occupies three consecutive floats (RGB 0...1). The current ABI exposes 16 float property slots.
