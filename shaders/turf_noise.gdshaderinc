// Gradient noise has no flat cell centres. Its analytic derivative shares
// the four corner samples used by wetness and filters the fine surface slope.
uint wet_bits(ivec2 cell) {
 uvec2 q=uvec2(cell);
 uint h=q.x*1597334677u ^ q.y*3812015801u;
 h=(h^(h>>16u))*2246822519u;
 h=h^(h>>13u);
 return h;
}
float wet_hash(ivec2 cell) {
 return float(wet_bits(cell)&0x00ffffffu)/16777215.0;
}
vec2 wet_gradient(ivec2 cell) {
 uint h=wet_bits(cell);
 vec2 g=(h&1u)==0u ? vec2(.9238795,.3826834) : vec2(.3826834,.9238795);
 g.x=(h&2u)==0u ? g.x : -g.x;
 g.y=(h&4u)==0u ? g.y : -g.y;
 return g;
}
vec3 wet_noise(vec2 point) {
 ivec2 cell=ivec2(floor(point));
 vec2 f=fract(point);
 vec2 u=f*f*f*(f*(f*6.0-15.0)+10.0);
 vec2 du=30.0*f*f*(f-1.0)*(f-1.0);
 vec2 ga=wet_gradient(cell), gb=wet_gradient(cell+ivec2(1,0));
 vec2 gc=wet_gradient(cell+ivec2(0,1)), gd=wet_gradient(cell+ivec2(1,1));
 float a=dot(ga,f), b=dot(gb,f-vec2(1,0));
 float c=dot(gc,f-vec2(0,1)), d=dot(gd,f-vec2(1,1));
 float value=mix(mix(a,b,u.x),mix(c,d,u.x),u.y);
 vec2 gradient=mix(mix(ga,gb,u.x),mix(gc,gd,u.x),u.y);
 gradient+=du*vec2(mix(b-a,d-c,u.y),mix(c-a,d-b,u.x));
 return vec3(.5+value*.65,gradient*.65);
}
