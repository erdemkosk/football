shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/color_space.gdshaderinc"
uniform float crowd_time=0.0;
uniform float danger=0.0;
uniform float danger_team=0.0;
uniform float event_age=100.0;
uniform float event_duration=0.0;
uniform float event_strength=0.0;
uniform float event_team=0.0;
uniform bool event_goal=false;
uniform int event_style=0;
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
 float envelope=0.0;
 if(event_duration>0.0){
  envelope=smoothstep(0.0,0.45,age)*(1.0-smoothstep(max(0.5,event_duration-1.2),event_duration,age));
 }
 float cheer=envelope*event_strength*supporting;
 // Both sections spring up for a shot; the defending end reacts anxiously.
 if(event_style==1) cheer=envelope*event_strength*(0.72+0.28*supporting);
 if(event_style==3) cheer=envelope*event_strength*(1.0-supporting);
 float anticipation=danger*(0.32+0.18*(1.0-step(0.5,abs(fan_team-danger_team))));
 // A single crest travels around the stadium, with rows following each other.
 float distance=fract(INSTANCE_CUSTOM.a-wave_origin+1.0);
 float passage=wave_age-distance*7.2-INSTANCE_CUSTOM.b*0.20;
 float wave=smoothstep(0.0,0.28,passage)*(1.0-smoothstep(0.55,1.05,passage));
 wave*=1.0-fan_team;
 // Small neighbouring groups start their own chants even in quiet play.
 // Different blocks, rows and people keep the entire stand out of sync.
 float block=floor(INSTANCE_CUSTOM.a*40.0)+floor(INSTANCE_CUSTOM.b*4.0)*43.0+fan_team*163.0;
 float block_seed=fract(sin(block*12.9898)*43758.5453);
 float personality=fract(INSTANCE_CUSTOM.r*13.71+INSTANCE_CUSTOM.g*7.19);
 float chant_time=mod(crowd_time*(0.85+block_seed*0.35)+block_seed*29.0,26.0);
 float chorus=smoothstep(0.5,1.5,chant_time)*(1.0-smoothstep(4.8,6.2,chant_time));
 float solo_time=mod(crowd_time*(0.75+INSTANCE_CUSTOM.r*0.55)+phase*5.4,19.0+INSTANCE_CUSTOM.r*13.0);
 float solo=smoothstep(1.0,1.8,solo_time)*(1.0-smoothstep(3.2,4.4,solo_time));
 solo*=step(0.66,personality);
 // Match reactions and the Mexican wave take priority over casual movement.
 float ambient=1.0-clamp(max(envelope*event_strength,wave),0.0,1.0);
 float chant=max(chorus*step(0.24,personality),solo*0.8);
 chant*=ambient*(0.82+personality*0.18);
 float raise=clamp(max(wave,max(chant,max(cheer,anticipation))),0.0,1.0);
 VERTEX+=vec3(UV,UV2.x)*raise;
 float weight=smoothstep(0.18,1.5,VERTEX.y);
 float sway=sin(crowd_time*(0.7+INSTANCE_CUSTOM.r*0.55)+phase);
 VERTEX.x+=(sway*(0.045+personality*0.055)+sin(crowd_time*4.8+phase)*cheer*0.085)*weight;
 VERTEX.z+=cos(crowd_time*(0.6+personality*0.45)+phase)*0.035*weight;
 VERTEX.y+=sin(crowd_time*1.7+phase)*0.012*weight;
 float hopping=max(chorus*step(0.62,personality),solo*step(0.88,personality))*ambient;
 float beat=sin(crowd_time*(7.0+INSTANCE_CUSTOM.r*2.5)+phase);
 VERTEX.y+=pow(max(0.0,beat),2.0)*hopping*(0.17+INSTANCE_CUSTOM.r*0.13);
 VERTEX.y-=max(0.0,-beat)*hopping*0.045*weight;
 // Raised arms pump and clap independently, while the feet stay on the steps.
 float hands=smoothstep(1.45,2.0,VERTEX.y)*smoothstep(0.15,0.23,abs(VERTEX.x));
 float clap=sin(crowd_time*(7.5+INSTANCE_CUSTOM.r)+phase);
 float hand_activity=clamp(cheer+chant+ambient*0.12,0.0,1.0);
 VERTEX.x-=sign(VERTEX.x)*hands*(0.045+0.10*clap)*hand_activity;
 VERTEX.y+=hands*sin(crowd_time*6.0+phase)*0.09*hand_activity;
 if(event_style==1 || event_style==2 || event_style==4){
  float hop=max(0.0,sin(age*(6.0+INSTANCE_CUSTOM.r)+phase));
  VERTEX.y+=hop*hop*cheer*(event_style==2 ? 0.25 : 0.15);
  VERTEX.z-=envelope*0.08*weight;
 }
 if(event_style==3){
  float regret=envelope*supporting;
  VERTEX.z-=regret*0.18*weight;
  VERTEX.y-=regret*0.16*weight;
 }
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
 ALBEDO=palette_color(COLOR.rgb);
 ROUGHNESS=0.98;
 SPECULAR=0.08;
}
