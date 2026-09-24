extends RefCounted
const KEYS := ["pace","acceleration","control","balance","heading","finishing"]
const LABELS := ["HIZ","İVME","KONTROL","DENGE","KAFA","ŞUT"]

static func profile(club: int,member: int,keeper: bool=false) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed=19391*(club+1)+65537*(member+1)
	var values := [72,72,72,72,72,72]
	var style := "DENGELİ"
	if keeper: values=[61,64,66,79,64,48]; style="KALECİ"
	elif member in [2,3,13]: values=[65,62,66,86,87,58]; style="GÜÇLÜ STOPER"
	elif member in [1,4,12]: values=[81,80,70,72,65,61]; style="HAREKETLİ BEK"
	elif member in [5,8,10,16]: values=[86,88,80,66,58,76]; style="ÇEVİK KANAT"
	elif member in [9,17]: values=[73,69,76,85,86,87]; style="GÜÇLÜ SANTRFOR"
	else: values=[72,75,87,77,63,73]; style="OYUN KURUCU"
	var result := {"preferred_foot":0 if random.randf()<.25 else 1,"weak_foot":random.randi_range(2,4),"archetype":style}
	for i in range(KEYS.size()): result[KEYS[i]]=clampi(values[i]+random.randi_range(-5,5),45,93)
	return result

static func multiplier(value: float,spread: float=.14) -> float:
	return 1.0+clampf((value-72)/24.0,-1,1)*spread

static func technique(value: float) -> float:
	return clampf((value-35)/60.0,0,1)

static func foot_quality(p,foot: int) -> float:
	if foot==int(p.attributes.preferred_foot): return 1.0
	return lerpf(.64,1.0,clampf((float(p.attributes.weak_foot)-1)/4.0,0,1))

static func turning(p) -> float:
	# Technique governs a quick change of feet; balance controls the plant and
	# agility the speed of the hips over it.
	return multiplier(float(p.attributes.control)*.45+float(p.attributes.balance)*.25+value(p,"agility")*.30,.22)

## Detailed techniques. They derive from the stored core ratings plus a stable
## per-player signature, so saves need no migration and training a core rating
## still moves the related techniques. An explicit stored value always wins.
const DETAILS := ["agility","reactions","composure","vision","crossing","curve","long_shots","shot_power","volleys","jumping","tackling","interceptions","kicking"]
const DETAIL_LABELS := ["ÇEVİKLİK","REAKSİYON","SOĞUKKANLILIK","VİZYON","ORTA","FALSO","UZAKTAN ŞUT","ŞUT GÜCÜ","VOLE","SIÇRAMA","TOP KAPMA","ARAYA GİRME","DEGAJ"]
## Minimum skill-move stars for each move; the body feint and the basic
## ground moves stay available to everyone.
const MOVE_STARS := {"roll":1,"stop_go":1,"knock_around":1,"feint":1,"fake_shot":1,"fake_pass":1,"heel":2,"ball_roll_cut":2,"heel_to_heel":3,"flick":3,"roulette":3,"nutmeg":3,"scoop":4,"spin":4,"elastico":4,"rainbow":4}
const STYLES := ["finesse","power_shot","chip","first_touch","rapid","quick_step","incisive","whipped","press_proven","anticipate","intercept","aerial","bruiser","far_reach","footwork"]
const STYLE_LABELS := {"finesse":"PLASE ŞUT","power_shot":"SERT ŞUT","chip":"AŞIRTMA","first_touch":"İLK DOKUNUŞ","rapid":"SÜRAT","quick_step":"ÇABUK ADIM","incisive":"KESKİN PAS","whipped":"KAVİSLİ ORTA","press_proven":"BASKIYA DAYANIKLI","anticipate":"SEZGİ","intercept":"ARAYA GİRME","aerial":"HAVA HAKİMİ","bruiser":"GÜÇLÜ","far_reach":"UZUN KOL","footwork":"AYAK OYUNU"}
const MAX_STYLES := 4

static func core(a: Dictionary,key: String) -> float:
	return float(a.get(key,a.get("balance",72) if key=="strength" else 72))

static func signature(identity: int,slot: int) -> float:
	# A stable [-1, 1] offset per player and technique; never a match roll.
	var x: float=sin(float(identity)*12.9898+float(slot)*78.233)*43758.5453
	return (x-floor(x))*2.0-1.0

static func detail(a: Dictionary,key: String,identity: int) -> float:
	if a.has(key): return float(a[key])
	var base := 72.0
	match key:
		"agility": base=core(a,"acceleration")*.45+core(a,"control")*.35+(144.0-core(a,"strength"))*.20
		"reactions": base=core(a,"control")*.40+core(a,"positioning")*.30+core(a,"acceleration")*.30
		"composure": base=core(a,"finishing")*.35+core(a,"control")*.35+core(a,"positioning")*.30
		"vision": base=core(a,"passing")*.70+core(a,"control")*.30
		"crossing": base=core(a,"passing")*.60+core(a,"control")*.25+core(a,"pace")*.15
		"curve": base=core(a,"passing")*.45+core(a,"control")*.35+core(a,"finishing")*.20
		"long_shots": base=core(a,"finishing")*.60+core(a,"strength")*.20+core(a,"control")*.20
		"shot_power": base=core(a,"finishing")*.40+core(a,"strength")*.60
		"volleys": base=core(a,"finishing")*.60+core(a,"control")*.25+core(a,"balance")*.15
		"jumping": base=core(a,"heading")*.45+core(a,"acceleration")*.30+core(a,"strength")*.25
		"tackling": base=core(a,"defending")*.80+core(a,"strength")*.20
		"interceptions": base=core(a,"defending")*.60+core(a,"positioning")*.40
		"kicking": base=core(a,"passing")*.60+core(a,"strength")*.40
	return clampf(roundf(base+signature(identity,DETAILS.find(key))*6.0),35,95)

static func details_for(a: Dictionary,identity: int) -> Dictionary:
	var result := {}
	for key in DETAILS: result[key]=detail(a,key,identity)
	return result

static func stars_for(a: Dictionary,identity: int,keeper: bool=false) -> int:
	if a.has("skill_moves"): return clampi(int(a.skill_moves),1,5)
	if keeper: return 1
	var score: float=core(a,"control")*.6+detail(a,"agility",identity)*.4+signature(identity,31)*4.0
	return clampi(1+int(floor((score-54.0)/8.0)),1,5)

static func styles_for(a: Dictionary,identity: int,keeper: bool=false) -> Array[String]:
	# Each style needs a genuine specialism; the largest margins are kept.
	var d := details_for(a,identity)
	var margins := {}
	if keeper:
		margins={"far_reach":core(a,"reflexes")-83,"footwork":d.kicking-77}
	else:
		margins={"finesse":minf(d.curve-81,core(a,"finishing")-73),"power_shot":d.shot_power-84,"chip":minf(core(a,"control")-83,d.composure-77),
			"first_touch":minf(core(a,"control")-84,d.reactions-79),"rapid":minf(core(a,"pace")-85,core(a,"control")-75),"quick_step":core(a,"acceleration")-87,
			"incisive":minf(d.vision-83,core(a,"passing")-79),"whipped":d.crossing-81,"press_proven":d.composure-83,"anticipate":d.tackling-81,
			"intercept":d.interceptions-81,"aerial":minf(d.jumping-81,core(a,"heading")-81),"bruiser":core(a,"strength")-85}
	var chosen: Array[String]=[]
	for key in margins:
		if float(margins[key])>=0: chosen.append(key)
	chosen.sort_custom(func(x: String,y: String) -> bool: return float(margins[x])>float(margins[y]))
	while chosen.size()>MAX_STYLES: chosen.pop_back()
	return chosen

## Match-time cache, keyed to a fingerprint of the core ratings and the
## identity, so a substitution, training or an in-place edit refreshes it.
static func fingerprint(a: Dictionary) -> float:
	return core(a,"pace")+core(a,"acceleration")*3+core(a,"control")*7+core(a,"balance")*11+core(a,"heading")*13+core(a,"finishing")*17+core(a,"passing")*19+core(a,"defending")*23+core(a,"strength")*29+core(a,"positioning")*31+core(a,"reflexes")*37

static func traits(p) -> Dictionary:
	var stamp: float=fingerprint(p.attributes)
	if p.trait_stamp==stamp and p.trait_identity==int(p.appearance_id) and not p.traits.is_empty(): return p.traits
	p.traits={"details":details_for(p.attributes,int(p.appearance_id)),"stars":stars_for(p.attributes,int(p.appearance_id),p.keeper),"styles":styles_for(p.attributes,int(p.appearance_id),p.keeper)}
	p.trait_stamp=stamp; p.trait_identity=int(p.appearance_id)
	return p.traits

static func value(p,key: String) -> float:
	if p.attributes.has(key): return float(p.attributes[key])
	return float(traits(p).details.get(key,72.0))

static func skill(p,key: String) -> float:
	return technique(value(p,key))

static func stars(p) -> int:
	if p.attributes.has("skill_moves"): return clampi(int(p.attributes.skill_moves),1,5)
	return int(traits(p).stars)

static func refresh(p) -> void:
	p.traits={}

static func has_style(p,key: String) -> bool:
	return key in traits(p).styles

static func can_perform(p,move: String) -> bool:
	return stars(p)>=int(MOVE_STARS.get(move,1))

static func execution_direction(p,direction: Vector3,attribute: String,challenge: float) -> Vector3:
	# A stable, bounded contact error: ordinary unpressured passes stay exact.
	# No dice roll, target magnet or correction after the ball leaves the boot.
	var limitation := pow(1-technique(float(p.attributes.get(attribute,72))),1.5)
	var phase: float=sin(p.position.x*.71+p.position.z*.39+float(p.appearance_id+1)*1.17)
	var error: float=phase*.08*limitation*clampf(challenge,0,1)
	return direction.rotated(Vector3.UP,error)

static func club_profile(club: int,member: int,keeper: bool=false) -> Dictionary:
	# Exhibition squads used to share identical role templates with only +/-5
	# noise. These visible ratings now describe distinct, stable squads.
	var stats := profile(club,member,keeper)
	var offset: int=[0,4,-1,-7,2,3,-12,-4][posmod(club,8)]
	for key in KEYS: stats[key]=clampi(int(stats[key])+offset,40,94)
	var defender := member in [1,2,3,4,12,13]
	stats.passing=clampi(roundi(float(stats.control)*.72+72*.28)+offset/3+(3 if club in [4,7] else 0),40,94)
	stats.defending=clampi((80 if defender else 62)+offset+(3 if club in [2,6] else 0)+member%5-2,40,94)
	# Power and balance are separate qualities: a strong target man is not
	# automatically as stable on the ball as a low-centred playmaker.
	var build: int=84 if member in [2,3,13,9,17] else (63 if member in [5,8,10,16] else 72)
	stats.strength=clampi(roundi(float(stats.balance)*.45+float(build)*.55)+offset/2,40,94)
	stats.stamina=clampi(76+offset+(4 if club==1 else 0)+member%7-3,40,94)
	stats.reflexes=clampi((79 if keeper else 50)+offset+member%3,40,94)
	stats.handling=clampi((77 if keeper else 50)+offset+member%4,40,94)
	stats.positioning=clampi((80 if keeper or defender else 72)+offset+member%5-2,40,94)
	var role := 0 if keeper else (1 if member in [1,2,3,4,12,13] else (3 if member in [9,10,16,17] else 2))
	var identity := {"attributes":stats,"role":role,"appearance_id":club*24+member,"age":25,"potential":85,"talent_club":"c%02d" % club,"talent_slot":member}
	preload("res://scripts/player_talent.gd").rebalance(identity)
	return stats

static func kick_factor(p,point: Vector3) -> float:
	var foot: int=p.ball_actions.choose_foot(p,point)
	var weak: float=1.0 if foot==p.attributes.preferred_foot else lerpf(.88,.99,(p.attributes.weak_foot-1)/4.0)
	var power: float=float(p.attributes.finishing)*.55+value(p,"shot_power")*.45
	return weak*multiplier(power,.13)*(1.04 if has_style(p,"power_shot") else 1.0)*(1-p.contest_weight*.045)
