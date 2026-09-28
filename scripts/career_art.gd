extends RefCounted
const Style=preload("res://scripts/ui_style.gd")
const WHITE=Style.PAPER
const MUTED=Style.MUTE
const LIME=Style.ACCENT
const BLUE=Style.BLUE

func fade(s,rect: Rect2,left: Color,right: Color) -> void:
	s.draw_polygon(PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]),PackedColorArray([left,right,right,left]))

func surface(s,rect: Rect2,_accent: Color=LIME) -> void:
	s.box(rect,Style.PANEL,12,Style.LINE)

func notice_rect(s) -> Rect2:
	var occupied: Array=[]
	for child in s.controls.get_children():
		if child is BaseButton and child.visible and child.position.y>=810:
			occupied.append(Vector2(child.position.x,child.position.x+child.size.x))
	occupied.sort_custom(func(a,b): return a.x<b.x)
	occupied.append(Vector2(1412,1412))
	var cursor:=36.0; var best:=Vector2.ZERO
	for span: Vector2 in occupied:
		if span.x-cursor>best.y: best=Vector2(cursor,span.x-cursor)
		cursor=maxf(cursor,span.y)
	return Rect2(best.x+14,828,maxf(0,best.y-28),42)

func background(s) -> void:
	s.draw_rect(s.game.ui.bounds(),Color("081019"))
	var tint: Color=Style.club_tint(s.game.career.club()) if s.game.career.exists() else BLUE
	fade(s,s.game.ui.bounds(),Style.INK.lerp(tint,.16),Style.INK)
	s.draw_rect(Rect2(0,817,1440,83),Color("081019"))
	s.draw_line(Vector2(52,807),Vector2(1396,807),Color("314252"),1)
	s.draw_texture_rect(s.Brand.CREST,Rect2(49,26,51,51),false)
	s.text("SEFC",Vector2(112,51),25,WHITE,true)
	s.text("KARİYER",Vector2(113,73),12,MUTED)
	if s.game.career.exists() and not s.page in ["entry","choose"]:
		var c: Dictionary=s.game.career.club()
		s.badge(Vector2(300,51),c,.62)
		Style.fit(s,s.bold,c.name,Vector2(335,53),700,23,WHITE)
		s.text(s.World.LEAGUES[int(c.league)],Vector2(337,75),11,MUTED)
		s.text(s.World.date_label(s.game.career.world.date),Vector2(1115,45),14,WHITE,true)
		s.text("BÜTÇE  "+s.game.career.money(c.budget),Vector2(1115,70),13,LIME,true)
	else:
		s.text("BİR KULÜP. SENİN HİKÂYEN.",Vector2(910,59),23,WHITE,true)
	if s.status!="":
		var notice:=notice_rect(s)
		s.box(notice,Color("243b38"),8)
		s.wrapped(s.status,notice.position+Vector2(12,16),notice.size.x-24,12,LIME,2)
	if s.game.controller.using_gamepad:
		var hints: Array=[["LS / D-PAD","Gez"],["A","Seç"],["B","Geri"]]
		if s.page in s.PAGES or s.page in s.director_ui.PAGES: hints.append(["LB / RB","Bölüm"])
		if s.page in ["squad","market"]: hints.append(["LT / RT","Sayfa"])
		if s.page=="tactics":
			hints.append(["Y","Kadro" if s.tactics.settings_open else "Ayarlar"])
			if not s.tactics.settings_open: hints.append(["LT / RT","Yedekler"])
			if not s.tactics.undo_lineup.is_empty() and not s.live: hints.append(["X","Geri al"])
			elif s.tactics.pending_index(s)>=0: hints.append(["X","İptal"])
		s.game.controller.Glyphs.draw_hints(s,Vector2(54,884),hints,s.game.controller.family,s.font,22,11)
	else: s.text("YÖN TUŞLARI  GEZ     ENTER  SEÇ     ESC  GERİ"+("     PAGE UP / DOWN  SAYFA" if s.page in ["squad","market"] else ("     T  AYARLAR     Z  GERİ AL     PAGE UP / DOWN  YEDEKLER" if s.page=="tactics" else "")),Vector2(54,891),11,MUTED)

func card_icon(canvas,at: Vector2,kind: String,color: Color) -> void:
	var muted:=Color(color,.24)
	canvas.draw_arc(at,38,0,TAU,48,muted,1.5,true)
	if kind=="market":
		for sign_value in [-1,1]:
			var y: float=at.y+sign_value*10
			canvas.draw_line(Vector2(at.x-24,y),Vector2(at.x+24,y),color,3,true)
			var end:=Vector2(at.x+sign_value*24,y)
			canvas.draw_polyline(PackedVector2Array([end+Vector2(-sign_value*9,-8),end,end+Vector2(-sign_value*9,8)]),color,3,true)
	elif kind=="board":
		canvas.draw_circle(at+Vector2(0,-10),10,color,false,2,true)
		canvas.draw_arc(at+Vector2(0,22),22,PI,TAU,24,color,2,true)
		canvas.draw_line(at+Vector2(-23,22),at+Vector2(23,22),color,2,true)
	elif kind=="finance":
		for i in range(4): canvas.draw_rect(Rect2(at+Vector2(-26+i*15,22-i*10),Vector2(9,8+i*10)),color)
	elif kind=="trophy":
		canvas.draw_polyline(PackedVector2Array([at+Vector2(-18,-24),at+Vector2(-13,4),at+Vector2(0,15),at+Vector2(13,4),at+Vector2(18,-24),at+Vector2(-18,-24)]),color,3,true)
		canvas.draw_line(at+Vector2(0,15),at+Vector2(0,30),color,3,true)
		canvas.draw_line(at+Vector2(-14,30),at+Vector2(14,30),color,3,true)
	else:
		canvas.draw_rect(Rect2(at-Vector2(24,28),Vector2(48,56)),color,false,2)
		canvas.draw_line(at-Vector2(24,0),at+Vector2(24,0),color,2,true)
		canvas.draw_circle(at,8,color,false,2,true)

func hub(s) -> void:
	var c=s.game.career; var f: Dictionary=c.next_fixture()
	Style.fit(s,s.font,"EZELİ RAKİP · "+s.World.Rivalries.label(c.club(),c.world.clubs),Vector2(55,166),1030,12,MUTED)
	s.text("DÜNYA #%d  ·  LİG #%d" % [c.world.rankings.clubs[c.world.user].rank,c.world.rankings.leagues[str(c.club().league)].rank],Vector2(1170,166),12,LIME,true)
	var rect:=Rect2(52,176,810,432)
	surface(s,rect)
	var image: Texture2D=s.showcase.picture()
	if image!=null: s.draw_texture_rect(image,rect,false)
	fade(s,rect,Color(.035,.075,.11,.98),Color(.03,.06,.1,.04))
	s.text("MAÇ GÜNÜ" if not f.is_empty() and f.day<=c.world.date else "KARİYER MERKEZİ",Vector2(78,214),12,LIME,true)
	var derby: Dictionary=s.World.Rivalries.fixture(f)
	s.text("Derbi günü" if not derby.is_empty() else "Sıradaki maç" if not f.is_empty() else "Sezon tamamlandı",Vector2(77,258),34,WHITE,true)
	s.text(s.showcase.hero_label,Vector2(596,486),12,MUTED,true)
	Style.fit(s,s.bold,s.showcase.hero_name,Vector2(596,510),244,17,WHITE)
	if not f.is_empty():
		var opp: String=f.away if f.home==c.world.user else f.home
		s.badge(Vector2(135,336),c.club(),1.25); s.badge(Vector2(382,336),c.world.clubs[opp],1.25)
		s.center("VS",Vector2(257,345),26,LIME,true)
		s.center(c.club().short,Vector2(135,412),23,WHITE,true); s.center(c.world.clubs[opp].short,Vector2(382,412),23,WHITE,true)
		s.text(c.cups.fixture_label(f),Vector2(79,455),15,LIME,true)
		s.text(s.World.date_label(f.day)+"   /   "+("İÇ SAHA" if f.home==c.world.user else "DEPLASMAN"),Vector2(79,484),14,WHITE)
	else:
		s.text("YENİ SEZON.",Vector2(79,347),43,LIME,true)
		s.text("YENİ BİR HEDEF.",Vector2(79,404),36,WHITE,true)
	var table: Array=c.standings(int(c.club().league))
	surface(s,Rect2(884,176,512,304),BLUE)
	s.text("Ligdeki yerin",Vector2(910,212),21,WHITE,true)
	var nearby: Array=table.slice(0,5)
	if not c.world.user in nearby and not nearby.is_empty(): nearby[-1]=c.world.user
	for n in range(nearby.size()):
		var id: String=nearby[n]; var y:=247+n*38
		if id==c.world.user: s.box(Rect2(899,y-24,481,35),Color("304a49"),4)
		s.text("%02d" % (table.find(id)+1),Vector2(911,y),12,MUTED)
		s.badge(Vector2(960,y-7),c.world.clubs[id],.40)
		s.draw_string(s.bold,Vector2(987,y),c.world.clubs[id].name,HORIZONTAL_ALIGNMENT_LEFT,320,14,WHITE)
		s.text(str(c.world.table[id].pts),Vector2(1339,y),19,LIME,true)
	surface(s,Rect2(884,494,512,114),Color("e7c993"))
	s.text("%d BEKLEYEN TEKLİF" % s.pending_offers() if s.pending_offers()>0 else "KULÜPTEN HABERLER",Vector2(910,522),12,BLUE,true)
	if not c.world.news.is_empty():
		var item: Dictionary=c.world.news[0]
		s.draw_string(s.bold,Vector2(910,551),item.title,HORIZONTAL_ALIGNMENT_LEFT,456,19,WHITE)
		if s.pending_offers()==0: s.wrapped(item.body,Vector2(910,577),452,12,MUTED,2)

func players(s) -> void:
	s.PlayerList.header(s)
	var c=s.game.career
	if s.page=="squad": s.text("TAKIMIN  /  %d" % s.list_ids.size(),Vector2(54,205),23,WHITE,true)
	s.center("%d / %d" % [s.list_page+1,maxi(1,ceili(s.list_ids.size()/9.0))],Vector2(682,778),15,MUTED)
	if s.selected=="":
		surface(s,Rect2(887,174,510,628))
		card_icon(s,Vector2(1138,339),"market",BLUE)
		s.wrapped("Bu filtreye uyan oyuncu yok. Aramayı veya filtreleri değiştirebilirsin.",Vector2(920,431),440,23,MUTED,4)
		return
	var p: Dictionary=c.player(s.selected)
	surface(s,Rect2(887,174,510,628))
	var color: Color=Color(c.world.clubs[p.club].primary) if p.club!="" else BLUE
	s.box(Rect2(904,191,476,194),Style.PANEL.lerp(color,.14),9)
	var photo: Texture2D=s.portraits.photo(s.portrait_data(s.selected))
	if photo!=null: s.draw_texture_rect(photo,Rect2(1121,165,248,248),false)
	s.text(str(s.World.ovr(p)),Vector2(914,252),65,LIME,true)
	s.text(s.World.ROLES[p.role],Vector2(918,279),12,WHITE,true)
	if p.club!="": s.badge(Vector2(945,327),c.world.clubs[p.club],.68)
	s.draw_string(s.bold,Vector2(915,372),c.world.clubs[p.club].name if p.club!="" else "SERBEST OYUNCU",HORIZONTAL_ALIGNMENT_LEFT,196,12,WHITE)
	Style.fit(s,s.bold,p.name,Vector2(912,397),460,24,WHITE)
	s.text("%d YAŞ  /  %d cm  /  %d kg  /  %s" % [p.age,p.height_cm,p.weight_kg,s.World.International.NATIONS.get(p.get("nationality","TR"),"TÜRKİYE")],Vector2(914,421),12,MUTED)
	var keys: Array=["pace","finishing","passing","control","defending","stamina"] if not p.keeper else ["reflexes","handling","positioning","passing","pace","stamina"]
	var labels: Array=["HIZ","ŞUT","PAS","TEKNİK","SAVUNMA","DAYANIKLILIK"] if not p.keeper else ["REFLEKS","TUTUŞ","POZİSYON","PAS","HIZ","DAYANIKLILIK"]
	for n in range(6):
		var at:=Vector2(916+(n%3)*152,454+(n/3)*45)
		var val: int=p.attributes.get(keys[n],72)
		Style.fit(s,s.font,labels[n],at,102,12,MUTED)
		s.text(str(val),at+Vector2(106,0),18,WHITE,true)
		s.box(Rect2(at+Vector2(0,10),Vector2(131,4)),Style.LINE,2)
		s.box(Rect2(at+Vector2(0,10),Vector2(131*val/100.0,4)),LIME if val>=70 else BLUE,2)
	var loan: Dictionary=p.get("loan",{}); var retiring: bool=p.get("retirement_year",0)>0
	s.text("MAAŞ  "+c.money(p.wage)+" / AY",Vector2(916,548),14,WHITE,true)
	s.text("EMEKLİLİK  HAZİRAN "+str(p.retirement_year) if retiring else "SÖZLEŞME  HAZİRAN "+str(p.contract),Vector2(916,576),12,Color("e8bb99") if retiring else MUTED)
	if not loan.is_empty():
		s.text("KİRALIK  ·  "+s.World.date_label(loan.end)+"  ·  MAAŞ PAYI %"+str(100-int(loan.share) if loan.owner==c.world.user else int(loan.share)),Vector2(916,598),11,BLUE)
		s.text("BONSERVİS  "+c.world.clubs[loan.owner].name,Vector2(916,620),11,MUTED)
	else: s.text("CEZALI" if p.banned>0 else ("SAKAT  ·  "+s.World.date_label(p.injury) if p.injury>c.world.date else "HAZIR  ·  FORM %+.0f" % (p.form*100)),Vector2(916,607),12,LIME,true)
	if s.page=="market":
		var reason: String=c.contracts.transfer_lock(s.selected)
		if reason!="": s.wrapped(reason,Vector2(916,659),440,14,Color("e8bb99"),3)
		else:
			s.text("PİYASA DEĞERİ  "+c.money(0 if p.club=="" else c.market.value(p)),Vector2(916,656),23,WHITE,true)
			s.text(("DÖNEM AÇIK" if c.window_open() else "DÖNEM KAPALI")+" · KULÜP %.0f / LİG %.0f İTİBAR" % [s.World.Rankings.prestige(c.world,c.world.user),c.world.rankings.leagues[str(c.club().league)].points],Vector2(916,688),12,LIME)
			var interest: Dictionary=c.market.interest(p,c.world.user)
			s.text(interest.label,Vector2(916,713),11,Color("e8bb99") if interest.gap>4 else MUTED)
	elif not loan.is_empty(): s.text("OPSİYON  "+c.money(loan.option) if loan.option>0 else "SATIN ALMA OPSİYONU YOK",Vector2(916,709),12,MUTED)

func entry(s) -> void:
	s.text("Kariyerin",Vector2(53,167),44,WHITE,true)
	s.text("Kaldığın yerden devam et veya yeni bir kulüple başla.",Vector2(55,211),20,MUTED)
	for i in range(3):
		var x:=50+i*458
		surface(s,Rect2(x,270,418,475),[LIME,BLUE,Color("e6c299")][i])
		s.text("KARİYER   /   %02d" % (i+1),Vector2(x+26,310),12,LIME,true)
		var saved: Dictionary=s.summaries[i] if i<s.summaries.size() else {}
		if saved.is_empty():
			card_icon(s,Vector2(x+322,388),"trophy",Color("778d9f"))
			s.text("Yeni kariyer",Vector2(x+25,404),31,WHITE,true)
			s.text("Bir kulüp seçerek başla.",Vector2(x+25,449),14,MUTED)
		else:
			s.badge(Vector2(x+327,393),saved.badge,1.2)
			s.draw_string(s.bold,Vector2(x+25,422),saved.name,HORIZONTAL_ALIGNMENT_LEFT,269,25,WHITE)
			s.text(s.World.LEAGUES[int(saved.league)],Vector2(x+25,453),13,LIME)
			s.text(s.World.date_label(saved.date),Vector2(x+25,480),14,MUTED)
		s.text("Kayıtlar birbirinden bağımsızdır.",Vector2(x+26,702),13,MUTED)
	s.text("%d LİG     /     3 KUPA     /     %d KULÜP     /     TEK FUTBOL HİKÂYESİ" % [s.World.LEAGUES.size(),s.World.CLUB_COUNT],Vector2(54,783),14,MUTED)

func pitch(s,rect: Rect2,alpha: float=1.0) -> void:
	var ink:=Color("92b8af"); ink.a=alpha
	s.draw_rect(rect,ink,false,1.5)
	s.draw_line(Vector2(rect.position.x,rect.get_center().y),Vector2(rect.end.x,rect.get_center().y),ink,1.5,true)
	s.draw_arc(rect.get_center(),rect.size.x*.12,0,TAU,48,ink,1.5,true)
	for bottom in [false,true]:
		var y:=rect.end.y-rect.size.y*.16 if bottom else rect.position.y
		s.draw_rect(Rect2(rect.position.x+rect.size.x*.3,y,rect.size.x*.4,rect.size.y*.16),ink,false,1.5)

func tactics(s) -> void:
	s.tactics.draw(s)
