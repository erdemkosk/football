extends Button
## A real focusable game card; mouse, keyboard and controller share the same state.
var screen
var identity := ""
var kind := "player"
var caption := ""
var detail := ""
var accent := Color("d6f77a")
var emphasis := 0.0

func _ready() -> void:
	clip_contents=true
	for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: add_theme_color_override(state,Color.TRANSPARENT)
	screen.portraits.portrait_ready.connect(func(_key): queue_redraw())

func _process(delta: float) -> void:
	var target:=1.0 if has_focus() or is_hovered() else 0.0
	var before:=emphasis
	emphasis=move_toward(emphasis,target,delta*9)
	if not is_equal_approx(before,emphasis): queue_redraw()

func label(value: String,at: Vector2,points: int,color: Color,font_value: Font=null,width: float=-1) -> void:
	draw_string(screen.bold if font_value==null else font_value,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,points,color)

func _draw() -> void:
	if screen==null: return
	var chosen: bool=identity==screen.selected if kind=="player" else identity==screen.selected_club
	var base:=Color("10202b").lerp(Color("253e48"),emphasis*.8)
	var style:=StyleBoxFlat.new(); style.bg_color=base; style.set_corner_radius_all(16)
	style.set_border_width_all(3 if emphasis>.05 else 1)
	style.border_color=accent.lerp(Color("f5ffe9"),emphasis) if chosen or emphasis>.05 else Color("304254")
	draw_style_box(style,Rect2(Vector2.ZERO,size))
	draw_colored_polygon(PackedVector2Array([Vector2(size.x*.49,0),Vector2(size.x,0),Vector2(size.x,size.y),Vector2(size.x*.12,size.y)]),Color(accent,.055+.055*emphasis))
	if kind=="player":
		var p: Dictionary=screen.game.career.player(identity)
		var photo: Texture2D=screen.portraits.photo(screen.portrait_data(identity))
		if photo!=null:
			var zoom:=1.0+.025*emphasis
			var rect:=Rect2(size.x-159-(zoom-1)*72,0,155*zoom,155*zoom)
			draw_texture_rect(photo,rect,false)
		label(str(screen.World.ovr(p)),Vector2(16,49),36,accent)
		label(screen.World.ROLES[p.role],Vector2(17,70),11,screen.PAPER)
		label("%02d" % p.shirt,Vector2(17,107),22,Color("728697"))
		draw_rect(Rect2(1,119,size.x-2,size.y-120),Color("0d1b25"))
		label(p.name,Vector2(16,137),15,screen.PAPER,null,size.x-27)
		var info: String=("İLK 11" if identity in screen.game.career.club().lineup else "KADRO")+"  ·  %d YAŞ" % p.age
		if screen.page=="market": info=screen.game.career.money(0 if p.club=="" else screen.World.value(p))+"  ·  %d YAŞ" % p.age
		if p.get("retirement_year",0)>0: info="SEZON SONUNDA EMEKLİ"
		elif not p.get("loan",{}).is_empty(): info="KİRALIK  ·  %d YAŞ" % p.age
		info+="  ·  "+str(p.get("nationality","TR"))
		label(info,Vector2(16,152),10,screen.MUTE,screen.font)
		var fitness: float=clampf(p.fitness,0,1)
		draw_rect(Rect2(16,size.y-5,size.x-32,3),Color("334454"))
		draw_rect(Rect2(16,size.y-5,(size.x-32)*fitness,3),accent)
	elif kind=="club":
		var c: Dictionary=screen.new_world.clubs[identity]
		var texture: Texture2D=preload("res://scripts/kit_graphics.gd").badge(c.badge_id,Color(c.primary),Color(c.accent))
		draw_texture_rect(texture,Rect2(10,7,48,48),false)
		label(c.name,Vector2(68,28),13,screen.PAPER,null,size.x-78)
		label(c.city,Vector2(68,47),10,screen.MUTE,screen.font,size.x-78)
	else:
		screen.art.card_icon(self,Vector2(size.x-69,62),identity,accent)
		label(caption,Vector2(23,36),11,accent)
		label(text,Vector2(23,size.y-44),18,screen.PAPER,null,size.x-40)
		label(detail,Vector2(23,size.y-20),12,screen.MUTE,screen.font,size.x-40)
	style.bg_color=Color.TRANSPARENT
	draw_style_box(style,Rect2(Vector2.ZERO,size))
	if has_focus():
		draw_rect(Rect2(12,11,4,17),accent)
		draw_circle(Vector2(size.x-14,14),3.5,accent)
