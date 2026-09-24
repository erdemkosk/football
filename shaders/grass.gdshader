shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/color_space.gdshaderinc"
varying vec3 world_pos;
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
// Gradient noise has no flat cell centres. Its analytic derivative shares
// the four corner samples used by wetness and filters the fine surface slope.
uint wet_bits(ivec2 cell) {
 uvec2 q=uvec2(cell);
 uint h=q.x*1597334677u ^ q.y*3812015801u;
 h=(h^(h>>16u))*2246822519u;
 h=h^(h>>13u);
 return h;
}
float wet_hash(ivec2 cell) {
 return float(wet_bits(cell)&0x00ffffffu)/16777215.0;
}
vec2 wet_gradient(ivec2 cell) {
 uint h=wet_bits(cell);
 vec2 g=(h&1u)==0u ? vec2(.9238795,.3826834) : vec2(.3826834,.9238795);
 g.x=(h&2u)==0u ? g.x : -g.x;
 g.y=(h&4u)==0u ? g.y : -g.y;
 return g;
}
vec3 wet_noise(vec2 point) {
 ivec2 cell=ivec2(floor(point));
 vec2 f=fract(point);
 vec2 u=f*f*f*(f*(f*6.0-15.0)+10.0);
 vec2 du=30.0*f*f*(f-1.0)*(f-1.0);
 vec2 ga=wet_gradient(cell), gb=wet_gradient(cell+ivec2(1,0));
 vec2 gc=wet_gradient(cell+ivec2(0,1)), gd=wet_gradient(cell+ivec2(1,1));
 float a=dot(ga,f), b=dot(gb,f-vec2(1,0));
 float c=dot(gc,f-vec2(0,1)), d=dot(gd,f-vec2(1,1));
 float value=mix(mix(a,b,u.x),mix(c,d,u.x),u.y);
 vec2 gradient=mix(mix(ga,gb,u.x),mix(gc,gd,u.x),u.y);
 gradient+=du*vec2(mix(b-a,d-c,u.y),mix(c-a,d-b,u.x));
 return vec3(.5+value*.65,gradient*.65);
}
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
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
 // Boot traffic exposes earth through the centre of each six-yard box.
 float goalmouth=exp(-pow(p.x/4.3,2.0)-pow((abs(p.y)-48.0)/2.7,2.0));
 float scars=smoothstep(.32,.75,noise(p*2.7)*.6+noise(p*8.0)*.4);
 wear+=goalmouth*(.28+play_wear*.30)*scars;
 vec3 turf=mix(grass,vec3(0.15,0.16,0.095),wear);
 turf=mix(turf,vec3(0.138,0.132,0.072),play_wear*0.22);
 turf=mix(turf,vec3(.23,.185,.105),goalmouth*scars*(.18+play_wear*.23));
 float roughness=.96+grain*.3;
 float specular=0.0;
 if(wetness>0.0) {
  vec3 broad=wet_noise(p*.21+vec2(7.7,-19.0));
  vec2 rotated=vec2(p.x*.8+p.y*.6,-p.x*.6+p.y*.8);
  vec3 broken=wet_noise(rotated*.95+broad.yz*.35);
  float damp=wetness*(.72+.28*broad.x);
  // A water film darkens living grass gently; pooled water keeps the turf
  // beneath it visible instead of painting opaque blue/black camouflage.
  turf*=1.0-damp*.105;
  float exposed=mud*smoothstep(.28,.80,broken.x)*(.22+play_wear*.16);
  turf=mix(turf,vec3(.115,.111,.069),exposed);
  float pool=smoothstep(.52,.72,broad.x*.60+broken.x*.40);
  pool*=smoothstep(.12,.80,mud)*smoothstep(.55,1.0,wetness);
  roughness=mix(roughness,.67+broken.x*.10,damp);
  roughness=mix(roughness,.48,pool);
  specular=wetness*mix(.23,.32,pool);
  // Filter blade-scale slopes with the pixel footprint so the distant
  // playing surface stays calm as the camera moves.
  vec2 slope=broad.yz*.006*damp;
  float blade_detail=1.0-smoothstep(.22,.55,footprint*30.0);
  if(blade_detail>0.0) {
   vec3 blades=wet_noise(rotated*vec2(30.0,7.0));
   vec2 blade_slope=vec2(blades.y*.8-blades.z*.6,blades.y*.6+blades.z*.8);
   slope+=blade_slope*.028*blade_detail*damp*(1.0-pool*.85);
  }
  if(pool>.01 && rain>.01 && detail>.01) {
   vec2 cell=floor(p*2.3);
   float seed=wet_hash(ivec2(cell));
   vec2 impact=vec2(wet_hash(ivec2(cell)+ivec2(13,7)),wet_hash(ivec2(cell)+ivec2(3,29)))*.30+.35;
   float age=fract(weather_clock*mix(1.1,1.7,seed)+seed);
   vec2 offset=fract(p*2.3)-impact;
   float radius=length(offset);
   float ring=1.0-smoothstep(.018,.075,abs(radius-age*.27));
   float ripple=sin((radius-age*.27)*95.0)*ring*age*(1.0-age);
   slope+=offset/max(radius,.01)*ripple*.06*rain*pool*detail;
  }
  vec3 world_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
  world_normal=normalize(world_normal+vec3(-slope.x,0.0,-slope.y)*max(world_normal.y,0.0));
  NORMAL=normalize((VIEW_MATRIX*vec4(world_normal,0.0)).xyz);
 }
 ALBEDO=palette_color(turf);
 ROUGHNESS=clamp(roughness,.48,1.0);
 SPECULAR=specular;
}
