shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/color_space.gdshaderinc"
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 bend = vec3(0.0);
uniform float soil : hint_range(0.0,1.0) = 0.0;
uniform float wetness : hint_range(0.0,1.0) = 0.0;
uniform float soil_seed = 0.0;
uniform int garment = 0;
float fleck(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float dirt_noise(vec2 p) {
	vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(fleck(i),fleck(i+vec2(1,0)),f.x),mix(fleck(i+vec2(0,1)),fleck(i+vec2(1)),f.x),f.y);
}
void vertex() {
	// Hem lags the spine so the printed shirt folds instead of rotating as a rigid shell.
	float hem = smoothstep(0.22, -0.26, VERTEX.y);
	VERTEX.z += bend.x * hem * 0.20;
	VERTEX.x += -bend.z * hem * 0.16;
	VERTEX.y += abs(bend.x) * hem * 0.035;
}
void fragment() {
	vec3 cloth = texture(albedo_tex, UV).rgb * albedo.rgb;
	vec2 patch_uv=UV*vec2(19.0,9.0)+vec2(soil_seed,soil_seed*.37);
	float patch=dirt_noise(patch_uv)*.72+dirt_noise(patch_uv*4.7)*.28;
	float zone=garment==0 ? smoothstep(.40,.93,UV.y) : (garment==1 ? .4+.6*UV.y : .85);
	float dirt=smoothstep(1.0-soil*.95,1.04,patch)*zone;
	cloth=mix(cloth,vec3(.22,.145,.072),dirt*.88);
	// Filter the weave out at match distance to avoid crawling/moiré on shirts.
	vec2 weave_uv=UV*vec2(150.0,110.0);
	float weave_filter=1.0-smoothstep(.18,.6,max(length(dFdx(weave_uv)),length(dFdy(weave_uv))));
	float weave=sin(weave_uv.x*6.283185)*sin(weave_uv.y*6.283185)*weave_filter;
	float fabric=garment<3 ? 1.0 : 0.0;
	cloth*=1.0+weave*.045*fabric;
	float damp=wetness*(.75+.25*patch);
	cloth*=1.0-damp*.11;
	ALBEDO = palette_color(cloth);
	ROUGHNESS = clamp(mix(.88,.54,damp)+weave*.045*fabric,.45,.95);
	SPECULAR = mix(.22,.40,damp);
}
