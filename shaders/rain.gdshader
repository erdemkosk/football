shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, world_vertex_coords, depth_draw_never;
#include "res://shaders/color_space.gdshaderinc"
uniform float clock = 0.0;
uniform float intensity = 0.0;
varying float visibility;
void vertex() {
 vec3 origin = MODEL_MATRIX[3].xyz;
 float speed = mix(16.0,23.0,INSTANCE_CUSTOM.r);
 float height = 18.0-mod(origin.y+clock*speed,18.0);
 float wind = 0.085+sin(clock*0.7)*0.018;
 vec3 fall = normalize(vec3(wind,-1.0,0.025));
 vec3 center = vec3(origin.x+(18.0-height)*wind,height,origin.z+(18.0-height)*0.025);
 vec3 eye = CAMERA_POSITION_WORLD-center;
 vec3 across = normalize(cross(fall,normalize(eye))+vec3(0.0001,0.0,0.0));
 float streak = mix(0.18,0.38,INSTANCE_CUSTOM.g);
 float width = mix(0.014,0.026,INSTANCE_CUSTOM.b);
 VERTEX = center+across*(UV.x-0.5)*width+fall*(UV.y-0.5)*streak;
 // Fade near the camera and at either end of the falling volume.
 visibility = smoothstep(8.0,24.0,length(eye))*smoothstep(0.2,0.9,height);
 visibility *= 1.0-smoothstep(16.5,18.0,height);
 visibility *= mix(0.65,1.0,INSTANCE_CUSTOM.a);
}
void fragment() {
 float edge = 1.0-smoothstep(0.10,0.50,abs(UV.x-0.5));
 float tip = smoothstep(0.0,0.20,UV.y)*(1.0-smoothstep(0.65,1.0,UV.y));
 ALBEDO = palette_color(vec3(0.68,0.77,0.81));
 ALPHA = edge*tip*visibility*mix(0.14,0.23,intensity);
}
