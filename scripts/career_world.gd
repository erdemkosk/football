extends RefCounted
const Attributes = preload("res://scripts/player_attributes.gd")
const Catalog = preload("res://scripts/club_catalog.gd")
const Physique = preload("res://scripts/player_physique.gd")
const International = preload("res://scripts/career_international.gd")
const Turkey = preload("res://scripts/career_turkey.gd")
const Talent = preload("res://scripts/player_talent.gd")
const SEFC = preload("res://scripts/sefc_identity.gd")
const VERSION:=5
const CLUB_COUNT:=110
const ROLES := ["KL","DEF","OS","FV"]
const LEAGUES := ["SEFC Premier Lig","SEFC Birinci Lig","İspanya Ligi","Portekiz Ligi","İtalya Ligi","Almanya Ligi","Fransa Ligi","İngiltere Ligi","Hollanda Ligi","Türkiye Süper Ligi"]
# Keep the existing sixteen-team cup: every independent top division is represented.
const CHAMPIONS_PLACES:=[4,0,2,2,2,2,1,1,1,1]
# Game-economy rewards, independent of the number of clubs in each calendar.
const LEAGUE_CHAMPION_PRIZES:=[8000000,2000000,14000000,5000000,12000000,13000000,10000000,18000000,4000000,6000000]
const NAMES := ["ADA","ÇINAR","YALIN","KAYA","ATEŞ","TOPRAK","DORUK","POYRAZ","MERT","ALP","EMİR","CAN","EREN","BERK","ARDA","EFE","KAAN","ONUR","DENİZ","BORA","TUNA","UMUT","BARAN","AYAZ","MARC","LEO","NOAH","OMAR","ENZO","RAFA","LUKA","DIEGO"]
const SURNAMES := ["AKSOY","YILMAZ","DEMİR","KAYA","ŞEN","ARSLAN","AYDIN","KILIÇ","ÇELİK","ÖZTÜRK","GÜNEŞ","YALÇIN","MARTIN","COSTA","SILVA","MORENO"]

static func full_calendar(league: int) -> bool:
	return league in [0,1,Turkey.LEAGUE]

static func league_prize(league: int,position: int,club_count: int) -> int:
	if league<0 or league>=LEAGUE_CHAMPION_PRIZES.size() or position<1 or position>club_count: return 0
	var title: int=LEAGUE_CHAMPION_PRIZES[league]
	if position==1: return title
	var merit: float=float(club_count-position)/maxi(1,club_count-1)
	return roundi(title*(.12+.53*merit)/10000.0)*10000

static func plan() -> Dictionary:
	return {"formation":0,"mentality":1,"pressing":1,"line_height":1,"width":1,"tempo":1,"runs":1,"fullbacks":1,"anchor":true}

static func ovr(p: Dictionary) -> int:
	return Talent.overall(p)

static func value(p: Dictionary) -> int:
	var age_factor := 1.25 if p.age<24 else (.65 if p.age>30 else 1.0)
	return roundi(maxf(80000,pow(maxf(1,ovr(p)-38),2.7)*26*age_factor)/10000)*10000

static func wage(p: Dictionary) -> int:
	return maxi(1500,roundi(value(p)*.008/500)*500)

static func kit(c: Dictionary) -> Dictionary:
	return {"primary":Color(c.primary),"accent":Color(c.accent),"shorts":Color(c.shorts),"pattern":c.pattern,"club_id":c.badge_id,"badge_primary":Color(c.primary),"badge_accent":Color(c.accent)}

static func contract_fields(p: Dictionary) -> void:
	# Stable across saves and reloads; goalkeepers can have a longer career.
	if not p.has("retirement_age"): p.retirement_age=(36 if p.keeper else 34)+posmod(int(p.appearance_id)*13+int(p.role)*7,5)
	if not p.has("retirement_year"): p.retirement_year=0
	if not p.has("retired"): p.retired=false
	if not p.has("loan"): p.loan={}
	if not p.has("loan_listed"): p.loan_listed=false

static func upgrade(w: Dictionary) -> void:
	w.match_settings=preload("res://scripts/match_settings.gd").normalized(w.get("match_settings",{}))
	if not w.has("league_prizes"): w.league_prizes={}
	for p in w.players.values(): contract_fields(p)
	SEFC.upgrade(w)
	International.expand(w)
	for pid in Turkey.expand(w,plan()):
		contract_fields(w.players[pid]); w.players[pid].wage=wage(w.players[pid])
	for p in w.players.values():
		Talent.rebalance(p)
		p.potential=maxi(int(p.potential),ovr(p))
	w.version=VERSION

static func create(year: int=2026) -> Dictionary:
	var w := {"version":1,"year":year,"date":day(year,7,1),"user":"c00","clubs":{},"players":{},"fixtures":[],"table":{},"news":[],"offers":[],"history":[],"ledger":[],"deals":[],"round":0,"season_done":false,"rng":19880622,"next_player":864,"scorers":{},"results":[],"pending_fixture":""}
	var rng := RandomNumberGenerator.new(); rng.seed=11761
	for i in range(36):
		var id := "c%02d" % i
		var c: Dictionary
		if i<8: c=Catalog.CLUBS[i].duplicate(true)
		else:
			var city: String=SEFC.CLUBS[i][2]
			var hue := fmod(i*.137,1.0)
			c={"name":SEFC.CLUBS[i][0],"short":city.left(3),"city":city,"year":str(1920+i*2),"primary":Color.from_hsv(hue,.64,.66).to_html(false),"accent":"eee5ce","shorts":Color.from_hsv(hue,.6,.22).to_html(false),"alt":"eee5ce","alt_trim":Color.from_hsv(hue,.64,.66).to_html(false),"pattern":i%3,"style":["KANATLARDAN OYUN","ÖN ALAN BASKISI","DİSİPLİNLİ SAVUNMA","SABIRLI PAS OYUNU"][i%4]}
		c.merge(SEFC.club(i),true)
		var strength: int=(83-i%18 if i<18 else 67-i%18)
		c.merge({"id":id,"badge_id":i,"league":i/18,"cash":int(1800000+pow(strength-40,2)*13500),"budget":int(900000+pow(strength-40,2)*8000),"roster":[],"lineup":[],"plan":plan(),"plans":[plan(),plan(),plan()],"objective":"Şampiyonluk" if i%18<4 else ("İlk yarı" if i%18<10 else "Ligde kal"),"reputation":strength})
		c.plans[0].mentality=0; c.plans[0].pressing=0; c.plans[0].line_height=0
		c.plans[2].mentality=2; c.plans[2].pressing=2; c.plans[2].line_height=2
		c.plan.formation=i%3; c.plan.mentality=[1,2,0,1][i%4]
		c.plan.pressing=[1,2,0,1][i%4]; c.plan.line_height=[1,2,0,1][i%4]
		c.plan.width=2 if i%4==0 else 1; c.plan.tempo=0 if i%4==3 else 1
		for j in range(24):
			var pid := "p%04d" % (i*24+j)
			var role: int=0 if j in [0,11] else (1 if j in [1,2,3,4,12,13,18,19] else (3 if j in [9,10,16,17,23] else 2))
			var stats := Attributes.profile(i,j,role==0)
			var offset: int=strength-74+rng.randi_range(-6,5)-(5 if j>17 else 0)
			for key in Attributes.KEYS: stats[key]=clampi(stats[key]+offset,35,95)
			for key in ["passing","defending","strength","stamina","reflexes","handling","positioning"]:
				var bonus: int=7 if (key=="passing" and role==2) or (key=="defending" and role==1) or (key in ["reflexes","handling","positioning"] and role==0) else 0
				stats[key]=clampi(strength+rng.randi_range(-8,6)+bonus-(8 if key=="defending" and role==3 else 0),35,95)
			var title: String=SEFC.player(i*24+j).name
			var p := {"id":pid,"career_id":pid,"club":id,"name":title,"shirt":j+1,"role":role,"keeper":role==0,"attributes":stats,"appearance_id":i*24+j,"age":rng.randi_range(18,33),"potential":mini(96,strength+rng.randi_range(2,12)),"contract":year+rng.randi_range(1,4),"wage":0,"squad_role":1,"fitness":1.0,"form":0.0,"morale":.7,"banned":0,"yellow":0,"injury":0,"listed":false,"goals":0,"appearances":0,"used":false}
			p.merge(Physique.profile(i,j,role==0)); p.wage=wage(p)
			p.talent_club=id; p.talent_slot=j
			p.merge(SEFC.player(i*24+j),true)
			contract_fields(p); p.loan_listed=j>=18 and p.age<=25
			w.players[pid]=p; c.roster.append(pid)
			if j<11: c.lineup.append(pid)
		w.clubs[id]=c
	upgrade(w)
	# Existing saves keep signed salaries; a new world prices its actual ratings.
	for p in w.players.values(): p.wage=wage(p)
	fixtures(w)
	return w

static func academy_player(w: Dictionary,c: Dictionary,role: int) -> Dictionary:
	var serial: int=w.next_player; w.next_player+=1
	var rng:=RandomNumberGenerator.new(); rng.seed=serial*177+int(w.year)
	var quality:=clampi(int(c.reputation)-rng.randi_range(12,20),40,72)
	var stats:=Attributes.profile(serial%36,serial%24,role==0)
	for key in Attributes.KEYS: stats[key]=clampi(quality+rng.randi_range(-8,7),35,82)
	for key in ["passing","defending","strength","stamina","reflexes","handling","positioning"]: stats[key]=clampi(quality+rng.randi_range(-7,8),35,82)
	var pid:="p%04d" % serial
	var p:={"id":pid,"career_id":pid,"club":c.id,"name":NAMES[serial%NAMES.size()]+" "+SURNAMES[(serial/7)%SURNAMES.size()],"shirt":serial%99+1,"role":role,"keeper":role==0,"attributes":stats,"appearance_id":serial,"age":rng.randi_range(17,19),"potential":mini(95,quality+rng.randi_range(10,22)),"contract":w.year+3,"wage":1500,"squad_role":0,"fitness":1.0,"form":0.0,"morale":.7,"banned":0,"yellow":0,"injury":0,"listed":false,"goals":0,"appearances":0,"used":false}
	p.merge(Physique.profile(serial%36,serial%24,role==0))
	p.talent_club=""; p.talent_slot=-1
	contract_fields(p)
	if c.league==Turkey.LEAGUE: p.name=Turkey.NAMES[serial%Turkey.NAMES.size()]+" "+Turkey.SURNAMES[(serial/7)%Turkey.SURNAMES.size()]
	if c.get("nation","")==SEFC.NATION: p.merge(SEFC.player(serial),true)
	else: International.nationality(p,c.get("nation","TR"),true)
	Talent.rebalance(p)
	return p

static func day(year: int,month: int,date: int) -> int:
	return int(Time.get_unix_time_from_datetime_string("%04d-%02d-%02dT12:00:00" % [year,month,date]))/86400

static func calendar(value: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(value*86400+43200)

static func date_label(value: int) -> String:
	var d:=calendar(value)
	return "%02d %s %d" % [d.day,["OCA","ŞUB","MAR","NİS","MAY","HAZ","TEM","AĞU","EYL","EKİ","KAS","ARA"][d.month-1],d.year]

static func fixtures(w: Dictionary) -> void:
	w.fixtures.clear(); w.table.clear(); w.round=0; w.season_done=false; w.scorers.clear()
	for id in w.clubs:
		w.table[id]={"p":0,"w":0,"d":0,"l":0,"gf":0,"ga":0,"pts":0}
	for league in range(LEAGUES.size()): append_league(w,league)
	w.fixtures.sort_custom(func(a,b): return a.day<b.day if a.day!=b.day else a.id<b.id)

static func append_league(w: Dictionary,league: int) -> void:
	var ring: Array=[]
	for id in w.clubs:
		if int(w.clubs[id].league)==league: ring.append(id)
	var count:=ring.size(); var rounds:=count-1
	for round_index in range(rounds*2):
		if round_index==rounds:
			ring.clear()
			for id in w.clubs:
				if int(w.clubs[id].league)==league: ring.append(id)
		var date: int=day(w.year,8,8)+round_index*(7 if full_calendar(league) else 21)
		if full_calendar(league) and round_index>=17: date=day(w.year+1,1,9)+(round_index-17)*7
		for m in range(count/2):
			var a: String=ring[m]; var b: String=ring[count-1-m]
			if ((round_index%rounds)%2==1)!=(round_index>=rounds): var swap:=a; a=b; b=swap
			w.fixtures.append({"id":"%d-%d-%d-%d" % [w.year,league,round_index,m],"league":league,"round":round_index,"day":date,"home":a,"away":b,"played":false,"score":[]})
		var last=ring.pop_back(); ring.insert(1,last)
