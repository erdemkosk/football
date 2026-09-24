shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://shaders/color_space.gdshaderinc"
uniform float clock = 0.0;
uniform float intensity = 0.0;
void vertex() {
 vec3 origin = MODEL_MATRIX[3].xyz;
 float drop = mod(origin.y + clock * (17.0 + INSTANCE_CUSTOM.r * 7.0), 18.0);
 VERTEX.x += VERTEX.y*0.11;
 VERTEX.y += 18.0 - drop - origin.y;
 VERTEX.x += (18.0-drop)*0.11;
 VERTEX.z += (18.0-drop)*0.035;
}
void fragment() {
 ALBEDO = palette_color(vec3(0.78,0.86,0.90));
 ALPHA = intensity * 0.42;
}
