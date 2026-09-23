shader_type spatial;
render_mode diffuse_burley, cull_disabled;
#include "res://shaders/color_space.gdshaderinc"
#include "res://shaders/crowd_motion.gdshaderinc"
uniform sampler2D slogan : filter_linear_mipmap, repeat_disable;
void fragment() {
 float away=step(.5,supporter.y);
 vec3 main=mix(home_color.rgb,away_color.rgb,away);
 vec3 accent=mix(home_accent.rgb,away_accent.rgb,away);
 vec2 uv=vec2(prop_position.x/1.12+.5,1.0-(prop_position.y-1.825)/.48);
 // Fans face local -Z, so local +X is the reader's left on that side.
 if(prop_position.z<-.11) uv.x=1.0-uv.x;
 float border=step(.055,uv.y)*step(uv.y,.945);
 float ink=texture(slogan,uv).r;
 vec3 lettering=mix(vec3(.96),vec3(.025),step(.42,dot(main,vec3(.2126,.7152,.0722))));
 ALBEDO=palette_color(mix(accent,mix(main,lettering,ink),border));
 ROUGHNESS=.95;
 SPECULAR=.08;
}
