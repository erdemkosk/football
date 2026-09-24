extends RefCounted
const Physique = preload("res://scripts/player_physique.gd")
const World = preload("res://scripts/career_world.gd")
const SEFC = preload("res://scripts/sefc_identity.gd")
var game
var selected := [0,1]
var league := [0,0]
var alternate := [false,false]
var contrast_override: Dictionary = {}
var career_clubs: Array=[]
var career_rosters: Array=[]
var exhibition: Dictionary={}
var lineups: Array = [range(11),range(11)]
var reserves: Array = [range(11,18),range(11,18)]
const CLUBS := [
	{"name":SEFC.CLUBS[0][0],"short":SEFC.CLUBS[0][1],"city":SEFC.CLUBS[0][2],"year":"1967","primary":"e5ece5","accent":"193d39","shorts":"133933","alt":"193d39","alt_trim":"e5ece5","pattern":0,"style":"KANATLARDAN OYUN","nation":SEFC.NATION},
	{"name":SEFC.CLUBS[1][0],"short":SEFC.CLUBS[1][1],"city":SEFC.CLUBS[1][2],"year":"1924","primary":"d34532","accent":"f1d7bd","shorts":"eee3d2","alt":"202f48","alt_trim":"e4ae79","pattern":1,"style":"ÖN ALAN BASKISI","nation":SEFC.NATION},
	{"name":SEFC.CLUBS[2][0],"short":SEFC.CLUBS[2][1],"city":SEFC.CLUBS[2][2],"year":"1938","primary":"2463a3","accent":"b8e6f2","shorts":"102d50","alt":"e7edf2","alt_trim":"235282","pattern":2,"style":"DİSİPLİNLİ SAVUNMA","nation":SEFC.NATION},
	{"name":SEFC.CLUBS[3][0],"short":SEFC.CLUBS[3][1],"city":SEFC.CLUBS[3][2],"year":"1972","primary":"f2be49","accent":"54253b","shorts":"54253b","alt":"58223d","alt_trim":"f3cc66","pattern":1,"style":"HIZLI GEÇİŞLER","nation":SEFC.NATION},
	{"name":SEFC.CLUBS[4][0],"short":SEFC.CLUBS[4][1],"city":SEFC.CLUBS[4][2],"year":"1963","primary":"24715b","accent":"eee5ce","shorts":"173c34","alt":"f0e7cf","alt_trim":"24694f","pattern":2,"style":"SABIRLI PAS OYUNU","nation":SEFC.NATION},
	{"name":SEFC.CLUBS[5][0],"short":SEFC.CLUBS[5][1],"city":SEFC.CLUBS[5][2],"year":"1955","primary":"7d324c","accent":"77bed6","shorts":"20334a","alt":"79bed3","alt_trim":"733047","pattern":1,"style":"CESUR HÜCUM","nation":SEFC.NATION},
	{"name":SEFC.CLUBS[6][0],"short":SEFC.CLUBS[6][1],"city":SEFC.CLUBS[6][2],"year":"1981","primary":"243346","accent":"f1f0df","shorts":"1a2636","alt":"f0eee3","alt_trim":"29384f","pattern":0,"style":"KOMPAKT BLOK","nation":SEFC.NATION},
	{"name":SEFC.CLUBS[7][0],"short":SEFC.CLUBS[7][1],"city":SEFC.CLUBS[7][2],"year":"1969","primary":"8d629d","accent":"f0ded1","shorts":"422d58","alt":"eee0cf","alt_trim":"705180","pattern":2,"style":"YARATICI ORTA SAHA","nation":SEFC.NATION}]

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
	var colors := strip(side)
	var keepers := keeper_palette()
	colors.keeper_color=keepers[side]
	return colors

func strip(side: int) -> Dictionary:
	var club := data(side)
	var fallback: int=catalog_index(side)
	var away: String=str(club.get("alt",club.primary))
	var colors := {"primary":Color(away if alternate[side] else club.primary),"accent":Color(club.get("alt_trim",club.accent) if alternate[side] else club.accent),"shorts":Color(away if alternate[side] else club.shorts),"pattern":int(club.get("pattern",0)),"club_id":club.get("badge_id",fallback if fallback>=0 else selected[side]),"badge_primary":Color(club.primary),"badge_accent":Color(club.accent)}
	if contrast_override.has(side):
		colors.primary=contrast_override[side]
		colors.shorts=colors.primary
		colors.accent=Color("172328") if colors.primary.get_luminance()>.45 else Color("f5f3e8")
	return colors

func clear_career() -> void:
	career_clubs.clear(); career_rosters.clear()
	lineups=[range(11),range(11)]
	reserves=[range(11,18),range(11,18)]

static func separation(a: Color,b: Color) -> float:
	return absf(a.get_luminance()-b.get_luminance())*.70+Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()*.30/sqrt(3.0)

func contrast_kits(preferred: int=0) -> void:
	contrast_override.clear()
	var other := 1-preferred
	var a: Color=strip(preferred).primary
	var current := separation(a,strip(other).primary)
	if current>=.26: return
	alternate[other]=not alternate[other]
	if separation(a,strip(other).primary)<current: alternate[other]=not alternate[other]
	if separation(a,strip(other).primary)<.26:
		var light := Color("f3f1df"); var dark := Color("152337")
		contrast_override[other]=light if separation(a,light)>separation(a,dark) else dark

func keeper_palette() -> Array[Color]:
	var against: Array[Color]=[strip(0).primary,strip(1).primary]
	var result: Array[Color]=[]
	for side in range(2):
		var best := Color("e5c747"); var score := -1.0
		for candidate in [Color("e5c747"),Color("6cd3e7"),Color("be72d2"),Color("f09747"),Color("58bc7a"),Color("26313b")]:
			var minimum := 1.0
			for color in against: minimum=minf(minimum,Vector3(candidate.r-color.r,candidate.g-color.g,candidate.b-color.b).length())
			if minimum>score: score=minimum; best=candidate
		result.append(best); against.append(best)
	return result

func reset_side(side: int) -> void:
	lineups[side]=range(11)
	reserves[side]=range(11,18)
	alternate[side]=false
	if side==0:
		var plan := tactical_plan(side)
		for key in plan:
			if key in game.management.identity.SETTINGS: game.management.set(key,bool(plan[key]) if key=="anchor" else int(plan[key]))

func tactical_plan(side: int) -> Dictionary:
	return preload("res://scripts/team_identity.gd").plan(data(side))

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
		var result := SEFC.player(cat*24+id)
		result.merge({"shirt":id+1,"keeper":id in [0,11],"used":false,"appearance_id":cat*24+id})
		result.role=game.management.natural_role(result.shirt,result.keeper)
		result.merge(Physique.profile(cat,id,result.keeper))
		result.attributes=preload("res://scripts/player_attributes.gd").club_profile(cat,id,result.keeper)
		return result
	var club := data(side)
	var roster: Array=club.get("roster",[])
	if id<roster.size() and exhibition.players.has(roster[id]):
		var player: Dictionary=exhibition.players[roster[id]].duplicate(true)
		if not player.has("used"): player.used=false
		return player
	var fallback := {"name":"OYUNCU","shirt":id+1,"keeper":id==0,"used":false,"appearance_id":id}
	fallback.role=game.management.natural_role(fallback.shirt,fallback.keeper)
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

func swap_positions(a: int,b: int) -> bool:
	if a<0 or b<0 or a>=11 or b>=11 or a==b: return false
	var first: int=lineups[0][a]
	var second: int=lineups[0][b]
	if member(0,first).keeper!=member(0,second).keeper: return false
	lineups[0][a]=second
	lineups[0][b]=first
	apply()
	return true

func apply(preferred: int=0) -> void:
	# Resolve clashes for career and quick-match entry as well as the kit picker.
	contrast_kits(preferred)
	game.management.originals.clear()
	game.management.reserve_originals=[[],[]]
	for side in range(2):
		for slot in range(11):
			var identity := member(side,lineups[side][slot])
			game.management.originals.append(identity)
		for id in reserves[side]: game.management.reserve_originals[side].append(member(side,id))
	game.management.reset()
	game.stadium.crowd.set_clubs(kit(0),kit(1))
	game.referees.refresh_kits()
	for banner in game.stadium.supporter_banners:
		var club := data(1 if banner.away else 0)
		banner.label.text=str(club.short)+(" · DEPLASMAN" if banner.away else " · "+str(club.get("year","")))
	if game.stadium.sidelines.team_labels.size()==2:
		for side in range(2): game.stadium.sidelines.team_labels[side].text=data(side).name+" · YEDEK KULÜBESİ"
	for actor in game.stadium.sidelines.actors:
		if actor.role=="substitute":
			actor.kit_material.albedo_color=kit(actor.team).primary
			actor.bib_material.albedo_color=kit(actor.team).accent.lerp(Color("9eae97"),0.5)
	for caption in game.stadium.architecture.team_captions: caption.text=data(0).short+"       "+data(1).short
