extends RefCounted
const Physique = preload("res://scripts/player_physique.gd")
const World = preload("res://scripts/career_world.gd")
var game
var selected := [0,1]
var league := [0,0]
var alternate := [false,false]
var career_clubs: Array=[]
var career_rosters: Array=[]
var exhibition: Dictionary={}
var lineups: Array = [range(11),range(11)]
var reserves: Array = [range(11,18),range(11,18)]
const CLUBS := [
	{"name":"KIYI SPOR","short":"KIY","city":"İSTANBUL","year":"1967","primary":"e5ece5","accent":"193d39","shorts":"133933","alt":"193d39","alt_trim":"e5ece5","pattern":0,"style":"KANATLARDAN OYUN","squad":"DENİZ,KAAN,DEMİR,CAN,EMİR,ARAS,MERT,ALP,KEREM,EGE,BORA,EFE,UMUT,TUNA,OZAN,BARAN,YİĞİT,ATA"},
	{"name":"ATLAS FC","short":"ATL","city":"İZMİR","year":"1924","primary":"d34532","accent":"f1d7bd","shorts":"eee3d2","alt":"202f48","alt_trim":"e4ae79","pattern":1,"style":"ÖN ALAN BASKISI","squad":"MARC,LUCA,IVAN,ALEX,THEO,RAFA,OMAR,LEO,NICO,ENZO,SAM,JOEL,MIRO,NOAH,LARS,LUIS,ADAM,FINN"},
	{"name":"DEMİRSPOR","short":"DEM","city":"ANKARA","year":"1938","primary":"2463a3","accent":"b8e6f2","shorts":"102d50","alt":"e7edf2","alt_trim":"235282","pattern":2,"style":"DİSİPLİNLİ SAVUNMA","squad":"VOLKAN,EREN,BERK,ONUR,SERHAT,CEM,SELİM,ERDEM,HAKAN,TOLGA,BATU,SİNAN,AYAZ,DORUK,UFUK,TAYLAN,KORAY,ERAY"},
	{"name":"GÜNEŞ FK","short":"GÜN","city":"ANTALYA","year":"1972","primary":"f2be49","accent":"54253b","shorts":"54253b","alt":"58223d","alt_trim":"f3cc66","pattern":1,"style":"HIZLI GEÇİŞLER","squad":"ARDA,ALPER,İLKER,FIRAT,ENGİN,OKAN,BURAK,DOĞAN,SARP,YAMAN,RÜZGAR,UTKU,ÖMER,İSMAİL,HAMZA,TARIK,ERSEL,CEYHUN"},
	{"name":"ORMAN BİRLİĞİ","short":"ORM","city":"BURSA","year":"1963","primary":"24715b","accent":"eee5ce","shorts":"173c34","alt":"f0e7cf","alt_trim":"24694f","pattern":2,"style":"SABIRLI PAS OYUNU","squad":"YUSUF,ÖZGÜR,MURAT,EMRE,MESUT,SEZER,ORÇUN,CİHAN,İLHAN,HALİL,FATİH,MEHMET,KAHRAMAN,SONER,ŞAHİN,GÖKHAN,ŞENER,İSA"},
	{"name":"KUZEY YILDIZI","short":"KUZ","city":"TRABZON","year":"1955","primary":"7d324c","accent":"77bed6","shorts":"20334a","alt":"79bed3","alt_trim":"733047","pattern":1,"style":"CESUR HÜCUM","squad":"KIVANÇ,ADİL,AYKUT,MUZAFFER,YAVUZ,LEVENT,ENGİNCAN,TAMER,ORHAN,TUNCAY,HAKAN,ERGİN,AZİZ,İRFAN,KEMAL,BİLAL,ZAFER,MELİH"},
	{"name":"LİMAN ATHLETIC","short":"LİM","city":"MERSİN","year":"1981","primary":"243346","accent":"f1f0df","shorts":"1a2636","alt":"f0eee3","alt_trim":"29384f","pattern":0,"style":"KOMPAKT BLOK","squad":"DIEGO,BRUNO,HUGO,TIAGO,ANDRE,MATEO,OSCAR,PABLO,ELIAS,MARCO,FELIX,RENE,LOREN,JORGE,DARIO,INES,TONI,VICTOR"},
	{"name":"KAPADOKYA SK","short":"KAP","city":"NEVŞEHİR","year":"1969","primary":"8d629d","accent":"f0ded1","shorts":"422d58","alt":"eee0cf","alt_trim":"705180","pattern":2,"style":"YARATICI ORTA SAHA","squad":"CANER,BARIŞ,BERAT,BULUT,İHSAN,ENES,İBRAHİM,FERHAT,SEFA,FURKAN,BATUHAN,RECEP,SALİH,AHMET,MAHMUT,NECATİ,KAĞAN,SERDAR"}]

func ensure_world() -> void:
	if exhibition.is_empty(): exhibition=World.create()

func league_ids(div: int) -> Array:
	if exhibition.is_empty() and div==0:
		var local: Array=[]
		for i in range(CLUBS.size()): local.append("c%02d" % i)
		return local
	ensure_world()
	var ids: Array=[]
	for id in exhibition.clubs:
		if int(exhibition.clubs[id].league)==div: ids.append(id)
	ids.sort()
	return ids

func league_name(side: int) -> String:
	return World.LEAGUES[league[side]]

func club_id(side: int) -> String:
	if exhibition.is_empty(): return "c%02d" % clampi(selected[side],0,CLUBS.size()-1)
	var ids: Array=league_ids(league[side])
	if ids.is_empty(): return "c%02d" % selected[side]
	return str(ids[clampi(selected[side],0,ids.size()-1)])

func catalog_index(side: int) -> int:
	if exhibition.is_empty(): return clampi(selected[side],0,CLUBS.size()-1)
	var id := club_id(side)
	if id.begins_with("c"):
		var n := int(id.substr(1))
		if n<CLUBS.size(): return n
	return -1

func data(side: int) -> Dictionary:
	if not career_clubs.is_empty(): return career_clubs[side]
	if exhibition.is_empty(): return CLUBS[clampi(selected[side],0,CLUBS.size()-1)]
	var id := club_id(side)
	if exhibition.clubs.has(id): return exhibition.clubs[id]
	return CLUBS[selected[side]%CLUBS.size()]

func kit(side: int) -> Dictionary:
	var club := data(side)
	var fallback: int=catalog_index(side)
	var away: String=str(club.get("alt",club.primary))
	return {"primary":Color(away if alternate[side] else club.primary),"accent":Color(club.get("alt_trim",club.accent) if alternate[side] else club.accent),"shorts":Color(away if alternate[side] else club.shorts),"pattern":int(club.get("pattern",0)),"club_id":club.get("badge_id",fallback if fallback>=0 else selected[side]),"badge_primary":Color(club.primary),"badge_accent":Color(club.accent)}

func clear_career() -> void:
	career_clubs.clear(); career_rosters.clear()
	lineups=[range(11),range(11)]
	reserves=[range(11,18),range(11,18)]

func contrast_kits() -> void:
	var a := Color(data(0).primary)
	var b := Color(data(1).primary)
	if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()<0.4: alternate[1]=true

func reset_side(side: int) -> void:
	lineups[side]=range(11)
	reserves[side]=range(11,18)
	alternate[side]=false

func choose(side: int,id: int) -> void:
	clear_career()
	var ids: Array=league_ids(league[side])
	var count: int=maxi(1,ids.size())
	var direction := -1 if id<selected[side] else 1
	selected[side]=posmod(id,count)
	while club_id(0)==club_id(1) and count>1:
		selected[side]=posmod(selected[side]+direction,count)
	reset_side(side)
	contrast_kits()
	apply()

func set_league(side: int,div: int) -> void:
	clear_career()
	league[side]=posmod(div,World.LEAGUES.size())
	selected[side]=0
	var ids: Array=league_ids(league[side])
	if club_id(0)==club_id(1) and ids.size()>1: selected[side]=1
	reset_side(side)
	contrast_kits()
	apply()

func member(side: int,id: int) -> Dictionary:
	if not career_rosters.is_empty(): return career_rosters[side][id].duplicate(true)
	var cat := catalog_index(side)
	if cat>=0:
		var names: PackedStringArray=CLUBS[cat].squad.split(",")
		var result := {"name":names[id],"shirt":id+1,"keeper":id in [0,11],"used":false,"appearance_id":cat*24+id}
		result.merge(Physique.profile(cat,id,result.keeper))
		result.attributes=preload("res://scripts/player_attributes.gd").profile(cat,id,result.keeper)
		return result
	var club := data(side)
	var roster: Array=club.get("roster",[])
	if id<roster.size() and exhibition.players.has(roster[id]):
		var player: Dictionary=exhibition.players[roster[id]].duplicate(true)
		if not player.has("used"): player.used=false
		return player
	var fallback := {"name":"OYUNCU","shirt":id+1,"keeper":id==0,"used":false,"appearance_id":id}
	fallback.merge(Physique.profile(side,id,fallback.keeper))
	fallback.attributes=preload("res://scripts/player_attributes.gd").profile(side,id,fallback.keeper)
	return fallback

func swap_starter(slot: int,reserve: int) -> bool:
	var a: int=lineups[0][slot]
	var b: int=reserves[0][reserve]
	if member(0,a).keeper!=member(0,b).keeper: return false
	lineups[0][slot]=b
	reserves[0][reserve]=a
	apply()
	return true

func apply() -> void:
	game.management.originals.clear()
	game.management.reserve_originals=[[],[]]
	for side in range(2):
		for slot in range(11):
			var identity := member(side,lineups[side][slot])
			game.management.originals.append(identity)
			var p=game.players[side*11+slot]
			p.apply_kit(kit(side))
		for id in reserves[side]: game.management.reserve_originals[side].append(member(side,id))
	game.management.reset()
	if game.stadium.sidelines.team_labels.size()==2:
		for side in range(2): game.stadium.sidelines.team_labels[side].text=data(side).name+" · YEDEK KULÜBESİ"
	for actor in game.stadium.sidelines.actors:
		if actor.role=="substitute":
			actor.kit_material.albedo_color=kit(actor.team).primary
			actor.bib_material.albedo_color=kit(actor.team).accent.lerp(Color("9eae97"),0.5)
	for caption in game.stadium.architecture.team_captions: caption.text=data(0).short+"       "+data(1).short
