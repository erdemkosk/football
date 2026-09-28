shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 pigment : source_color = vec4(1.0);
uniform float roughness = .86;
uniform bool vertex_colors = false;
void fragment() {
 // The connected body carries a coverage mask beneath the shirt. Face and
 // hand meshes have opaque vertex alpha, including their individual tints.
 if (COLOR.a < .5) discard;
 vec2 pore_uv=UV*vec2(126.0,104.0);
 float detail=1.0-smoothstep(.22,.7,max(length(dFdx(pore_uv)),length(dFdy(pore_uv))));
 float pores=sin(pore_uv.x*6.283185+sin(pore_uv.y*3.1))*sin(pore_uv.y*6.283185)*detail;
 ALBEDO=pigment.rgb*(vertex_colors ? COLOR.rgb : vec3(1.0))*(1.0+pores*.009);
 ROUGHNESS=clamp(roughness+pores*.032,.67,.94);
 SPECULAR=.19;
}
