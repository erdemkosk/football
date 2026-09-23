extends Control
const P = preload("res://scripts/pitch_dimensions.gd")
const Brand = preload("res://scripts/branding.gd")
var shot_guide := preload("res://scripts/shot_guide.gd").new()
var pass_guide := preload("res://scripts/shot_guide.gd").new()
var landing_guide := preload("res://scripts/ball_landing_guide.gd").new()
var last_pass: Dictionary = {}
var pass_trail_time := 0.0
var pass_trail_kicker := -1
var nav_state := ""
var nav_buttons: Array[Button] = []
var nav_index := 0
var help_launcher: Button
var help_glyphs: Control
var game: Node3D
var font: Font = SystemFont.new()
var bold: Font = SystemFont.new()
var display: Font = SystemFont.new()
const INK := Color("101c22")
const PAPER := Color("f5f0df")
const GOLD := Color("e9ce87")
const MUTE := Color("b4c5bd")
const LIVE := Rect2(1177,28,229,38)

func _process(delta: float) -> void:
	landing_guide.update(game,delta)
	if game.state=="paused": return
	pass_trail_time=maxf(0,pass_trail_time-delta)
	if game.state!="playing" or game.last_kicker!=pass_trail_kicker: pass_trail_time=0

func remember_pass(_plan: Dictionary,_passer: int) -> void:
	last_pass={}
	pass_trail_kicker=-1
	pass_trail_time=0

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font.font_names = PackedStringArray(["Avenir Next","DejaVu Sans"])
	bold.font_names = PackedStringArray(["Avenir Next","DejaVu Sans"])
	bold.font_weight = 700
	display.font_names = PackedStringArray(["Avenir Next Condensed","DejaVu Sans"])
	display.font_weight = 800
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_launcher=Button.new()
	help_launcher.position=Vector2(1120,852)
	help_launcher.size=Vector2(280,36)
	help_launcher.focus_mode=Control.FOCUS_NONE
	help_launcher.add_theme_font_override("font",bold)
	help_launcher.add_theme_font_size_override("font_size",12)
	help_launcher.add_theme_color_override("font_color",GOLD)
	for mode in ["normal","hover","pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color=Color("19373e") if mode=="normal" else Color("2d5056")
		style.border_color=Color(GOLD,0.3); style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		help_launcher.add_theme_stylebox_override(mode,style)
	help_launcher.pressed.connect(func(): game.controls_help.open_panel())
	add_child(help_launcher)
	help_glyphs=preload("res://scripts/controller_hint.gd").new()
	help_glyphs.controller=game.controller
	help_glyphs.items=[["START → Y","Kontroller"]]
	help_glyphs.position=Vector2(12,1)
	help_launcher.add_child(help_glyphs)

func panel(rect: Rect2,color: Color=Color(0.04,0.09,0.11,0.90),radius: int=4,border: Color=Color.TRANSPARENT) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border.a>0: style.border_color = border; style.set_border_width_all(1)
	draw_style_box(style,rect)

func text(value: String,p: Vector2,size: int=16,color: Color=PAPER,weight: bool=false) -> void:
	draw_string(bold if weight else font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func center(value: String,p: Vector2,size: int=16,color: Color=PAPER,weight: bool=true) -> void:
	var f = bold if weight else font
	var w = f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	draw_string(f,p-Vector2(w*0.5,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func headline(value: String,p: Vector2,size: int=84,color: Color=PAPER) -> void:
	draw_string(display,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	if game.state in ["shootout","trophy"]: game.finale.draw(self); return
	if is_instance_valid(game.controls_help) and game.controls_help.visible: return
	if game.match_menu!=null and game.match_menu.visible: return
	if game.frontend!=null and game.frontend.visible: return
	if game.training_menu!=null and game.training_menu.visible: return
	if game.controller.using_gamepad:
		var items := [["START","Mola"],["VIEW","Antrenmanlar" if game.training else "Kadro & taktik"]]
		pad_hints(Vector2(live_mid()-pad_hint_width(items,20,11)*0.5,20),items,20,11)
	else: center("P · AYARLAR     T · ANTRENMANLAR" if game.training else "P · AYARLAR     K · KADRO & TAKTİK",Vector2(live_mid(),22),11,MUTE)
	if game.state=="replay":
		panel(Rect2(0,0,1440,72))
		text("GOL TEKRARI  ·  0.8×",Vector2(45,46),23,GOLD,true)
		if game.controller.using_gamepad: pad_hints(Vector2(1220,38),[["A","Geç"]],30,16)
		else: text("SPACE / ENTER · GEÇ",Vector2(1120,46),16,PAPER)
		return
	# Thin broadcast overlays leave the entire playing surface visible.
	if game.state=="menu":
		menu()
		if game.controller.using_gamepad: pad_hints(Vector2(1230,850),[["VIEW","Ayarlar"]],26,14)
		else: text("P · AYARLAR",Vector2(1250,855),14,GOLD,true)
		return
	if game.feedback.hurt>0:
		var contact_color := Color(0.82,0.36,0.18,game.feedback.hurt*0.35)
		draw_rect(Rect2(0,0,6,900),contact_color)
		draw_rect(Rect2(1434,0,6,900),contact_color)
	if game.state=="ceremony" or (game.state=="paused" and game.before_pause=="ceremony"):
		ceremony_overlay()
		if game.state=="paused": modal()
		return
	landing_guide.draw(self)
	scoreboard()
	if game.broadcast.active:
		game.broadcast.draw(self)
		if game.state=="paused": modal()
		return
	if game.state=="halftime": halftime_overlay(); return
	if not game.management.transit.is_empty():
		panel(Rect2(480,90,480,40))
		center("OYUNCU DEĞİŞİKLİĞİ · KENARDA HAZIRLIK",Vector2(720,116),14,GOLD)
	if game.state=="goal":
		goal_banner()
		return
	player_info()
	minimap()
	game.advanced_controls.draw(self)
	var p = game.players[game.controlled]
	var marker: Vector2 = game.screen_position(p.position+Vector3.UP*2.75)
	if not game.camera.is_position_behind(p.position) and marker.x>0 and marker.x<1440 and marker.y>80 and marker.y<790:
		draw_colored_polygon(PackedVector2Array([marker+Vector2(-5,-4),marker+Vector2(5,-4),marker+Vector2(0,3)]),GOLD)
		center(p.display_name,marker+Vector2(0,-13),11,GOLD)
	if game.charging:
		var at: Vector2 = game.screen_position(p.position)+Vector2(-24,16)
		panel(Rect2(at,Vector2(48,6)),Color(0,0,0,0.6),3)
		panel(Rect2(at,Vector2(maxf(3,game.charge*48),6)),GOLD if game.charge<0.8 else Color("f07d59"),3)
		var origin: Vector2 = game.screen_position(game.ball.position)
		var chip: bool = game.shot_chip
		var curl: bool = game.shot_finesse and not chip
		var launch: Vector3=game.shot_velocity(game.aim_direction(),game.charge,curl,chip)
		var curve: float = game.finesse_curve(game.aim_direction()) if curl else 0.0
		if game.heading.active(game.controlled):
			launch=game.heading.launch_velocity(game.controlled,game.aim_direction(),game.charge)
			curve=0
		elif game.volleys.active(game.controlled):
			launch=game.volleys.launch_velocity(game.controlled,game.aim_direction(),game.charge)
			curve=0
		if game.finishing.style!="":
			curve=game.finishing.curve(game.controlled,game.finishing.style)
			center(game.finishing.LABELS[game.finishing.style],origin+Vector2(0,-18),11,GOLD)
		var color := Color("8ec6e8",0.92) if chip else (Color("ecad72",0.9) if curl else Color(GOLD,0.8))
		draw_shot_guide(launch,curve,color)
		if chip: center("AŞIRT",origin+Vector2(0,-18),11,color)
		elif curl: center("FALSO",origin+Vector2(0,-18),11,color)
	if game.pass_charging and not game.pass_preview.is_empty():
		var route: Dictionary = game.pass_preview
		var color := Color("ecad72") if game.pass_risk>0.48 else Color("a7d9bb")
		draw_pass_guide(route,pass_guide.pass_preview(game.ball.position,route,game.weather),color)
		panel(Rect2(552,765,336,70),Color(0.035,0.09,0.105,0.94),4)
		var strength := "KISA" if game.pass_power<0.3 else ("ORTA" if game.pass_power<0.72 else "UZUN")
		var pass_name: String=("SERT ARA PAS" if game.pass_through else "SERT DÜZ PAS") if game.pass_driven else "HAVADAN "+strength if game.pass_lob else ("KOŞU YOLUNA" if game.pass_through else strength+" PAS")
		if route.has("distribution"): pass_name="UZUN EL ATIŞI" if route.distribution=="throw" else "ELLE YERDEN PAS"
		if game.controller.using_gamepad:
			text(pass_name,Vector2(569,789),13,color,true)
			pad_hints(Vector2(790,784),[["Y" if game.pass_lob else action_label(KEY_Y if game.pass_through else KEY_S),"Bırak"]],25,12)
		else: center(pass_name+"  ·  "+action_label(KEY_Y if game.pass_through else KEY_S)+" BIRAK",Vector2(720,789),13,color)
		panel(Rect2(572,801,296,6),Color("39504d"),3)
		panel(Rect2(572,801,maxf(3,296*game.pass_power),6),color,3)
		center("PAS YOLUNDA RAKİP VAR" if game.pass_risk>0.48 else ("SOL ANALOG İLE HEDEF SEÇ" if game.controller.using_gamepad else "YÖN TUŞLARIYLA HEDEF SEÇ"),Vector2(720,824),10,MUTE)
	elif game.state=="playing" and game.controller.combos.cross_player>=0:
		var plan: Dictionary=game.cross_plan(game.controller.combos.cross_direction)
		draw_pass_guide(plan,pass_guide.pass_preview(game.ball.position,plan,game.weather),Color("8ec6e8"))
	elif game.state=="playing" and pass_trail_time>0 and not game.charging:
		draw_pass_guide(last_pass.plan,last_pass.route,Color("8ec6e8") if last_pass.plan.get("lob",false) else Color("a7d9bb"),clampf(pass_trail_time/0.3,0,1)*0.85)
	if game.state in ["restart","set_piece"]: set_piece_overlay()
	if game.rules.card_time>0:
		panel(Rect2(475,153,490,42),Color(0.035,0.08,0.1,0.94),4)
		draw_rect(Rect2(489,163,14,22),Color("e45a43") if game.rules.card_red else GOLD)
		center(game.rules.card_text,Vector2(733,181),14,PAPER)
	game.coaching.draw(self)
	if game.state in ["paused","finished"]: modal()
	elif game.state=="playing" and game.controller.using_gamepad:
		pad_hints(Vector2(44,870),action_hints(),28,12)

func live_mid() -> float:
	return LIVE.position.x+LIVE.size.x*0.5

func pad_hint_width(items: Array,height: float=27,font_size: int=12,gap: float=24) -> float:
	var total := 0.0
	for item in items:
		total+=game.controller.Glyphs.width(item[0],font,height,font_size)+7+font.get_string_size(item[1],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+gap
	return maxf(total-gap,0)

func pad_hints(at: Vector2,items: Array,height: float=27,font_size: int=12) -> void:
	game.controller.Glyphs.draw_hints(self,at,items,game.controller.family,font,height,font_size)

func shot_warning(route: Dictionary) -> String:
	if route.get("goal_plane",false) and route.target.y>=2.22: return "YÜKSEK"
	return ""

func draw_shot_guide(launch: Vector3,spin: float,color: Color) -> void:
	var route: Dictionary=shot_guide.preview(game.ball.position,launch,spin,game.attack_sign(0)*50,game.weather)
	draw_ball_path(route.points,color)
	draw_landing_disc(route.target,color,route.target.y>1.1)
	var warning := shot_warning(route)
	if warning!="": draw_target_marker(route.target,warning,Color("f19b80",color.a))

func draw_ball_path(points: PackedVector3Array,color: Color) -> void:
	var arc := PackedVector2Array()
	var ground := PackedVector2Array()
	for point in points:
		if game.camera.is_position_behind(point): continue
		arc.append(game.screen_position(point))
		ground.append(game.screen_position(Vector3(point.x,0.03,point.z)))
	if arc.size()<2: return
	for i in range(1,ground.size(),2): draw_line(ground[i-1],ground[i],Color(color,color.a*0.32),1.2,true)
	draw_polyline(arc,Color(0.015,0.04,0.05,color.a*0.75),5,true)
	draw_polyline(arc,color,2.3,true)
	for i in range(6,arc.size(),10):
		var tangent := (arc[i]-arc[i-1]).normalized()
		var side := tangent.orthogonal()*3.5
		draw_colored_polygon(PackedVector2Array([arc[i]+tangent*5,arc[i]-tangent*4+side,arc[i]-tangent*4-side]),color)

func draw_target_marker(point: Vector3,label: String,color: Color) -> void:
	if game.camera.is_position_behind(point): return
	var target: Vector2=game.screen_position(point)
	if Rect2(26,115,1388,600).has_point(target):
		draw_circle(target,8,Color(0.015,0.04,0.05,color.a*0.8))
		draw_arc(target,9,0,TAU,32,color,2,true)
		draw_line(target-Vector2(4,0),target+Vector2(4,0),color,1.5,true)
		draw_line(target-Vector2(0,4),target+Vector2(0,4),color,1.5,true)
		if label=="": return
		var width: float=bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x+16
		var at := Vector2(clampf(target.x,28+width*0.5,1412-width*0.5),target.y-18)
		panel(Rect2(at-Vector2(width*0.5,13),Vector2(width,19)),Color(0.015,0.04,0.05,color.a*0.88),3)
		center(label,at,10,color)

func draw_pass_guide(plan: Dictionary,route: Dictionary,color: Color,opacity: float=1.0) -> void:
	color.a*=opacity
	draw_ball_path(route.points,color)
	var warning := ""
	if absf(route.target.x)>P.HALF_WIDTH or absf(route.target.z)>50: warning="DIŞARI"
	elif game.pass_charging and game.pass_risk>0.48: warning="RAKİP"
	draw_landing_disc(route.target,color,plan.get("lob",false))
	if warning!="": draw_target_marker(route.target,warning,color)

func draw_landing_disc(point: Vector3,color: Color,lob: bool) -> void:
	if game.camera.is_position_behind(point): return
	var ring := PackedVector2Array()
	var radius: float=0.85 if lob else 0.58
	for i in range(33):
		var angle := TAU*i/32.0
		ring.append(game.screen_position(Vector3(point.x,0.04,point.z)+Vector3(cos(angle),0,sin(angle))*radius))
	if ring.size()>2:
		draw_colored_polygon(ring,Color(color,color.a*0.16))
		draw_polyline(ring,Color(color,color.a*0.28),1.2,true)
	var target: Vector2=game.screen_position(point)
	if Rect2(26,115,1388,600).has_point(target):
		draw_circle(target,12 if lob else 9,Color(color,color.a*0.14))
		draw_circle(target,4,Color(color,color.a*0.22))

func action_hints() -> Array:
	if game.ball.held_by==game.players[game.controlled]:
		return [[action_label(KEY_S),"Elle pas"],[action_label(KEY_Y),"Uzun atış"],[action_label(KEY_D),"Ayaktan aç"],[action_label(KEY_V),"Yere bırak"],[action_label(KEY_Q),"Oyuncu seç"]]
	var on_ball: bool=game.has_ball_control(game.controlled)
	var teammate: bool=not on_ball and game.carrier>=0 and game.players[game.carrier].team==0
	var shot_label: String= "Kafa" if game.heading.can_request(game.controlled) else (game.volleys.label(game.controlled) if game.volleys.can_request(game.controlled) else ("Hava vuruşu" if game.aerial_assist.can_request(game.controlled) else ("Şut" if on_ball else "Müdahale")))
	return [[action_label(KEY_D),shot_label],[action_label(KEY_A),"Orta" if on_ball else "Kayma"],[action_label(KEY_S),"Pas" if on_ball else ("Baskı (tut)" if game.last_touch!=0 else "Pas iste")],[action_label(KEY_Y),"Ara pas" if on_ball else ("Ara pas iste" if teammate else "Kaleciyi çıkar")],[action_label(KEY_W),"Hızlı koş"],[action_label(KEY_Q),"Oyuncu seç"]]

func ceremony_overlay() -> void:
	draw_rect(Rect2(0,0,1440,60),Color(0.02,0.04,0.055,0.96))
	draw_rect(Rect2(0,796,1440,104),Color(0.02,0.04,0.055,0.96))
	draw_texture_rect(Brand.CREST,Rect2(36,10,38,38),false)
	text(Brand.SHORT+"  /  MAÇ GÜNÜ",Vector2(84,38),13,GOLD,true)
	skip_chip(Rect2(1177,12,229,36),"SPACE  ·  SEREMONİYİ GEÇ","Seremoniyi geç")
	center(game.ceremony.caption(),Vector2(720,827),11,GOLD)
	center(game.team_name(0)+"    –    "+game.team_name(1),Vector2(720,865),27,PAPER)
	panel(Rect2(1175,825,225,40),Color(0.13,0.20,0.21,0.95),4,Color(GOLD,0.3))
	if game.controller.using_gamepad:
		pad_hints(Vector2(1187,845),[["A","Seremoniyi geç"]],27,11)
		pad_hints(Vector2(40,845),[["START","Mola"]],25,11)
	else:
		center("SPACE  ·  SEREMONİYİ GEÇ",Vector2(1288,851),11,GOLD)
		text("ESC  MOLA",Vector2(40,850),10,MUTE)

func scoreboard() -> void:
	var extra: float=game.management.added[game.half-1]
	if extra>0 and not game.career.cups.extra_active() and game.match_time>=game.LENGTH*game.half*0.5-10:
		panel(Rect2(515,28,100,56))
		center("+%d DK" % roundi(extra*90/game.LENGTH),Vector2(565,64),18,GOLD)
	panel(Rect2(32,28,476,56),Color(0.045,0.10,0.12,0.95),3)
	draw_rect(Rect2(32,28,5,56),GOLD)
	text(game.clubs.data(0).short,Vector2(88,64),22,PAPER,true)
	crest(Vector2(62,56),false,0.6)
	panel(Rect2(151,28,97,56),PAPER,0)
	center("%d  –  %d" % game.score,Vector2(199,65),24,INK)
	text(game.clubs.data(1).short,Vector2(262,64),22,PAPER,true)
	crest(Vector2(338,56),true,0.6)
	draw_line(Vector2(362,39),Vector2(362,73),Color(1,1,1,0.15))
	var extended: bool=game.career.cups.extra_phase>0 and not game.clubs.career_clubs.is_empty()
	var minutes = mini(120 if extended else 90,int(game.match_time/game.LENGTH*90))
	var seconds = int(fmod(game.match_time/game.LENGTH*5400,60))
	var time_label := "%02d:%02d" % [minutes,seconds]
	if not extended and game.match_time>game.LENGTH*game.half*0.5:
		time_label="%d+%d" % [45*game.half,ceili((game.match_time-game.LENGTH*game.half*0.5)*90/game.LENGTH)]
	center(time_label,Vector2(435,64),22,GOLD)
	text("ANTRENMAN" if game.training else (("UZATMA  ·  " if extended else "")+("1. YARI  ·  HÜCUM ↑" if game.half==1 else "2. YARI  ·  HÜCUM ↓")),Vector2(34,104),10,Color(1,1,1,0.8),true)
	panel(LIVE,Color(0.045,0.10,0.12,0.88),3)
	draw_circle(Vector2(LIVE.position.x+17,LIVE.get_center().y),3.5,Color("f17561"))
	text("CANLI",Vector2(LIVE.position.x+29,LIVE.position.y+24),11,PAPER,true)
	draw_texture_rect(Brand.CREST,Rect2(LIVE.position.x+91,LIVE.position.y+4,30,30),false)
	text(Brand.SHORT,Vector2(LIVE.position.x+131,LIVE.position.y+25),18,GOLD,true)
	if can_skip_to_kickoff():
		skip_chip(Rect2(LIVE.position.x,LIVE.end.y+8,LIVE.size.x,36))
	else:
		center(game.stadium.light_rig.label()+"  ·  "+game.weather.label()+"  ·  C "+game.match_camera.label(),Vector2(live_mid(),LIVE.end.y+22),11,MUTE,true)
	if game.training:
		text("GOL: %d    ŞUT: %d" % [game.practice_goals,game.shots[0]]+("    R: YENİ DENEME" if not game.controller.using_gamepad else ""),Vector2(34,126),11,GOLD,true)

func can_skip_to_kickoff() -> bool:
	return game.state=="goal" or (game.state=="restart" and game.restart_type=="SANTRA" and not game.training)

func skip_chip(rect: Rect2,label: String="SPACE  ·  SANTRAYA GEÇ",pad_label: String="Santraya geç") -> void:
	panel(rect,Color(0.045,0.10,0.12,0.88),3)
	if game.controller.using_gamepad:
		pad_hints(rect.position+Vector2(11,rect.size.y*0.5+2),[["A",pad_label]],24,11)
	else:
		center(label,rect.get_center()+Vector2(0,5),11,GOLD)

func set_piece_overlay() -> void:
	var setup = game.set_pieces
	if game.state!="set_piece" or game.restart_team!=0: return
	if setup.power>0.02:
		panel(Rect2(572,848,296,6),Color("39504d"),3)
		panel(Rect2(572,848,maxf(3,296*setup.power),6),GOLD,3)
	if setup.kind()=="shot":
		var curl := absf(setup.pending_curve)>0.01
		draw_shot_guide(setup.pending_velocity,setup.pending_curve,Color("ecad72") if curl else GOLD)
		return
	var lob: bool=setup.kind() in ["cross","throw"]
	var curl := absf(setup.pending_curve)>0.01
	var plan := {"target":setup.target,"velocity":setup.pending_velocity,"lob":lob,"receiver":setup.receiver,"flight":4.0,"cross":setup.kind()=="cross"}
	draw_pass_guide(plan,pass_guide.pass_preview(game.ball.position,plan,game.weather,setup.pending_curve),Color("ecad72") if curl else (Color("8ec6e8") if lob else Color("a7d9bb")))

func crest(p: Vector2,away: bool,scale_value: float=1) -> void:
	var club: Dictionary=game.clubs.data(1 if away else 0)
	var points = PackedVector2Array([Vector2(-20,-22),Vector2(20,-22),Vector2(18,7),Vector2(0,24),Vector2(-18,7)])
	for i in range(points.size()): points[i]=p+points[i]*scale_value
	draw_colored_polygon(points,Color(club.primary))
	var points2 = PackedVector2Array([Vector2(-15,-17),Vector2(15,-17),Vector2(13,5),Vector2(0,18),Vector2(-13,5)])
	for i in range(points2.size()): points2[i]=p+points2[i]*scale_value
	draw_colored_polygon(points2,Color(club.accent))
	center(club.short.substr(0,1),p+Vector2(0,7*scale_value),int(22*scale_value),Color("9e3d32") if away else GOLD)

func player_info() -> void:
	var p = game.players[game.controlled]
	panel(Rect2(32,744,266,100),Color(0.045,0.10,0.12,0.93),4)
	draw_rect(Rect2(32,744,4,100),GOLD)
	text("%02d" % p.shirt_number,Vector2(51,789),31,GOLD,true)
	text(p.display_name,Vector2(103,773),21,PAPER,true)
	text("YILDIZ MODU" if game.player_lock else game.team_name(0),Vector2(103,792),9,MUTE,true)
	var stamina_color := Color("ed9279") if p.exhausted else (Color("e9ce87") if p.energy<0.4 else Color("a7d9bb"))
	var stamina_status := "STAMİNA"
	if p.exhausted: stamina_status = "YORGUN · SPRİNTİ BIRAK" if p.sprinting else "YORGUN · TOPARLANIYOR"
	elif p.active_sprint: stamina_status = "SPRİNT"
	elif p.desired.length()<0.1 and p.energy<0.99: stamina_status = "DİNLENİYOR"
	text(stamina_status,Vector2(51,815),10,stamina_color,true)
	text("%d%%" % roundi(p.energy*100),Vector2(247,815),10,stamina_color,true)
	panel(Rect2(51,827,225,6),Color("39504d"),3)
	if p.energy>0: panel(Rect2(51,827,225*p.energy,6),stamina_color,3)
	if p.exhausted:
		var threshold: float = 51+225*p.RECOVERY_LIMIT
		draw_line(Vector2(threshold,825),Vector2(threshold,835),PAPER,1)
	if game.training or game.charging:
		var velocity: Vector3 = game.ball.linear_velocity
		var kmh = int(velocity.length()*3.6)
		if kmh>4:
			panel(Rect2(330,783,108,45),Color(0.045,0.10,0.12,0.86),3)
			text(str(kmh),Vector2(344,814),26,GOLD,true)
			text("km/sa",Vector2(386,813),11,PAPER)

func minimap() -> void:
	var rect = Rect2(1268,655,138,190)
	panel(rect,Color(0.03,0.08,0.09,0.72),4,Color(1,1,1,0.1))
	var pitch = Rect2(1281,673,112,155)
	draw_rect(pitch,Color(1,1,1,0.24),false,1)
	draw_line(Vector2(1281,750.5),Vector2(1393,750.5),Color(1,1,1,0.22),1)
	draw_arc(Vector2(1337,750.5),14,0,TAU,32,Color(1,1,1,0.22),1,true)
	var box_size := Vector2(40.32/P.WIDTH*112,16.5/P.LENGTH*155)
	for side in [-1,1]: draw_rect(Rect2(1337-box_size.x*.5,673 if side<0 else 828-box_size.y,box_size.x,box_size.y),Color(1,1,1,0.22),false,1)
	for i in range(game.players.size()):
		var p = game.players[i]
		if not p.visible: continue
		var pos = Vector2(1337+p.position.x/P.WIDTH*112,750.5+p.position.z/P.LENGTH*155)
		draw_circle(pos,3 if i==game.controlled else 2.2,GOLD if i==game.controlled else game.clubs.kit(p.team).primary)
	var ball_pos: Vector3 = game.ball.position
	draw_circle(Vector2(1337+ball_pos.x/P.WIDTH*112,750.5+ball_pos.z/P.LENGTH*155),2.3,Color.WHITE)
	center("↑  HÜCUM",Vector2(1337,643),10,Color(1,1,1,0.7))

func menu() -> void:
	# The pitch remains live behind an editorial, restrained match-day title card.
	for i in range(90):
		draw_rect(Rect2(i*10,0,10,900),Color(0.025,0.055,0.065,0.97*pow(1.0-i/90.0,0.45)))
	draw_texture_rect(Brand.CREST,Rect2(62,32,146,146),false)
	text("STARTING",Vector2(226,83),31,PAPER,true)
	headline("ELEVEN FC",Vector2(223,135),53,PAPER)
	text("S E F C   /   1 1 ' E  1 1  F U T B O L",Vector2(228,160),10,GOLD,true)
	panel(Rect2(68,225,166,29),Color(0.9,0.81,0.54,0.13),2,Color(GOLD,0.35))
	text("M A Ç   G Ü N Ü",Vector2(84,245),11,GOLD,true)
	headline("SAHA SENİN.",Vector2(64,363),96)
	headline("OYUN SENİN.",Vector2(64,461),96,GOLD)
	text("İlk dokunuştan son düdüğe.",Vector2(70,513),22,PAPER)
	text("11'e 11 futbol. Bir sonraki golü sen yaz.",Vector2(70,548),16,MUTE)
	button(Rect2(68,601,345,64),"HIZLI MAÇ","ENTER",true)
	button(Rect2(68,681,345,56),"ANTRENMAN","T",false)
	button(Rect2(440,601,295,64),"KARİYER","",true)
	button(Rect2(68,751,345,46),"AYARLAR","P",false)
	button(Rect2(68,820,345,48),"KONTROL REHBERİ","Y" if game.controller.using_gamepad else "F1",false)
	panel(Rect2(1194,36,208,33),Color(0.03,0.08,0.09,0.75),3)
	text("KIYI ARENA  ·  İSTANBUL",Vector2(1210,58),10,PAPER,true)

func button(rect: Rect2,title: String,key: String,primary: bool) -> void:
	if game.controller.using_gamepad:
		key="A" if nav_buttons.any(func(item): return item.has_focus() and item.position==rect.position) else ""
	var hover = rect.has_point(get_global_mouse_position())
	var color = GOLD.lightened(0.1) if hover else GOLD
	if not primary: color = Color(0.14,0.23,0.24,0.98) if hover else Color(0.09,0.16,0.17,0.92)
	panel(rect,color,4,Color(GOLD,0.25) if not primary else Color.TRANSPARENT)
	text(title,rect.position+Vector2(22,rect.size.y*0.5+7),18,INK if primary else PAPER,true)
	if game.controller.using_gamepad and key!="":
		draw_texture_rect(game.controller.Glyphs.icon(JOY_BUTTON_A,game.controller.family),Rect2(rect.position+Vector2(rect.size.x-51,rect.size.y*0.5-15),Vector2(30,30)),false)
	else:
		var w = font.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		text(key,rect.position+Vector2(rect.size.x-w-22,rect.size.y*0.5+4),10,INK if primary else MUTE,true)

func goal_banner() -> void:
	panel(Rect2(435,756,570,108),Color(0.045,0.10,0.12,0.95),3)
	draw_rect(Rect2(435,756,5,108),GOLD)
	text("GOOOL!",Vector2(458,799),32,GOLD,true)
	var scorer = ""
	if game.last_kicker>=0 and game.players[game.last_kicker].team==game.goal_team: scorer = "  ·  "+game.players[game.last_kicker].display_name
	text(game.team_name(game.goal_team)+scorer,Vector2(458,834),16,PAPER,true)
	center("%d  –  %d" % game.score,Vector2(915,808),32,PAPER)

func modal() -> void:
	draw_rect(Rect2(0,0,1440,900),Color(0.02,0.05,0.06,0.73))
	panel(Rect2(425,218,590,480),Color("112527"),6,Color(GOLD,0.28))
	center(Brand.SHORT+"  /  MAÇ GÜNÜ",Vector2(720,261),11,GOLD)
	if game.state=="paused":
		center("OYUN SENİ BEKLER.",Vector2(720,339),35,PAPER)
		center("Kısa bir nefes. Sonra tekrar sahaya.",Vector2(720,380),16,MUTE)
		button(Rect2(490,420,460,55),"DEVAM ET","ESC",true)
		button(Rect2(490,485,460,48),"YENİ DENEME" if game.training else "KADRO & TAKTİK","R" if game.training else "K / VIEW",false)
		button(Rect2(490,543,460,48),"AYARLAR","P",false)
		button(Rect2(490,601,220,48),"ANTRENMANLAR" if game.training else "HIZLI MAÇ","T" if game.training else "R",false)
		button(Rect2(730,601,220,48),"ANA MENÜ","←",false)
	else:
		center(game.ending_reason if game.ending_reason!="" else "SON DÜDÜK",Vector2(720,313),18 if game.ending_reason!="" else 35,PAPER)
		center("%d  –  %d" % game.score,Vector2(720,384),60,GOLD)
		center(game.team_name(0)+"       ·       "+game.team_name(1),Vector2(720,415),13,MUTE)
		center("ŞUT  %d – %d     KURTARIŞ  %d – %d" % [game.shots[0],game.shots[1],game.saves[0],game.saves[1]],Vector2(720,458),14,PAPER)
		var total: float = maxf(0.01,game.possession[0]+game.possession[1])
		center("TOPA SAHİP OLMA  %%%d – %%%d" % [int(game.possession[0]/total*100),int(game.possession[1]/total*100)],Vector2(720,488),12,MUTE)
		button(Rect2(490,526,460,58),"KARİYERE DÖN" if not game.clubs.career_clubs.is_empty() else "TEKRAR OYNA","ENTER",true)
		button(Rect2(490,600,460,54),"ANA MENÜ","←",false)
	if game.state=="paused": button(Rect2(490,660,460,34),"KONTROL REHBERİ","F1",false)

func sync_navigation() -> void:
	var state: String=game.state if game.state in ["menu","paused","finished","halftime","ceremony","replay","goal"] else ""
	if state=="" and can_skip_to_kickoff(): state="kickoff_skip"
	var covered: bool=(is_instance_valid(game.match_menu) and game.match_menu.visible) or (is_instance_valid(game.frontend) and game.frontend.visible) or (is_instance_valid(game.controls_help) and game.controls_help.visible)
	covered=covered or (is_instance_valid(game.career_screen) and game.career_screen.visible)
	covered=covered or (is_instance_valid(game.training_menu) and game.training_menu.visible) or (game.broadcast.active and game.state!="paused")
	help_launcher.visible=not covered and state in ["","finished"]
	help_launcher.text="" if game.controller.using_gamepad else "F1  ·  KONTROL REHBERİ"
	help_glyphs.visible=game.controller.using_gamepad
	if covered:
		for item in nav_buttons: item.hide()
		return
	if state!=nav_state:
		for item in nav_buttons: remove_child(item); item.queue_free()
		nav_buttons.clear()
		nav_state=state
		nav_index=0
		match state:
			"menu":
				nav_button(Rect2(68,601,345,64),game.frontend.open_selection)
				nav_button(Rect2(68,681,345,56),game.training_menu.open_menu)
				nav_button(Rect2(68,751,345,46),game.match_menu.open_menu)
				nav_button(Rect2(68,820,345,48),game.controls_help.open_panel)
				nav_button(Rect2(440,601,295,64),game.career_screen.open_entry)
			"paused":
				nav_button(Rect2(490,420,460,55),game.resume)
				nav_button(Rect2(490,485,460,48),game.reset_practice if game.training else game.frontend.open_tactics)
				nav_button(Rect2(490,543,460,48),game.match_menu.open_menu)
				nav_button(Rect2(490,601,220,48),game.training_menu.open_menu if game.training else game.frontend.open_selection)
				nav_button(Rect2(730,601,220,48),game.return_menu)
				nav_button(Rect2(490,660,460,34),game.controls_help.open_panel)
			"finished":
				nav_button(Rect2(490,526,460,58),game.career_screen.open_hub if not game.clubs.career_clubs.is_empty() else game.frontend.open_selection)
				nav_button(Rect2(490,600,460,54),game.return_menu)
			"halftime": nav_button(Rect2(510,564,420,54),game.interval.finish)
			"ceremony": nav_button(Rect2(1175,825,225,40),game.ceremony.finish.bind(true))
			"replay": nav_button(Rect2(1080,15,320,42),game.replay.finish)
			"goal","kickoff_skip": nav_button(Rect2(1177,74,229,36),game.skip_to_kickoff)
		for i in range(nav_buttons.size()):
			var item := nav_buttons[i]
			item.focus_neighbor_top=item.get_path_to(nav_buttons[posmod(i-1,nav_buttons.size())])
			item.focus_neighbor_bottom=item.get_path_to(nav_buttons[(i+1)%nav_buttons.size()])
			item.focus_neighbor_left=item.focus_neighbor_top
			item.focus_neighbor_right=item.focus_neighbor_bottom
			item.focus_next=item.focus_neighbor_bottom
			item.focus_previous=item.focus_neighbor_top
		if state=="menu":
			nav_buttons[0].focus_neighbor_right=nav_buttons[0].get_path_to(nav_buttons[4])
			nav_buttons[4].focus_neighbor_left=nav_buttons[4].get_path_to(nav_buttons[0])
	for item in nav_buttons: item.show()
	if not nav_buttons.is_empty() and not nav_buttons.has(get_viewport().gui_get_focus_owner()): nav_buttons[nav_index].grab_focus()

func nav_button(rect: Rect2,callback: Callable) -> void:
	var item := Button.new()
	item.position=rect.position; item.size=rect.size
	for state in ["normal","hover","pressed","disabled"]: item.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var outline := StyleBoxFlat.new()
	outline.bg_color=Color.TRANSPARENT
	outline.border_color=PAPER
	outline.set_border_width_all(2)
	outline.set_corner_radius_all(7)
	outline.set_expand_margin_all(5)
	item.add_theme_stylebox_override("focus",outline)
	item.pressed.connect(callback)
	var index := nav_buttons.size()
	item.focus_entered.connect(func(): nav_index=index; queue_redraw())
	add_child(item)
	nav_buttons.append(item)

func handle_pad(code: int) -> void:
	if code==JOY_BUTTON_Y:
		game.controls_help.open_panel()
		return
	if code==JOY_BUTTON_BACK:
		if game.state in ["menu","finished"]: game.match_menu.open_menu()
		elif game.state=="paused" and game.before_pause not in ["ceremony","replay"]:
			if game.training: game.training_menu.open_menu()
			else: game.frontend.open_tactics()
	elif code in [JOY_BUTTON_B,JOY_BUTTON_START]:
		if game.state=="paused": game.resume()
		elif game.state=="finished": game.return_menu()
		elif game.state=="menu" and code==JOY_BUTTON_START: game.frontend.open_selection()
		elif game.state in ["ceremony","replay","halftime","goal","restart"] and code==JOY_BUTTON_START:
			var event := InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=true
			game._input(event)

func halftime_overlay() -> void:
	draw_rect(Rect2(0,0,1440,900),Color(0.02,0.05,0.06,0.42))
	panel(Rect2(440,250,560,390),Color(0.035,0.09,0.10,0.96),6,Color(GOLD,0.35))
	center("45:00  /  DEVRE ARASI",Vector2(720,294),17,GOLD)
	center("%d  –  %d" % game.score,Vector2(720,366),58,PAPER)
	center(game.team_name(0)+"       ·       "+game.team_name(1),Vector2(720,403),14,MUTE)
	center("ŞUT  %d – %d       PAS  %d – %d" % [game.shots[0],game.shots[1],game.passes[0],game.passes[1]],Vector2(720,447),15,PAPER)
	center("OYUNCULAR DİNLENİYOR · ENERJİ +%20",Vector2(720,491),12,GOLD)
	center("İkinci yarıda kaleler değişir. Hücum yönün ↓",Vector2(720,521),13,MUTE)
	button(Rect2(510,564,420,54),"İKİNCİ YARIYA GEÇ  ·  %d" % ceili(maxf(0,game.interval.DURATION-game.interval.age)),"ENTER",true)

func action_label(action: int) -> String:
	return game.controller.label_for(action) if game.controller.using_gamepad else OS.get_keycode_string(game.match_menu.key_for(action))
