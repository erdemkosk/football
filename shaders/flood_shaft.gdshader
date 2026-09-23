shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 glow : source_color = vec4(0.82, 0.90, 1.0, 1.0);
uniform float strength = 0.12;
varying float progress;
void vertex() { progress=clamp(VERTEX.y/46.0+0.5,0.0,1.0); }
void fragment() {
	float along = pow(1.0-progress,1.7)*smoothstep(0.0,.05,progress)*(1.0-smoothstep(.65,1.0,progress));
	float rim = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = glow.rgb;
	ALPHA = strength * along * rim;
}
