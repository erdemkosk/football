extends RefCounted
## Selection graphics share the existing canvas and two kit studios.
const INK := Color("09161c")
const PANEL := Color("10262e")
const LINE := Color("29434c")
const PAPER := Color("f4f0df")
const MUTE := Color("91aaae")
const GOLD := Color("e9ce87")
const MINT := Color("a8e1be")

static func fitted(front,value: String,at: Vector2,px: int,width: float,color: Color=PAPER) -> void:
	while px>12 and front.bold.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x>width: px-=1
	front.text(value,at,px,color,true)

static func draw(front) -> void:
	front.draw_rect(front.game.ui.bounds(),INK)
	# Quiet architectural lines keep the information in front of the backdrop.
	for i in range(12): front.draw_line(Vector2(700+i*90,0),Vector2(240+i*90,900),Color(.35,.65,.69,.035),1)
	front.draw_texture_rect(front.Brand.CREST,Rect2(48,30,42,50),false)
	front.text("SEFC  /  MAÇ GÜNÜ",Vector2(108,50),15,PAPER,true)
	front.text("HIZLI MAÇ",Vector2(109,72),10,GOLD,true)
	front.text("01  TAKIMLAR",Vector2(1005,57),12,GOLD,true)
	front.text("02  KADRO",Vector2(1160,57),12,MUTE,true)
	front.text("03  SAHA",Vector2(1290,57),12,MUTE,true)
	front.draw_line(Vector2(48,99),Vector2(1392,99),LINE,1)
	front.text("SAHNE SENİN.",Vector2(48,159),44,PAPER,true)
	var prompt: String="Takımını seç." if front.pick_step==0 else ("Şimdi rakibini seç." if front.pick_step==1 else "İki takım da hazır. Son hazırlıklara geç.")
	front.text(prompt,Vector2(51,185),15,MUTE)
	front.text("KIYI ARENA",Vector2(1180,149),15,PAPER,true)
	front.text("İSTANBUL  ·  11'E 11",Vector2(1181,173),11,MUTE)
	for side in range(2):
		var x := 48.0 if side==0 else 758.0
		var data: Dictionary=front.game.clubs.data(side)
		var kit: Dictionary=front.game.clubs.kit(side)
		var selected: bool=front.picked[side]
		var active: bool=front.pick_step==side
		var accent: Color=Color(data.primary).lerp(PAPER,.28)
		var border := MINT if selected else (GOLD if active else LINE)
		front.box(Rect2(x,207,634,523),PANEL,14,border)
		front.draw_line(Vector2(x+20,208),Vector2(x+614,208),border,2,true)
		front.draw_colored_polygon(PackedVector2Array([Vector2(x+318,273),Vector2(x+633,273),Vector2(x+633,652),Vector2(x+210,652)]),Color(kit.primary,.075))
		front.draw_line(Vector2(x+24,272),Vector2(x+610,272),LINE,1)
		front.text("%02d / %02d" % [front.game.clubs.selected[side]+1,front.game.clubs.league_ids(front.game.clubs.league[side]).size()],Vector2(x+539,248),12,MUTE,true)
		front.badge(Vector2(x+61,321),data,1.0)
		fitted(front,str(data.name),Vector2(x+111,319),32,489)
		front.text(str(data.city)+"  /  "+str(data.get("year","")),Vector2(x+113,342),11,MUTE)
		front.text("EV SAHİBİ" if side==0 else "DEPLASMAN",Vector2(x+29,381),10,accent,true)
		front.text(str(data.short),Vector2(x+343,507),82,Color(accent,.07),true)
		front.draw_arc(Vector2(x+462,529),105,.12,PI-.12,56,Color(accent,.20),1.2,true)
		front.draw_arc(Vector2(x+462,529),119,.12,PI-.12,56,Color(accent,.07),1,true)
		var ratings: Dictionary=front.selection_ratings[side]
		var power := roundi(front.shown_ovr[side])
		front.text("%02d" % power,Vector2(x+27,469),74,PAPER,true)
		front.text("TAKIM",Vector2(x+142,430),11,MUTE,true)
		front.text("GÜCÜ",Vector2(x+142,450),11,MUTE,true)
		var labels := ["HÜCUM","ORTA SAHA","DEFANS"]
		var values := [ratings.att,ratings.mid,ratings.def]
		for row in range(3):
			var y := 501.0+row*39
			front.text(labels[row],Vector2(x+29,y),10,MUTE,true)
			front.text(str(values[row]),Vector2(x+241,y),13,PAPER,true)
			front.box(Rect2(x+29,y+9,244,4),LINE,2)
			front.box(Rect2(x+29,y+9,244*values[row]/100.0,4),accent,2)
		fitted(front,str(data.get("style","DENGELİ OYUN")),Vector2(x+29,640),12,282,MUTE)
		front.draw_circle(Vector2(x+596,379),3,MINT if selected else GOLD if active else MUTE)
		front.text("HAZIR" if selected else "SEÇİLİYOR" if active else "SIRADAKİ",Vector2(x+500,382),10,MINT if selected else MUTE,true)
	front.draw_line(Vector2(720,258),Vector2(720,443),LINE,1)
	front.center("VS",Vector2(720,478),18,GOLD,true)
	front.draw_line(Vector2(720,504),Vector2(720,686),LINE,1)
	front.draw_line(Vector2(48,797),Vector2(1392,797),LINE,1)
	if front.game.controller.using_gamepad:
		front.game.controller.Glyphs.draw_hints(front,Vector2(52,762),[["LS / D-PAD","Takım"],["LB / RB","Lig"],["X","Forma"],["A","Seç"],["B","Geri"]],front.game.controller.family,front.font,25,11,26)
	else: front.text("← →  TAKIM     Q / E  LİG     ENTER  ONAYLA     ESC  GERİ",Vector2(52,779),11,MUTE)
	front.text("FORMA, HAVA VE ZORLUK SANA BAĞLI",Vector2(1071,779),10,MUTE)

static func overlay(front) -> void:
	var focus: Control=front.get_viewport().gui_get_focus_owner()
	if focus!=null and front.controls.is_ancestor_of(focus):
		var style := StyleBoxFlat.new()
		style.bg_color=Color.TRANSPARENT; style.border_color=PAPER
		style.set_border_width_all(2); style.set_corner_radius_all(9)
		front.overlay.draw_style_box(style,Rect2(focus.position,focus.size).grow(4))
