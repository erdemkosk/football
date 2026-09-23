extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
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
var departing_player := -1
var defence_candidate := -1
var defence_candidate_age := 0.0

func reset() -> void:
	cooldown=0
	manual_hold=0
	run_receiver=-1
	touch_hold=0; prediction_in=0
	previous_contacts.clear(); previous_velocity=Vector3.ZERO
	predicted_receiver=-1
	departing_player=-1
	defence_candidate=-1; defence_candidate_age=0

func eligible(index: int) -> bool:
	return index>=0 and index<game.players.size() and game.players[index].team==0 and game.players[index].visible and not game.players[index].dismissed

func automatic() -> bool:
	return game.training_drills.team_play() and not game.player_lock and not game.menu_match.running and game.state=="playing"

func touched(index: int) -> void:
	if game.state!="playing" or index<0 or index>=game.players.size(): return
	var player=game.players[index]
	if not player.visible or player.dismissed: return
	# A real deflection ends the previous carry, even when both bodies remain
	# close to the ball. Otherwise update() immediately selects that old owner.
	if game.dribbler>=0 and game.dribbler!=index:
		game.players[game.dribbler].dribble_motion.release_collision()
		game.dribbler=-1
	if game.carrier>=0 and game.carrier!=index: game.carrier=-1
	if not automatic() or not eligible(index): return
	# A chest trap, spill or tackle is still a touch, even during recovery.
	manual_hold=0; touch_hold=.18; prediction_in=0
	predicted_receiver=-1
	departing_player=-1
	if game.controlled==index: return
	if game.requested_receiver>=0: game.clear_pass_request()
	select(index)
	game.players[index].desired=game.movement_input()

func released(index: int) -> void:
	touch_hold=0; cooldown=0; prediction_in=0
	departing_player=index
	if index==game.controlled: manual_hold=0

func physical_contacts() -> void:
	var contacts: Array[int]=[]
	for body in game.ball.get_colliding_bodies():
		var index: int=game.players.find(body)
		if index<0: continue
		if not game.players[index].visible or game.players[index].dismissed: continue
		contacts.append(index)
		# Continuous capsule overlap must not repeatedly steal a manual choice.
		if index not in previous_contacts and not (index==game.last_kicker and game.kick_lock>0):
			game.last_touch=game.players[index].team
			game.last_kicker=index
			touched(index)
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
	defence_candidate=-1; defence_candidate_age=0
	if manual: manual_hold=1.0; predicted_receiver=-1

func opponent_possession() -> bool:
	if game.ball.held_by!=null: return game.ball.held_by.team==1
	return game.dribbler>=0 and game.players[game.dribbler].visible and game.players[game.dribbler].team==1

func committed_challenge(index: int) -> bool:
	var p=game.players[index]
	return eligible(index) and p.action_timer>0 and p.pose in ["poke","slide","intercept"] and game.flat_distance(p.position,game.ball.position)<2.4

func defender_cost(index: int) -> float:
	if not eligible(index): return INF
	var p=game.players[index]
	if p.keeper or p.action_timer>0 or p.dummy_time>0: return INF
	var ball: Vector3=game.ball.position*Vector3(1,0,1)
	var velocity: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
	if opponent_possession() and game.dribbler>=0: velocity=game.players[game.dribbler].velocity
	# Proximity remains the main signal. A short look ahead distinguishes an
	# already beaten chaser from the nearby defender who can meet the runner.
	var target := ball+(velocity*Vector3(1,0,1)).limit_length(14)*.26
	var offset: Vector3=ball-p.position*Vector3(1,0,1)
	var gap := offset.length()
	var cost: float=gap*.55+game.flat_distance(p.position,target)*.45
	var closing: float=p.velocity.dot(offset.normalized()) if gap>.01 else 0.0
	cost+=clampf(-closing*.12,0,.8)+(1-p.energy)*.35
	return cost

func switch_choice(exclude_current: bool=true) -> int:
	var best := -1
	var cost := INF
	for i in range(1,11):
		if exclude_current and i==game.controlled: continue
		var candidate_cost := defender_cost(i)
		if candidate_cost<cost: best=i; cost=candidate_cost
	return best

func next_switch() -> int:
	if game.state!="playing" or not game.training_drills.team_play() or game.menu_match.running or eligible(game.dribbler) or game.ball.held_by!=null: return -1
	return switch_choice()

func select_defender(delta: float) -> void:
	var best := switch_choice(false)
	if best<0 or best==game.controlled:
		defence_candidate=-1; defence_candidate_age=0
		return
	var current_cost := defender_cost(game.controlled)
	var advantage := current_cost-defender_cost(best)
	# Small positional differences are not a reason to take the cursor away.
	if advantage<.65:
		defence_candidate=-1; defence_candidate_age=0
		return
	if defence_candidate!=best: defence_candidate=best; defence_candidate_age=0
	defence_candidate_age+=delta
	var current_gap: float=game.flat_distance(game.players[game.controlled].position,game.ball.position)
	var best_gap: float=game.flat_distance(game.players[best].position,game.ball.position)
	var urgent := is_inf(current_cost) or advantage>2.4 or (best_gap<2.1 and current_gap>best_gap+.9)
	if urgent or (cooldown<=0 and defence_candidate_age>=.09):
		select(best)
		cooldown=.28

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
	var opposing := opponent_possession()
	var committed := committed_challenge(game.controlled)
	if eligible(game.controlled):
		if manual_hold>0 and (current.action_timer<=0 or committed): return
		if touch_hold>0 and not opposing: return
	if not game.kick_contact.pending.is_empty(): return
	if game.aerial_shot_active(game.controlled): return
	if committed: return
	# Calling a second presser is an explicit choice to cover with this player.
	if game.defending.pressing and game.defending.presser>=0 and eligible(game.controlled) and current.action_timer<=0: return
	var owner := -1
	if game.dribbler<0 and game.kick_lock<=0 and game.ball.position.y<1.05 and game.ball.linear_velocity.length()<16:
		owner=game.nearest_to_ball(1.12)
	if owner>=0:
		var p=game.players[owner]
		if eligible(owner) and (not p.keeper or game.last_touch==0) and p.action_timer<=0 and p.touch_cooldown<=0 and p.dummy_time<=0:
			if owner!=game.controlled: select(owner)
			return
	if opposing:
		# An intercepted pass must not leave the old attack's input state locking
		# the cursor to a player who is no longer involved in the challenge.
		if game.requested_receiver>=0: game.clear_pass_request()
		if game.pass_charging: game.cancel_pass()
		game.charging=false; game.charge=0
	elif game.charging or game.pass_charging or game.requested_receiver>=0: return
	var velocity: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
	var changed := velocity.distance_to(previous_velocity)>4
	previous_velocity=velocity
	var in_flight: bool=game.dribbler<0 and game.ball.held_by==null and (velocity.length()>2 or game.ball.position.y>.6)
	var current_available: bool=eligible(game.controlled) and current.action_timer<=0 and current.dummy_time<=0
	if in_flight and (prediction_in<=0 or changed or not current_available):
		prediction_in=.08
		var reception := predict_receiver(velocity)
		predicted_receiver=reception.index
		predicted_point=reception.point
		if reception.index>=0 and reception.index!=game.controlled and (not current_available or ((cooldown<=0 or changed) and reception.advantage>.22)):
			select(reception.index)
	# Do not undo a valid receiver choice with the ground-defence heuristic,
	# especially while the real rigid body is still applying a pending kick.
	if in_flight and predicted_receiver>=0: return
	predicted_receiver=-1
	select_defender(delta)

func predict_receiver(velocity: Vector3) -> Dictionary:
	var costs: Dictionary={}
	var targets: Dictionary={}
	var own_pass: bool=game.last_touch==0 and game.ai_pass_time[0]>0
	for i in range(11):
		if not eligible(i): continue
		var p=game.players[i]
		if p.action_timer>0 or p.dummy_time>0 or i in game.rules.candidates: continue
		if i==departing_player and (game.kick_lock>0 or own_pass): continue
		# Keep the outfield defence selected on opponent shots until a real save.
		if p.keeper and not (own_pass and game.ai_receivers[0]==i): continue
		costs[i]=INF
	var point: Vector3=game.ball.position
	var spin: float=game.ball.spin
	var drag := Motion.air_drag(game.weather)
	const STEP := .08
	for sample in range(1,51):
		var airborne: bool=point.y>game.ball.RADIUS+.08 or absf(velocity.y)>1.2
		if airborne:
			velocity=Motion.apply_spin(Motion.air_velocity(velocity,STEP,drag),spin,STEP)
			velocity.y-=Motion.GRAVITY*STEP
		else:
			var resistance := Motion.profile(game.weather,point)
			var flat := Vector3(velocity.x,0,velocity.z)
			velocity=flat.normalized()*Motion.rolling_speed(flat.length(),STEP,resistance)
		spin=Motion.decay_spin(spin,STEP,airborne)
		point+=velocity*STEP
		if point.y<game.ball.RADIUS: point.y=game.ball.RADIUS; velocity.y=0
		if absf(point.x)>P.HALF_WIDTH or absf(point.z)>50: break
		if point.y>2.05 or (point.y>.65 and velocity.y>2.5): continue
		var time := sample*STEP
		for i in costs:
			var p=game.players[i]
			var gap: float=game.flat_distance(p.position,point)
			var speed: float=maxf(.1,p.movement_speed())
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

func awaiting_delivery() -> bool:
	if game.player_lock or game.dribbler>=0 or game.ball.held_by!=null: return false
	if game.last_touch!=0: return false
	if game.incoming_receiver==game.controlled and game.incoming_time>0: return true
	if game.ai_receivers[0]==game.controlled and game.ai_pass_time[0]>0: return true
	return predicted_receiver==game.controlled

func reception_direction() -> Vector3:
	# FIFA-style: jog to the drop / meeting point. Sprint only changes pace.
	if not awaiting_delivery(): return Vector3.ZERO
	var p=game.players[game.controlled]
	if p.action_timer>0: return Vector3.ZERO
	var distance: float=game.flat_distance(p.position,game.ball.position)
	var velocity: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
	var target: Vector3=game.ai_attack.receiving_target(game.controlled)
	if predicted_receiver==game.controlled and game.ai_receivers[0]!=game.controlled and game.incoming_receiver!=game.controlled:
		target=predicted_point
	if run_receiver==game.controlled and velocity.dot(run_target-game.ball.position)>0 and distance>1.1:
		target=run_target
	target.x=clampf(target.x,-(P.HALF_WIDTH-2),(P.HALF_WIDTH-2)); target.z=clampf(target.z,-48,48)
	var offset: Vector3=(target-p.position)*Vector3(1,0,1)
	if offset.length()<0.28: return Vector3.ZERO
	if offset.length()>1.35: return offset.normalized()
	return game.ai_attack.receiving_movement(game.controlled,target)
