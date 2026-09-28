// Shared by living turf and painted lines. Colors are authored in sRGB and
// converted once by palette_color, so these uniforms have no source_color hint.
uniform int mow_pattern=0;
uniform vec2 mow_axis=vec2(0.0,1.0);
uniform float mow_width=8.333333;
uniform vec3 turf_dark=vec3(.116,.213,.133);
uniform vec3 turf_light=vec3(.128,.231,.146);
uniform float turf_patchiness=1.0;
uniform float turf_age=1.0;
uniform vec2 turf_offset=vec2(0.0);

float mowing_band(float distance) {
 float phase=distance*3.14159265/max(mow_width,1.0);
 float edge=max(.16,fwidth(phase));
 return smoothstep(-edge,edge,sin(phase));
}

// x is the cut's light/dark band, yz its blade lean in world X/Z coordinates.
vec3 mowing(vec2 ground) {
 float first=mowing_band(dot(ground+vec2(0.0,50.0),mow_axis));
 vec2 lean=mow_axis*(first-.5);
 float stripe=first;
 if(mow_pattern==1) {
  vec2 across=vec2(-mow_axis.y,mow_axis.x);
  float second=mowing_band(dot(ground,across));
  stripe=.5+2.0*(first-.5)*(second-.5);
  lean=(lean+across*(second-.5))*.5;
 }
 return vec3(stripe,lean);
}
