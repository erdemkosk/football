shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
#include "res://shaders/color_space.gdshaderinc"
void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	float pool = pow(max(0.0,1.0-radius),2.2);
	ALBEDO = palette_color(COLOR.rgb);
	ALPHA = pool * 0.30;
}
