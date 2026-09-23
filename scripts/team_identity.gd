extends RefCounted
## Club habits choose between viable actions. Ability comes from the current
## footballers, including substitutes; badges never grant hidden match bonuses.
var game
const SETTINGS := ["formation","mentality","pressing","line_height","width","tempo","runs","fullbacks","anchor"]
const STYLES := {
	"KANATLARDAN OYUN":[1,1,1,1,2,1,2,2,1],
	"ÖN ALAN BASKISI":[1,2,2,2,1,2,2,1,1],
	"DİSİPLİNLİ SAVUNMA":[0,0,0,0,1,1,1,0,1],
	"HIZLI GEÇİŞLER":[0,1,1,0,2,2,2,1,1],
	"SABIRLI PAS OYUNU":[2,1,1,1,1,0,0,1,1],
	"CESUR HÜCUM":[1,2,1,2,2,2,2,2,0],
	"KOMPAKT BLOK":[0,0,0,0,0,0,0,0,1],
	"YARATICI ORTA SAHA":[2,1,1,1,0,1,1,1,1]
}

static func plan(club: Dictionary) -> Dictionary:
	var values: Array=STYLES.get(str(club.get("style","")),[0,1,1,1,1,1,1,1,1])
	var result := {}
	for i in range(SETTINGS.size()): result[SETTINGS[i]]=values[i]
	# Saved career tactics and generated clubs remain authoritative.
	result.merge(club.get("plan",{}),true)
	return result

static func setting(club: Dictionary,key: String) -> int:
	# Hot AI reads need one value, not a rebuilt nine-field plan per player.
	var saved: Dictionary=club.get("plan",{})
	if saved.has(key): return int(saved[key])
	var slot := SETTINGS.find(key)
	if slot<0: return 1
	return int(STYLES.get(str(club.get("style","")),[0,1,1,1,1,1,1,1,1])[slot])

func quality(index: int,defense: bool=false) -> float:
	var p=game.players[index]
	var stats: Dictionary=p.attributes
	var rating: float=float(stats.get("defending",stats.balance))*.55+float(stats.balance)*.25+float(stats.control)*.20 if defense else float(stats.get("passing",stats.control))*.50+float(stats.control)*.35+float(stats.get("positioning",stats.balance))*.15
	var result := clampf((rating-48)/46,0,1)
	# Fatigue and a player deployed outside his natural line slow the read.
	result*=lerpf(.78,1,smoothstep(.15,.65,p.energy))
	if not p.keeper and p.natural_position!=game.management.slot_role(index): result*=.94
	return result

func team_quality(team: int,defense: bool=false) -> float:
	var total := 0.0
	var count := 0
	for i in range(team*11+1,team*11+11):
		if not game.players[i].visible or game.players[i].dismissed: continue
		total+=quality(i,defense); count+=1
	return total/maxi(1,count) if count>0 else .52

func decision_bias(index: int,choice: Dictionary) -> float:
	var p=game.players[index]
	var style: String=game.clubs.data(p.team).get("style","")
	var kind: String=choice.kind
	if choice.has("velocity") or choice.get("advanced",false): return 0
	if not choice.has("route"):
		return -3.0 if kind=="carry" and style=="SABIRLI PAS OYUNU" else 0.0
	if kind=="clearance": return 0
	var route: Dictionary=choice.route
	var distance: float=game.flat_distance(game.ball.position,route.target)
	var progress: float=(route.target.z-game.ball.position.z)*game.attack_sign(p.team)
	var bias: float=(game.management.detail(p.team,"tempo")-1)*clampf(progress/4,-3,4)
	if style=="KANATLARDAN OYUN":
		bias+=7 if kind in ["cross","driven_cross","switch"] else (4 if absf(route.target.x)>18 else 0)
	elif style=="SABIRLI PAS OYUNU":
		bias+=7 if distance<19 and not route.get("lob",false) else -3
		if kind in ["one_two","return_pass"]: bias+=3
	elif style=="YARATICI ORTA SAHA":
		bias+=7 if kind in ["through","one_two","return_pass"] else (3 if absf(route.target.x)<14 else 0)
	elif style in ["HIZLI GEÇİŞLER","ÖN ALAN BASKISI"]:
		bias+=clampf(progress*.25,-3,6)
		if kind in ["through","lob_through"]: bias+=3
	elif style=="CESUR HÜCUM":
		bias+=4 if kind in ["cross","through","lob_through"] else 0
	elif style in ["KOMPAKT BLOK","DİSİPLİNLİ SAVUNMA"]:
		bias+=3 if distance<18 else 0
	return bias
