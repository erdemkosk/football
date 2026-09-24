extends Control
const P = preload("res://scripts/pitch_dimensions.gd")
const Brand = preload("res://scripts/branding.gd")
var shot_guide := preload("res://scripts/shot_guide.gd").new()
var pass_guide := preload("res://scripts/shot_guide.gd").new()
var landing_guide := preload("res://scripts/ball_landing_guide.gd").new()
var aim_indicator := preload("res://scripts/aim_indicator.gd").new()
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
var bug_age := 0.0
var toast_overlay: Control
var replay_frame: Control

func _process(delta: float) -> void:
	if is_instance_valid(help_launcher): help_launcher.position=Vector2(1120,852)+game.ui.edge_offset(1,1)
	landing_guide.update(game,delta)
	if game.state in ["playing","restart","set_piece","goal","replay","halftime","finished"]:
		if game.state!="paused": bug_age+=delta
	else:
		bug_age=0
	if game.state=="paused": return
	game.team_control.selection_age=minf(1,game.team_control.selection_age+delta)
	pass_trail_time=maxf(0,pass_trail_time-delta)
	if game.state!="playing" or game.last_kicker!=pass_trail_kicker: pass_trail_time=0

func bug_slide() -> float:
	return (1.0-smoothstep(0.0,0.55,bug_age))*-510.0

func live_slide() -> float:
	return (1.0-smoothstep(0.0,0.55,bug_age))*250.0

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
	focus_mode=Control.FOCUS_NONE
	replay_frame=preload("res://scripts/replay_frame.gd").new()
	replay_frame.game=game
	replay_frame.show_behind_parent=true
	add_child(replay_frame)
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

func mount_toast(canvas: CanvasLayer) -> void:
	toast_overlay=Control.new()
	toast_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	toast_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_overlay.draw.connect(func(): draw_toast(toast_overlay))
	canvas.add_child(toast_overlay)

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
	if game.state=="replay":
		var full: Rect2=game.ui.bounds()
		var y: float=full.position.y+32
		draw_circle(Vector2(full.position.x+30,y-5),3,GOLD)
		text("GOL TEKRARI  ·  %.1f×" % game.replay.playback_speed(),Vector2(full.position.x+43,y),16,GOLD,true)
		if game.controller.using_gamepad: pad_hints(Vector2(full.end.x-170,y-5),[["A","Geç"]],25,14)
		else: text("SPACE / ENTER · GEÇ",Vector2(full.end.x-207,y),14,PAPER)
		game.broadcast.draw_graphic(self)
		return
	# Thin broadcast overlays leave the entire playing surface visible.
	if game.state=="menu":
		menu()
		return
	if game.feedback.hurt>0:
		var contact_color := Color(0.82,0.36,0.18,game.feedback.hurt*0.35)
		var full: Rect2=game.ui.bounds()
		draw_rect(Rect2(full.position,Vector2(6,full.size.y)),contact_color)
		draw_rect(Rect2(full.end.x-6,full.position.y,6,full.size.y),contact_color)
	if game.state=="ceremony" or (game.state=="paused" and game.before_pause=="ceremony"):
		ceremony_overlay()
		if game.state=="paused": modal()
		return
	landing_guide.draw(self)
	scoreboard()
	game.broadcast.draw_graphic(self)
	if game.broadcast.active:
		game.broadcast.draw(self)
		if game.state=="paused": modal()
		return
	if game.state=="halftime": halftime_overlay(); return
	if not game.management.transit.is_empty():
		draw_set_transform(game.ui.edge_offset(0,-1))
		panel(Rect2(480,90,480,40))
		center("OYUNCU DEĞİŞİKLİĞİ · KENARDA HAZIRLIK",Vector2(720,116),14,GOLD)
		draw_set_transform(Vector2.ZERO)
	if game.state=="goal":
		goal_banner()
		return
	player_info()
	minimap()
	if game.training and game.training_drills.mode=="duel": game.training_drills.duel.draw(self)
	game.advanced_controls.draw(self)
	var p = game.players[game.controlled]
	var marker: Vector2 = game.screen_position(p.position+Vector3.UP*(p.height_cm/100.0+0.30))
	if not game.camera.is_position_behind(p.position) and game.ui.bounds().grow(-36).has_point(marker):
		var pulse := 1-smoothstep(0,.42,game.team_control.selection_age)
		if pulse>0: draw_arc(marker,11+(1-pulse)*14,0,TAU,32,Color(GOLD,pulse*.85),2,true)
		draw_colored_polygon(PackedVector2Array([marker+Vector2(-9,-7),marker+Vector2(9,-7),marker+Vector2(0,7)]),INK)
		draw_colored_polygon(PackedVector2Array([marker+Vector2(-6,-5),marker+Vector2(6,-5),marker+Vector2(0,4)]),GOLD)
		var name_width := bold.get_string_size(p.display_name,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
		panel(Rect2(marker+Vector2(-name_width*.5-6,-28),Vector2(name_width+12,19)),Color(INK,.88),3)
		center(p.display_name,marker+Vector2(0,-13),11,GOLD)
	if game.charging:
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
		var color := Color("a0cfe7") if chip else GOLD
		var label := "AŞIRTMA" if chip else ("FALSO ŞUT" if curl else "ŞUT")
		if game.heading.active(game.controlled): label="KAFA"
		elif game.volleys.active(game.controlled): label=game.volleys.label(game.controlled).to_upper()
		elif game.finishing.style!="": label=game.finishing.LABELS.get(game.finishing.style,label)
		draw_shot_guide(launch,curve,color,game.charge,label)
	if game.pass_charging and not game.pass_preview.is_empty():
		var route: Dictionary = game.pass_preview
		var color := Color("a0cfe7") if route.get("lob",false) else Color("a7d9bb")
		draw_pass_guide(route,pass_guide.pass_preview(game.ball.position,route,game.weather),color)
	elif game.state=="playing" and game.controller.combos.cross_player>=0:
		var combo=game.controller.combos
		var plan: Dictionary=game.cross_plan(combo.cross_direction,combo.cross_driven,combo.cross_power)
		draw_pass_guide(plan,pass_guide.pass_preview(game.ball.position,plan,game.weather),Color("8ec6e8"))
	elif game.state=="playing" and pass_trail_time>0 and not game.charging:
		draw_pass_guide(last_pass.plan,last_pass.route,Color("8ec6e8") if last_pass.plan.get("lob",false) else Color("a7d9bb"),clampf(pass_trail_time/0.3,0,1)*0.85)
	if game.state in ["restart","set_piece"]: set_piece_overlay()
	if game.rules.card_time>0:
		draw_set_transform(game.ui.edge_offset(0,-1))
		panel(Rect2(475,153,490,42),Color(0.035,0.08,0.1,0.94),4)
		draw_rect(Rect2(489,163,14,22),Color("e45a43") if game.rules.card_red else GOLD)
		center(game.rules.card_text,Vector2(733,181),14,PAPER)
		draw_set_transform(Vector2.ZERO)
	game.coaching.draw(self)
	if game.state in ["paused","finished"]: modal()

func draw_toast(on: CanvasItem=self) -> void:
	if game.toast_timer<=0 or game.toast=="": return
	var fade := smoothstep(0.0,0.2,game.toast_timer)*smoothstep(0.0,0.18,2.8-game.toast_timer)
	var y := 28.0 if (game.frontend!=null and game.frontend.visible) or game.state=="menu" else 110.0
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.035,0.085,0.075,0.94*fade)
	style.set_corner_radius_all(6)
	var width := bold.get_string_size(game.toast,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	var toast_width := clampf(width+36,240,game.ui.bounds().size.x-48)
	var toast_x := 720-toast_width*.5
	on.draw_style_box(style,Rect2(toast_x,y,toast_width,40))
	on.draw_rect(Rect2(toast_x,y,4,40),Color(GOLD,fade))
	on.draw_string(bold,Vector2(720.0-width*0.5,y+32),game.toast,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(GOLD,fade))

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
	if route.get("goal_plane",false) and route.target.y>=2.44-game.ball.RADIUS: return "YÜKSEK"
	return ""

func draw_shot_guide(launch: Vector3,spin: float,color: Color,power: float=-1.0,label: String="ŞUT") -> void:
	var route: Dictionary=shot_guide.preview(game.ball.position,launch,spin,game.attack_sign(0)*50,game.weather)
	if power<0: power=game.set_pieces.preview_power() if game.state=="set_piece" else game.charge
	aim_indicator.draw_arrow(self,route.points,power,color)
	aim_indicator.draw_meter(self,power,label,color,shot_warning(route),game.shot_chip)

func draw_pass_guide(plan: Dictionary,route: Dictionary,color: Color,opacity: float=1.0) -> void:
	color.a*=opacity
	var power: float=game.set_pieces.preview_power() if game.state=="set_piece" else (game.pass_power if game.pass_charging else .55)
	if game.controller.combos.cross_player>=0: power=game.controller.combos.cross_power
	var lob: bool=plan.get("lob",false)
	var label := "HAVADAN PAS" if lob else "PAS"
	if plan.get("cross",false): label="ORTA"
	if game.controller.combos.cross_player>=0 and game.controller.combos.cross_driven: label="YERDEN ORTA"
	elif game.pass_through or plan.get("through",false): label="HAVADAN ARA PAS" if lob else "ARA PAS"
	if game.pass_driven: label="SERT ARA PAS" if game.pass_through else "SERT PAS"
	if plan.has("distribution"): label="EL ATIŞI" if plan.distribution=="throw" else "ELLE PAS"
	if game.state=="set_piece": label=game.restart_type
	var warning := ""
	if absf(route.target.x)>P.HALF_WIDTH or absf(route.target.z)>50: warning="SAHA DIŞINA YÖNELİYOR"
	elif game.pass_charging and game.pass_risk>0.48: warning="PAS YOLUNDA RAKİP"
	aim_indicator.draw_arrow(self,route.points,power,color)
	aim_indicator.draw_meter(self,power,label,color,warning,lob)

func action_hints() -> Array:
	if game.ball.held_by==game.players[game.controlled]:
		return [[action_label(KEY_S),"Elle pas"],[action_label(KEY_Y),"Uzun atış"],[action_label(KEY_D),"Ayaktan aç"],[action_label(KEY_V),"Yere bırak"],[action_label(KEY_Q),"Oyuncu seç"]]
	var on_ball: bool=game.has_ball_control(game.controlled)
	var teammate: bool=not on_ball and game.carrier>=0 and game.players[game.carrier].team==0
	var shot_label: String= "Kafa" if game.heading.can_request(game.controlled) else (game.volleys.label(game.controlled) if game.volleys.can_request(game.controlled) else ("Hava vuruşu" if game.aerial_assist.can_request(game.controlled) else ("Şut" if on_ball else "Müdahale")))
	return [[action_label(KEY_D),shot_label],[action_label(KEY_A),"Orta" if on_ball else "Kayma"],[action_label(KEY_S),"Pas" if on_ball else ("Baskı (tut)" if game.last_touch!=0 else "Pas iste")],[action_label(KEY_Y),"Ara pas" if on_ball else ("Ara pas iste" if teammate else "Kaleciyi çıkar")],[action_label(KEY_W),"Hızlı koş"],[action_label(KEY_Q),"Oyuncu seç"]]

func ceremony_overlay() -> void:
	var full: Rect2=game.ui.bounds()
	draw_rect(Rect2(full.position,Vector2(full.size.x,60)),Color(0.02,0.04,0.055,0.96))
	draw_rect(Rect2(full.position.x,full.end.y-104,full.size.x,104),Color(0.02,0.04,0.055,0.96))
	draw_set_transform(game.ui.edge_offset(-1,-1))
	draw_texture_rect(Brand.CREST,Rect2(36,10,38,38),false)
	text(Brand.SHORT+"  /  MAÇ GÜNÜ",Vector2(84,38),13,GOLD,true)
	draw_set_transform(game.ui.edge_offset(1,-1))
	skip_chip(Rect2(1177,12,229,36))
	draw_set_transform(game.ui.edge_offset(0,1))
	center(game.ceremony.caption(),Vector2(720,827),11,GOLD)
	center(game.team_name(0)+"    –    "+game.team_name(1),Vector2(720,865),27,PAPER)
	draw_set_transform(game.ui.edge_offset(1,1))
	panel(Rect2(1175,825,225,40),Color(0.13,0.20,0.21,0.95),4,Color(GOLD,0.3))
	if game.controller.using_gamepad:
		pad_hints(Vector2(1187,845),[["A","Geç"]],27,11)
		draw_set_transform(game.ui.edge_offset(-1,1))
		pad_hints(Vector2(40,845),[["START","Mola"]],25,11)
	else:
		center("SPACE / ENTER  ·  GEÇ",Vector2(1288,851),11,GOLD)
		draw_set_transform(game.ui.edge_offset(-1,1))
		text("ESC  MOLA",Vector2(40,850),10,MUTE)
	draw_set_transform(Vector2.ZERO)

func scoreboard() -> void:
	draw_set_transform(game.ui.edge_offset(-1,-1))
	var slide := bug_slide()
	if game.training:
		training_scoreboard(slide)
	else:
		var extra: float=game.management.added[game.half-1]
		if extra>0 and not game.career.cups.extra_active() and game.match_time>=game.LENGTH*game.half*0.5-10:
			panel(Rect2(515+slide,28,100,56))
			center("+%d DK" % roundi(extra*90/game.LENGTH),Vector2(565+slide,64),18,GOLD)
		panel(Rect2(32+slide,28,476,56),Color(0.045,0.10,0.12,0.95),3)
		draw_rect(Rect2(32+slide,28,5,56),GOLD)
		text(game.clubs.data(0).short,Vector2(88+slide,64),22,PAPER,true)
		crest(Vector2(62+slide,56),false,0.6)
		panel(Rect2(151+slide,28,97,56),PAPER,0)
		center("%d  –  %d" % game.score,Vector2(199+slide,65),24,INK)
		text(game.clubs.data(1).short,Vector2(262+slide,64),22,PAPER,true)
		crest(Vector2(338+slide,56),true,0.6)
		draw_line(Vector2(362+slide,39),Vector2(362+slide,73),Color(1,1,1,0.15))
		var extended: bool=game.career.cups.extra_phase>0 and not game.clubs.career_clubs.is_empty()
		center(preload("res://scripts/match_clock.gd").text(game.match_time,game.LENGTH,game.half,extended),Vector2(435+slide,64),22,GOLD)
		text(("UZATMA  ·  " if extended else "")+("1. YARI  ·  HÜCUM ↑" if game.half==1 else "2. YARI  ·  HÜCUM ↓"),Vector2(34+slide,104),10,Color(1,1,1,0.8),true)
	draw_set_transform(game.ui.edge_offset(1,-1))
	var live := Rect2(LIVE.position+Vector2(live_slide(),0),LIVE.size)
	panel(live,Color(0.045,0.10,0.12,0.88),3)
	draw_circle(Vector2(live.position.x+17,live.get_center().y),3.5,Color("f17561"))
	text("CANLI",Vector2(live.position.x+29,live.position.y+24),11,PAPER,true)
	draw_texture_rect(Brand.CREST,Rect2(live.position.x+91,live.position.y+4,30,30),false)
	text(Brand.SHORT,Vector2(live.position.x+131,live.position.y+25),18,GOLD,true)
	if can_skip_to_kickoff():
		skip_chip(Rect2(live.position.x,live.end.y+8,live.size.x,36))
	else:
		center(game.stadium.light_rig.label()+"  ·  "+game.weather.label()+"  ·  C "+game.match_camera.label(),Vector2(live.get_center().x,live.end.y+22),11,MUTE,true)
	draw_set_transform(Vector2.ZERO)

func training_scoreboard(slide: float) -> void:
	panel(Rect2(32+slide,28,520,56),Color(0.045,0.10,0.12,0.95),3)
	draw_rect(Rect2(32+slide,28,5,56),GOLD)
	text("GOL",Vector2(50+slide,48),10,MUTE,true)
	panel(Rect2(88+slide,28,72,56),PAPER,0)
	center(str(game.practice_goals),Vector2(124+slide,65),26,INK)
	text("ŞUT",Vector2(174+slide,48),10,MUTE,true)
	text(str(game.shots[0]),Vector2(174+slide,70),18,PAPER,true)
	text("PAS",Vector2(232+slide,48),10,MUTE,true)
	text(str(game.passes[0]),Vector2(232+slide,70),18,PAPER,true)
	text("KURTARIŞ",Vector2(290+slide,48),10,MUTE,true)
	text(str(game.saves[1]),Vector2(290+slide,70),18,PAPER,true)
	draw_line(Vector2(372+slide,39),Vector2(372+slide,73),Color(1,1,1,0.15))
	center(preload("res://scripts/match_clock.gd").session(game.match_time),Vector2(462+slide,64),22,GOLD)
	var drill: String=game.training_drills.title()
	if game.training_drills.mode!="free" and game.training_drills.attempt>0:
		drill+="  ·  %d. DENEME" % game.training_drills.attempt
	text(drill,Vector2(34+slide,104),10,Color(1,1,1,0.8),true)
	if not game.controller.using_gamepad:
		text("R  YENİ DENEME",Vector2(34+slide,126),11,GOLD,true)

func can_skip_to_kickoff() -> bool:
	return game.state=="goal" or (game.state=="restart" and game.restart_type=="SANTRA" and not game.training)

func skip_chip(rect: Rect2,label: String="SPACE / ENTER  ·  GEÇ",pad_label: String="Geç") -> void:
	panel(rect,Color(0.045,0.10,0.12,0.88),3)
	if game.controller.using_gamepad:
		pad_hints(rect.position+Vector2(11,rect.size.y*0.5+2),[["A",pad_label]],24,11)
	else:
		center(label,rect.get_center()+Vector2(0,5),11,GOLD)

func set_piece_overlay() -> void:
	var setup = game.set_pieces
	if game.state!="set_piece" or game.restart_team!=0: return
	if setup.kind()=="shot":
		draw_shot_guide(setup.pending_velocity,setup.pending_curve,GOLD,setup.preview_power(),"PENALTI" if game.restart_type=="PENALTI" else "FRİKİK")
		return
	var lob: bool=setup.kind() in ["cross","throw"]
	var plan := {"target":setup.target,"velocity":setup.pending_velocity,"lob":lob,"receiver":setup.receiver,"flight":4.0,"cross":setup.kind()=="cross"}
	draw_pass_guide(plan,pass_guide.pass_preview(game.ball.position,plan,game.weather,setup.pending_curve),Color("a0cfe7") if lob else Color("a7d9bb"))

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
	draw_set_transform(game.ui.edge_offset(-1,1)+Vector2(0,24))
	var p = game.players[game.controlled]
	panel(Rect2(32,744,266,100),Color(0.045,0.10,0.12,0.93),4)
	draw_rect(Rect2(32,744,4,100),GOLD)
	text("%02d" % p.shirt_number,Vector2(51,789),31,GOLD,true)
	text(p.display_name,Vector2(103,773),21,PAPER,true)
	text("YILDIZ MODU" if game.player_lock else game.team_name(0),Vector2(103,792),9,MUTE,true)
	var stamina_color := Color("ed9279") if p.exhausted else (Color("e9ce87") if p.energy<0.4 else Color("a7d9bb"))
	var stamina_status := "STAMİNA"
	if p.exhausted: stamina_status = "YORGUN"
	elif p.active_sprint: stamina_status = "SPRİNT"
	elif p.desired.length()<0.1 and p.energy<0.99: stamina_status = "DİNLENİYOR"
	text(stamina_status,Vector2(51,815),12,stamina_color,true)
	text("%d%%" % roundi(p.energy*100),Vector2(241,815),12,stamina_color,true)
	panel(Rect2(51,827,225,6),Color("39504d"),3)
	if p.energy>0: panel(Rect2(51,827,225*p.energy,6),stamina_color,3)
	if p.exhausted:
		var threshold: float = 51+225*p.RECOVERY_LIMIT
		draw_line(Vector2(threshold,825),Vector2(threshold,835),PAPER,1)
	if p.ball_actions.receive_feedback_time>0 and p.ball_actions.receive_reason!="":
		panel(Rect2(32,715,266,25),Color(INK,.93),3)
		text(p.ball_actions.receive_reason,Vector2(44,733),11,Color("ed9279"),true)
	if game.skills.notice_time>0:
		panel(Rect2(32,682,390,27),Color(INK,.94),3)
		text(game.skills.notice,Vector2(44,701),11,GOLD,true)
	if game.training or game.charging:
		var velocity: Vector3 = game.ball.linear_velocity
		var kmh = int(velocity.length()*3.6)
		if kmh>4:
			panel(Rect2(330,783,108,45),Color(0.045,0.10,0.12,0.86),3)
			text(str(kmh),Vector2(344,814),26,GOLD,true)
			text("km/sa",Vector2(386,813),11,PAPER)
	draw_set_transform(Vector2.ZERO)

func minimap() -> void:
	draw_set_transform(game.ui.edge_offset(1,1)+Vector2(0,24))
	var rect = Rect2(1268,655,138,190)
	panel(rect,Color(0.03,0.08,0.09,0.72),4,Color(1,1,1,0.1))
	var pitch = Rect2(1281,673,112,155)
	draw_rect(pitch,Color(1,1,1,0.24),false,1)
	draw_line(Vector2(1281,750.5),Vector2(1393,750.5),Color(1,1,1,0.22),1)
	draw_arc(Vector2(1337,750.5),14,0,TAU,32,Color(1,1,1,0.22),1,true)
	var box_size := Vector2(40.32/P.WIDTH*112,16.5/P.LENGTH*155)
	for side in [-1,1]: draw_rect(Rect2(1337-box_size.x*.5,673 if side<0 else 828-box_size.y,box_size.x,box_size.y),Color(1,1,1,0.22),false,1)
	# Dots only need each strip's primary colour; the full kit also solves both
	# goalkeeper palettes, which used to run once per dot on every drawn frame.
	var team_colors: Array[Color]=[game.clubs.strip(0).primary,game.clubs.strip(1).primary]
	for i in range(game.players.size()):
		var p = game.players[i]
		if not p.visible: continue
		var pos = Vector2(1337+p.position.x/P.WIDTH*112,750.5+p.position.z/P.LENGTH*155)
		draw_circle(pos,3 if i==game.controlled else 2.2,GOLD if i==game.controlled else team_colors[p.team])
	var ball_pos: Vector3 = game.ball.position
	draw_circle(Vector2(1337+ball_pos.x/P.WIDTH*112,750.5+ball_pos.z/P.LENGTH*155),2.3,Color.WHITE)
	center("↑  HÜCUM",Vector2(1337,643),10,Color(1,1,1,0.7))
	draw_set_transform(Vector2.ZERO)

func menu() -> void:
	# The pitch remains live behind an editorial, restrained match-day title card.
	var full: Rect2=game.ui.bounds()
	if full.position.x<0: draw_rect(Rect2(full.position,Vector2(-full.position.x,full.size.y)),Color(0.025,0.055,0.065,.97))
	for i in range(90):
		draw_rect(Rect2(i*10,full.position.y,10,full.size.y),Color(0.025,0.055,0.065,0.97*pow(1.0-i/90.0,0.45)))
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
	draw_set_transform(game.ui.edge_offset(1,-1))
	panel(Rect2(1194,36,208,33),Color(0.03,0.08,0.09,0.75),3)
	text("KIYI ARENA  ·  İSTANBUL",Vector2(1210,58),10,PAPER,true)
	draw_set_transform(Vector2.ZERO)

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
	draw_set_transform(game.ui.edge_offset(0,1))
	panel(Rect2(435,756,570,108),Color(0.045,0.10,0.12,0.95),3)
	draw_rect(Rect2(435,756,5,108),GOLD)
	text("GOOOL!",Vector2(458,799),32,GOLD,true)
	var scorer = ""
	if game.last_kicker>=0 and game.players[game.last_kicker].team==game.goal_team: scorer = "  ·  "+game.players[game.last_kicker].display_name
	text(game.team_name(game.goal_team)+scorer,Vector2(458,834),16,PAPER,true)
	center("%d  –  %d" % game.score,Vector2(915,808),32,PAPER)
	draw_set_transform(Vector2.ZERO)

func modal() -> void:
	if game.state=="paused":
		preload("res://scripts/pause_art.gd").draw(self)
		return
	draw_rect(game.ui.bounds(),Color(0.02,0.05,0.06,0.73))
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
		center("ŞUT  %d – %d     İSABET  %d – %d" % [game.shots[0],game.shots[1],game.shots_on_target[0],game.shots_on_target[1]],Vector2(720,447),14,PAPER)
		center("PAS  %d – %d     KURTARIŞ  %d – %d" % [game.passes[0],game.passes[1],game.saves[0],game.saves[1]],Vector2(720,472),14,PAPER)
		var total: float = maxf(0.01,game.possession[0]+game.possession[1])
		center("TOPA SAHİP OLMA  %%%d – %%%d" % [int(game.possession[0]/total*100),int(game.possession[1]/total*100)],Vector2(720,498),12,MUTE)
		button(Rect2(490,526,460,58),"KARİYERE DÖN" if not game.clubs.career_clubs.is_empty() else "TEKRAR OYNA","ENTER",true)
		button(Rect2(490,600,460,54),"ANA MENÜ","←",false)
	if game.state=="paused": button(Rect2(490,660,460,34),"KONTROL REHBERİ","F1",false)

func rematch() -> void:
	if game.state!="finished" or not game.clubs.career_clubs.is_empty(): return
	game.controller.held.clear()
	game.start_match(false,false)

func sync_navigation() -> void:
	var state: String=game.state if game.state in ["menu","paused","finished","halftime","ceremony","replay","goal"] else ""
	if state=="" and can_skip_to_kickoff(): state="kickoff_skip"
	var covered: bool=(is_instance_valid(game.match_menu) and game.match_menu.visible) or (is_instance_valid(game.frontend) and game.frontend.visible) or (is_instance_valid(game.controls_help) and game.controls_help.visible)
	covered=covered or (is_instance_valid(game.career_screen) and game.career_screen.visible)
	covered=covered or (is_instance_valid(game.training_menu) and game.training_menu.visible) or (game.broadcast.active and game.state!="paused")
	help_launcher.visible=not covered and state=="finished"
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
				var rects=preload("res://scripts/pause_art.gd").RECTS
				nav_button(rects[0],game.resume)
				nav_button(rects[1],game.reset_practice if game.training else game.frontend.open_tactics)
				nav_button(rects[2],game.match_menu.open_menu)
				nav_button(rects[3],game.training_menu.open_menu if game.training else game.frontend.open_selection)
				nav_button(rects[4],game.return_menu)
				nav_button(rects[5],game.controls_help.open_panel)
			"finished":
				nav_button(Rect2(490,526,460,58),game.career_screen.open_hub if not game.clubs.career_clubs.is_empty() else rematch)
				nav_button(Rect2(490,600,460,54),game.return_menu)
			"halftime": nav_button(Rect2(510,564,420,54),game.interval.finish)
			"ceremony": nav_button(Rect2(1175,825,225,40),game.ceremony.finish.bind(true))
			"replay": nav_button(Rect2(game.ui.bounds().end.x-225,game.ui.bounds().position.y+8,215,36),game.replay.finish)
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
	if state=="replay" and not nav_buttons.is_empty():
		nav_buttons[0].position=Vector2(game.ui.bounds().end.x-225,game.ui.bounds().position.y+8)
	elif state=="ceremony" and not nav_buttons.is_empty():
		nav_buttons[0].position=Vector2(1175,825)+game.ui.edge_offset(1,1)
	elif state in ["goal","kickoff_skip"] and not nav_buttons.is_empty():
		nav_buttons[0].position=Vector2(1177,74)+game.ui.edge_offset(1,-1)+Vector2(live_slide(),0)
	for item in nav_buttons: item.show()
	if not nav_buttons.is_empty() and not nav_buttons.has(get_viewport().gui_get_focus_owner()) and state not in ["ceremony","replay","goal","kickoff_skip"]:
		nav_buttons[nav_index].grab_focus()

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
	draw_rect(game.ui.bounds(),Color(0.02,0.05,0.06,0.42))
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
