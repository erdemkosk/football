shader_type spatial;
render_mode diffuse_burley, cull_disabled;
#include "res://shaders/color_space.gdshaderinc"
#include "res://shaders/crowd_motion.gdshaderinc"
uniform sampler2D home_badge : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D away_badge : source_color, filter_linear_mipmap, repeat_disable;
void fragment(){
 float away=step(.5,supporter.y);
 vec3 main=mix(home_color.rgb,away_color.rgb,away);
 vec3 accent=mix(home_accent.rgb,away_accent.rgb,away);
 vec2 uv=vec2((prop_position.x-.27)/1.35,1.0-(prop_position.y-2.17)/.88);
 float stripe=step(.34,uv.x)*step(uv.x,.66);
 vec3 cloth=palette_color(mix(main,accent,stripe));
 // Match the actual club crest used on the shirts and menus.
 vec2 crest_uv=(uv-.5)*vec2(2.9,1.9)+.5;
 vec4 crest=mix(texture(home_badge,crest_uv),texture(away_badge,crest_uv),away);
 float inside=step(0.0,crest_uv.x)*step(crest_uv.x,1.0)*step(0.0,crest_uv.y)*step(crest_uv.y,1.0);
 cloth=mix(cloth,crest.rgb,crest.a*inside);
 bool pole=prop_position.x<.269 || prop_position.y<2.16;
 ALBEDO=pole ? vec3(.34,.31,.25) : cloth;
 ROUGHNESS=.94;
 SPECULAR=.08;
}
