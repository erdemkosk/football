extends Button
## Real squad identity and condition, with the same actions for mouse and controller.
var frontend
var portrait_key := ""
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
	if width>=50:
		var graphics=preload("res://scripts/kit_graphics.gd")
		canvas.draw_texture_rect(graphics.badge(kit.get("club_id",0),kit.get("badge_primary",kit.primary),kit.get("badge_accent",kit.accent)),Rect2(at+Vector2(.08,-.24)*width,Vector2(.12,.14)*width),false)
	var value := str(number)
	var length := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	canvas.draw_string(font,at+Vector2(-length*.5,width*.25),value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,kit.accent)

func portrait(rect: Rect2) -> void:
	var tint: Color=frontend.ROLE_COLORS[data.group]
	draw_circle(rect.get_center(),rect.size.x*.43,Color(tint,.24))
	var photo: Texture2D=frontend.portraits.cache.get(portrait_key)
	if photo!=null: draw_texture_rect(photo,rect,false,Color.WHITE if eligible else Color(1,1,1,.45))
	else: shirt(self,rect.get_center()+Vector2(0,3),rect.size.x*.7,data.kit,data.shirt,strong)

func _draw() -> void:
	if data.is_empty() or face==null: return
	var highlighted := active or drop_hot
	var background := Color("f0eee1").lerp(Color("ffffff"),hover_mix*.55)
	if highlighted: background=Color("f3dfaa")
	if not eligible: background=Color("cad3cb")
	var edge := Color("edd087") if highlighted else Color("a7bcb0")
	if has_focus(): edge=Color("f7e4a9")
	panel(Rect2(Vector2(0,4),size),Color(0,0,0,.18))
	panel(Rect2(Vector2.ZERO,size),background,edge,3 if highlighted or has_focus() else 1)
	var ink := Color("16352f") if eligible else Color("64776e")
	var muted := Color("577265")
	var energy: float=data.energy
	var tint := Color("357558") if energy>.5 else (Color("a57829") if energy>.25 else Color("b4513e"))
	var status: String=data.get("status","")
	if kind=="slot":
		portrait(Rect2(size.x/2-28,1,56,56))
		var role_color: Color=frontend.ROLE_COLORS[data.group]
		panel(Rect2(5,4,31,16),Color(role_color,.5))
		label_at(data.role,Vector2(8,15),9,role_color.darkened(.58),true)
		label_at("%02d" % data.shirt,Vector2(8,34),13,ink,true)
		label_at(str(data.get("ovr","")),Vector2(size.x-28,34),16,Color("2d6b4a"),true)
		if data.get("dismissed",false): draw_rect(Rect2(size.x-15,9,7,11),Color("c6433e"))
		elif data.get("yellow",0)>0: draw_rect(Rect2(size.x-15,9,7,11),Color("bd962e"))
		var px := 13 if str(data.name).length()<10 else 10
		middle(data.name,Vector2(size.x/2,67),px,ink)
		middle(status if status!="" else data.position_label,Vector2(size.x/2,79),8,muted)
		draw_line(Vector2(10,size.y-4),Vector2(size.x-10,size.y-4),Color("c3cdbf"),2,true)
		draw_line(Vector2(10,size.y-4),Vector2(10+(size.x-20)*maxf(.01,energy),size.y-4),tint,2,true)
		if active:
			draw_circle(Vector2(size.x-12,36),4,Color("397355"))
	else:
		portrait(Rect2(5,3,57,57))
		label_at(data.name,Vector2(66,24),13 if str(data.name).length()<10 else 11,ink,true,size.x-70)
		label_at(data.position_label,Vector2(67,41),9,muted,true)
		label_at("#%02d" % data.shirt,Vector2(67,55),10,muted)
		label_at(str(data.get("ovr","")),Vector2(size.x-36,28),21,Color("2d6b4a"),true)
		label_at(status if status!="" else ("HAZIR" if eligible else data.get("unavailable","SEÇİLEMİYOR")),Vector2(12,71),9,muted,true)
		label_at("%d%%" % roundi(energy*100),Vector2(size.x-40,71),10,tint,true)
		draw_line(Vector2(12,82),Vector2(size.x-12,82),Color("c3cdbf"),3,true)
		draw_line(Vector2(12,82),Vector2(12+(size.x-24)*maxf(.01,energy),82),tint,3,true)

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
