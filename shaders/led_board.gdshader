shader_type spatial;
render_mode unshaded;
#include "res://shaders/color_space.gdshaderinc"
uniform sampler2D art : source_color,filter_linear_mipmap,repeat_enable;
uniform float phase=0.0;
uniform sampler2D goal_art : source_color,filter_linear_mipmap,repeat_enable;
uniform float goal_amount=0.0;
uniform vec4 goal_primary : source_color=vec4(.1,.3,.3,1);
uniform vec4 goal_accent : source_color=vec4(1,.85,.5,1);
uniform float event_age=0.0;
void fragment() {
	vec2 at=vec2(fract(UV.x*.25+phase+TIME*.006),UV.y);
	vec3 color=texture(art,at).rgb;
	float pixels=sin(UV.y*128.0*3.14159)*.035;
	ALBEDO=palette_color(color)*(0.88+pixels);
	float slash=1.0-smoothstep(.20,.24,fract(UV.x*7.0-UV.y*.65-event_age*.65+phase));
	vec3 celebration=mix(goal_primary.rgb*.65,goal_accent.rgb,slash*.45);
	float letters=texture(goal_art,vec2(fract(UV.x-event_age*.09+phase),UV.y)).a;
	celebration=mix(celebration,vec3(1.0,.97,.88),letters);
	ALBEDO=mix(ALBEDO,celebration*(.92+pixels),goal_amount);
	EMISSION=celebration*goal_amount*.22;
}
