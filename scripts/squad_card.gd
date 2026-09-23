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
	mouse_entered.connect(func():
		if not frontend.game.controller.using_gamepad and frontend.swap_stage!="confirm": frontend.preview_player(kind,index))
	mouse_exited.connect(func(): drop_hot=false)
	focus_entered.connect(func(): frontend.preview_player(kind,index))
	focus_exited.connect(queue_redraw)
	pressed.connect(func(): frontend.activate_card(kind,index))
	tooltip_text="%s · %s\nSahadan ya da yedekten başla, ikinci oyuncuyu seç ve onayla. Sürükleyerek de değiştirebilirsin." % [data.name,data.role]

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
	var focused := has_focus()
	var accent: Color=Color("d6f77a") if active else (Color("82e5d0") if focused else frontend.ROLE_COLORS[data.group])
	var energy: float=data.energy
	var tint := energy_color(energy)
	var status: String=data.get("status","")
	if kind=="slot":
		# Floating player tokens keep the pitch visible, instead of eleven forms.
		draw_set_transform(Vector2(size.x*.5,58),0,Vector2(1,.24))
		draw_circle(Vector2.ZERO,35,Color(0,0,0,.4))
		draw_set_transform(Vector2.ZERO)
		draw_circle(Vector2(size.x*.5,29),30,Color(accent,.10))
		draw_arc(Vector2(size.x*.5,29),31,0,TAU,40,Color(accent,.8 if focused or active else .25),2,true)
		portrait(Rect2(size.x*.5-34,-5,68,68))
		panel(Rect2(1,12,27,20),Color("081721",.94),Color(accent,.3),1)
		label_at("%02d" % data.shirt,Vector2(5,27),12,LIGHT,true)
		draw_circle(Vector2(size.x-17,25),15,Color("0d252a"))
		middle(str(data.get("ovr","")),Vector2(size.x-17,30),14,accent)
		panel(Rect2(3,62,size.x-6,23),Color("071821",.97),accent if focused or active else Color("33505a"),2 if active else 1)
		var parts: PackedStringArray=str(data.name).split(" ")
		var surname: String=parts[-1] if parts.size()>1 else str(data.name)
		middle(surname,Vector2(size.x*.5,77),11 if surname.length()<13 else 9,LIGHT)
		draw_line(Vector2(12,87),Vector2(size.x-12,87),Color("294550"),2,true)
		draw_line(Vector2(12,87),Vector2(12+(size.x-24)*energy,87),tint,2,true)
		if data.get("dismissed",false): draw_rect(Rect2(size.x-10,43,7,11),Color("f27469"))
		elif data.get("yellow",0)>0: draw_rect(Rect2(size.x-10,43,7,11),Color("e9ce87"))
	else:
		panel(Rect2(Vector2.ZERO,size),Color("1a303a") if focused else Color("11242e"),accent if focused or active else Color("2a414c"),2 if focused or active else 1)
		portrait(Rect2(3,10,64,64))
		label_at(data.name,Vector2(72,25),11,LIGHT,true,size.x-77)
		label_at(data.role,Vector2(73,43),10,accent,true)
		label_at(str(data.get("ovr","")),Vector2(size.x-34,62),25,accent,true)
		label_at(status if status!="" else ("#%02d" % data.shirt if eligible else "KULLANILDI"),Vector2(73,64),9,MUTED)
		draw_line(Vector2(12,83),Vector2(size.x-12,83),Color("294550"),3,true)
		draw_line(Vector2(12,83),Vector2(12+(size.x-24)*energy,83),tint,3,true)

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
