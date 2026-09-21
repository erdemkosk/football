shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float clock = 0.0;
uniform float lifetime = 180.0;
varying vec4 ink;
varying float born;
varying float is_trail;
varying vec2 ground;
void vertex() { ink=COLOR; born=INSTANCE_CUSTOM.r; is_trail=INSTANCE_CUSTOM.g; ground=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
 vec2 uv=UV*2.0-1.0;
 float edge=1.0-smoothstep(0.65,1.0,length(uv));
 float tread=0.82+0.18*step(0.0,sin(UV.y*40.0));
 if(is_trail>0.5) {
  float ragged=0.88+0.1*sin(ground.x*19.0+sin(ground.y*13.0));
  edge=1.0-smoothstep(0.5,ragged,abs(uv.x));
  tread=0.68+0.1*sin(ground.x*21.0+ground.y*15.0);
 }
 ALBEDO=ink.rgb;
 ALPHA=ink.a*edge*tread*(1.0-smoothstep(lifetime*0.7,lifetime,clock-born));
}
