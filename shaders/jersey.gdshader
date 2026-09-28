shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/color_space.gdshaderinc"
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 bend = vec3(0.0);
uniform mat3 waist_unbend = mat3(1.0);
uniform bool skeletal_waist = false;
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
	// The shoulders follow the chest; the waist stays near the pelvis. Distribute
	// the turn through the shirt instead of rotating the torso like a solid tube.
	// Atlas Y retains the rest height after shoulder skinning. Cuffs end above
	// .64, so moving an arm down cannot accidentally bend its sleeve at the waist.
	float hem = smoothstep(.64,1.0,UV.y)*.82;
	vec3 waist = vec3(0.0,.28,0.0);
	if(!skeletal_waist) {
	 VERTEX = mix(VERTEX,waist_unbend*(VERTEX+waist)-waist,hem);
	 NORMAL = normalize(mix(NORMAL,waist_unbend*NORMAL,hem));
	}
	VERTEX.z += sin(VERTEX.y*24.0)*abs(bend.x)*hem*.006;
}
void fragment() {
	vec3 cloth = texture(albedo_tex, UV).rgb * albedo.rgb;
	vec2 patch_uv=UV*vec2(19.0,9.0)+vec2(soil_seed,soil_seed*.37);
	float patch=dirt_noise(patch_uv)*.72+dirt_noise(patch_uv*4.7)*.28;
	float zone=garment==0 ? smoothstep(.40,.93,UV.y) : (garment==1 ? .4+.6*UV.y : .85);
	float dirt=smoothstep(1.0-soil*.95,1.04,patch)*zone;
	vec3 soil_color=vec3(.22,.145,.072);
	cloth=mix(cloth,garment==3 ? palette_color(soil_color) : soil_color,dirt*.88);
	// Filter the weave out at match distance to avoid crawling/moiré on shirts.
	vec2 weave_uv=UV*(garment==2 ? vec2(72.0,95.0) : vec2(150.0,110.0));
	float weave_filter=1.0-smoothstep(.18,.6,max(length(dFdx(weave_uv)),length(dFdy(weave_uv))));
	float weave=sin(weave_uv.x*6.283185)*sin(weave_uv.y*6.283185)*weave_filter;
	float fabric=garment<3 ? 1.0 : 0.0;
	cloth*=1.0+weave*.045*fabric;
	// Broad tension folds survive close-ups; fine sock ribbing fades with
	// distance. Surface gradients also work on the rigidly batched limbs.
	float close_detail=1.0-smoothstep(5.0,17.0,length(VERTEX));
	float fold_zone=smoothstep(.40,.86,UV.y);
	// Three broad gathers follow the waist. Turning the torso tilts them;
	// compression adds two short diagonal creases instead of repeated ribs.
	float side=sin((UV.x-.25)*6.283185);
	float lean=clamp(bend.z*1.8,-.8,.8);
	float tension=clamp(length(bend.xz)*1.6,0.0,1.0);
	float gather=sin(UV.x*18.84956+UV.y*(2.0+lean*4.0)+sin(UV.x*6.283185)*.7);
	float diagonal=sin((UV.y+side*(.10+lean*.08))*12.56637);
	float fold=gather*fold_zone*.55+diagonal*tension*smoothstep(.48,.82,UV.y)*(1.0-smoothstep(.84,1.0,UV.y))*.65;
	float rib=sin(UV.x*150.796);
	float height=(garment==2 ? rib*.00045*weave_filter : fold*.0014)*fabric*close_detail;
	vec3 dpdx=dFdx(VERTEX), dpdy=dFdy(VERTEX);
	vec3 across=cross(dpdy,NORMAL), along=cross(NORMAL,dpdx);
	float determinant=dot(dpdx,across);
	vec3 gradient=sign(determinant)*(dFdx(height)*across+dFdy(height)*along)/max(abs(determinant),.000001);
	NORMAL=normalize(NORMAL-gradient);
	cloth*=1.0+fold*.012*fabric*close_detail;
	float damp=wetness*(.75+.25*patch);
	cloth*=1.0-damp*.11;
	// Skin uses the same source_color conversion as StandardMaterial3D on the
	// face/arms. Converting it a second time made bare knees dark red.
	ALBEDO = garment==3 ? cloth : palette_color(cloth);
	// A restrained fabric rim separates the shoulders/legs in the match view.
	// Keep team pigments in shadow, without turning skin or wet kits luminous.
	RIM = .16*fabric;
	RIM_TINT = .72;
	EMISSION = palette_color(cloth)*.025*fabric;
	float dry_roughness=garment==1 ? .91 : (garment==2 ? .96 : .86);
	ROUGHNESS = clamp(mix(dry_roughness,garment==3 ? .70 : .60,damp)+weave*.025*fabric,.55,.98);
	SPECULAR = mix(garment==2 ? .16 : .23,.32,damp);
}
