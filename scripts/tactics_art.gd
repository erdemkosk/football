extends RefCounted
const Art=preload("res://scripts/quick_match_art.gd")
static func draw(front) -> void:
	Art.backdrop(front)
	front.badge(Vector2(73,59),front.game.clubs.data(0),.85)
	front.text("İLK ON BİR",Vector2(122,64),31,Art.PAPER,true)
	front.text(front.game.management.FORMATIONS[front.game.management.formation],Vector2(62,182),27,Art.GOLD,true)
	front.text(front.game.team_name(0).to_upper(),Vector2(244,181),17,Art.PAPER,true)
	front.box(Rect2(40,198,886,433),Color("102d32",.85),18,Color("33505a"))
	var pitch := Rect2(78,209,810,402)
	for i in range(10):
		front.draw_rect(Rect2(pitch.position+Vector2(i*81,0),Vector2(81,402)),Color(.16,.42,.36,.08 if i%2 else .025))
	var line := Color(.55,.85,.77,.21)
	front.draw_rect(pitch,line,false,1.2)
	front.draw_line(Vector2(78,410),Vector2(888,410),line,1)
	front.draw_arc(Vector2(483,410),58,0,TAU,60,line,1,true)
	front.draw_circle(Vector2(483,410),3,line)
	for y in [209,536]: front.draw_rect(Rect2(326,y,314,75),line,false,1)
	for y in [209,585]: front.draw_rect(Rect2(414,y,138,26),line,false,1)
	front.draw_polyline(PackedVector2Array([Vector2(861,180),Vector2(866,172),Vector2(871,180)]),Art.GOLD,2,true)
	front.box(Rect2(952,155,448,476),Color("0e1c27",.97),18,Art.LINE)
	if front.pane==0: front.draw_comparison()
	else:
		front.text("OYUN KİMLİĞİ",Vector2(978,190),21,Art.PAPER,true)
		for i in range(4): front.text(["DİZİLİŞ","YAKLAŞIM","PRES","SAVUNMA ÇİZGİSİ"][i],Vector2(978,222+i*99),11,Art.MUTE,true)
	front.box(Rect2(40,650,1360,151),Color("0c1923",.95),16,Art.LINE)
	front.text("KULÜBE" if front.pane==0 else "SAHADAKİ PLAN",Vector2(58,678),12,Art.MUTE,true)
	if front.pane==1:
		var management=front.game.management
		for i in range(4):
			var x := 76.0+i*330
			var level: int=[management.formation,management.mentality,management.pressing,management.line_height][i]
			for j in range(3):
				front.box(Rect2(x+j*19,708+(2-j)*9,11,20+j*9),Art.GOLD if j<=level else Art.LINE,3)
			front.text([management.FORMATIONS[level],["SAVUNMA","DENGE","HÜCUM"][level],["BLOK","DENGE","BASKI"][level],["DERİN","ORTA","ÖNDE"][level]][i],Vector2(x+77,739),23,Art.PAPER,true)
	if front.game.controller.using_gamepad:
		front.game.controller.Glyphs.draw_hints(front,Vector2(42,818),[["LS / D-PAD","Gez"],["A",front.tactics_action_label()],["B","Geri"],["LB / RB","Sekme"],["X","Geri al"]]+([["Y / R3","Talimat"]] if front.pane==0 else []),front.game.controller.family,front.font,23,10,22)
	else: front.text("YÖNLER  GEZ      ENTER  SEÇ      ESC  GERİ      Z  GERİ AL"+("      T / Y  TALİMAT" if front.pane==0 else ""),Vector2(42,819),10,Art.MUTE)
	if front.status!="": front.text(front.status.left(65),Vector2(283,863),11,Art.MINT)
	elif front.swap_stage!="browse": front.text("İkinci oyuncuyu seç, değişikliği onayla.",Vector2(283,863),12,Art.GOLD)
