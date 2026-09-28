shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/color_space.gdshaderinc"
#include "res://shaders/crowd_motion.gdshaderinc"
void fragment(){
 vec3 fabric=COLOR.rgb;
 if(club_cloth) {
  float away=step(.5,supporter.y);
  vec3 main=mix(home_color.rgb,away_color.rgb,away);
  vec3 accent=mix(home_accent.rgb,away_accent.rgb,away);
  float family=fract(supporter.x*7.13+supporter.y*11.71);
  vec3 club=mix(main,accent,step(.72,family));
  fabric=mix(club*(.76+family*.24),fabric,step(.66,supporter.x));
 }
 ALBEDO=palette_color(fabric);
 ROUGHNESS=0.98;
 SPECULAR=0.08;
}
