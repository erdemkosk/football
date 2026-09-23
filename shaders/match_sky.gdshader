shader_type sky;
render_mode use_half_res_pass;

uniform vec3 horizon : source_color = vec3(0.62, 0.71, 0.73);
uniform vec3 zenith : source_color = vec3(0.26, 0.40, 0.52);
uniform vec3 cloud_light : source_color = vec3(0.89, 0.90, 0.85);
uniform vec3 cloud_shade : source_color = vec3(0.54, 0.62, 0.66);
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform float cloud_clock = 0.0;
uniform float coverage = 0.38;
uniform float sky_brightness = 0.72;

void sky() {
	float height = max(EYEDIR.y, 0.0);
	vec3 gradient = mix(horizon, zenith, pow(height, 0.55))*sky_brightness;
	if (AT_CUBEMAP_PASS) {
		// Lighting stays stable while the two visible cloud decks drift overhead.
		COLOR = gradient;
	} else if (AT_HALF_RES_PASS) {
		vec2 plane = EYEDIR.xz / (height + 0.22);
		vec2 high_uv = plane * vec2(0.20, 0.35) + vec2(cloud_clock * 0.00065, 0.17);
		vec2 low_uv = plane * 0.32 + vec2(-0.31, cloud_clock * 0.0014);
		float high = texture(cloud_noise, high_uv).r;
		float low = texture(cloud_noise, low_uv).r*.72+texture(cloud_noise,low_uv*3.7+vec2(.13,.43)).r*.28;
		float wisps = smoothstep(0.50 - coverage * 0.12, 0.76, high) * 0.36;
		float banks = smoothstep(0.66 - coverage * 0.24, 0.84 - coverage * 0.18, low);
		float clouds = (wisps + banks * (1.0 - wisps)) * smoothstep(0.0, 0.17, height);
		vec3 cloud = mix(cloud_shade, cloud_light, smoothstep(0.48, 0.80, low))*sky_brightness;
		COLOR = mix(gradient, cloud, clouds * 0.74);
		ALPHA = 1.0;
	} else {
		COLOR = HALF_RES_COLOR.rgb;
	}
}
