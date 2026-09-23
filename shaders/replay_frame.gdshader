shader_type canvas_item;
render_mode unshaded;
uniform vec2 frame_size = vec2(1440.0,900.0);
uniform float bar_height = 45.0;
uniform float grain_frame = 0.0;
uniform float transition = 0.0;
uniform float replay_amount = 1.0;
float grain(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233))+grain_frame*3.17)*43758.5453); }
void fragment() {
	vec2 pixel=UV*frame_size;
	float border=1.0-step(bar_height,min(pixel.y,frame_size.y-pixel.y));
	float vignette=smoothstep(.35,.82,length((UV-.5)*vec2(1.0,.8)))*.035;
	COLOR=vec4(.015,.025,.029,vignette);
	COLOR=mix(COLOR,vec4(.015,.025,.029,1.0),border);
	COLOR.a*=replay_amount;
	COLOR=mix(COLOR,vec4(.015,.025,.029,1.0),transition);
}
