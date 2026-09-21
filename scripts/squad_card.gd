extends Button
## Real squad identity and condition, with the same actions for mouse and controller.
var frontend
var kind := "slot"
var index := 0
var data: Dictionary = {}
var active := false
var eligible := true
var hover_mix := 0.0
var drop_hot := false
const LIGHT := Color("eef4ee")
const MINT := Color("8ee4bd")
const MUTED := Color("90a7aa")
var face: Font
var strong: Font

func _ready() -> void:
	face=frontend.font
	strong=frontend.bold
	for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): frontend.preview_player(kind,index))
	mouse_exited.connect(func(): drop_hot=false)
	focus_entered.connect(func(): frontend.preview_player(kind,index))
	pressed.connect(func(): frontend.select_slot(index) if kind=="slot" else frontend.select_reserve(index))
	tooltip_text="%s · %s\n%s" % [data.name,data.role,"Oyuncuyu seç, ardından yedeği seç. Sürükleyerek de değiştirebilirsin." if kind=="slot" else "Seçili oyuncuyla değiştir veya saha üzerine sürükle."]

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var next := move_toward(hover_mix,1.0 if is_hovered() or has_focus() else 0.0,delta*9)
	if not is_equal_approx(next,hover_mix): hover_mix=next; queue_redraw()

func panel(rect: Rect2,color: Color,border: Color=Color.TRANSPARENT,width: int=1) -> void:
	var style := StyleBoxFlat.new(); style.bg_color=color; style.set_corner_radius_all(7)
	style.border_color=border; style.set_border_width_all(width)
	draw_style_box(style,rect)

func label_at(value: String,at: Vector2,px: int,color: Color=LIGHT,bold: bool=false,max_width: float=-1) -> void:
	draw_string(strong if bold else face,at,value,HORIZONTAL_ALIGNMENT_LEFT,max_width,px,color)

func middle(value: String,at: Vector2,px: int,color: Color=LIGHT) -> void:
	var width := strong.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	label_at(value,at-Vector2(width/2,0),px,color,true)

static func energy_color(value: float) -> Color:
	return Color("8ee4bd") if value>0.5 else (Color("efcb78") if value>0.25 else Color("f28172"))

static func shirt(canvas: CanvasItem,at: Vector2,width: float,kit: Dictionary,number: int,font: Font) -> void:
	var shape := PackedVector2Array([Vector2(-.24,-.43),Vector2(-.5,-.23),Vector2(-.35,-.03),Vector2(-.25,-.12),Vector2(-.25,.47),Vector2(.25,.47),Vector2(.25,-.12),Vector2(.35,-.03),Vector2(.5,-.23),Vector2(.24,-.43),Vector2(.10,-.35),Vector2(-.10,-.35)])
	for i in range(shape.size()): shape[i]=at+shape[i]*width
	var shadow := shape.duplicate()
	for i in range(shadow.size()): shadow[i]+=Vector2(0,3)
	canvas.draw_colored_polygon(shadow,Color(0,0,0,0.25))
	canvas.draw_colored_polygon(shape,kit.primary)
	canvas.draw_polyline(shape+PackedVector2Array([shape[0]]),Color(kit.primary.lightened(0.22),0.8),1,true)
	canvas.draw_line(at+Vector2(-.17,-.38)*width,at+Vector2(0,-.28)*width,kit.accent,2,true)
	canvas.draw_line(at+Vector2(.17,-.38)*width,at+Vector2(0,-.28)*width,kit.accent,2,true)
	if int(kit.pattern)==1:
		canvas.draw_rect(Rect2(at+Vector2(-.05,-.24)*width,Vector2(.1,.64)*width),Color(kit.accent,0.30))
	else:
		canvas.draw_line(at+Vector2(-.23,-.13)*width,at+Vector2(.23,-.13 if int(kit.pattern)==0 else .08)*width,Color(kit.accent,0.6),width*.075,true)
	var px := int(width*.27)
	var value := str(number)
	var length := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	canvas.draw_string(font,at+Vector2(-length*.5,width*.25),value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,kit.accent)

func _draw() -> void:
	if data.is_empty() or face==null: return
	var background := Color("102930").lerp(Color("24464b"),hover_mix*.8)
	var edge := MINT if active or drop_hot else Color("335051")
	if has_focus(): edge=LIGHT
	panel(Rect2(Vector2(0,3),size),Color(0,0,0,0.2))
	panel(Rect2(Vector2.ZERO,size),background,edge,2 if active or has_focus() or drop_hot else 1)
	var ink := LIGHT if eligible else MUTED
	var energy: float=data.energy
	var tint := energy_color(energy)
	var status: String=data.get("status","")
	if kind=="slot":
		label_at(status if status!="" else data.role,Vector2(8,13),8,MINT if active else MUTED,true)
		label_at("%d%%" % roundi(energy*100),Vector2(size.x-33,13),9,tint,true)
		shirt(self,Vector2(size.x/2,32),35,data.kit,data.shirt,strong)
		var px := 12 if str(data.name).length()<10 else 10
		middle(data.name,Vector2(size.x/2,62),px,ink)
		draw_line(Vector2(12,size.y-7),Vector2(size.x-12,size.y-7),Color("354d4e"),3,true)
		draw_line(Vector2(12,size.y-7),Vector2(12+(size.x-24)*maxf(.01,energy),size.y-7),tint,3,true)
	else:
		shirt(self,Vector2(28,31),38,data.kit,data.shirt,strong)
		label_at(data.name,Vector2(55,26),14,ink,true,size.x-62)
		label_at(data.role,Vector2(55,44),10,MUTED)
		label_at(status if status!="" else ("HAZIR" if eligible else data.get("unavailable","SEÇİLEMİYOR")),Vector2(13,67),9,MINT if eligible else MUTED,true)
		label_at("%d%%" % roundi(energy*100),Vector2(size.x-40,67),10,tint,true)
		draw_line(Vector2(13,80),Vector2(size.x-13,80),Color("354d4e"),3,true)
		draw_line(Vector2(13,80),Vector2(13+(size.x-26)*maxf(.01,energy),80),tint,3,true)
	if data.get("dismissed",false): draw_rect(Rect2(size.x-16,21,8,12),Color("f07972"))
	elif data.get("yellow",0)>0: draw_rect(Rect2(size.x-16,21,8,12),Color("efcb78"))

func _get_drag_data(_at: Vector2) -> Variant:
	var preview := PanelContainer.new()
	var style := StyleBoxFlat.new(); style.bg_color=Color("21443f"); style.border_color=MINT; style.set_border_width_all(2); style.set_corner_radius_all(6)
	style.content_margin_left=16; style.content_margin_right=16; style.content_margin_top=12; style.content_margin_bottom=12
	preview.add_theme_stylebox_override("panel",style)
	var title := Label.new(); title.text="%02d  %s" % [data.shirt,data.name]; title.add_theme_font_override("font",strong)
	preview.add_child(title)
	set_drag_preview(preview)
	return {"squad":frontend.get_instance_id(),"kind":kind,"index":index}

func _can_drop_data(_at: Vector2,value: Variant) -> bool:
	drop_hot=frontend.can_drop_player(value,kind,index)
	queue_redraw()
	return drop_hot

func _drop_data(_at: Vector2,value: Variant) -> void:
	drop_hot=false
	frontend.drop_player(value,kind,index)
