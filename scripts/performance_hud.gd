extends Control
## Render-frame samples, independent of physics ticks and the match clock.
var samples := PackedFloat32Array()
var elapsed := 0.0
var frame_count := 0
var fps := 0.0
var frame_ms := 0.0
var font := SystemFont.new()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font.font_names=PackedStringArray(["Avenir Next","DejaVu Sans"])
	visible=false

func _process(delta: float) -> void:
	elapsed+=delta
	frame_count+=1
	if elapsed<0.2: return
	fps=frame_count/maxf(elapsed,0.0001)
	frame_ms=elapsed*1000/frame_count
	samples.append(fps)
	if samples.size()>48: samples.remove_at(0)
	elapsed=0
	frame_count=0
	if visible: queue_redraw()

func _draw() -> void:
	var origin: Vector2=Vector2(1177,110)+get_parent().edge_offset(1,-1)
	var good := Color("a7d9bb") if fps>=55 else (Color("e9ce87") if fps>=30 else Color("f17561"))
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.025,0.07,0.085,0.94)
	style.set_corner_radius_all(5)
	draw_style_box(style,Rect2(origin,Vector2(229,90)))
	draw_string(font,origin+Vector2(12,25),"%3.0f FPS" % fps,HORIZONTAL_ALIGNMENT_LEFT,-1,20,good)
	draw_string(font,origin+Vector2(126,24),"%.1f ms  ·  F" % frame_ms,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("b4c5bd"))
	draw_rect(Rect2(origin+Vector2(12,35),Vector2(205,4)),Color("334944"))
	draw_rect(Rect2(origin+Vector2(12,35),Vector2(205*clampf(fps/120,0,1),4)),good)
	var points := PackedVector2Array()
	for i in range(samples.size()): points.append(origin+Vector2(12+i*205.0/47,78-clampf(samples[i]/120,0,1)*29))
	draw_line(origin+Vector2(12,63.5),origin+Vector2(217,63.5),Color(1,1,1,0.12))
	if points.size()>1: draw_polyline(points,good,1.5,true)
