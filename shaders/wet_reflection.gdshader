shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, world_vertex_coords;
#include "res://shaders/color_space.gdshaderinc"
uniform float wetness=0.0;
uniform float clock=0.0;
uniform vec2 half_pitch=vec2(36,50);
varying vec2 ground;
varying float height;
void vertex() {
	// Project an articulated, mirrored silhouette onto the receiving turf.
	// Works in Mobile too; no full-scene reflection pass or depth-test bypass.
	vec3 eye=INV_VIEW_MATRIX[3].xyz;
	height=max(VERTEX.y,0.0);
	if(abs(PROJECTION_MATRIX[3][3])<.5) {
		float t=(eye.y-.022)/max(.1,eye.y+height);
		VERTEX.xz=mix(eye.xz,VERTEX.xz,t);
	} else {
		vec3 view=INV_VIEW_MATRIX[2].xyz;
		VERTEX.xz+=view.xz/max(.15,abs(view.y))*height;
	}
	VERTEX.y=.022;
	ground=VERTEX.xz;
}
void fragment() {
	if(abs(ground.x)>half_pitch.x || abs(ground.y)>half_pitch.y) discard;
	float broken=.78+.22*sin(ground.y*54.0+sin(ground.x*13.0)+clock*.9);
	ALBEDO=palette_color(mix(vec3(.08,.12,.10),COLOR.rgb*.40,.65));
	// Grass breaks up the reflection quickly above the shins. Upper-body
	// mirror silhouettes would make saturated turf look like polished glass.
	ALPHA=smoothstep(.25,.95,wetness)*.065*broken*(1.0-smoothstep(.12,1.35,height));
}
