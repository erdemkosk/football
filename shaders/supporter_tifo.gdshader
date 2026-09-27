shader_type spatial;
render_mode cull_disabled;
uniform vec4 primary : source_color=vec4(.12,.3,.3,1.0);
uniform vec4 accent : source_color=vec4(.9,.9,.8,1.0);
uniform sampler2D crest : source_color,filter_linear_mipmap;
uniform float unfold=0.0;
uniform float cloth_time=0.0;
uniform int pattern=0;
void vertex(){
 VERTEX.y=mix(-6.0,VERTEX.y,unfold);
 VERTEX.z+=sin(VERTEX.x*.8+cloth_time*1.8)*.10*unfold;
 VERTEX.z+=sin(VERTEX.y*1.3-cloth_time*1.2)*.04*unfold;
}
void fragment(){
 float stripe=step(.55,fract(UV.x*9.0));
 if(pattern==1) stripe=step(.5,UV.x);
 if(pattern==2) stripe=step(.35,UV.x+UV.y*.5)*step(UV.x+UV.y*.5,.70);
 if(pattern==3) stripe=step(.5,fract(UV.y*5.0));
 vec3 fabric=mix(primary.rgb,accent.rgb,stripe*.85);
 vec2 badge_uv=(UV-vec2(.5,.42))*vec2(3.7,1.55)+.5;
 vec4 badge=texture(crest,clamp(badge_uv,vec2(0.0),vec2(1.0)));
 float inside=step(0.0,badge_uv.x)*step(badge_uv.x,1.0)*step(0.0,badge_uv.y)*step(badge_uv.y,1.0);
 fabric=mix(fabric,badge.rgb,badge.a*inside);
 float weave=.97+.03*sin(UV.x*1100.0)*sin(UV.y*700.0);
 ALBEDO=fabric*weave; ROUGHNESS=.96; SPECULAR=.12;
}
