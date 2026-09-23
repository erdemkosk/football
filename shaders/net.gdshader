shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/color_space.gdshaderinc"
uniform vec2 grid_count=vec2(38.0,14.0);
void fragment(){
 vec2 cells=UV*grid_count;
 vec2 grid=abs(fract(cells)-0.5);
 vec2 aa=max(fwidth(cells),vec2(.008));
 vec2 thread=smoothstep(vec2(.475)-aa*.6,vec2(.475)+aa*.6,grid);
 ALPHA=max(thread.x,thread.y);
 ALPHA_SCISSOR_THRESHOLD=.30;
 // A darker underside gives individual cords a round, woven appearance.
 float cord=max(grid.x,grid.y);
 ALBEDO=palette_color(mix(vec3(.48,.56,.52),vec3(.91,.92,.84),smoothstep(.474,.495,cord)));
 ROUGHNESS=.78;
}
