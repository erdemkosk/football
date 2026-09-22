extends RefCounted
var game
var targets: Dictionary = {}
var roles: Dictionary = {}
var remaining := 0.0
var previous_velocity := Vector3.ZERO
var scan_in := 0.0
var attacking_team := 0
var source := ""

func reset() -> void:
	targets.clear(); roles.clear(); remaining=0; previous_velocity=Vector3.ZERO; scan_in=0; source=""

func alert(kind: String,attack: int) -> void:
	if game.state!="playing": return
	remaining=2.8; scan_in=0; attacking_team=attack; source=kind

func landing() -> Vector3:
	var ball=game.ball
	var velocity: Vector3=ball.kick_velocity if ball.pending_kick else ball.linear_velocity
	var point: Vector3=ball.position
	if point.y>.5 or velocity.y>1:
		var samples=game.Passing.Motion.sample_flight(point,velocity,ball.spin,1.4,28,game.weather)
		for next in samples:
			var descending: bool=next.y<point.y
			point=next
			if point.y<.45 and descending: break
	else:
		var speed: float=Vector2(velocity.x,velocity.z).length()
		var distance: float=game.Passing.Motion.distance_at(speed,.40,game.Passing.Motion.profile(game.weather,point))
		point+=(velocity*Vector3(1,0,1)).normalized()*minf(distance,7)
	return Vector3(clampf(point.x,-31,31),0,clampf(point.z,-49,49))

func update(delta: float) -> void:
	if game.state!="playing" or game.ball.held_by!=null:
		reset(); return
	var velocity: Vector3=game.ball.linear_velocity
	var impact: bool=previous_velocity.length()>7 and velocity.length()>2 and previous_velocity.normalized().dot(velocity.normalized())<.55
	if impact and not game.ball.pending_kick and game.kick_lock<=0 and game.reactions.shot_age<5:
		alert("rebound",game.players[game.reactions.shooter].team if game.reactions.shooter>=0 else 1-game.last_touch)
	previous_velocity=velocity
	remaining=maxf(0,remaining-delta)
	if remaining<=0 or game.dribbler>=0:
		targets.clear(); roles.clear(); remaining=0; return
	scan_in-=delta
	if scan_in>0: return
	scan_in=.12; targets.clear(); roles.clear()
	var point := landing()
	for team in range(2):
		var candidates: Array[int]=[]
		for i in range(team*11+1,team*11+11):
			var p=game.players[i]
			if p.visible and not p.dismissed and p.action_timer<=0: candidates.append(i)
		candidates.sort_custom(func(a,b): return arrival(a,point)<arrival(b,point))
		if candidates.is_empty() or arrival(candidates[0],point)>3.8: continue
		var first: int=candidates[0]
		targets[first]=point; roles[first]="contest"
		game.players[first].reaction.reset()
		if candidates.size()>1:
			var next: int=candidates[1]
			var forward: float=game.attack_sign(team)
			var side := -1.0 if game.players[next].position.x<point.x else 1.0
			var support := point+Vector3(side*4.0,0,forward*(2 if team==attacking_team else -4))
			targets[next]=Vector3(clampf(support.x,-29,29),0,clampf(support.z,-46,46))
			roles[next]="finish" if team==attacking_team else "protect_goal"

func arrival(index: int,point: Vector3) -> float:
	var p=game.players[index]
	return game.flat_distance(p.position,point)/maxf(3,p.movement_speed())+p.touch_cooldown*.4
