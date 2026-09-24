extends RefCounted
const World=preload("res://scripts/career_world.gd")
const PAGES:=["development","academy","relations","board","jobs"]
const TITLES:=["GELİŞİM","AKADEMİ","OYUNCU İLİŞKİLERİ","YÖNETİM","TEKNİK DİREKTÖR"]
var nation:="TR"
var role:=-1
var duration:=30
var academy_id:=""
var job:=""
var job_league:=0
var confirmed:=""

func build(s) -> void:
	var c=s.game.career
	s.button_at(Rect2(52,826,260,44),"← KARİYER MERKEZİ",func(): s.go("hub"))
	if s.page=="terms": build_terms(s); return
	for n in range(PAGES.size()): s.button_at(Rect2(52+n*270,111,256,44),TITLES[n],func(): s.page=PAGES[n]; s.build(),s.page==PAGES[n])
	match s.page:
		"development","relations":
			var ids: Array=c.roster(c.world.user)
			if s.page=="development": ids.append_array(c.world.academy.get(c.world.user,[]))
			if not s.selected in ids: s.selected=ids[0]
			s.option_at(Rect2(76,192,654,47),ids.map(func(id): return c.player(id).name+" · "+World.ROLES[c.player(id).role]),ids.find(s.selected),func(v): s.selected=ids[v]; s.build())
			var p: Dictionary=c.player(s.selected)
			s.portraits.request(s.portrait_data(s.selected))
			if s.page=="development":
				s.button_at(Rect2(77,252,653,46),"HAFTALIK ANTRENMAN · OYNA / OTOMATİK",func(): s.go("training"),true)
				s.option_at(Rect2(76,359,654,47),c.director.PLANS,int(p.development.plan),func(v): p.development.plan=v; c.save(); s.build())
				s.option_at(Rect2(76,469,654,47),["HAFİF · TOPARLANMA","NORMAL · DENGELİ","YOĞUN · HAFTALIK KONDİSYON MALİYETİ"],p.development.intensity,func(v): p.development.intensity=v; c.save(); s.build())
			else:
				s.office=s.Office.new(); s.office.position=Vector2(76,266); s.office.size=Vector2(654,366)
				s.office.club_data=c.club(); s.office.guest_data=p; s.controls.add_child(s.office)
				for n in range(4):
					s.button_at(Rect2(77+(n%2)*333,666+(n/2)*54,320,43),["PERFORMANSINI ÖV","180 DAKİKA SÖZÜ VER","ROTASYON ROLÜNÜ KONUŞ","AYRILIĞA İZİN VER"][n],func(): s.status=c.director.talk(s.selected,n); s.build())
		"academy":
			s.option_at(Rect2(77,254,622,44),World.International.NATIONS.values(),World.International.NATIONS.keys().find(nation),func(v): nation=World.International.NATIONS.keys()[v])
			s.option_at(Rect2(77,323,622,44),["TÜM MEVKİLER","KALECİ","DEFANS","ORTA SAHA","FORVET"],role+1,func(v): role=v-1)
			s.option_at(Rect2(77,388,622,44),["30 GÜN · €45.000","60 GÜN · €90.000","90 GÜN · €135.000"],[30,60,90].find(duration),func(v): duration=[30,60,90][v])
			s.button_at(Rect2(77,455,622,49),"GÖZLEMCİ GÖNDER",func(): s.status=c.director.scout(nation,role,duration); s.build(),true)
			var ids: Array=c.world.academy.get(c.world.user,[])
			if not ids.is_empty():
				if not academy_id in ids: academy_id=ids[0]
				s.option_at(Rect2(785,253,580,44),ids.map(func(id): return c.player(id).name+" · "+World.ROLES[c.player(id).role]),ids.find(academy_id),func(v): academy_id=ids[v]; s.build())
				s.portraits.request(s.portrait_data(academy_id))
				s.button_at(Rect2(786,710,372,49),"A TAKIMA YÜKSELT",func(): s.status=c.director.promote(academy_id); s.build(),true)
				s.button_at(Rect2(1170,710,196,49),"ADAYI BIRAK",func(): c.world.academy[c.world.user].erase(academy_id); c.world.players.erase(academy_id); academy_id=""; c.save(); s.build())
		"jobs":
			s.option_at(Rect2(77,255,622,44),World.LEAGUES,job_league,func(v): job_league=v; job=""; confirmed=""; s.build())
			var ids: Array=c.director.job_clubs().filter(func(id): return int(c.world.clubs[id].league)==job_league)
			if not ids.is_empty():
				if not job in ids: job=ids[0]
				s.option_at(Rect2(77,330,622,44),ids.map(func(id): return c.world.clubs[id].name),ids.find(job),func(v): job=ids[v]; confirmed=""; s.build())
				s.button_at(Rect2(77,438,622,52),"ONAYLA · KULÜP DEĞİŞTİR" if confirmed==job else "BU GÖREVİ SEÇ",func():
					if confirmed==job: s.status=c.director.accept_job(job); confirmed=""; job=""; s.build()
					else: confirmed=job; s.status="Yeni kulübün kadrosu ve bütçesini devralacaksın. Mevcut görevinden ayrılmak için onayla."; s.build(),true)

func draw(s) -> void:
	var c=s.game.career
	s.art.surface(s,Rect2(52,175,702,618))
	s.art.surface(s,Rect2(769,175,627,618),s.art.BLUE)
	if s.page=="terms": draw_terms(s); return
	match s.page:
		"development","relations":
			var p: Dictionary=c.player(s.selected)
			s.text(p.name,Vector2(795,222),25,s.PAPER,true)
			s.art.fade(s,Rect2(772,241,620,270),Color(s.art.BLUE,.09),Color(s.art.LIME,.14))
			photo(s,s.selected,Rect2(1046,228,301,301))
			s.text(str(World.ovr(p)),Vector2(807,374),92,s.art.LIME,true)
			s.text("GENEL GÜÇ",Vector2(813,403),12,s.art.MUTED,true)
			s.badge(Vector2(852,463),c.club(),.94)
			s.text("%d YAŞ  ·  GEN %d  ·  POTANSİYEL %d" % [p.age,World.ovr(p),p.potential],Vector2(795,540),19,s.GOLD,true)
			s.text("MORAL  %d / 100     SEZON  %d DK" % [p.morale*100,p.minutes],Vector2(795,578),16,s.PAPER)
			s.wrapped(p.concern if p.concern!="" else "Takımdaki rolümden memnunum.",Vector2(795,620),560,18,s.MUTE,2)
			if not p.promise.is_empty(): s.wrapped("SÖZ: "+World.date_label(p.promise.due)+" tarihine kadar 180 dakika. İlerleme: "+str(maxi(0,p.minutes-int(p.promise.start)))+" dk",Vector2(795,696),554,15,s.GOLD,3)
			if s.page=="development":
				s.text("GELİŞİM PLANI",Vector2(77,338),12,s.GOLD,true)
				s.text("ANTRENMAN YÜKÜ",Vector2(77,448),12,s.GOLD,true)
				s.text("ÖZELLİK GELİŞİMİ  %d / 100" % p.development.xp,Vector2(77,573),17,s.PAPER,true)
				s.box(Rect2(77,595,650,10),Color("304b44"),4); s.box(Rect2(77,595,650*p.development.xp/100,10),s.GOLD,4)
				for n in range(3):
					var x:=77+n*219
					s.box(Rect2(x,635,207,127),Color("1c3244"),8)
					s.text(["MAÇ SÜRESİ","POTANSİYEL","İLERLEME"][n],Vector2(x+15,662),11,s.art.MUTED,true)
					s.text([str(p.minutes)+" dk",str(p.potential),str(roundi(p.development.xp))+" / 100"][n],Vector2(x+15,705),27,s.art.LIME,true)
					s.text(["Sahada tecrübe kazanır","Gelişim tavanı","100 puanda gelişir"][n],Vector2(x+15,743),11,s.art.MUTED)
		"academy":
			s.text("YARININ İLK 11'İ",Vector2(77,220),27,s.PAPER,true)
			s.text("AKADEMİ RAPORLARI",Vector2(793,221),24,s.PAPER,true)
			var active: Array=c.world.scouts.filter(func(j): return j.club==c.world.user and not j.done)
			s.text("GÖREVDEKİ GÖZLEMCİLER  %d / 3" % active.size(),Vector2(77,554),14,s.GOLD,true)
			for n in range(active.size()): s.text(active[n].nation+"  ·  "+World.date_label(active[n].due),Vector2(77,592+n*31),19,s.PAPER)
			s.wrapped("Rapor üç aday getirir. Uzun görevlerde daha yüksek potansiyel aranır. Akademide 12 kişiye kadar yer var; haftalık eğitim alırlar.",Vector2(77,705),620,14,s.MUTE,3)
			if academy_id in c.world.academy.get(c.world.user,[]):
				var p: Dictionary=c.player(academy_id)
				s.art.fade(s,Rect2(772,310,620,248),Color(s.art.BLUE,.08),Color(s.art.LIME,.15))
				photo(s,academy_id,Rect2(1054,306,252,252))
				s.text(str(World.ovr(p)),Vector2(810,420),79,s.art.LIME,true)
				s.text("GENEL GÜÇ",Vector2(814,451),11,s.art.MUTED,true)
				s.text("%s  ·  %d YAŞ  ·  %s" % [p.nationality,p.age,World.ROLES[p.role]],Vector2(794,585),20,s.GOLD,true)
				s.text("GEN %d   /   POTANSİYEL %d" % [World.ovr(p),p.potential],Vector2(794,624),24,s.PAPER,true)
				s.text("PROFESYONEL MAAŞ  "+c.money(World.wage(p))+" / AY",Vector2(794,667),16,s.MUTE)
			else:
				for n in range(3):
					var x:=804+n*188
					s.box(Rect2(x,304,168,223),Color("1c3447"),9)
					s.art.card_icon(s,Vector2(x+84,386),"board",s.art.BLUE)
					s.center("?",Vector2(x+84,487),46,s.art.LIME,true)
				s.text("GELECEĞİN YILDIZLARI",Vector2(799,598),26,s.PAPER,true)
				s.wrapped("Gözlemciyi gönder. Döndüğünde üç adayı burada keşfet; en yeteneklileri A takıma yükselt.",Vector2(801,651),545,20,s.MUTE,4)
		"board":
			var m: Dictionary=c.world.manager
			s.text("YÖNETİMİN GÜVENİ",Vector2(77,232),26,s.PAPER,true)
			s.draw_arc(Vector2(399,420),139,0,TAU,90,Color("2a4051"),13,true)
			s.draw_arc(Vector2(399,420),139,-PI/2,-PI/2+TAU*clampf(m.trust/100.0,.001,1),90,s.art.LIME,13,true)
			s.center(str(roundi(m.trust)),Vector2(399,440),104,s.art.LIME,true)
			s.center("GÜVEN / 100",Vector2(399,479),14,s.art.MUTED,true)
			s.art.card_icon(s,Vector2(640,291),"trophy",s.art.BLUE)
			s.center("GÖREV DEVAM EDİYOR" if m.employed else "GÖREVİN SONA ERDİ",Vector2(400,618),27,s.PAPER,true)
			s.wrapped("Lig sırası, mali denge ve gençlere verilen süre her ay değerlendirilir. Güven 25'in altına düşerse görev tehlikeye girer.",Vector2(89,687),614,17,s.art.MUTED,3)
			s.text("SEZON HEDEFLERİ",Vector2(795,232),24,s.art.BLUE,true)
			var rank: int=c.standings(int(c.club().league)).find(c.world.user)+1
			var labels: Array=["LİG SIRALAMASI","AKADEMİYE FIRSAT","MALİ DENGE","TRANSFER YETKİSİ"]
			var values: Array=["%d. sıra  /  Hedef ilk %d" % [rank,m.target],"%d / 450 dakika" % m.youth_minutes,c.money(c.club().cash),c.money(c.club().budget)]
			var levels: Array=[minf(1,float(m.target)/maxi(1,rank)),minf(1,m.youth_minutes/450.0),1.0 if c.club().cash>0 else 0.0,clampf(float(c.club().budget)/maxi(1,c.club().cash),0,1)]
			for n in range(4):
				var y:=267+n*118
				s.box(Rect2(793,y,577,103),Color("1c3144"),8)
				s.text(labels[n],Vector2(811,y+25),11,s.art.MUTED,true)
				s.text(values[n],Vector2(811,y+61),24,s.PAPER,true)
				s.box(Rect2(811,y+81,541,4),Color("31495a"),2)
				s.box(Rect2(811,y+81,541*levels[n],4),s.art.LIME if n<3 else s.art.BLUE,2)

		"jobs":
			s.text("YENİ BİR SAYFA",Vector2(77,224),29,s.PAPER,true)
			s.wrapped("Başvurabileceğin kulüpler itibarına ve yönetim güvenine göre belirlenir. Takvim, diğer ligler ve transferler aynı dünyada devam eder.",Vector2(77,564),624,22,s.MUTE,5)
			if c.world.clubs.has(job):
				var q: Dictionary=c.world.clubs[job]
				s.art.pitch(s,Rect2(815,255,535,220),.15)
				s.badge(Vector2(1081,342),q,2.3); s.center(q.name,Vector2(1081,492),25,s.PAPER,true)
				s.text("GÜÇ  %d" % q.reputation,Vector2(798,567),25,s.GOLD,true)
				s.text("TRANSFER BÜTÇESİ  "+c.money(q.budget),Vector2(798,624),20,s.PAPER)
				s.text("HEDEF  "+q.objective,Vector2(798,681),20,s.MUTE)
			else: s.wrapped("Bu ligde şu anda uygun görev bulunmuyor. Başka bir lig seç.",Vector2(796,347),546,24,s.MUTE,4)

func build_terms(s) -> void:
	var d: Dictionary=s.game.career.deal
	for n in range(6):
		var key: String=["signing","appearance","goal","title","release","sell_on"][n]
		var step: int=[10000,500,500,10000,100000,5][n]
		if key=="release": step=maxi(100000,roundi(s.game.career.market.value(s.game.career.player(d.player))*.05/100000.0)*100000)
		for dir in [-1,1]:
			s.button_at(Rect2(78 if dir<0 else 645,266+n*76,61,43),"−" if dir<0 else "+",adjust_term.bind(s,key,dir*step))
	s.button_at(Rect2(798,707,568,54),"ŞARTLARI KAYDET & GÖRÜŞMEYE DÖN",func():
		if d.stage=="sign": d.stage="contract"; d.response="Güncel primlerle maaş teklifini yeniden sunabilirsin."
		s.page="talks"; s.build(),true)

func adjust_term(s,key: String,amount: int) -> void:
	var c=s.game.career; var d: Dictionary=c.deal
	var minimum: int=c.market.value(c.player(d.player))
	var limit: int=30 if key=="sell_on" else maxi(100000000,minimum*5) if key=="release" else 100000000
	var next: int=clampi(int(d.terms[key])+amount,0,limit)
	if key=="release" and next<minimum: next=minimum if amount>0 else 0
	d.terms[key]=next; s.queue_redraw()

func draw_terms(s) -> void:
	var c=s.game.career; var d: Dictionary=c.deal
	s.text("SÖZLEŞME DETAYLARI",Vector2(77,226),28,s.PAPER,true)
	for n in range(6):
		var key: String=["signing","appearance","goal","title","release","sell_on"][n]
		s.text(["İMZA PARASI","MAÇ BAŞI PRİM","GOL PRİMİ","KUPA ŞAMPİYONLUK PRİMİ","SERBEST KALMA BEDELİ","SONRAKİ SATIŞ PAYI"][n],Vector2(162,272+n*76),11,s.MUTE)
		s.text(("%%%d" % d.terms[key]) if key=="sell_on" else c.money(d.terms[key]),Vector2(162,301+n*76),24,s.PAPER,true)
	s.text("MASADAKİ TEKLİF",Vector2(798,227),26,s.GOLD,true)
	s.wrapped("İmza parası hemen ödenir. Maç, gol ve kupa primleri gerçekleştiğinde kasadan düşer. Satış payı bir sonraki nakit bonservis üzerinden eski kulübe ödenir.",Vector2(798,281),547,22,s.PAPER,7)
	s.wrapped("Serbest kalma bedeli, kulübün kabul edeceği bonservise üst sınır getirir. Kadro derinliği, transfer dönemi ve oyuncunun kararı yine geçerlidir.",Vector2(798,489),547,18,s.MUTE,4)
	if d.get("rival","")!="": s.wrapped("RAKİP TEKLİF: "+c.world.clubs[d.rival].name+" · "+c.money(d.rival_fee)+"\nSon tarih: "+World.date_label(d.deadline),Vector2(798,613),547,16,s.GOLD,3)

func photo(s,id: String,rect: Rect2) -> void:
	var texture: Texture2D=s.portraits.photo(s.portrait_data(id))
	if texture!=null: s.draw_texture_rect(texture,rect,false)
