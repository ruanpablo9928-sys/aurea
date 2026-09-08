#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uSize;
uniform float uMode;
uniform float uAmount;
uniform float uAngle;
uniform float uRadius;
uniform vec2 uCenter;
uniform float uCount;
uniform float uSeed;
uniform float uFilter;
uniform sampler2D uImage;
out vec4 fragColor;
const float PI = 3.141592653589793;
float noise(vec2 v) { return fract(sin(dot(v,vec2(12.9898,78.233))+uSeed*17.17)*43758.5453); }
vec2 rotate2(vec2 v,float a) {return mat2(cos(a),-sin(a),sin(a),cos(a))*v;}
void main() {
 vec2 uv=FlutterFragCoord().xy/uSize;
 vec2 q=uv; float mask=1.0;
 float aspect=uSize.x/max(1.0,uSize.y);
 vec2 v=(uv-uCenter)*vec2(aspect,1.0);
 float r=length(v), radius=max(.001,uRadius);
 if(uMode<.5) { // Twirl, taper continuously at radius.
  v=rotate2(v,-uAmount*PI/180.0*pow(max(0.0,1.0-r/radius),2.0));
  q=uCenter+v/vec2(aspect,1.0);
 } else if(uMode<1.5) { // Radial lens with identity at zero.
  float weight=max(0.0,1.0-r/radius);
  q=uCenter+v*exp(-uAmount*weight*weight)/vec2(aspect,1.0);
 } else if(uMode<2.5) { // Mirrored angular sectors.
  float sector=2.0*PI/max(1.0,uCount);
  float a=atan(v.y,v.x)+uAngle;
  a=abs(mod(a+sector*.5,sector)-sector*.5);
  vec2 folded=vec2(cos(a),sin(a))*r;
  q=mix(uv,uCenter+folded/vec2(aspect,1.0),clamp(uAmount,0.0,1.0));
 } else if(uMode<3.5) { // Venetian blinds.
  float stripe=fract(dot(uv,vec2(cos(uAngle),sin(uAngle)))*max(1.0,uCount));
  float softness=max(.0001,uRadius);
  mask=uAmount<=0.0?1.0:(uAmount>=1.0?0.0:smoothstep(uAmount-softness,uAmount+softness,stripe));
 } else if(uMode<4.5) { // Block dissolve, deterministic at arbitrary seek.
  vec2 cell=floor(uv*vec2(aspect,1.0)*max(1.0,uCount));
  float n=noise(cell);
  mask=uAmount<=0.0?1.0:(uAmount>=1.0?0.0:smoothstep(uAmount-.015,uAmount+.015,n));
 } else if(uMode<5.5) { // Offset, seamless wrap.
  q=fract(uv-uCenter+.5);
 } else if(uMode<6.5) { // Invert below, keep premultiplication.
 } else { // Wave warp: phase is angle, count is frequency.
  q.x+=sin(uv.y*2.0*PI*uCount+uAngle)*uAmount;
  q.y+=sin(uv.x*2.0*PI*uCount+uAngle)*uAmount*uRadius;
 }
 // Mirror sampling avoids black borders when distorted beyond the image.
 if(uMode<5.0 || uMode>6.5) q=1.0-abs(mod(q,2.0)-1.0);
 q=clamp(q,.5/uSize,1.0-.5/uSize);
 #if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
 if(uFilter>.5) q.y=1.0-q.y;
 #endif
 vec4 color=texture(uImage,q);
 if(uMode>5.5 && uMode<6.5) color.rgb=mix(color.rgb,vec3(color.a)-color.rgb,clamp(uAmount,0.0,1.0));
 fragColor=color*mask;
}
