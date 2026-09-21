extends RefCounted
const OPEN_GAP := 1.05
const POKE_REACH := 1.35
const OPEN_POKE_REACH := 1.72
const POKE_BALL := 0.32
const OPEN_POKE_BALL := 0.46
const POKE_BODY_SLACK := 0.10
const OPEN_POKE_BODY_SLACK := 0.38
const STEAL_REACH := 0.72
const OPEN_STEAL_REACH := 1.02
const STEAL_MARGIN := 0.18
const OPEN_STEAL_MARGIN := 0.06
var game
var attempts: Dictionary = {}
var feint_side := 1.0

func reset() -> void:
	attempts.clear()
	for p in game.players:
		p.protecting=false
		p.jockeying=false
		p.feint_time=0
		p.skill_cooldown=0

func shield_direction(index: int) -> Vector3:
	var p=game.players[index]
	var direction: Vector3=p.facing
	var nearest := 4.0
	for q in game.players:
		if not q.visible or q.team==p.team: continue
		var distance: float=game.flat_distance(p.position,q.position)
		if distance<nearest:
			nearest=distance
			direction=((p.position-q.position)*Vector3(1,0,1)).normalized()
	return direction

func ball_opened(owner: int) -> bool:
	if owner<0: return true
	var p=game.players[owner]
	if p.active_sprint: return true
	return game.flat_distance(p.position,game.ball.position)>OPEN_GAP

func steal_reach(owner: int) -> float:
	return OPEN_STEAL_REACH if ball_opened(owner) else STEAL_REACH

func steal_margin(owner: int) -> float:
	return OPEN_STEAL_MARGIN if ball_opened(owner) else STEAL_MARGIN

func poke_reach(owner: int) -> float:
	return OPEN_POKE_REACH if ball_opened(owner) else POKE_REACH

func poke_ball_radius(owner: int) -> float:
	return OPEN_POKE_BALL if ball_opened(owner) else POKE_BALL

func poke_body_slack(owner: int) -> float:
	return OPEN_POKE_BODY_SLACK if ball_opened(owner) else POKE_BODY_SLACK

func ball_exposed(challenger: int,owner: int) -> bool:
	if owner<0 or ball_opened(owner) or not game.players[owner].protecting: return true
	var a: Vector3=game.players[challenger].position*Vector3(1,0,1)
	var b: Vector3=game.ball.position*Vector3(1,0,1)
	var body: Vector3=game.players[owner].position*Vector3(1,0,1)
	var near := Geometry3D.get_closest_point_to_segment(body,a,b)
	return near.distance_to(body)>0.48 or a.distance_to(b)<a.distance_to(body)

func feint(index: int) -> void:
	var p=game.players[index]
	if game.dribbler!=index or p.action_timer>0 or p.skill_cooldown>0 or p.energy<0.06: return
	game.cancel_pass()
	game.charging=false
	feint_side=-feint_side
	p.feint_side=feint_side
	p.feint_time=0.48
	p.skill_cooldown=0.85
	p.energy=maxf(0,p.energy-0.035)

func push_ahead(index: int) -> void:
	var p=game.players[index]
	if game.dribbler!=index or p.action_timer>0 or p.skill_cooldown>0 or p.energy<0.05: return
	game.clear_pass_request()
	game.charging=false
	if game.strike(index,p.facing*clampf(Vector2(p.velocity.x,p.velocity.z).length()+4.5,7,13)+Vector3.UP*0.12):
		p.skill_cooldown=0.8
		p.energy=maxf(0,p.energy-0.025)

func standing_tackle(index: int) -> void:
	var p=game.players[index]
	if not p.visible or p.action_timer>0 or p.tackle_cooldown>0 or game.dribbler==index: return
	var facing: Vector3=(game.ball.position-p.position)*Vector3(1,0,1)
	if facing.length()>0.1: p.facing=facing.normalized()
	p.pose="poke"
	p.action_timer=0.38
	p.tackle_cooldown=0.85
	p.sprinting=false
	attempts[index]=0.0

func resolve(delta: float) -> void:
	for i in attempts.keys():
		var p=game.players[i]
		if p.pose!="poke" or p.action_timer<=0: attempts.erase(i); continue
		attempts[i]+=delta
		if attempts[i]<0.12: continue
		attempts.erase(i)
		var a: Vector3=p.position*Vector3(1,0,1)
		var owner: int=game.dribbler
		var end: Vector3=a+p.facing*poke_reach(owner)
		var ball: Vector3=game.ball.position*Vector3(1,0,1)
		var victim := -1
		var body_distance := INF
		for j in range(game.players.size()):
			var q=game.players[j]
			if not q.visible or q.team==p.team: continue
			var body: Vector3=q.position*Vector3(1,0,1)
			if Geometry3D.get_closest_point_to_segment(body,a,end).distance_to(body)<0.43 and a.distance_to(body)<body_distance:
				victim=j
				body_distance=a.distance_to(body)
		var reaches_ball: bool=Geometry3D.get_closest_point_to_segment(ball,a,end).distance_to(ball)<poke_ball_radius(owner) and game.ball.position.y<0.75
		if reaches_ball and (victim<0 or a.distance_to(ball)<body_distance+poke_body_slack(owner)) and ball_exposed(i,owner):
			game.strike(i,p.facing*4.8+Vector3.UP*0.15,0,false,"ball_tackle")
		elif victim>=0 and body_distance<1.05:
			game.tackle_impact(i,victim)
			if not game.training: game.rules.foul(i,victim)

func switch_choice() -> int:
	var threat: Vector3=game.ball.position+game.ball.linear_velocity.limit_length(20)*0.38
	if game.dribbler>=0 and game.players[game.dribbler].team==1:
		threat=game.players[game.dribbler].position+game.players[game.dribbler].velocity*0.5
	var best := -1
	var best_cost := INF
	var input: Vector3=game.movement_input()
	for i in range(1,11):
		var p=game.players[i]
		if not p.visible or i==game.controlled: continue
		var cost: float=game.flat_distance(p.position,threat)
		if game.last_touch==1 and p.position.z*game.attack_sign(1)>threat.z*game.attack_sign(1): cost-=3.0
		if p.action_timer>0: cost+=10
		cost+=(1-p.energy)*2
		var relative: Vector3=(p.position-game.players[game.controlled].position)*Vector3(1,0,1)
		if input.length()>0 and relative.length()>0.1: cost-=input.normalized().dot(relative.normalized())*5
		if cost<best_cost: best_cost=cost; best=i
	return best
