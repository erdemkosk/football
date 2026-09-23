shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment() {
	float distance=length((UV-.5)*2.0);
	float core=1.0-smoothstep(.10,1.0,distance);
	ALBEDO=vec3(.015,.024,.018);
	ALPHA=core*core*COLOR.a;
}
