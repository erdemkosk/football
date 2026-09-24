extends RefCounted
const UI=preload("res://scripts/ui_style.gd")
const TABS=["MAÇIN ÖZETİ","OYUNCU NOTLARI","İSTATİSTİKLER"]
const CONTINUE=Rect2(1008,814,380,56)
const HOME=Rect2(52,814,220,56)

static func tab_rect(i: int) -> Rect2: return Rect2(52+i*450,227,436,46)

static func change(h,page: int) -> void:
	h.game.match_report.page=page; h.nav_state=""; h.sync_navigation()
	h.nav_buttons[2+page].grab_focus(); h.queue_redraw()

static func navigation(h) -> void:
	var g=h.game; var r=g.match_report
	h.nav_button(CONTINUE,g.career_screen.open_hub if not g.clubs.career_clubs.is_empty() else h.rematch)
	h.nav_button(HOME,g.return_menu)
	for i in range(3): h.nav_button(tab_rect(i),change.bind(h,i))
	if r.page==0 and r.events.size()>5:
		h.nav_button(Rect2(902,574,202,36),func(): r.event_page=posmod(r.event_page-1,ceili(r.events.size()/5.0)); h.queue_redraw())
		h.nav_button(Rect2(1116,574,242,36),func(): r.event_page=posmod(r.event_page+1,ceili(r.events.size()/5.0)); h.queue_redraw())
	if r.page==1:
		h.nav_button(Rect2(565,720,144,38),func(): r.roster_page=maxi(0,r.roster_page-1); h.queue_redraw())
		h.nav_button(Rect2(731,720,144,38),func(): r.roster_page=mini(1,r.roster_page+1); h.queue_redraw())
	if not g.playtest.report.is_empty(): h.nav_button(Rect2(291,814,266,56),func(): g.match_menu.open_menu(); g.match_menu.show_page(4))

static func fit(h,value: String,at: Vector2,width: float,points: int=18,color: Color=UI.PAPER) -> void:
	UI.fit(h,h.bold,value,at,width,points,color)

static func draw(h) -> void:
	var g=h.game; var r=g.match_report
	h.draw_rect(g.ui.bounds(),UI.INK)
	h.panel(Rect2(52,35,1336,171),UI.PANEL,12,UI.LINE)
	h.center("MAÇ RAPORU · SON DÜDÜK",Vector2(720,66),13,UI.MUTE)
	for team in [0,1]:
		var x:=103.0 if team==0 else 1334.0
		var club: Dictionary=g.clubs.data(team)
		var graphics=preload("res://scripts/kit_graphics.gd")
		h.draw_texture_rect(graphics.badge(int(club.get("badge_id",graphics.SHORTS.find(club.short))),Color(club.primary),Color(club.accent)),Rect2(x-31,95,62,62),false)
		fit(h,g.team_name(team),Vector2(157 if team==0 else 911,121),326 if team==0 else 374,24)
	h.center("%d  –  %d" % g.score,Vector2(720,139),63,UI.PAPER)
	h.center(g.ending_reason if g.ending_reason!="" else ("KARİYER MAÇI" if not r.career_before.is_empty() else "HIZLI MAÇ"),Vector2(720,183),13,UI.ACCENT)
	for i in range(3): h.button(tab_rect(i),TABS[i],"",r.page==i)
	match r.page:
		0: summary(h)
		1: ratings(h)
		2: stats(h)
	h.button(CONTINUE,"KARİYER MERKEZİNE DÖN →" if not g.clubs.career_clubs.is_empty() else "TEKRAR OYNA →","",true)
	h.button(HOME,"← ANA MENÜ","",false)
	if not g.playtest.report.is_empty(): h.button(Rect2(291,814,266,56),"MAÇI DEĞERLENDİR","",false)

static func summary(h) -> void:
	var g=h.game; var r=g.match_report; var best: Dictionary=r.best()
	h.panel(Rect2(52,295,436,471),UI.PANEL,12,Color(UI.GOLD,.4))
	h.text("MAÇIN OYUNCUSU",Vector2(80,332),14,UI.GOLD,true)
	if best.is_empty():
		h.text("Henüz yeterli maç verisi yok.",Vector2(80,413),18,UI.PAPER)
	else:
		var tint: Color=UI.club_tint(g.clubs.data(best.team))
		h.draw_circle(Vector2(270,441),77,Color(tint,.18))
		h.center("%02d" % best.shirt,Vector2(270,470),65,tint)
		fit(h,best.name,Vector2(80,558),378,26)
		fit(h,g.team_name(best.team),Vector2(80,587),378,14,UI.MUTE)
		h.text("%.1f" % r.rating(best),Vector2(80,659),52,UI.GOLD,true)
		h.text("MAÇ NOTU",Vector2(193,642),12,UI.MUTE)
		h.text("%d GOL   ·   %d ŞUT" % [best.goals,best.shots],Vector2(193,671),14,UI.PAPER)
		h.text("%d KURTARIŞ   ·   %d TOPA MÜDAHALE" % [best.saves,best.tackles],Vector2(80,724),13,UI.MUTE)
	h.panel(Rect2(508,295,880,327),UI.PANEL,12,UI.LINE)
	h.text("MAÇIN ÖNEMLİ ANLARI",Vector2(535,332),14,UI.ACCENT,true)
	if r.events.is_empty(): h.text("Gol, kart veya oyuncu değişikliği yok.",Vector2(535,391),18,UI.MUTE)
	for i in range(r.event_page*5,mini(r.events.size(),r.event_page*5+5)):
		var e: Dictionary=r.events[i]; var y: float=369+(i-r.event_page*5)*39
		h.text("%d′" % e.minute,Vector2(535,y+6),16,UI.ACCENT,true)
		fit(h,e.kind,Vector2(594,y+6),225,13,UI.GOLD if str(e.kind).begins_with("GOL") else UI.MUTE)
		fit(h,e.label,Vector2(821,y+6),535,16)
	if r.events.size()>5:
		h.text("%d / %d" % [r.event_page+1,ceili(r.events.size()/5.0)],Vector2(535,598),13,UI.MUTE)
		h.button(Rect2(902,574,202,36),"← ÖNCEKİ","",false); h.button(Rect2(1116,574,242,36),"SONRAKİ →","",false)
	h.panel(Rect2(508,640,880,126),UI.PANEL,12,UI.LINE)
	h.text("KARİYERE ETKİSİ" if not r.career_before.is_empty() else "BİR SONRAKİ MAÇA HAZIR",Vector2(535,670),13,UI.ACCENT,true)
	if r.consequences.is_empty():
		h.text("Oyuncu notları ve takım istatistiklerini sekmelerden incele.",Vector2(535,705),17,UI.PAPER)
		h.text("Tekrar oyna ile aynı eşleşmeyi yeniden başlatabilirsin.",Vector2(535,738),14,UI.MUTE)
	else:
		for i in range(r.consequences.size()): fit(h,r.consequences[i],Vector2(535,696+i*25),822,15)

static func ratings(h) -> void:
	var g=h.game; var r=g.match_report
	for team in [0,1]:
		var x: float=52+team*678
		h.panel(Rect2(x,295,658,409),UI.PANEL,12,UI.LINE)
		fit(h,g.team_name(team),Vector2(x+20,330),420,21)
		for col in [["DK",357],["GOL",415],["ŞUT",475],["KRT",534],["NOT",591]]: h.text(col[0],Vector2(x+col[1],365),12,UI.MUTE,true)
		var list: Array=r.participants(team)
		for i in range(r.roster_page*8,mini(list.size(),r.roster_page*8+8)):
			var p: Dictionary=list[i]; var y: float=392+(i-r.roster_page*8)*39
			fit(h,"%02d  %s" % [p.shirt,p.name],Vector2(x+20,y),326,16)
			h.text(str(roundi(p.minutes)),Vector2(x+357,y),14,UI.MUTE)
			h.text(str(p.goals),Vector2(x+426,y),15)
			h.text(str(p.shots),Vector2(x+483,y),15)
			h.text("K" if p.red else (str(p.yellow)+"S" if p.yellow else "—"),Vector2(x+540,y),14,UI.RED if p.red else UI.GOLD)
			h.text("%.1f" % r.rating(p),Vector2(x+591,y),17,UI.ACCENT,true)
	h.button(Rect2(565,720,144,38),"← ÖNCEKİ","",false); h.button(Rect2(731,720,144,38),"SONRAKİ →","",false)
	h.center("Notlar: gol, şut, kurtarış, topa müdahale ve kartlar. Oynamayan yedekler listelenmez.",Vector2(720,789),13,UI.MUTE,false)

static func stats(h) -> void:
	var g=h.game
	h.panel(Rect2(52,295,1336,471),UI.PANEL,12,UI.LINE)
	var total: float=g.possession[0]+g.possession[1]
	var home: int=roundi(g.possession[0]/total*100) if total>0 else 50
	var data: Array=[["ŞUT",g.shots],["İSABETLİ ŞUT",g.shots_on_target],["PAS",g.passes],["KURTARIŞ",g.saves],["TOPA SAHİP OLMA (%)",[home,100-home]]]
	for i in range(data.size()):
		var y:=342+i*86; var values: Array=data[i][1]
		h.center(data[i][0],Vector2(720,y),14,UI.MUTE)
		h.text(str(values[0]),Vector2(176,y+5),26,UI.ACCENT,true)
		h.text(str(values[1]),Vector2(1220,y+5),26,UI.BLUE,true)
		var share: float=float(values[0])/maxf(1,values[0]+values[1])
		h.draw_style_box(UI.surface(UI.LINE,Color.TRANSPARENT,3),Rect2(289,y+14,862,7))
		if values[0]+values[1]>0:
			h.draw_rect(Rect2(289,y+14,862*share,7),UI.ACCENT)
			h.draw_rect(Rect2(289+862*share,y+14,862*(1-share),7),UI.BLUE)
