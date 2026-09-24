extends RefCounted
const Style=preload("res://scripts/ui_style.gd")
## Native canvas artwork; two existing kit studios provide the live heroes.
const INK := Style.INK
const PANEL := Style.PANEL
const LINE := Style.LINE
const PAPER := Style.PAPER
const MUTE := Style.MUTE
const GOLD := Style.ACCENT
const MINT := Color("7fe4c2")

static func fitted(front,value: String,at: Vector2,px: int,width: float,color: Color=PAPER) -> void:
	while px>12 and front.bold.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x>width: px-=1
	front.text(value,at,px,color,true)

static func backdrop(front) -> void:
	var full: Rect2=front.game.ui.bounds()
	front.draw_rect(full,INK)
	for i in range(24):
		var t := i/23.0
		front.draw_rect(Rect2(full.position+Vector2(0,full.size.y*t),Vector2(full.size.x,full.size.y/23+1)),Color(.06,.16,.20,.16*(1-t)))
	front.draw_line(Vector2(48,101),Vector2(1392,101),LINE,1)

static func gauge(front,at: Vector2,value: float,label: String,color: Color,radius: float=22) -> void:
	front.draw_arc(at,radius,-PI*.8,PI*.8,36,Color(color,.16),3,true)
	front.draw_arc(at,radius,-PI*.8,lerpf(-PI*.8,PI*.8,clampf(value/100,0,1)),36,color,3,true)
	front.center(str(roundi(value)),at+Vector2(0,6),18,PAPER,true)
	front.center(label,at+Vector2(0,radius+17),9,MUTE,true)

static func draw(front) -> void:
	backdrop(front)
	front.draw_texture_rect(front.Brand.CREST,Rect2(48,30,40,49),false)
	front.text("MAÇ GÜNÜ",Vector2(108,66),29,PAPER,true)
	front.text("01",Vector2(1150,63),22,GOLD,true)
	front.draw_line(Vector2(1190,55),Vector2(1242,55),LINE,2)
	front.text("02",Vector2(1259,63),22,MUTE,true)
	front.draw_line(Vector2(1300,55),Vector2(1352,55),LINE,2)
	front.text("03",Vector2(1365,63),22,MUTE,true)
	front.text("TARAFINI SEÇ." if front.pick_step==0 else ("RAKİBİN KİM?" if front.pick_step==1 else "SAHAYA HAZIR."),Vector2(48,164),43,PAPER,true)
	front.text("SEFC ARENA",Vector2(1144,165),12,MUTE,true)
	for side in range(2):
		var x := 48.0 if side==0 else 758.0
		var data: Dictionary=front.game.clubs.data(side)
		var kit: Dictionary=front.game.clubs.kit(side)
		var selected: bool=front.picked[side]
		var active: bool=front.pick_step==side
		var accent: Color=Color(data.primary).lerp(PAPER,.35)
		var border := GOLD if active else (MINT if selected else LINE)
		front.box(Rect2(x,207,634,523),PANEL,20,border)
		# Floodlit club-colour stage, with a floor ellipse under the live model.
		for i in range(16):
			var t := i/15.0
			front.draw_colored_polygon(PackedVector2Array([Vector2(x+180+t*220,274),Vector2(x+430+t*150,274),Vector2(x+605,631),Vector2(x+260,631)]),Color(accent,.005))
		front.draw_colored_polygon(PackedVector2Array([Vector2(x+385,271),Vector2(x+620,271),Vector2(x+400,647),Vector2(x+164,647)]),Color(accent,.09))
		front.draw_set_transform(Vector2(x+401,612),0,Vector2(1,.20))
		front.draw_circle(Vector2.ZERO,126,Color(accent,.13))
		front.draw_arc(Vector2.ZERO,131,0,TAU,64,Color(accent,.35),1.5,true)
		front.draw_set_transform(Vector2.ZERO)
		front.text(str(data.short),Vector2(x+236,548),119,Color(accent,.12),true)
		front.badge(Vector2(x+73,322),data,1.30)
		front.text("EV SAHİBİ" if side==0 else "DEPLASMAN",Vector2(x+25,391),10,MUTE,true)
		front.box(Rect2(x+25,410,85,86),Color("081019",.8),13,Color(accent,.25))
		front.center(str(roundi(front.shown_ovr[side])),Vector2(x+67,463),43,PAPER,true)
		front.center("GÜÇ",Vector2(x+67,484),9,accent,true)
		var rating: Dictionary=front.selection_ratings[side]
		for row in range(3):
			var value: float=[rating.att,rating.mid,rating.def][row]
			gauge(front,Vector2(x+42+row*70,561),value,["HÜCUM","ORTA","DEFANS"][row],accent,19)
		front.box(Rect2(x+18,605,306,45),Color("081019",.90),9)
		fitted(front,str(data.name),Vector2(x+29,635),25,284)
		front.draw_circle(Vector2(x+597,245),4,MINT if selected else GOLD if active else MUTE)
	front.draw_circle(Vector2(720,466),27,INK)
	front.center("VS",Vector2(720,473),20,GOLD,true)
	front.draw_line(Vector2(48,797),Vector2(1392,797),LINE,1)
	if front.game.controller.using_gamepad:
		front.game.controller.Glyphs.draw_hints(front,Vector2(52,765),[["LS / D-PAD","Takım"],["LB / RB","Lig"],["X","Forma"],["A","Seç"],["B","Geri"]],front.game.controller.family,front.font,25,11,26)
	else: front.text("← →  TAKIM      Q / E  LİG      ENTER  SEÇ      ESC  GERİ",Vector2(52,777),11,MUTE)
	front.text("2 × %d DK  ·  %d DK MAÇ" % [front.game.quick_half_minutes,front.game.quick_half_minutes*2],Vector2(1170,777),12,GOLD,true)

static func overlay(front) -> void:
	var focus: Control=front.get_viewport().gui_get_focus_owner()
	if focus!=null and front.controls.is_ancestor_of(focus):
		var style := StyleBoxFlat.new()
		style.bg_color=Color.TRANSPARENT; style.border_color=GOLD
		style.set_border_width_all(2); style.set_corner_radius_all(11)
		front.overlay.draw_style_box(style,Rect2(focus.position,focus.size).grow(4))
