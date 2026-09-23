extends Button
var screen
var identity := ""
var on_pitch := false

func _ready() -> void:
	clip_text=true
	for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: add_theme_color_override(state,Color.TRANSPARENT)
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	focus_entered.connect(func():
		if screen!=null: screen.tactics.inspect(screen,identity)
		queue_redraw())
	focus_exited.connect(queue_redraw)
	screen.portraits.portrait_ready.connect(_portrait_ready)

func _portrait_ready(_key: String) -> void:
	queue_redraw()

func _get_drag_data(_position: Vector2) -> Variant:
	if disabled: return null
	var preview:=Label.new(); preview.text=screen.game.career.player(identity).name
	set_drag_preview(preview)
	return {"career_player":identity}

func _can_drop_data(_position: Vector2,data: Variant) -> bool:
	return not disabled and data is Dictionary and data.has("career_player") and data.career_player!=identity and data.career_player in screen.game.career.club().roster

func _drop_data(_position: Vector2,data: Variant) -> void:
	screen.tactics.selected=data.career_player; screen.tactics.choose(screen,identity)

func label(value: String,at: Vector2,points: int,color: Color,width: float=-1) -> void:
	draw_string(screen.bold,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,points,color)

func _draw() -> void:
	if screen==null: return
	var p: Dictionary=screen.tactics.player_info(screen,identity)
	var chosen: bool=screen.tactics.selected==identity
	var focused:=has_focus() or is_hovered()
	var accent: Color=screen.art.BLUE if p.keeper else screen.art.LIME
	if disabled: accent=screen.art.MUTED; p.tactic_status="OYUNA GİRDİ"
	var style:=StyleBoxFlat.new(); style.set_corner_radius_all(8)
	style.bg_color=Color("28484a") if chosen else Color("172d3b")
	style.border_color=accent if chosen or focused else Color("36505e")
	style.set_border_width_all(3 if focused else (2 if chosen else 1))
	if not on_pitch: draw_style_box(style,Rect2(Vector2.ZERO,size))
	var photo: Texture2D=screen.portraits.photo(screen.portrait_data(identity))
	if on_pitch:
		draw_circle(Vector2(size.x*.5,25),29,Color("10202b"))
		draw_arc(Vector2(size.x*.5,25),30,0,TAU,40,accent if chosen or focused else Color("35505c"),3 if focused else 1,true)
		if photo!=null: draw_texture_rect(photo,Rect2(15,-12,62,62),false)
		label(str(screen.World.ovr(p)),Vector2(4,17),12,accent)
		label(screen.World.ROLES[p.role],Vector2(5,34),9,screen.art.MUTED)
		var pill:=StyleBoxFlat.new(); pill.bg_color=Color("081019"); pill.set_corner_radius_all(6)
		draw_style_box(pill,Rect2(1,47,size.x-2,20))
		label(p.name.split(" ")[-1],Vector2(5,61),10,screen.PAPER,size.x-10)
		if p.get("tactic_status","HAZIR")!="HAZIR": draw_circle(Vector2(size.x-9,10),4,Color("edb98e"))
	else:
		if photo!=null: draw_texture_rect(photo,Rect2(0,1,74,74),false)
		label(str(screen.World.ovr(p)),Vector2(size.x-35,25),21,accent)
		label(p.name.split(" ")[-1],Vector2(78,25),12,screen.PAPER,size.x-118)
		label(screen.World.ROLES[p.role]+"  ·  %d YAŞ" % p.age,Vector2(78,44),10,screen.art.MUTED)
		label(p.get("tactic_status","HAZIR"),Vector2(78,63),9,accent if p.get("tactic_status","HAZIR")=="HAZIR" else Color("edb98e"))
	var energy: float=p.fitness
	draw_rect(Rect2(5,size.y-5,size.x-10,3),Color("3a4c58"))
	draw_rect(Rect2(5,size.y-5,(size.x-10)*energy,3),accent if energy>.45 else Color("edb98e"))
