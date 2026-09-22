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

static func kick_factor(p,point: Vector3) -> float:
	var foot: int=p.ball_actions.choose_foot(p,point)
	var weak: float=1.0 if foot==p.attributes.preferred_foot else lerpf(.88,.99,(p.attributes.weak_foot-1)/4.0)
	return weak*multiplier(p.attributes.finishing,.13 if p.career_id!="" else .055)*(1-p.contest_weight*.045)
