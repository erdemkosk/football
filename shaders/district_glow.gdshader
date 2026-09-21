shader_type spatial;
#include "res://shaders/color_space.gdshaderinc"
uniform float night = 0.0;
void fragment() {
	vec3 lamp = palette_color(COLOR.rgb);
	ALBEDO = mix(palette_color(vec3(0.32,0.43,0.46)),lamp,night);
	EMISSION = lamp * night * 1.8;
	ROUGHNESS = 0.5;
}
