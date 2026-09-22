extends RefCounted
## Paired, bounded shoulder pressure; no forced tackles or scripted possession.
var game
var pairs: Array = []

func reset() -> void:
	pairs.clear()
	for p in game.players:
		p.contest_weight=0; p.contest_direction=Vector3.ZERO
		p.landing_age=1; p.landing_strength=0; p.header_airborne=false

func update(delta: float) -> void:
	pairs.clear()
	for p in game.players: p.contest_weight=move_toward(p.contest_weight,0,delta*4)
	if game.state!="playing": return
	var paired: Array=[]
	for a in range(1,11):
		var p=game.players[a]
		if not eligible(p) or game.flat_distance(p.position,game.ball.position)>6: continue
		for b in range(12,22):
			var q=game.players[b]
			if b in paired or not eligible(q): continue
			var gap: Vector3=(p.position-q.position)*Vector3(1,0,1)
			var distance := gap.length()
			if distance<.05 or distance>1.12 or absf(p.position.y-q.position.y)>1.3: continue
			var air: bool=game.heading.active(a) or game.heading.active(b) or p.pose=="header" or q.pose=="header"
			var shielding: bool=(p.protecting and game.dribbler==a) or (q.protecting and game.dribbler==b)
			if not air and not shielding and (p.velocity.length()<1 or q.velocity.length()<1 or p.facing.dot(q.facing)<.3 or absf(gap.normalized().dot(p.facing))>.65): continue
			var normal := gap.normalized()
			p.contest_direction=-normal; q.contest_direction=normal
			p.contest_weight=move_toward(p.contest_weight,.8,delta*8)
			q.contest_weight=move_toward(q.contest_weight,.8,delta*8)
			# Equal opposing impulses respect mass. Already-separated runners keep input.
			if distance<.92:
				var impulse := normal*(.92-distance)*delta*(70 if air else 110)
				p.velocity+=impulse*(76.0/p.weight_kg)/p.Attributes.multiplier(p.attributes.get("strength",72),.22)
				q.velocity-=impulse*(76.0/q.weight_kg)/q.Attributes.multiplier(q.attributes.get("strength",72),.22)
			pairs.append([a,b]); paired.append(b)
			break

func eligible(p) -> bool:
	return p.visible and not p.dismissed and not p.keeper and (p.action_timer<=0 or p.pose=="header")
