shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	float center = max(0.0, 1.0 - abs(UV.y * 2.0 - 1.0));
	float softness = pow(center, 1.6);
	vec3 tint = mix(vec3(1.0, 0.48, 0.12), vec3(1.0, 0.98, 0.85), smoothstep(0.3, 0.9, center));
	ALBEDO = tint;
	EMISSION = tint * 0.65;
	ALPHA = COLOR.a * softness * 0.8;
}
