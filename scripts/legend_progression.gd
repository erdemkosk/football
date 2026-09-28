extends RefCounted
## Player-career progression is earned once per fixture/session, independently
## of manager development, simulation speed and the match duration setting.
const World=preload("res://scripts/career_world.gd")
const Talent=preload("res://scripts/player_talent.gd")
const POSITIONS:=["KALECİ","STOPER","SOL BEK","SAĞ BEK","ÖN LİBERO","MERKEZ ORTA SAHA","OFANSİF ORTA SAHA","SOL KANAT","SAĞ KANAT","SANTRFOR"]
const SHORT:=["KL","STP","SLB","SĞB","DOS","OS","OOS","SLK","SĞK","SF"]
const ROLES:=[0,1,1,1,2,2,2,2,2,3]
const ANCHORS:=[Vector2(0,46),Vector2(0,32),Vector2(-23,28),Vector2(23,28),Vector2(0,19),Vector2(0,11),Vector2(0,3),Vector2(-23,0),Vector2(23,0),Vector2(0,-9)]
const SKILLS:=[["reflexes","handling","positioning"],["defending","heading","strength"],["pace","defending","passing"],["pace","defending","passing"],["defending","passing","stamina"],["passing","control","stamina"],["control","passing","finishing"],["pace","control","passing"],["pace","control","passing"],["finishing","control","heading"]]
const TRAINING_LIMIT:=3

static func create_data(pid: String,position: int,day: int) -> Dictionary:
	return {"version":1,"player":pid,"primary":position,"position":position,"positions":{str(position):100.0},"learning":-1,"trust":22.0,"form":6.0,"games":0,"starts":0,"minutes":0,"goals":0,"assists":0,"week":day,"sessions":0,"xp":{},"history":[],"last":{},"processed":[],"training_history":[],"training_gain":0.0}

static func valid(w: Dictionary) -> bool:
	if not w.has("legend"): return true
	var d=w.legend
	if not d is Dictionary: return false
	for key in ["player","primary","position","positions","learning","trust","form","games","starts","minutes","goals","assists","week","sessions","xp","history","last","processed","training_history","training_gain"]:
		if not d.has(key): return false
	if not w.players.has(d.player) or not d.positions is Dictionary or not d.xp is Dictionary or not d.last is Dictionary: return false
	for key in ["history","processed","training_history"]:
		if not d[key] is Array: return false
	for key in ["primary","position","learning","games","starts","minutes","goals","assists","week","sessions"]:
		if not (d[key] is int or d[key] is float) or not is_finite(float(d[key])) or float(d[key])!=floor(float(d[key])): return false
	for key in ["trust","form","training_gain"]:
		if not (d[key] is int or d[key] is float) or not is_finite(float(d[key])): return false
	for key in ["games","starts","minutes","goals","assists","week"]:
		if d[key]<0: return false
	if d.primary<0 or d.primary>=POSITIONS.size() or d.position<0 or d.position>=POSITIONS.size(): return false
	if not d.positions.has(str(int(d.primary))) or not d.positions.has(str(int(d.position))): return false
	if d.positions.size()>3 or d.positions[str(int(d.primary))]!=100: return false
	if d.learning>=0 and (not d.positions.has(str(int(d.learning))) or d.positions[str(int(d.learning))]>=100): return false
	for key in ["last_offer_day","transfer_day"]:
		if d.has(key) and (not d[key] is int or d[key]<0): return false
	if not d.last.is_empty():
		for key in ["rating","minutes","trust_change","xp"]:
			if not d.last.has(key) or not (d.last[key] is int or d.last[key] is float) or not is_finite(float(d.last[key])): return false
	if d.learning< -1 or d.learning>=POSITIONS.size() or d.sessions<0 or d.sessions>TRAINING_LIMIT: return false
	if not w.players[d.player].get("legend_player",false): return false
	if w.players[d.player].club!=w.user and not w.players[d.player].get("retired",false): return false
	for key in d.xp:
		if not key in Talent.STATS or not (d.xp[key] is float or d.xp[key] is int) or not is_finite(float(d.xp[key])) or d.xp[key]<0 or d.xp[key]>=100: return false
	for key in d.positions:
		if not str(key).is_valid_int() or int(key)<0 or int(key)>=POSITIONS.size(): return false
		if not (d.positions[key] is float or d.positions[key] is int) or not is_finite(float(d.positions[key])) or d.positions[key]<0 or d.positions[key]>100: return false
	return d.positions[str(int(d.position))]>=100 and d.trust>=0 and d.trust<=100 and d.form>=3 and d.form<=10

static func initial_attributes(position: int,foot: int) -> Dictionary:
	var a: Dictionary={"preferred_foot":clampi(foot,0,1),"weak_foot":2,"archetype":POSITIONS[position]}
	for key in Talent.STATS: a[key]=48
	for key in SKILLS[position]: a[key]=57
	a.stamina=58; a.balance=54; a.acceleration=54
	if position!=0: a.reflexes=35; a.handling=35
	else: a.finishing=35; a.pace=46
	return a

static func refresh_week(d: Dictionary,day: int) -> void:
	if day>=int(d.week)+7:
		d.week=day; d.sessions=0; d.training_gain=0.0

static func slot_for(position: int,formation: int) -> int:
	if position==0: return 0
	var shapes: Array=preload("res://scripts/match_management.gd").SHAPES[formation]
	var best:=INF; var slot:=1
	for i in range(1,11):
		var offset: Vector2=shapes[i]-ANCHORS[position]
		var cost:=offset.length_squared()
		if cost<best: best=cost; slot=i
	return slot

static func selection(d: Dictionary,p: Dictionary,rival: Dictionary) -> Dictionary:
	var role: int=ROLES[int(d.position)]
	var candidate: Dictionary=p.duplicate(); candidate.role=role
	var opponent: Dictionary=rival.duplicate(); opponent.role=role
	var ability:=World.ovr(candidate)-(3 if d.position!=d.primary else 0)
	var competition:=World.ovr(opponent)
	var ready: bool=d.games>=3 and d.trust>=60 and ability>=competition-7 and p.fitness>=.65
	# Training alone cannot make a debutant the automatic starter. Form and
	# the actual competing player matter, especially at elite clubs.
	if d.form<5.5: ready=false
	var minute:=clampi(roundi(85-float(d.trust)*.32+maxi(0,competition-ability-10)*.22),55,82)
	return {"starter":ready,"minute":0 if ready else minute,"ability":ability,"competition":competition,"gap":competition-ability,"role":"İLK 11" if ready else "YEDEK","reason":"Teknik direktör ilk 11 için sana güveniyor." if ready else "İlk 11: en az 3 maç, 60 güven ve rakibinin en fazla 7 puan gerisinde ol."}

static func gain(d: Dictionary,p: Dictionary,amount: float,skills: Array) -> Dictionary:
	var earned: Dictionary={}
	if skills.is_empty() or World.ovr(p)>=p.potential: return earned
	var overall:=World.ovr(p)
	var rate:=1.0 if overall<65 else .8 if overall<75 else .6 if overall<85 else .35
	var eligible: Array=skills.filter(func(key): return key in Talent.STATS and int(p.attributes.get(key,35))<mini(95,int(p.potential)+3))
	if eligible.is_empty(): return earned
	for key in eligible:
		d.xp[key]=float(d.xp.get(key,0))+amount*rate/eligible.size()
		while d.xp[key]>=100 and World.ovr(p)<p.potential and int(p.attributes[key])<mini(95,int(p.potential)+3):
			d.xp[key]-=100; p.attributes[key]=int(p.attributes.get(key,35))+1
			earned[key]=int(earned.get(key,0))+1
		if World.ovr(p)>=p.potential or p.attributes[key]>=mini(95,int(p.potential)+3): d.xp[key]=minf(99,d.xp[key])
	return earned

static func training(d: Dictionary,p: Dictionary,day: int,score: int,skills: Array,drill: String) -> Dictionary:
	refresh_week(d,day)
	if d.sessions>=TRAINING_LIMIT: return {}
	d.sessions+=1; score=clampi(score,0,100)
	var xp:=0.0 if score==0 else 18+score*.42
	var gains:=gain(d,p,xp,skills)
	# Three weekly sessions cannot replace match performances in selection.
	var trust:=minf(1.2,maxf(0,(score-35)*.02))
	d.trust=minf(58,float(d.trust)+trust) if d.trust<58 else d.trust
	d.training_gain+=trust
	var learned:=""
	if d.learning>=0 and score>=40:
		var key:=str(int(d.learning))
		d.positions[key]=minf(100,float(d.positions.get(key,0))+8+score*.12)
		if d.positions[key]>=100: learned=POSITIONS[d.learning]; d.learning=-1
	var result:={"score":score,"xp":xp,"gains":gains,"day":day,"drill":drill,"learned":learned,"name":p.name,"player":p.id,"manual":true,"grade":preload("res://scripts/training_catalog.gd").grade(score)}
	d.training_history.push_front(result.duplicate(true))
	if d.training_history.size()>12: d.training_history.resize(12)
	return result

static func match_result(d: Dictionary,p: Dictionary,fixture: String,row: Dictionary,starter: bool) -> Dictionary:
	if fixture in d.processed: return {}
	d.processed.append(fixture)
	var minutes:=clampi(roundi(row.get("minutes",0)),0,120)
	if minutes==0: return {}
	var rating:=float(row.get("rating",6))
	var weight:=clampf(minutes/45.0,.35,1)
	var change:=clampf((rating-6.0)*4.0,-7,8)*weight
	if row.get("red",false): change-=4
	d.trust=clampf(float(d.trust)+change,0,100)
	d.form=clampf(float(d.form)*.65+rating*.35,3,10)
	d.games+=1; d.starts+=int(starter); d.minutes+=minutes
	d.goals+=int(row.get("goals",0)); d.assists+=int(row.get("assists",0))
	var xp: float=(12+maxf(0,rating-5)*10)*clampf(minutes/60.0,.3,1.5)
	var gains:=gain(d,p,xp,SKILLS[int(d.position)])
	d.last=row.duplicate(true); d.last.merge({"fixture":fixture,"minutes":minutes,"trust_change":change,"xp":xp,"gains":gains,"position":int(d.position),"starter":starter},true)
	d.history.push_front(d.last.duplicate(true))
	if d.history.size()>20: d.history.resize(20)
	return d.last
