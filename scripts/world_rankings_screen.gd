extends RefCounted
const World=preload("res://scripts/career_world.gd")
const Style=preload("res://scripts/ui_style.gd")
var mode:=0
var page:=0
var personal:=false
var ids: Array=[]

func button(s,rect: Rect2,label: String,action: Callable,primary: bool=false) -> Button:
	return s.button(rect,label,action,primary) if personal else s.button_at(rect,label,action,primary)

func build(s,is_personal: bool=false) -> void:
	personal=is_personal
	var w: Dictionary=s.game.career.world
	ids=World.Rankings.ordered(w.rankings.clubs if mode==0 else w.rankings.leagues)
	page=clampi(page,0,maxi(0,(ids.size()-1)/10))
	var top:=280 if personal else 176
	for i in range(2): button(s,Rect2(52+i*228,top,216,42),["KULÜPLER","LİGLER"][i],func(): mode=i; page=0; s.build(),mode==i)
	button(s,Rect2(698,top,250,42),"KULÜBÜMÜ BUL" if mode==0 else "LİGİMİ BUL",func():
		page=maxi(0,ids.find(w.user if mode==0 else str(w.clubs[w.user].league)))/10; s.build())
	button(s,Rect2(340,823,190,46) if personal else Rect2(52,top+485,190,38),"← ÖNCEKİ",func(): page-=1; s.build()).disabled=page==0
	button(s,Rect2(550,823,190,46) if personal else Rect2(758,top+485,190,38),"SONRAKİ →",func(): page+=1; s.build()).disabled=(page+1)*10>=ids.size()
	if not personal:
		button(s,Rect2(52,827,280,43),"← LİG & KUPALAR",s.go.bind("league"))
		button(s,Rect2(1110,827,286,43),"KARİYERİ KAYDET",s.save_game)

func fit(s,value: String,at: Vector2,width: float,size: int=16,color: Color=Style.PAPER,strong: bool=false) -> void:
	Style.fit(s,s.bold if strong else s.font,value,at,width,size,color)

func movement(row: Dictionary) -> String:
	var change: int=int(row.start_rank)-int(row.rank)
	return "↑ %d" % change if change>0 else "↓ %d" % -change if change<0 else "—"

func draw(s) -> void:
	var c=s.game.career; var w: Dictionary=c.world
	var top:=280 if personal else 176
	if not personal: s.text("DÜNYA SIRALAMASI",Vector2(52,141),29,Style.PAPER,true)
	var rows: Dictionary=w.rankings.clubs if mode==0 else w.rankings.leagues
	s.box(Rect2(52,top+60,896,412),Style.PANEL,12,Style.LINE)
	for label in [["SIRA",75],["SEZON",125],["KULÜP" if mode==0 else "LİG",206],["LİG" if mode==0 else "ULUSLARARASI MAÇ",537],["PUAN",827]]:
		s.text(label[0],Vector2(label[1],top+86),11,Style.MUTE,true)
	for n in range(page*10,mini((page+1)*10,ids.size())):
		var id: String=ids[n]; var row: Dictionary=rows[id]; var y:=top+121+(n%10)*35
		var mine: bool=id==w.user if mode==0 else int(id)==int(c.club().league)
		if mine: s.box(Rect2(64,y-25,872,33),Color("2d443b"),5)
		s.text("%02d" % int(row.rank),Vector2(76,y),17,Style.ACCENT if mine else Style.PAPER,true)
		s.text(movement(row),Vector2(126,y),14,Style.ACCENT if row.rank<row.start_rank else Style.RED if row.rank>row.start_rank else Style.MUTE)
		if mode==0:
			s.badge(Vector2(207,y-6),w.clubs[id],.28)
			fit(s,w.clubs[id].name,Vector2(229,y),295,15,Style.PAPER,mine)
			fit(s,World.LEAGUES[int(w.clubs[id].league)],Vector2(537,y),242,12,Style.MUTE)
		else:
			fit(s,World.LEAGUES[int(id)],Vector2(207,y),316,16,Style.PAPER,mine)
			s.text(str(row.matches),Vector2(595,y),15,Style.MUTE)
		s.text("%.1f" % float(row.points),Vector2(819,y),17,Style.ACCENT,true)
	s.center("%d / %d  ·  %d %s" % [page+1,maxi(1,ceili(ids.size()/10.0)),ids.size(),"KULÜP" if mode==0 else "LİG"],Vector2(928,853) if personal else Vector2(500,top+510),13,Style.MUTE,true)
	# One compact explanation ties sporting success to the next transfer decision.
	s.box(Rect2(974,top,422,472),Style.PANEL,12,Style.LINE)
	s.badge(Vector2(1013,top+38),c.club(),.5)
	fit(s,c.club().name,Vector2(1050,top+43),322,17,Style.PAPER,true)
	var club: Dictionary=w.rankings.clubs[w.user]; var league: Dictionary=w.rankings.leagues[str(c.club().league)]
	s.text("DÜNYADA",Vector2(1000,top+91),12,Style.MUTE,true)
	s.text("#%d" % int(club.rank),Vector2(998,top+145),49,Style.ACCENT,true)
	s.text("%.1f BAŞARI PUANI" % float(club.points),Vector2(1146,top+126),13,Style.PAPER,true)
	s.text("SEZON BAŞINDAN  %+.1f" % (float(club.points)-float(club.start_points)),Vector2(1146,top+150),11,Style.MUTE)
	s.draw_line(Vector2(999,top+175),Vector2(1371,top+175),Style.LINE,1)
	s.text("KULÜP İTİBARI",Vector2(1000,top+207),12,Style.MUTE)
	s.text("%.1f / 100" % World.Rankings.prestige(w,w.user),Vector2(1266,top+207),16,Style.PAPER,true)
	s.text("LİG İTİBARI",Vector2(1000,top+241),12,Style.MUTE)
	s.text("%.1f / 100" % float(league.points),Vector2(1266,top+241),16,Style.PAPER,true)
	fit(s,"LİGİN DÜNYA SIRASI  #%d" % int(league.rank),Vector2(1000,top+274),371,13,Style.ACCENT,true)
	s.text("TRANSFERDE NE DEĞİŞİR?",Vector2(1000,top+313),14,Style.ACCENT,true)
	var lines: Array=["Başarı, daha iyi oyuncuların kulübüne", "gelmesini kolaylaştırır. Güçlü lig de", "çekiciliğini artırır. Maaş, kadro ve rol", "beklentileri kararın parçasıdır."]
	for i in range(lines.size()): fit(s,lines[i],Vector2(1000,top+343+i*23),371,14,Style.MUTE)
	if not personal:
		s.text("Güçlü rakibi yenmek daha değerli. Kupalar ek puan getirir; yenilgiler puan kaybettirir.",Vector2(55,747),15,Style.MUTE)
		s.text("Oklar sezon başına göre değişimi gösterir. Lig puanı, temsilci sayısına göre dengelenir.",Vector2(55,775),13,Style.MUTE)
