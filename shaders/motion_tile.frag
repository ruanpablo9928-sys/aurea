#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uSize;
uniform vec2 uOutput;
uniform vec2 uTile;
uniform vec2 uCenter;
uniform float uMirror;
uniform float uPhase;
uniform float uHorizontal;
uniform float uFilter;
uniform sampler2D uImage;
out vec4 fragColor;
void main() {
  vec2 uv=FlutterFragCoord().xy/uSize;
  // The source is centered in an enlarged transparent render target.
  vec2 p=(uv-0.5)*uOutput+0.5;
  vec2 q=(p-uCenter)/uTile+0.5;
  if(uHorizontal>0.5) q.x-=mod(floor(q.y),2.0)*uPhase;
  else q.y-=mod(floor(q.x),2.0)*uPhase;
  vec2 cell=floor(q), f=fract(q);
  if(uMirror>0.5) f=mix(f,1.0-f,mod(cell,2.0));
  vec2 sampleUv=0.5+(f-0.5)/uOutput;
  vec2 halfPixel=0.5/uSize;
  sampleUv=clamp(sampleUv,0.5-0.5/uOutput+halfPixel,0.5+0.5/uOutput-halfPixel);
  #if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  if(uFilter>0.5) sampleUv.y=1.0-sampleUv.y;
  #endif
  fragColor=texture(uImage,sampleUv);
}
