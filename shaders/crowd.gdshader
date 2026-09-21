shader_type spatial;
render_mode diffuse_burley;
uniform float crowd_time=0.0;
uniform float danger=0.0;
uniform float danger_team=0.0;
uniform float event_age=100.0;
uniform float event_duration=0.0;
uniform float event_strength=0.0;
uniform float event_team=0.0;
uniform bool event_goal=false;
uniform bool event_entrance=false;
uniform float wave_age=100.0;
uniform float wave_origin=0.0;
void vertex(){
 float phase=INSTANCE_CUSTOM.r*6.28318;
 float fan_team=step(0.5,INSTANCE_CUSTOM.g);
 float supporting=1.0-step(0.5,abs(fan_team-event_team));
 if(event_entrance) supporting=1.0;
 float delay=INSTANCE_CUSTOM.r*0.32+INSTANCE_CUSTOM.b*0.14;
 float age=event_age-delay;
 float envelope=smoothstep(0.0,0.45,age)*(1.0-smoothstep(max(0.5,event_duration-1.2),event_duration,age));
 float cheer=envelope*event_strength*supporting;
 float anticipation=danger*(0.32+0.18*(1.0-step(0.5,abs(fan_team-danger_team))));
 // A single crest travels around the stadium, with rows following each other.
 float distance=fract(INSTANCE_CUSTOM.a-wave_origin+1.0);
 float passage=wave_age-distance*7.2-INSTANCE_CUSTOM.b*0.20;
 float wave=smoothstep(0.0,0.28,passage)*(1.0-smoothstep(0.55,1.05,passage));
 wave*=1.0-fan_team;
 float raise=clamp(max(wave,max(cheer,anticipation)),0.0,1.0);
 VERTEX+=vec3(UV,UV2.x)*raise;
 float weight=smoothstep(0.18,1.5,VERTEX.y);
 float sway=sin(crowd_time*(0.7+INSTANCE_CUSTOM.r*0.55)+phase);
 VERTEX.x+=(sway*0.025+sin(crowd_time*4.8+phase)*cheer*0.035)*weight;
 VERTEX.z+=cos(crowd_time*0.8+phase)*0.012*weight;
 // Uneven timing keeps celebrations from looking like synchronized robots.
 float jump=max(0.0,sin(age*(7.0+INSTANCE_CUSTOM.r*2.0)+phase));
 if(event_goal){
  VERTEX.y+=jump*jump*(0.38+INSTANCE_CUSTOM.r*0.14)*cheer;
  VERTEX.x+=sin(age*10.0+phase)*0.10*cheer*weight;
  float disappointment=envelope*(1.0-supporting);
  VERTEX.y-=disappointment*0.12*weight;
  VERTEX.z-=disappointment*0.07*weight;
 }
}
void fragment(){
 ALBEDO=COLOR.rgb;
 ROUGHNESS=0.98;
 SPECULAR=0.08;
}
