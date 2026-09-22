extends RefCounted
## Select the receiver in flight; actual contact always wins over prediction.
const Motion = preload("res://scripts/ball_motion.gd")
var game
var cooldown := 0.0
var manual_hold := 0.0
var run_receiver := -1
var run_target := Vector3.ZERO
var touch_hold := 0.0
var prediction_in := 0.0
var previous_contacts: Array[int] = []
var previous_velocity := Vector3.ZERO
var predicted_receiver := -1
var predicted_point := Vector3.ZERO

func reset() -> void:
	cooldown=0
	manual_hold=0
	run_receiver=-1
	touch_hold=0; prediction_in=0
	previous_contacts.clear(); previous_velocity=Vector3.ZERO
	predicted_receiver=-1

func eligible(index: int) -> bool:
	return index>=0 and index<game.players.size() and game.players[index].team==0 and game.players[index].visible and not game.players[index].dismissed

func automatic() -> bool:
	return not game.training and not game.player_lock and not game.menu_match.running and game.state=="playing"

func touched(index: int) -> void:
	if not automatic() or not eligible(index): return
	# A chest trap, spill or tackle is still a touch, even during recovery.
	manual_hold=0; touch_hold=.18; prediction_in=0
	predicted_receiver=-1
	if game.controlled==index: return
	if game.requested_receiver>=0: game.clear_pass_request()
	select(index)
	game.players[index].desired=game.movement_input()

func released(index: int) -> void:
	touch_hold=0; cooldown=0; prediction_in=0
	if index==game.controlled: manual_hold=0

func physical_contacts() -> void:
	var contacts: Array[int]=[]
	for body in game.ball.get_colliding_bodies():
		var index: int=game.players.find(body)
		if index<0: continue
		contacts.append(index)
		# Continuous capsule overlap must not repeatedly steal a manual choice.
		if index not in previous_contacts and not (index==game.last_kicker and game.kick_lock>0): touched(index)
	previous_contacts=contacts

func follow_pass(receiver: int,route: Dictionary) -> void:
	run_receiver=receiver if route.get("through",false) else -1
	run_target=route.target

func select(index: int,manual: bool=false) -> void:
	if game.menu_match.running: return
	if index<0 or index>=game.players.size(): return
	var p=game.players[index]
	if not p.visible or p.dismissed or p.team!=0: return
	if game.controlled!=index:
		game.heading.cancel(game.controlled)
		game.volleys.cancel(game.controlled)
		game.aerial_assist.cancel(game.controlled)
		game.finishing.clear_pending(); game.finishing.style=""
		game.players[game.controlled].shot_preparation=0
		game.controlled=index
		game.charging=false; game.charge=0; game.cancel_pass()
		var direction: Vector3=game.movement_input()
		game.last_direction=direction.normalized() if direction.length()>0.1 else p.facing
		for i in range(game.players.size()): game.players[i].chosen=i==index
	cooldown=0.75
	if manual: manual_hold=1.4; predicted_receiver=-1

func update(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	manual_hold=maxf(0,manual_hold-delta)
	touch_hold=maxf(0,touch_hold-delta)
	prediction_in=maxf(0,prediction_in-delta)
	if not automatic(): previous_contacts.clear(); return
	physical_contacts()
	var current=game.players[game.controlled]
	if game.ball.held_by==game.players[0]:
		touched(0)
		return
	if eligible(game.dribbler):
		touched(game.dribbler)
		return
	if eligible(game.controlled) and (manual_hold>0 or touch_hold>0): return
	if game.ball.held_by!=null or not game.kick_contact.pending.is_empty(): return
	if game.aerial_shot_active(game.controlled): return
	var owner := -1
	if game.dribbler<0 and game.kick_lock<=0 and game.ball.position.y<1.05 and game.ball.linear_velocity.length()<16:
		owner=game.nearest_to_ball(1.12)
	if owner>=0:
		var p=game.players[owner]
		if eligible(owner) and (not p.keeper or game.last_touch==0) and p.action_timer<=0 and p.touch_cooldown<=0 and p.dummy_time<=0:
			if owner!=game.controlled: select(owner)
			return
	if game.charging or game.pass_charging or game.aerial_shot_active(game.controlled) or game.requested_receiver>=0: return
	var velocity: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
	var changed := velocity.distance_to(previous_velocity)>4
	previous_velocity=velocity
	if game.dribbler<0 and (velocity.length()>2 or game.ball.position.y>.6) and (prediction_in<=0 or changed):
		prediction_in=.08
		var reception := predict_receiver(velocity)
		predicted_receiver=reception.index
		predicted_point=reception.point
		if reception.index>=0 and reception.index!=game.controlled and (not eligible(game.controlled) or ((cooldown<=0 or changed) and reception.advantage>.22)):
			select(reception.index)
			return
	if current.visible and not current.dismissed and (cooldown>0 or manual_hold>0 or current.action_timer>0): return
	var threat: Vector3=game.ball.position+game.ball.linear_velocity.limit_length(20)*0.3
	if game.ball.held_by!=null: return
	var best := -1
	var best_cost := INF
	for i in range(1,11):
		var p=game.players[i]
		if not p.visible or p.dismissed or p.action_timer>0: continue
		var cost: float=game.flat_distance(p.position,threat)+(1-p.energy)*1.5
		if cost<best_cost: best_cost=cost; best=i
	var current_distance: float=game.flat_distance(current.position,threat)
	# A substantial advantage avoids the cursor hopping between nearby defenders.
	if best>=0 and best!=game.controlled and (not current.visible or current.dismissed or (current_distance>8 and best_cost+5<current_distance)):
		select(best)

func predict_receiver(velocity: Vector3) -> Dictionary:
	var costs: Dictionary={}
	var targets: Dictionary={}
	var own_pass: bool=game.last_touch==0 and game.ai_pass_time[0]>0
	for i in range(11):
		if not eligible(i): continue
		var p=game.players[i]
		if p.action_timer>0 or p.dummy_time>0 or i in game.rules.candidates: continue
		if i==game.last_kicker and (game.kick_lock>0 or own_pass): continue
		# Keep the outfield defence selected on opponent shots until a real save.
		if p.keeper and not (own_pass and game.ai_receivers[0]==i): continue
		costs[i]=INF
	var point: Vector3=game.ball.position
	var spin: float=game.ball.spin
	var drag := Motion.air_drag(game.weather)
	const STEP := .08
	for sample in range(1,51):
		var airborne := point.y>.30 or absf(velocity.y)>1.2
		if airborne:
			velocity=Motion.apply_spin(Motion.air_velocity(velocity,STEP,drag),spin,STEP)
			velocity.y-=Motion.GRAVITY*STEP
		else:
			var resistance := Motion.profile(game.weather,point)
			var flat := Vector3(velocity.x,0,velocity.z)
			velocity=flat.normalized()*Motion.rolling_speed(flat.length(),STEP,resistance)
		spin=Motion.decay_spin(spin,STEP,airborne)
		point+=velocity*STEP
		if point.y<.22: point.y=.22; velocity.y=0
		if absf(point.x)>32 or absf(point.z)>50: break
		if point.y>2.05 or (point.y>.65 and velocity.y>2.5): continue
		var time := sample*STEP
		for i in costs:
			var p=game.players[i]
			var gap: float=game.flat_distance(p.position,point)
			var speed: float=maxf(3.4,p.movement_speed())
			var travel := maxf(0,gap-.85)/speed
			# Standing players need a short acceleration step before an interception.
			travel+=.12*(1-clampf(p.velocity.length()/speed,0,1))
			if travel>time+.16: continue
			var cost := time+maxf(0,travel-time)*2
			if own_pass and game.ai_receivers[0]==i: cost-=.10
			if cost<costs[i]: costs[i]=cost; targets[i]=point
	var best := -1
	var best_cost := INF
	for i in costs:
		if costs[i]<best_cost: best=i; best_cost=costs[i]
	return {"index":best,"point":targets.get(best,game.ball.position),"advantage":float(costs.get(game.controlled,INF))-best_cost}

func reception_direction() -> Vector3:
	var predicted: bool=predicted_receiver==game.controlled
	if game.player_lock or game.pass_assistance==0 or (game.ai_receivers[0]!=game.controlled and not predicted) or game.ai_pass_time[0]<=0 or game.last_touch!=0 or game.dribbler>=0: return Vector3.ZERO
	var p=game.players[game.controlled]
	if p.action_timer>0 or game.ball.held_by!=null: return Vector3.ZERO
	var distance: float=game.flat_distance(p.position,game.ball.position)
	var velocity: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
	var target: Vector3=game.ball.position+velocity*clampf(distance/14,0.08,0.65)
	if predicted: target=predicted_point
	# A through-ball recipient keeps the run into space instead of checking back.
	if run_receiver==game.controlled and velocity.dot(run_target-game.ball.position)>0 and distance>1.1:
		target=run_target
	target.x=clampf(target.x,-30,30); target.z=clampf(target.z,-48,48)
	var offset: Vector3=(target-p.position)*Vector3(1,0,1)
	return offset.normalized()*clampf(offset.length()/1.4,0,1)
