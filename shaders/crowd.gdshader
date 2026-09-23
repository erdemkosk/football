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
  vec3 club=mix(main,accent,step(.70,supporter.x));
  fabric=mix(club*(.72+supporter.x*.20),fabric,step(.91,supporter.x));
 }
 ALBEDO=palette_color(fabric);
 ROUGHNESS=0.98;
 SPECULAR=0.08;
}
