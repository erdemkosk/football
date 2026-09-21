extends Control
var game: Node3D
var font: Font = SystemFont.new()
var bold: Font = SystemFont.new()
var display: Font = SystemFont.new()
const INK := Color("101c22")
const PAPER := Color("f5f0df")
const GOLD := Color("e9ce87")
const MUTE := Color("b4c5bd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font.font_names = PackedStringArray(["Avenir Next","DejaVu Sans"])
	bold.font_names = PackedStringArray(["Avenir Next","DejaVu Sans"])
	bold.font_weight = 700
	display.font_names = PackedStringArray(["Avenir Next Condensed","DejaVu Sans"])
	display.font_weight = 800
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
	# Thin broadcast overlays leave the entire playing surface visible.
	if game.state=="menu": menu(); return
	if game.feedback.hurt>0:
		var contact_color := Color(0.82,0.36,0.18,game.feedback.hurt*0.35)
		draw_rect(Rect2(0,0,6,900),contact_color)
		draw_rect(Rect2(1434,0,6,900),contact_color)
	if game.state=="ceremony" or (game.state=="paused" and game.before_pause=="ceremony"):
		ceremony_overlay()
		if game.state=="paused": modal()
		return
	scoreboard()
	if game.state=="goal":
		goal_banner()
		return
	player_info()
	minimap()
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
		var end: Vector2 = game.screen_position(game.ball.position+game.aim_direction()*(3+game.charge*4))
		draw_dashed_line(origin,end,Color(GOLD,0.8),2,6)
	if game.pass_charging and not game.pass_preview.is_empty():
		var route: Dictionary = game.pass_preview
		var color := Color("ecad72") if game.pass_risk>0.48 else Color("a7d9bb")
		var origin: Vector2 = game.screen_position(game.ball.position)
		var target: Vector2 = game.screen_position(route.target)
		draw_dashed_line(origin,target,Color(color,0.75),2,7)
		draw_arc(target,9,0,TAU,32,color,2,true)
		var recipient: String = "BOŞLUĞA" if route.receiver<0 else game.players[route.receiver].display_name
		center(recipient,target+Vector2(0,-17 if target.y>170 else 28),12,color)
		panel(Rect2(552,765,336,70),Color(0.035,0.09,0.105,0.94),4)
		var strength := "KISA" if game.pass_power<0.3 else ("ORTA" if game.pass_power<0.72 else "UZUN")
		center(strength+" PAS  ·  S BIRAK",Vector2(720,789),13,color)
		panel(Rect2(572,801,296,6),Color("39504d"),3)
		panel(Rect2(572,801,maxf(3,296*game.pass_power),6),color,3)
		center("PAS YOLUNDA RAKİP VAR" if game.pass_risk>0.48 else "YÖN TUŞLARIYLA HEDEF SEÇ",Vector2(720,824),10,MUTE)
	if game.toast_timer>0 and game.state in ["playing","restart"]:
		panel(Rect2(443,100,554,39),Color(0.04,0.09,0.11,0.84),3)
		center(game.toast,Vector2(720,126),14,GOLD)
	if game.state in ["restart","set_piece"]: set_piece_overlay()
	if game.rules.card_time>0:
		panel(Rect2(475,153,490,42),Color(0.035,0.08,0.1,0.94),4)
		draw_rect(Rect2(489,163,14,22),Color("e45a43") if game.rules.card_red else GOLD)
		center(game.rules.card_text,Vector2(733,181),14,PAPER)
	if game.state in ["paused","finished"]: modal()

func ceremony_overlay() -> void:
	draw_rect(Rect2(0,0,1440,60),Color(0.02,0.04,0.055,0.96))
	draw_rect(Rect2(0,796,1440,104),Color(0.02,0.04,0.055,0.96))
	text("TOUCHLINE  /  MAÇ GÜNÜ",Vector2(40,38),13,GOLD,true)
	text("KIYI ARENA  ·  "+game.weather.label(),Vector2(1130,38),11,MUTE)
	center(game.ceremony.caption(),Vector2(720,827),11,GOLD)
	center("KIYI SPOR    –    ATLAS FC",Vector2(720,865),27,PAPER)
	panel(Rect2(1175,825,225,40),Color(0.13,0.20,0.21,0.95),4,Color(GOLD,0.3))
	center("SPACE  ·  SEREMONİYİ GEÇ",Vector2(1288,851),11,GOLD)
	text("ESC  MOLA",Vector2(40,850),10,MUTE)

func scoreboard() -> void:
	panel(Rect2(32,28,476,56),Color(0.045,0.10,0.12,0.95),3)
	draw_rect(Rect2(32,28,5,56),GOLD)
	text("KIY",Vector2(88,64),22,PAPER,true)
	crest(Vector2(62,56),false,0.6)
	panel(Rect2(151,28,97,56),PAPER,0)
	center("%d  –  %d" % game.score,Vector2(199,65),24,INK)
	text("ATL",Vector2(262,64),22,PAPER,true)
	crest(Vector2(338,56),true,0.6)
	draw_line(Vector2(362,39),Vector2(362,73),Color(1,1,1,0.15))
	var minutes = mini(90,int(game.match_time/game.LENGTH*90))
	var seconds = int(fmod(game.match_time/game.LENGTH*5400,60))
	center("%02d:%02d" % [minutes,seconds],Vector2(435,64),22,GOLD)
	text("ANTRENMAN" if game.training else "KIYI ARENA  /  HAZIRLIK MAÇI",Vector2(34,104),10,Color(1,1,1,0.8),true)
	panel(Rect2(1177,28,229,38),Color(0.045,0.10,0.12,0.88),3)
	draw_circle(Vector2(1194,47),3.5,Color("f17561"))
	text("CANLI",Vector2(1206,52),11,PAPER,true)
	text("TOUCHLINE",Vector2(1268,53),16,GOLD,true)
	text(game.weather.label()+"  ·  H",Vector2(1220,88),11,MUTE,true)
	if game.training:
		text("GOL: %d    ŞUT: %d    R: TOPU YENİLE" % [game.practice_goals,game.shots[0]],Vector2(34,126),11,GOLD,true)

func set_piece_overlay() -> void:
	var setup = game.set_pieces
	panel(Rect2(423,712,594,126),Color(0.035,0.08,0.1,0.96),4)
	center(game.restart_type,Vector2(720,743),22,GOLD)
	var detail: String = setup.recovery.description()
	if game.state=="set_piece":
		if game.restart_team==1: detail="RAKİP VURUŞA HAZIRLANIYOR"
		elif game.restart_type=="PENALTI": detail="← → NİŞAN   ·   D BASILI TUT → BIRAK"
		elif game.restart_type=="TAÇ": detail="← → YÖN   ·   S KISA / A UZUN TAÇ · BAS → BIRAK"
		elif game.restart_type=="SANTRA": detail="← → YÖN   ·   S BAS → BIRAK: SANTRA PASI"
		else: detail="← → YÖN   ·   S PAS   ·   A ORTA   ·   D ŞUT · BAS → BIRAK"
	center(detail,Vector2(720,768),12,PAPER)
	panel(Rect2(455,784,530,7),Color("334944"),3)
	panel(Rect2(455,784,maxf(3,530*setup.power),7),GOLD,3)
	var note := "TOP VURULANA KADAR OYUN DURUR"
	if setup.wall.size()>0: note="BARAJ 9,15 m · AZ GÜÇ: AŞIRT · YÜKSEK GÜÇ: SERT VUR"
	if game.restart_type=="ENDİREKT VURUŞ": note="GOL İÇİN TOPA BAŞKA BİR OYUNCU DOKUNMALI"
	center(note,Vector2(720,817),11,MUTE)
	if game.state=="set_piece" and game.restart_team==0:
		var origin: Vector2=game.screen_position(game.restart_point+Vector3.UP*0.1)
		var end: Vector2=game.screen_position(game.restart_point+setup.direction*7+Vector3.UP*0.1)
		draw_dashed_line(origin,end,GOLD,2.5,7)
		draw_circle(end,4,GOLD)
		if setup.receiver>=0 and setup.button!=KEY_D:
			var at: Vector2=game.screen_position(game.players[setup.receiver].position)
			draw_arc(at,14,0,TAU,32,Color("a7d9bb"),2,true)

func crest(p: Vector2,away: bool,scale_value: float=1) -> void:
	var points = PackedVector2Array([Vector2(-20,-22),Vector2(20,-22),Vector2(18,7),Vector2(0,24),Vector2(-18,7)])
	for i in range(points.size()): points[i]=p+points[i]*scale_value
	draw_colored_polygon(points,Color("c34e3e") if away else Color("e7ddbc"))
	var points2 = PackedVector2Array([Vector2(-15,-17),Vector2(15,-17),Vector2(13,5),Vector2(0,18),Vector2(-13,5)])
	for i in range(points2.size()): points2[i]=p+points2[i]*scale_value
	draw_colored_polygon(points2,Color("e7ddbc") if away else Color("244a40"))
	center("A" if away else "K",p+Vector2(0,7*scale_value),int(22*scale_value),Color("9e3d32") if away else GOLD)

func player_info() -> void:
	var p = game.players[game.controlled]
	panel(Rect2(32,744,266,100),Color(0.045,0.10,0.12,0.93),4)
	draw_rect(Rect2(32,744,4,100),GOLD)
	text("%02d" % p.number,Vector2(51,789),31,GOLD,true)
	text(p.display_name,Vector2(103,773),21,PAPER,true)
	text("YILDIZ MODU" if game.player_lock else "KIYI SPOR",Vector2(103,792),9,MUTE,true)
	var stamina_color := Color("ed9279") if p.exhausted else (Color("e9ce87") if p.energy<0.4 else Color("a7d9bb"))
	var stamina_status := "STAMİNA"
	if p.exhausted: stamina_status = "YORGUN · W'Yİ BIRAK" if p.sprinting else "YORGUN · TOPARLANIYOR"
	elif p.active_sprint: stamina_status = "SPRİNT"
	elif p.desired.length()<0.1 and p.energy<0.99: stamina_status = "DİNLENİYOR"
	text(stamina_status,Vector2(51,815),10,stamina_color,true)
	text("%d%%" % roundi(p.energy*100),Vector2(247,815),10,stamina_color,true)
	panel(Rect2(51,827,225,6),Color("39504d"),3)
	if p.energy>0: panel(Rect2(51,827,225*p.energy,6),stamina_color,3)
	if p.exhausted:
		var threshold: float = 51+225*p.RECOVERY_LIMIT
		draw_line(Vector2(threshold,825),Vector2(threshold,835),PAPER,1)
	var pass_hint := "BAS / BIRAK PAS" if game.has_ball_control(game.controlled) else "PAS İSTE"
	text("↑ ↓ ← →  HAREKET     W  HIZLI KOŞ     S  "+pass_hint+"     A  ORTA",Vector2(34,869),10,Color(1,1,1,0.82),true)
	center("D  ŞUT    X  MÜDAHALE    Q  OYUNCU    C  KAMERA    ESC  MOLA",Vector2(784,869),10,Color(1,1,1,0.82))
	center("Z  ÇALIM    V  TOPU AÇ    E  KORU / KARŞILA    F  AYAKTA MÜDAHALE",Vector2(720,889),10,GOLD)
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
	for side in [-1,1]: draw_rect(Rect2(1310,673 if side<0 else 804,54,24),Color(1,1,1,0.22),false,1)
	for i in range(game.players.size()):
		var p = game.players[i]
		if not p.visible: continue
		var pos = Vector2(1337+p.position.x/64*112,750.5+p.position.z/100*155)
		draw_circle(pos,3 if i==game.controlled else 2.2,GOLD if i==game.controlled else (PAPER if p.team==0 else Color("e57760")))
	var ball_pos: Vector3 = game.ball.position
	draw_circle(Vector2(1337+ball_pos.x/64*112,750.5+ball_pos.z/100*155),2.3,Color.WHITE)
	center("↑  HÜCUM",Vector2(1337,643),10,Color(1,1,1,0.7))

func menu() -> void:
	# The pitch remains live behind an editorial, restrained match-day title card.
	for i in range(90):
		draw_rect(Rect2(i*10,0,10,900),Color(0.025,0.055,0.065,0.97*pow(1.0-i/90.0,0.45)))
	text("T /",Vector2(66,76),34,GOLD,true)
	text("TOUCHLINE",Vector2(125,74),25,PAPER,true)
	text("F O O T B A L L",Vector2(127,95),9,MUTE)
	panel(Rect2(68,225,166,29),Color(0.9,0.81,0.54,0.13),2,Color(GOLD,0.35))
	text("M A Ç   G Ü N Ü",Vector2(84,245),11,GOLD,true)
	headline("SAHA SENİN.",Vector2(64,363),96)
	headline("OYUN SENİN.",Vector2(64,461),96,GOLD)
	text("İlk dokunuştan son düdüğe.",Vector2(70,513),22,PAPER)
	text("11'e 11 futbol. Bir sonraki golü sen yaz.",Vector2(70,548),16,MUTE)
	button(Rect2(68,601,345,64),"MAÇA ÇIK","ENTER",true)
	button(Rect2(68,681,345,56),"ANTRENMAN","T",false)
	button(Rect2(68,751,345,46),"SERBEST VURUŞLA BAŞLA","F2",false)
	text("KIYI SPOR",Vector2(461,646),14,PAPER,true)
	text("vs",Vector2(562,646),13,MUTE)
	text("ATLAS FC",Vector2(591,646),14,PAPER,true)
	text("KIYI ARENA  /  4 DAKİKA",Vector2(461,671),11,MUTE)
	button(Rect2(461,695,305,46),game.weather.label(),"H",false)
	text("HAVA VE ZEMİN",Vector2(462,767),10,MUTE)
	text("Islak çim, çamur ve sahada kalan izler.",Vector2(462,788),12,MUTE)
	text("↑ ↓ ← →  Hareket     S  Pas / Pas iste     D  Şut     W  Hızlı koş",Vector2(69,828),12,MUTE)
	text("A  Orta     Q  Oyuncu     Fare tekeri  Yakınlaştır",Vector2(69,854),12,MUTE)
	panel(Rect2(1194,36,208,33),Color(0.03,0.08,0.09,0.75),3)
	text("KIYI ARENA  ·  İSTANBUL",Vector2(1210,58),10,PAPER,true)

func button(rect: Rect2,title: String,key: String,primary: bool) -> void:
	var hover = rect.has_point(get_global_mouse_position())
	var color = GOLD.lightened(0.1) if hover else GOLD
	if not primary: color = Color(0.14,0.23,0.24,0.98) if hover else Color(0.09,0.16,0.17,0.92)
	panel(rect,color,4,Color(GOLD,0.25) if not primary else Color.TRANSPARENT)
	text(title,rect.position+Vector2(22,rect.size.y*0.5+7),18,INK if primary else PAPER,true)
	var w = font.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
	text(key,rect.position+Vector2(rect.size.x-w-22,rect.size.y*0.5+4),10,INK if primary else MUTE,true)

func goal_banner() -> void:
	panel(Rect2(435,756,570,108),Color(0.045,0.10,0.12,0.95),3)
	draw_rect(Rect2(435,756,5,108),GOLD)
	text("GOOOL!",Vector2(458,799),32,GOLD,true)
	var scorer = ""
	if game.last_kicker>=0 and game.players[game.last_kicker].team==game.goal_team: scorer = "  ·  "+game.players[game.last_kicker].display_name
	text(("KIYI SPOR" if game.goal_team==0 else "ATLAS FC")+scorer,Vector2(458,834),16,PAPER,true)
	center("%d  –  %d" % game.score,Vector2(915,808),32,PAPER)

func modal() -> void:
	draw_rect(Rect2(0,0,1440,900),Color(0.02,0.05,0.06,0.73))
	panel(Rect2(425,218,590,480),Color("112527"),6,Color(GOLD,0.28))
	center("TOUCHLINE  /  MAÇ GÜNÜ",Vector2(720,261),11,GOLD)
	if game.state=="paused":
		center("OYUN SENİ BEKLER.",Vector2(720,339),35,PAPER)
		center("Kısa bir nefes. Sonra tekrar sahaya.",Vector2(720,380),16,MUTE)
		button(Rect2(490,432,460,61),"DEVAM ET","ESC",true)
		button(Rect2(490,509,460,54),"YENİ MAÇ","R",false)
		button(Rect2(490,579,460,54),"ANA MENÜ","←",false)
	else:
		center(game.ending_reason if game.ending_reason!="" else "SON DÜDÜK",Vector2(720,313),18 if game.ending_reason!="" else 35,PAPER)
		center("%d  –  %d" % game.score,Vector2(720,384),60,GOLD)
		center("KIYI SPOR                         ATLAS FC",Vector2(720,415),13,MUTE)
		center("ŞUT  %d – %d     KURTARIŞ  %d – %d" % [game.shots[0],game.shots[1],game.saves[0],game.saves[1]],Vector2(720,458),14,PAPER)
		var total: float = maxf(0.01,game.possession[0]+game.possession[1])
		center("TOPA SAHİP OLMA  %%%d – %%%d" % [int(game.possession[0]/total*100),int(game.possession[1]/total*100)],Vector2(720,488),12,MUTE)
		button(Rect2(490,526,460,58),"TEKRAR OYNA","ENTER",true)
		button(Rect2(490,600,460,54),"ANA MENÜ","←",false)
	center("M  SES AÇ / KAPAT     C  KAMERA     TAB  YILDIZ MODU",Vector2(720,676),10,MUTE)

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT): return
	var mouse = get_global_mouse_position()
	if game.state=="ceremony" and Rect2(1175,825,225,40).has_point(mouse):
		game.ceremony.finish(true)
		return
	if game.state=="menu":
		if Rect2(68,601,345,64).has_point(mouse): game.start_match()
		elif Rect2(461,695,305,46).has_point(mouse): game.weather.select((game.weather.preset+1)%3,true)
		elif Rect2(68,681,345,56).has_point(mouse): game.start_match(true)
		elif Rect2(68,751,345,46).has_point(mouse):
			game.start_match(false,false)
			game.begin_restart("SERBEST VURUŞ",0,Vector3(-8,0,-25))
	elif game.state=="paused":
		if Rect2(490,432,460,61).has_point(mouse): game.resume()
		elif Rect2(490,509,460,54).has_point(mouse): game.ball.freeze=false; game.start_match(game.training)
		elif Rect2(490,579,460,54).has_point(mouse): game.return_menu()
	elif game.state=="finished":
		if Rect2(490,526,460,58).has_point(mouse): game.start_match()
		elif Rect2(490,600,460,54).has_point(mouse): game.return_menu()
