extends RefCounted
## Stable individual ability, shared by career, academy and exhibition squads.
const VERSION := 3
const LeagueStrength=preload("res://scripts/league_strength.gd")
const STATS := ["pace","acceleration","control","balance","heading","finishing","passing","defending","strength","stamina","reflexes","handling","positioning"]
const WEIGHTS := [
	{"reflexes":.4,"handling":.35,"positioning":.25},
	{"defending":.35,"strength":.18,"pace":.12,"passing":.15,"heading":.2},
	{"passing":.30,"control":.25,"stamina":.15,"pace":.15,"finishing":.15},
	{"finishing":.4,"control":.20,"pace":.20,"heading":.2}]

static func overall(p: Dictionary) -> int:
	var value := 0.0
	var weights: Dictionary=WEIGHTS[int(p.role)]
	for key in weights: value+=float(p.attributes.get(key,72))*float(weights[key])
	return roundi(value)

static func rebalance(p: Dictionary) -> void:
	var previous_version: int=int(p.get("talent_version",0))
	if previous_version>=VERSION: return
	if previous_version<1:
		ordinary_talent(p)
		p.talent_club_bonus=0
	var before := overall(p)
	var seed_club := LeagueStrength.origin(p)
	p.talent_club=seed_club.club; p.talent_slot=seed_club.slot
	var previous_bonus: int=int(p.get("talent_club_bonus",0))
	var wanted: int=LeagueStrength.bonus(p)
	# A migration adds a fixed initial-squad adjustment to trained attributes;
	# it does not regenerate them from the player's current club or position.
	# Cloned expansion squads replace the template club's adjustment.
	# V2 already applied its club hierarchy. Subtract its authored adjustment,
	# not the smaller amount that survived stat caps, so training cannot unlock
	# an extra old bonus when the balance version changes.
	var change_wanted: int=wanted-(LeagueStrength.bonus(p,2) if previous_version>=2 else previous_bonus)
	var target := clampi(before+change_wanted,35,maxi(before,LeagueStrength.ceiling(p)))
	if before-previous_bonus>=85: target=before if previous_version>=2 else before-previous_bonus
	for key in STATS: p.attributes[key]=clampi(int(p.attributes[key])+target-before,35,95)
	var change := overall(p)-before
	p.talent_club_bonus=previous_bonus+change
	p.potential=clampi(maxi(overall(p),int(p.potential)+change),35,95)
	p.talent_version=VERSION

static func ordinary_talent(p: Dictionary) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=7919+int(p.appearance_id)*104729
	var previous := overall(p)
	var rarity := rng.randf()
	var target := clampi(roundi(60+(previous-72)*.70)+rng.randi_range(-6,6),36,79)
	# Most players are useful specialists. A small tail contains genuine stars;
	# identity determines it once, never team selection, a transfer or a reload.
	if previous>=65:
		if rarity<.003: target=rng.randi_range(90,92)
		elif rarity<.015: target=rng.randi_range(85,88)
		elif rarity<.045: target=rng.randi_range(79,83)
	for key in STATS:
		# Preserve strengths and weaknesses instead of giving every stat the OVR.
		p.attributes[key]=clampi(roundi(target+(float(p.attributes.get(key,previous))-previous)*.90),35,95)
	for iteration in range(3):
		var correction := target-overall(p)
		if correction==0: break
		for key in STATS: p.attributes[key]=clampi(int(p.attributes[key])+correction,35,95)
	var current := overall(p)
	var growth := clampi(roundi((int(p.get("potential",previous))-previous)*.6),0,12)
	if int(p.get("age",25))>=28: growth=mini(growth,2)
	elif int(p.get("age",25))>=24: growth=mini(growth,5)
	p.potential=mini(95,current+growth)
	if int(p.get("age",25))<=21 and rng.randf()<.015:
		p.potential=maxi(p.potential,rng.randi_range(85,92))
