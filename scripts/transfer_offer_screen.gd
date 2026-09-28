extends RefCounted
const World=preload("res://scripts/career_world.gd")
const Style=preload("res://scripts/ui_style.gd")
const ROLES:=["GELİŞİM","ROTASYON","İLK 11"]
var selected: Dictionary={}
var fee:=0
var wage:=500
var years:=3
var role:=1
var bonus:=0
var personal:=false

func choose(s,o: Dictionary) -> void:
	selected=o; sync(); s.build()

func sync() -> void:
	if selected.is_empty(): return
	fee=selected.fee; wage=int(selected.get("wage",500)); years=int(selected.get("years",3))
	role=int(selected.get("role",1)); bonus=int(selected.get("signing",0))

func button(s,rect: Rect2,label: String,action: Callable,primary: bool=false) -> Button:
	var control: Button=s.button(rect,label,action,primary) if personal else s.button_at(rect,label,action,primary)
	if rect.size.x<=60:
		for state in ["normal","hover","pressed","focus"]:
			var style: StyleBox=control.get_theme_stylebox(state).duplicate()
			style.content_margin_left=6; style.content_margin_right=6
			control.add_theme_stylebox_override(state,style)
	return control

func number(s,rect: Rect2,key: String,step: int,minimum: int,maximum: int) -> void:
	button(s,Rect2(rect.position,Vector2(40,42)),"−",func(): set(key,clampi(int(get(key))-step,minimum,maximum)); s.queue_redraw())
	button(s,Rect2(rect.end-Vector2(40,42),Vector2(40,42)),"+",func(): set(key,clampi(int(get(key))+step,minimum,maximum)); s.queue_redraw())

func build(s,is_personal: bool=false) -> void:
	personal=is_personal
	var c=s.game.career; var entries: Array=c.offers.active(personal)
	if personal:
		if selected.is_empty() or selected not in c.world.offers:
			selected=entries[0] if not entries.is_empty() else {}; sync()
		for i in range(mini(3,entries.size())):
			var o: Dictionary=entries[i]
			button(s,Rect2(72,343+i*95,359,44),c.world.clubs[o.buyer].name,choose.bind(s,o),o==selected)
	else: button(s,Rect2(52,824,300,44),"← GELEN TEKLİFLER",func(): s.go("finance"))
	if selected.is_empty() or not c.offers.live(selected): return
	if personal:
		number(s,Rect2(507,470,272,42),"wage",maxi(500,roundi(selected.wage*.1/500)*500),500,100000000)
		number(s,Rect2(803,470,272,42),"bonus",maxi(500,roundi(selected.wage*.5/500)*500),0,1000000000)
		number(s,Rect2(1099,470,272,42),"years",1,1,5)
		s.option(Rect2(507,542,420,43),ROLES,role,func(v): role=v)
	else: number(s,Rect2(507,470,864,42),"fee",maxi(10000,roundi(c.market.value(c.player(selected.player))*.05/10000)*10000),10000,2000000000)
	var y:=608 if personal else 548
	button(s,Rect2(507,y,416,48),"KARŞI TEKLİF SUN",func():
		if personal: c.offers.counter_personal(selected,wage,years,role,bonus)
		else: c.offers.counter_sale(selected,fee)
		sync(); s.build()).disabled=int(selected.get("rounds",0))>=3
	button(s,Rect2(947,y,424,48),"KULÜBÜN TEKLİFİNİ İMZALA" if personal else "SATIŞI TAMAMLA",func():
		var ok: bool=c.offers.accept_personal(selected) if personal else c.accept_sale(c.world.offers.find(selected))
		if ok: selected.response="İmzalar atıldı. Yeni kulübüne hoş geldin." if personal else "Satış tamamlandı. Bonservis kulüp kasasına işlendi."
		else: selected.response=c.error if not c.error.is_empty() else "İmza atılamadı. Dönem, kadro veya kulüp bütçesi değişmiş olabilir."
		s.build(),true)
	button(s,Rect2(72,715,359,35),"TEKLİFİ REDDET",func(): c.offers.reject(selected); s.build())

func fit(s,value: String,at: Vector2,width: float,size: int=16,color: Color=Style.PAPER,strong: bool=false) -> void:
	Style.fit(s,s.bold if strong else s.font,value,at,width,size,color)

func wrapped(s,value: String,at: Vector2,width: float,limit: int=3) -> void:
	var line:=""; var row:=0
	for word in value.split(" "):
		if s.font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x>width:
			s.text(line,at+Vector2(0,row*25),16,Style.ACCENT); row+=1; line=""
			if row>=limit: return
		line+=word+" "
	s.text(line,at+Vector2(0,row*25),16,Style.ACCENT)

func draw(s) -> void:
	var c=s.game.career
	if not personal: s.text("GELEN TEKLİF · PAZARLIK MASASI",Vector2(52,145),25,Style.PAPER,true)
	s.box(Rect2(52,282,401,474),Style.PANEL,12)
	s.box(Rect2(479,282,917,474),Style.PANEL,12)
	if personal:
		s.text("SANA GELEN TEKLİFLER",Vector2(74,320),15,Style.ACCENT,true)
		var entries: Array=c.offers.active(true)
		for i in range(mini(3,entries.size())):
			var o: Dictionary=entries[i]
			fit(s,c.money(o.wage)+" / ay · "+ROLES[o.role],Vector2(80,411+i*95),342,15)
			fit(s,"Son gün: "+World.date_label(o.expires),Vector2(80,432+i*95),342,12,Style.MUTE)
		if entries.is_empty():
			wrapped(s,"Şu anda açık teklif yok.",Vector2(76,379),345)
			fit(s,"Form, süre ve mevcut gücün belirleyici.",Vector2(76,427),345,15,Style.MUTE)
			var recent: bool=c.world.date-int(s.game.legend.data().get("transfer_day",-100))<45
			fit(s,"Yeni takımına alışma dönemi." if recent else "En az 3 maç ve 90 dakika oyna.",Vector2(76,454),345,15,Style.MUTE)
		s.text("MEVCUT MAAŞIN",Vector2(76,646),12,Style.MUTE)
		s.text(c.money(s.game.legend.player().wage)+" / ay",Vector2(76,677),24,Style.PAPER,true)
		fit(s,"TRANSFER DÖNEMİ AÇIK" if c.window_open() else "TRANSFER DÖNEMİ KAPALI",Vector2(76,703),345,12,Style.ACCENT)
	elif not selected.is_empty():
		var p: Dictionary=c.player(selected.player)
		fit(s,p.name,Vector2(76,329),350,25,Style.PAPER,true)
		fit(s,"GEN %d · %d YAŞ · %s" % [World.ovr(p),p.age,World.ROLES[p.role]],Vector2(76,365),350,16,Style.MUTE)
		s.text("PİYASA DEĞERİ",Vector2(76,415),12,Style.MUTE)
		s.text(c.money(c.market.value(p)),Vector2(76,452),29,Style.PAPER,true)
		s.text("GÖRÜŞME GEÇMİŞİ",Vector2(76,517),12,Style.ACCENT,true)
		var history: Array=selected.get("history",[])
		for i in range(mini(3,history.size())):
			var entry: Dictionary=history[maxi(0,history.size()-3)+i]
			var line: String=entry.text
			while s.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x>330: line=line.left(line.length()-1)
			fit(s,line+("…" if line!=entry.text else ""),Vector2(76,555+i*53),350,13,Style.MUTE)
		var t: Dictionary=p.get("terms",{})
		var cut:=int(t.get("sell_on",0)) if c.world.clubs.has(t.get("beneficiary","")) and t.get("beneficiary","")!=p.club else 0
		fit(s,"Satış payı sonrası: "+c.money(int(selected.get("net_income",roundi(selected.fee*(1-cut/100.0))))),Vector2(76,701),350,15,Style.ACCENT)
	if selected.is_empty():
		s.text("BİR SONRAKİ ADIMIN",Vector2(507,332),21,Style.PAPER,true)
		wrapped(s,"İyi performans göster, geliş ve transfer döneminde teklifleri burada değerlendir. Her kulüp seni kendi kadrosundaki rekabete göre ister.",Vector2(507,390),800,4)
		fit(s,"Maaş · İmza parası · Sözleşme süresi · Beklenen rol",Vector2(507,557),800,20)
		fit(s,"Teklifleri kabul etmek zorunda değilsin; mevcut takımında kalabilirsin.",Vector2(507,604),800,16,Style.MUTE)
		return
	var o: Dictionary=selected; var buyer: Dictionary=c.world.clubs[o.buyer]
	s.badge(Vector2(536,326),buyer,.72)
	fit(s,buyer.name,Vector2(580,325),750,24,Style.PAPER,true)
	fit(s,"SON GÜN "+World.date_label(o.expires)+" · "+str(3-int(o.get("rounds",0)))+" PAZARLIK TURU" if c.offers.live(o) else "GÖRÜŞME TAMAMLANDI",Vector2(580,348),750,12,Style.MUTE)
	fit(s,"DÜNYA #%d · LİG #%d · KULÜP İTİBARI %.1f" % [c.world.rankings.clubs[o.buyer].rank,c.world.rankings.leagues[str(buyer.league)].rank,World.Rankings.prestige(c.world,o.buyer)],Vector2(580,367),750,11,Style.ACCENT)
	var labels: Array=["KULÜBÜN MAAŞ TEKLİFİ","İMZA PARASI","SÜRE / BEKLENEN ROL"] if personal else ["KULÜBÜN BONSERVİS TEKLİFİ","OYUNCUNUN MAAŞI","BEKLENEN ROL"]
	var values: Array=[c.money(o.wage)+" / ay",c.money(o.get("signing",0)),str(o.get("years",3))+" yıl · "+ROLES[o.get("role",1)]] if personal else [c.money(o.fee),c.money(o.get("wage",0))+" / ay",ROLES[o.get("role",1)]]
	for i in range(3):
		s.text(labels[i],Vector2(507+i*296,384),11,Style.MUTE)
		fit(s,values[i],Vector2(507+i*296,416),273,22,Style.ACCENT,true)
	if c.offers.live(o):
		if personal:
			for i in range(3):
				s.text(["MAAŞ TALEBİN / AY","İMZA PARASI TALEBİN","SÖZLEŞME SÜRESİ"][i],Vector2(507+i*296,455),11,Style.MUTE)
				fit(s,[c.money(wage),c.money(bonus),str(years)+" yıl"][i],Vector2(554+i*296,498),176,20,Style.PAPER,true)
			s.text("BEKLEDİĞİN ROL",Vector2(507,535),11,Style.MUTE)
			fit(s,"İlk 11, form ve rekabete bağlıdır.",Vector2(951,569),420,15,Style.MUTE)
		else:
			s.text("BONSERVİS TALEBİN",Vector2(507,455),11,Style.MUTE)
			s.center(c.money(fee),Vector2(939,500),26,Style.PAPER,true)
		wrapped(s,o.get("response","Teklifinizi bekliyoruz."),Vector2(507,689 if personal else 641),850,2 if personal else 3)
		if personal: fit(s,"Bonservis: "+c.money(o.fee)+" · Kulüpler arasında ödenir.",Vector2(507,746),850,12,Style.MUTE)
	else:
		wrapped(s,"TEKLİFİN SÜRESİ DOLDU" if o.expires<c.world.date else o.get("response","Görüşme kapandı."),Vector2(507,500),850,4)
