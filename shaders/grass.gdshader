shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/color_space.gdshaderinc"
varying vec3 world_pos;
uniform float wetness = 0.0;
uniform float weather_clock = 0.0;
uniform float rain = 0.0;
uniform float play_wear = 0.0;
float patch(vec2 p,vec4 area) { return 1.0-smoothstep(0.3,1.0,length((p-area.xy)/area.zw)); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
uniform vec2 half_pitch = vec2(36.0, 50.0);
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 // Broad, low-contrast mowing bands; no hard edge or subpixel normal noise.
 float stripe=smoothstep(-0.16,0.16,sin((p.y+50.0)*0.376991));
 if(abs(p.x)>half_pitch.x || abs(p.y)>half_pitch.y) stripe=0.35;
 vec3 grass=mix(vec3(0.116,0.213,0.133),vec3(0.128,0.231,0.146),stripe);
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 float detail=1.0-smoothstep(0.06,0.15,footprint);
 float grain=(noise(p*5.0)-0.5)*0.018*detail;
 float natural=(noise(p*0.42)-0.5)*0.018;
 grass*=1.0+grain+natural;
 float wear=exp(-length(p*vec2(0.22,0.14)))*(0.035+play_wear*0.10);
 wear+=exp(-length((abs(p)-vec2(0.0,47.0))*vec2(0.35,0.48)))*(0.065+play_wear*0.14);
 wear+=play_wear*0.08*(0.45+noise(p*0.55)*0.55);
 float mud=max(max(patch(p,vec4(0,-47,8,5)),patch(p,vec4(0,47,8,5))),patch(p,vec4(0,0,7,5)));
 mud=max(mud,max(max(patch(p,vec4(-23,-17,6,10)),patch(p,vec4(22,20,7,9))),patch(p,vec4(9,-31,5,6))));
 if(abs(p.x)>half_pitch.x || abs(p.y)>half_pitch.y) mud=0.0;
 mud*=smoothstep(0.25,0.95,wetness);
 float broken=smoothstep(0.18,0.78,noise(p*1.15)*0.7+noise(p*3.0)*0.3);
 float puddle=smoothstep(0.58,0.86,noise(p*0.75))*mud;
 vec3 turf=mix(grass,vec3(0.15,0.16,0.095),wear)*(1.0-wetness*0.10);
 turf=mix(turf,vec3(0.138,0.132,0.072),play_wear*0.22*(1.0-wetness*0.35));
 turf=mix(turf,vec3(0.125,0.102,0.059),mud*broken*0.78);
 vec2 cell=floor(p*1.6);
 float phase=fract(weather_clock*1.7+hash(cell));
 float ring=1.0-smoothstep(0.015,0.05,abs(length(fract(p*1.6)-0.5)-phase*0.55));
 vec3 water=vec3(0.12,0.16,0.16)+ring*(1.0-phase)*rain*0.045;
 ALBEDO=palette_color(mix(turf,water,puddle*0.65));
 ROUGHNESS=mix(1.0,0.48,wetness)*(1.0-puddle*0.55);
 SPECULAR=wetness*(0.22+puddle*0.22);
}
