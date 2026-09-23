shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/color_space.gdshaderinc"
uniform float wetness=0.0;
uniform float play_wear=0.0;
varying vec2 ground;
float hash_paint(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float paint_noise(vec2 p){
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash_paint(i),hash_paint(i+vec2(1,0)),f.x),mix(hash_paint(i+vec2(0,1)),hash_paint(i+vec2(1,1)),f.x),f.y);
}
void vertex(){ground=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
 float footprint=max(length(dFdx(ground)),length(dFdy(ground)));
 float detail=1.0-smoothstep(.025,.10,footprint);
 float flecks=paint_noise(ground*32.0);
 float traffic=exp(-pow(ground.x/8.0,2.0)-pow((abs(ground.y)-46.0)/7.0,2.0));
 float wear=(.10+play_wear*(.10+traffic*.16));
 float chips=smoothstep(.57,.85,flecks)*detail*wear;
 // Opaque pigment variation preserves line readability and avoids an alpha pass.
 vec3 paint=mix(vec3(.725,.784,.706),vec3(.16,.25,.12),chips);
 paint*=1.0+(paint_noise(ground*2.0)-.5)*.065-wetness*.065;
 ALBEDO=palette_color(paint);
 ROUGHNESS=mix(.96,.73,wetness);
 SPECULAR=mix(.12,.25,wetness);
}
