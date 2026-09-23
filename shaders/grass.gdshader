shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/color_space.gdshaderinc"
varying vec3 world_pos;
varying vec3 reflected_flood;
uniform float wetness = 0.0;
uniform float weather_clock = 0.0;
uniform float rain = 0.0;
uniform float play_wear = 0.0;
uniform float flood_glint = 0.0;
uniform vec3 flood_positions[4];
float patch(vec2 p,vec4 area) { return 1.0-smoothstep(0.3,1.0,length((p-area.xy)/area.zw)); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
uniform vec2 half_pitch = vec2(36.0, 50.0);
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 // Pick one lamp for the whole surface, using the camera's reflected sightline.
 // This runs per vertex, and cannot produce four competing patches of glare.
 float best=-2.0;
 reflected_flood=flood_positions[0];
 for(int i=0;i<4;i++) {
  vec3 mirror=flood_positions[i]*vec3(1,-1,1);
  float facing=dot(normalize(mirror-CAMERA_POSITION_WORLD),-INV_VIEW_MATRIX[2].xyz);
  if(facing>best) { best=facing; reflected_flood=flood_positions[i]; }
 }
}
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
 // Boot traffic exposes earth through the centre of each six-yard box.
 float goalmouth=exp(-pow(p.x/4.3,2.0)-pow((abs(p.y)-48.0)/2.7,2.0));
 float scars=smoothstep(.32,.75,noise(p*2.7)*.6+noise(p*8.0)*.4);
 wear+=goalmouth*(.28+play_wear*.30)*scars;
 float puddle=smoothstep(0.58,0.86,noise(p*0.75))*mud;
 vec3 turf=mix(grass,vec3(0.15,0.16,0.095),wear)*(1.0-wetness*0.10);
 turf=mix(turf,vec3(0.138,0.132,0.072),play_wear*0.22*(1.0-wetness*0.35));
 turf=mix(turf,vec3(0.125,0.102,0.059),mud*broken*0.78);
 turf=mix(turf,vec3(.23,.185,.105)*(1.0-wetness*.38),goalmouth*scars*(.18+play_wear*.23));
 vec2 cell=floor(p*1.6);
 float phase=fract(weather_clock*1.7+hash(cell));
 float ring=1.0-smoothstep(0.015,0.05,abs(length(fract(p*1.6)-0.5)-phase*0.55));
 vec3 water=vec3(0.12,0.16,0.16)+ring*(1.0-phase)*rain*0.045;
 ALBEDO=palette_color(mix(turf,water,puddle*0.65));
 ROUGHNESS=clamp(mix(.96+grain*.3,.56+broken*.12,wetness)*(1.0-puddle*.62),.18,1.0);
 SPECULAR=wetness*(0.22+puddle*0.22);
 // The strongest reflected lamp produces one broken highlight, not a luminous field.
 float glint=0.0;
 if (flood_glint>0.0 && wetness>0.05) {
  vec3 eye=normalize(CAMERA_POSITION_WORLD-world_pos);
  vec3 ray=normalize(reflected_flood-world_pos);
  float alignment=max(dot(reflect(-ray,vec3(0,1,0)),eye),0.0);
  glint=pow(alignment,220.0);
 }
 float surface_break=mix(.68,.66+.18*sin(p.x*17.0+p.y*9.0)*sin(p.y*29.0),detail);
 EMISSION=vec3(.67,.80,1.0)*glint*surface_break*wetness*wetness*flood_glint*.24;
}
