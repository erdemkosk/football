shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/color_space.gdshaderinc"
uniform vec2 grid_count=vec2(38.0,14.0);
void fragment(){
 vec2 grid=abs(fract(UV*grid_count)-0.5);
 if(max(grid.x,grid.y)<0.458) discard;
 ALBEDO=palette_color(vec3(0.77,0.82,0.76));
 ROUGHNESS=0.86;
}
