extends RefCounted
## In-match knocks. A heavy challenge can leave a player carrying a knock: he
## loses his sprint and some pace until replaced, and his readiness drops so
## both the user's bench suggestion and the opponent's coach replace him first.
## Both teams share the same rules; the injury slider sets the frequency.
const LABELS := ["","HAFİF SAKATLIK","SAKATLIK","CİDDİ SAKATLIK"]
## Career days out for each severity.
const DAYS := [0,3,9,24]
var game
var injured: Dictionary = {}
var rng := RandomNumberGenerator.new()
var last_event: Dictionary = {}

func reset() -> void:
	injured.clear(); last_event.clear()
	rng.seed=7717
	for p in game.players: p.injury_level=0

func chance(victim: int,strength: float,foul: bool) -> float:
	var p=game.players[victim]
	var rate: float=game.sliders.scale(p.team,"injuries",0.0,2.2)
	# Strength and balance absorb a knock; a late, fast challenge is worse.
	var sturdiness: float=p.Attributes.technique(float(p.attributes.get("strength",72))*.6+float(p.attributes.balance)*.4)
	return clampf((.03+strength*.09+(.05 if foul else 0.0))*lerpf(1.25,.75,sturdiness)*rate,0,.6)

func impact(victim: int,strength: float,foul: bool) -> bool:
	if game.training or game.menu_match.running: return false
	var p=game.players[victim]
	if p.keeper or p.dismissed or not p.visible or p.injury_level>0: return false
	if rng.randf()>=chance(victim,strength,foul): return false
	var roll: float=rng.randf()
	var severity: int=1 if roll<.62 else (2 if roll<.9 else 3)
	injured[victim]={"severity":severity}
	p.injury_level=severity
	last_event={"index":victim,"severity":severity,"name":p.display_name,"team":p.team}
	game.skills.explain(victim,LABELS[severity]+" · DEĞİŞİKLİK GEREKEBİLİR")
	game.broadcast_event("injury",{"index":victim,"severity":severity})
	if game.career.in_match and p.career_id!="":
		var record: Dictionary=game.career.player(p.career_id)
		record.injury=maxi(int(record.get("injury",0)),int(game.career.world.date)+DAYS[severity])
	return true

func replaced(index: int) -> void:
	injured.erase(index)
	game.players[index].injury_level=0
