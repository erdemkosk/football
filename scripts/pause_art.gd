extends RefCounted
const UI=preload("res://scripts/quick_match_art.gd")
const RECTS=[Rect2(848,277,496,64),Rect2(848,361,496,56),Rect2(848,435,496,56),Rect2(848,509,238,56),Rect2(1106,509,238,56),Rect2(848,589,496,44),Rect2(848,641,496,40)]

static func draw(hud) -> void:
	hud.draw_rect(hud.game.ui.bounds(),Color("081019",.96))
	hud.draw_texture_rect(hud.Brand.CREST,Rect2(64,47,46,56),false)
	hud.text("MAÇA ARA",Vector2(130,86),28,UI.PAPER,true)
	hud.text("BİR NEFES.",Vector2(68,220),53,UI.PAPER,true)
	hud.text("SONRA YİNE SAHADASIN.",Vector2(71,260),18,UI.MUTE)
	hud.panel(Rect2(66,302,697,336),UI.PANEL,20,UI.LINE)
	for side in range(2):
		var club: Dictionary=hud.game.clubs.data(side)
		var graphics=preload("res://scripts/kit_graphics.gd")
		var badge: Texture2D=graphics.badge(club.get("badge_id",graphics.SHORTS.find(club.short)),Color(club.primary),Color(club.accent))
		hud.draw_texture_rect(badge,Rect2(128+side*407,356,104,104),false)
		hud.center(hud.game.team_name(side),Vector2(180+side*407,507),19,UI.PAPER)
	hud.center("%d  –  %d" % hud.game.score,Vector2(412,421),58,UI.GOLD)
	hud.center("ANTRENMAN" if hud.game.training else "%d. DAKİKA" % roundi(hud.game.match_time/hud.game.LENGTH*90),Vector2(412,464),11,UI.MUTE)
	var total: float=maxf(.01,hud.game.possession[0]+hud.game.possession[1])
	hud.panel(Rect2(108,553,610,5),UI.LINE,2)
	hud.panel(Rect2(108,553,610*hud.game.possession[0]/total,5),UI.MINT,2)
	hud.center("ŞUT  %d – %d        KURTARIŞ  %d – %d" % [hud.game.shots[0],hud.game.shots[1],hud.game.saves[0],hud.game.saves[1]],Vector2(412,598),14,UI.MUTE)
	var labels=["DEVAM ET  →","YENİ DENEME" if hud.game.training else "KADRO & TAKTİK","AYARLAR","ANTRENMAN" if hud.game.training else "HIZLI MAÇ","ANA MENÜ","KONTROL REHBERİ","ANLIK TEKRAR  ·  SON 12 SN"]
	for i in range(RECTS.size()):
		var rect: Rect2=RECTS[i]
		hud.panel(rect,UI.GOLD if i==0 else UI.PANEL,10,UI.LINE if i>0 else Color.TRANSPARENT)
		hud.text(labels[i],rect.position+Vector2(22,rect.size.y*.5+6),18 if i<3 else 14,UI.INK if i==0 else UI.PAPER,true)
	if hud.game.controller.using_gamepad: hud.pad_hints(Vector2(850,700),[["LS / D-PAD","Gez"],["A","Seç"],["B","Devam"]],27,13)
	else: hud.text("YÖN TUŞLARI · Gez     ENTER · Seç     ESC · Devam",Vector2(848,711),12,UI.MUTE)
