shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float progress=0.0;
uniform int kind=0;
uniform bool reduced_motion=false;
void fragment() {
 vec2 p=UV*2.0-1.0;
 float radius=length(p);
 float age=clamp(progress,0.0,1.0);
 float mask=0.0;
 if(kind==0) {
  float ring=reduced_motion ? .67 : mix(.28,.88,age);
  mask=(1.0-smoothstep(.010,.031,abs(radius-ring)))*pow(1.0-age,1.15);
 } else if(kind==1) {
  float core=exp(-radius*radius*27.0);
  float rays=pow(abs(cos(atan(p.y,p.x)*3.0)),16.0)*(1.0-smoothstep(.12,.86,radius));
  mask=(core*.45+rays*.75)*pow(1.0-age,1.7);
 } else if(kind==2) {
  mask=pow(max(0.0,1.0-abs(p.y)),1.5)*smoothstep(0.0,.28,UV.x)*(1.0-UV.x)*2.0*pow(1.0-age,1.3);
 } else if(kind==3) {
  float ring=mix(.70,.48,age);
  float gaps=smoothstep(.18,.35,abs(sin(atan(p.y,p.x)*3.0)));
  mask=(1.0-smoothstep(.02,.06,abs(radius-ring)))*gaps*(.25+age*.65);
 } else {
  float fade=pow(1.0-age,1.2);
  float angle=atan(p.y,p.x);
  if(kind==4) { // Curled sweep for turns and sole rolls.
   mask=(1.0-smoothstep(.015,.047,abs(radius-.62)))*smoothstep(-2.6,-1.8,angle)*(1.0-smoothstep(1.6,2.4,angle));
  } else if(kind==5) { // Outside / inside S for elastic and cutting touches.
   float curve=sin(p.x*3.4)*.35;
   mask=(1.0-smoothstep(.015,.06,abs(p.y-curve)))*(1.0-smoothstep(.58,.86,abs(p.x)));
  } else if(kind==6) { // Two short angled strokes for a touch into space.
   float stroke=min(abs(p.x-.22-p.y*.32),abs(p.x+.22-p.y*.32));
   mask=(1.0-smoothstep(.012,.05,stroke))*(1.0-smoothstep(.25,.80,abs(p.y)));
  } else { // A rising arch at a lifting boot.
   mask=(1.0-smoothstep(.015,.045,abs(radius-.56)))*smoothstep(-.2,.08,p.y);
  }
  mask*=fade*.8;
 }
 ALBEDO=tint.rgb;
 EMISSION=tint.rgb*.4;
 ALPHA=clamp(mask*tint.a,0.0,.92);
}
