shader_type spatial;
render_mode unshaded;
#include "res://shaders/color_space.gdshaderinc"
uniform sampler2D art : source_color,filter_linear_mipmap,repeat_enable;
uniform float phase=0.0;
void fragment() {
	vec2 at=vec2(fract(UV.x*.25+phase+TIME*.006),UV.y);
	vec3 color=texture(art,at).rgb;
	float pixels=sin(UV.y*128.0*3.14159)*.035;
	ALBEDO=palette_color(color)*(0.88+pixels);
}
