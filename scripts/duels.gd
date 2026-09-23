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
		p.defensive_turn_load=0

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
	# The tackle reach follows the resized body, just like the visible leg.
	# Sprinting exposes the ball; it must not grant a two-metre invisible boot.
	return (OPEN_POKE_REACH if ball_opened(owner) else POKE_REACH)*preload("res://scripts/footballer.gd").WORLD_SCALE

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

func feint(index: int,chosen_side: float=0) -> void:
	var p=game.players[index]
	if game.dribbler!=index or p.action_timer>0 or p.skill_cooldown>0 or p.energy<0.06: return
	if game.is_user_player(index):
		game.cancel_pass()
		game.charging=false
	feint_side=signf(chosen_side) if absf(chosen_side)>.1 else -feint_side
	p.feint_side=feint_side
	p.feint_time=0.48
	p.skill_cooldown=0.85
	p.energy=maxf(0,p.energy-0.035)

func push_ahead(index: int) -> void:
	var p=game.players[index]
	if game.dribbler!=index or p.action_timer>0 or p.skill_cooldown>0 or p.energy<0.05: return
	if game.is_user_player(index):
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
	p.tackle_foot=p.ball_actions.choose_foot(p,game.ball.position)
	p.tackle_target=game.ball.position
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
		var end: Vector3=a+p.facing*poke_reach(owner)*p.Attributes.multiplier(p.attributes.get("defending",72),.075)
		var ball: Vector3=game.ball.position*Vector3(1,0,1)
		var victim := -1
		var body_distance := INF
		var body_offset := INF
		for j in range(game.players.size()):
			var q=game.players[j]
			if not q.visible or q.team==p.team: continue
			var body: Vector3=q.position*Vector3(1,0,1)
			var offset := Geometry3D.get_closest_point_to_segment(body,a,end).distance_to(body)
			if offset<0.43 and a.distance_to(body)<body_distance:
				victim=j
				body_distance=a.distance_to(body)
				body_offset=offset
		var boot: Vector3=(p.left_knee if p.tackle_foot==0 else p.right_knee).to_global(p.ball_actions.BOOT)
		var reaches_ball: bool=Geometry3D.get_closest_point_to_segment(ball,a,end).distance_to(ball)<poke_ball_radius(owner) and boot.distance_to(game.ball.position)<.53 and game.ball.position.y<0.75
		if reaches_ball and (victim<0 or a.distance_to(ball)<body_distance+poke_body_slack(owner)) and ball_exposed(i,owner):
			game.strike(i,p.facing*4.8+Vector3.UP*0.15,0,false,"ball_tackle")
		elif victim>=0 and body_distance<1.05:
			var q=game.players[victim]
			var from_victim: Vector3=(a-q.position*Vector3(1,0,1)).normalized()
			var behind: bool=from_victim.dot(q.facing)<-0.48
			var closing: float=maxf(0,(p.velocity-q.velocity).dot(-from_victim))
			var late: bool=a.distance_to(ball)>poke_reach(owner)+0.25 or game.ball.position.y>1.1
			# A missed poke beside the carrier is a duel, not an automatic trip.
			# Penalize a foot through the legs from behind, a late lunge or a forceful charge.
			var trip: bool=body_offset<0.27 and (behind or late or closing>7.5)
			if trip:
				game.tackle_impact(i,victim)
				if not game.training: game.rules.foul(i,victim,closing>10.0 and (behind or late))
			else:
				q.body_language.contact(q,-from_victim,0.25)
				p.velocity*=0.88

func ai_poke_window(index: int,owner: int) -> bool:
	var p=game.players[index]
	# A poke commits for 120 ms. If a runner will have already left its path,
	# keep moving and get alongside instead of repeatedly stabbing behind him.
	var start: Vector3=p.position*Vector3(1,0,1)+p.velocity*Vector3(1,0,1)*.065
	var now: Vector3=game.ball.position*Vector3(1,0,1)
	var future: Vector3=now+game.ball.linear_velocity*Vector3(1,0,1)*.12
	var aim: Vector3=(now-p.position*Vector3(1,0,1)).normalized()
	var end: Vector3=start+aim*poke_reach(owner)*p.Attributes.multiplier(p.attributes.get("defending",72),.075)
	return Geometry3D.get_closest_point_to_segment(future,start,end).distance_to(future)<poke_ball_radius(owner)*.9

func ai_can_challenge(index: int,owner: int,sliding: bool=false) -> bool:
	if owner<0: return false
	var p=game.players[index]
	var q=game.players[owner]
	var start: Vector3=p.position*Vector3(1,0,1)
	var ball: Vector3=game.ball.position*Vector3(1,0,1)
	var body: Vector3=q.position*Vector3(1,0,1)
	var near := Geometry3D.get_closest_point_to_segment(body,start,ball)
	var blocked := near.distance_to(body)<(0.64 if sliding else 0.36) and start.distance_to(body)+0.15<start.distance_to(ball)
	if blocked or not ball_exposed(index,owner): return false
	if p.team==1:
		var box: bool=absf(body.x)<20.16 and body.z*game.attack_sign(p.team)<-33.5
		var cautious: bool=box or p.yellow_cards>0
		var facing: Vector3=(start-body).normalized()
		var behind: bool=facing.dot(q.facing)<-.35
		var closing: float=maxf(0,(p.velocity-q.velocity).dot(-facing))
		# Penalize the attempted path through a leg, not the result of a dice roll.
		var clearance: float=near.distance_to(body)
		var first_to_ball: bool=start.distance_to(ball)+.18<start.distance_to(body)
		if cautious and (behind or closing>7.0 or (clearance<.62 and not first_to_ball)): return false
		if sliding and (p.yellow_cards>0 or (box and (clearance<.95 or not first_to_ball))): return false
	# AI slides only into a loose, reachable ball; jockeying handles protected possession.
	return not sliding or (ball_opened(owner) and game.ball.position.y<0.65 and start.distance_to(ball)<2.2)

func switch_choice() -> int:
	# LB/Q means the next nearby challenger. Directional selection belongs to
	# the right stick, so running with the left stick cannot redirect this button.
	return game.team_control.switch_choice()
