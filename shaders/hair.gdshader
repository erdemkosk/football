shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/color_space.gdshaderinc"
uniform vec4 pigment : source_color = vec4(.12,.09,.06,1.0);
uniform float roughness : hint_range(0.0,1.0) = .78;
void fragment() {
 // Uneven strand groups avoid the regular corduroy bands of a single sine.
 float flow=sin(UV.x*37.7+sin(UV.y*13.0))*1.3+sin(UV.y*19.0+UV.x*11.0)*.7;
 vec2 strands=vec2(UV.x*92.0+flow,UV.y*18.0);
 float detail=1.0-smoothstep(.25,.8,max(length(dFdx(strands)),length(dFdy(strands))));
 float groove=sin(strands.x*6.283185)*detail;
 float locks=sin(UV.x*75.398+UV.y*5.0+flow*.8)*sin(UV.y*7.0+UV.x*19.0);
 float surface=groove*.000055+locks*.00012;
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
 vec3 across=cross(dy,NORMAL),along=cross(NORMAL,dx);
 float determinant=dot(dx,across);
 vec3 gradient=sign(determinant)*(dFdx(surface)*across+dFdy(surface)*along)/max(abs(determinant),.000001);
 NORMAL=normalize(NORMAL-gradient);
 float roots=mix(1.0,.94,smoothstep(.80,1.0,UV.y));
 ALBEDO=palette_color(pigment.rgb)*COLOR.rgb*roots*(1.0+groove*.025+locks*.018);
 ROUGHNESS=clamp(roughness+groove*.018,.65,.94);
 SPECULAR=.16;
}
