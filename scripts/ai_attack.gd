extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
## Opponent decisions use the same ball, pass planners, stamina and contact windows.
var game
var think_in: Dictionary = {}
var skill_in: Dictionary = {}
var team_skill_in := [0.0,0.0]
var flourish_in := [0.0,0.0]
var uses: Dictionary = {}
var last_decision := ""
var finishing := preload("res://scripts/advanced_finishing.gd").new()
var decisions := preload("res://scripts/attack_decisions.gd").new()
var delivery := preload("res://scripts/ai_delivery.gd").new()
var carry_cache: Dictionary = {}
var carry_age := 0.0
var positioning: Dictionary = {}
var holds: Dictionary = {}
var hold_cooldown: Dictionary = {}

func reset() -> void:
	delivery.game=game
	think_in.clear(); skill_in.clear(); uses.clear(); last_decision=""
	team_skill_in=[0.0,0.0]; flourish_in=[0.0,0.0]
	finishing.reset(); decisions.reset(); carry_cache.clear(); carry_age=0
	positioning.clear()
	holds.clear(); hold_cooldown.clear()

func race_sprint(index: int,target: Vector3) -> bool:
	var p=game.players[index]
	if p.exhausted or p.energy<.18: return false
	var gap: Vector3=(target-p.position)*Vector3(1,0,1)
	if gap.length()<3.0: return false
	var ball_velocity: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
	var escaping: bool=ball_velocity.dot(gap.normalized())>3.0
	var contested := false
	for q in game.players:
		if q.team==p.team or not q.visible or q.dismissed or q.keeper: continue
		if game.flat_distance(q.position,target)<gap.length()+3 and q.velocity.length()>3.2:
			contested=true; break
	return gap.length()>7 or escaping or contested

func positional_movement(index: int,target: Vector3,delta: float) -> Vector3:
	var p=game.players[index]
	if not positioning.has(index):
		positioning[index]={"target":target,"age":0.0,"moving":game.flat_distance(p.position,target)>1.25}
	var state: Dictionary=positioning[index]
	state.age-=delta
	# Off-ball shape changes have individual observation times and a settled
	# stance. A tiny ball movement no longer sets all 20 bodies walking/turning.
	if state.age<=0 or game.flat_distance(state.target,target)>5:
		state.target=target
		state.age=.17+fmod(index*.137,.26)
	var offset: Vector3=(state.target-p.position)*Vector3(1,0,1)
	if state.moving and offset.length()<.32: state.moving=false
	elif not state.moving and offset.length()>1.25: state.moving=true
	if not state.moving: return Vector3.ZERO
	return offset.normalized()*clampf(offset.length()/1.6,0,1)

func update(delta: float) -> void:
	finishing.game=game
	if game.state!="playing": finishing.reset(); return
	carry_age-=delta
	if carry_age<=0: carry_cache.clear(); carry_age=.22
	for i in think_in: think_in[i]=maxf(0,think_in[i]-delta)
	for i in skill_in: skill_in[i]=maxf(0,skill_in[i]-delta)
	for i in hold_cooldown: hold_cooldown[i]=maxf(0,hold_cooldown[i]-delta)
	for i in holds.keys():
		holds[i].age+=delta
		if game.dribbler!=i or not game.players[i].visible: holds.erase(i)
	for team in range(2):
		team_skill_in[team]=maxf(0,team_skill_in[team]-delta)
		flourish_in[team]=maxf(0,flourish_in[team]-delta)

func record(kind: String) -> void:
	last_decision=kind
	uses[kind]=int(uses.get(kind,0))+1

func clearance(point: Vector3,team: int,include_keeper: bool=true) -> float:
	var distance := 20.0
	for q in game.players:
		if not q.visible or q.dismissed or q.team==team: continue
		if q.keeper and not include_keeper: continue
		distance=minf(distance,game.flat_distance(q.position,point))
	return distance

func through_on_goal(index: int) -> bool:
	var p=game.players[index]
	var forward: float=game.attack_sign(p.team)
	var attack: float=p.position.z*forward
	if attack<14: return false
	var cover := 20.0
	var chase := 20.0
	for q in game.players:
		if not q.visible or q.dismissed or q.team==p.team or q.keeper: continue
		var gap: float=game.flat_distance(p.position,q.position)
		if q.position.z*forward>=attack-1.2: cover=minf(cover,gap)
		else: chase=minf(chase,gap)
	return cover>4.8 and chase>2.6

func onside(index: int,team: int) -> bool:
	var p=game.players[index]
	return p.visible and not p.dismissed and p.team==team and not p.keeper and p.position.z*game.attack_sign(team)<=game.rules.offside_line(team)+.10

func level(team: int) -> int:
	return game.opponent_coach.level() if team==1 else 1

func pressure_read(index: int,include_keeper: bool=true) -> Dictionary:
	var p=game.players[index]
	var result := {"gap":20.0,"closing":0.0,"time":10.0,"urgency":0.0,"opponent":-1}
	var horizon: float=[.28,.52,.72][level(p.team)]*lerpf(.72,1.18,game.management.identity.quality(index))
	for j in range(game.players.size()):
		var q=game.players[j]
		if not q.visible or q.dismissed or q.team==p.team: continue
		if q.keeper and not include_keeper: continue
		var offset: Vector3=(p.position-q.position)*Vector3(1,0,1)
		var gap := offset.length()
		if gap>12: continue
		var relative: Vector3=(q.velocity-p.velocity)*Vector3(1,0,1)
		var closing := maxf(0,relative.dot(offset.normalized()))
		var meeting := clampf(offset.dot(relative)/maxf(.01,relative.length_squared()),0,horizon)
		var predicted := (offset-relative*meeting).length()
		var urgency := 1-smoothstep(1.0,4.8,minf(gap,predicted))
		if urgency>result.urgency or (is_equal_approx(urgency,result.urgency) and gap<result.gap):
			result={"gap":gap,"closing":closing,"time":maxf(0,gap-1.1)/maxf(.1,closing),"urgency":urgency,"opponent":j}
	return result

func future_clearance(point: Vector3,team: int,time: float) -> float:
	var room := 20.0
	for q in game.players:
		if not q.visible or q.dismissed or q.team==team: continue
		var predicted: Vector3=q.position+(q.velocity*Vector3(1,0,1)).limit_length(11)*time
		room=minf(room,game.flat_distance(predicted,point))
	return room

static func sampled_clearance(point: Vector3,positions: PackedVector2Array) -> float:
	var at := Vector2(point.x,point.z)
	var closest_squared := 400.0
	for position in positions: closest_squared=minf(closest_squared,at.distance_squared_to(position))
	return sqrt(closest_squared)

func carry_sprint(index: int,target: Vector3,read: Dictionary) -> bool:
	var p=game.players[index]
	if p.energy<.28 or p.exhausted or p.ball_actions.control_grace>0 or p.receive_timer>.12: return false
	var aim: Vector3=((target-p.position)*Vector3(1,0,1)).normalized()
	var room := future_clearance(p.position+aim*3.2,p.team,.32)
	var pursued: bool=read.closing>1.5 and read.gap<10 and read.urgency>.12
	var open_run: bool=room>5.5 and game.flat_distance(p.position,target)>3 and p.position.z*game.attack_sign(p.team)<30
	return room>1.8 and (pursued or open_run)

func carry_movement(index: int,target: Vector3) -> Vector3:
	var p=game.players[index]
	var offset: Vector3=(target-p.position)*Vector3(1,0,1)
	var ball_offset: Vector3=(game.ball.position-p.position)*Vector3(1,0,1)
	if p.receive_timer>0 and ball_offset.length()>.85:
		# Complete the receiving step before accelerating away from the ball.
		# This is body steering; the ball still needs its normal foot impulse.
		var settle: Vector3=game.ball.linear_velocity*Vector3(1,0,1)+ball_offset*4-p.velocity*Vector3(1,0,1)*.35
		return (settle/maxf(1,p.movement_speed())).limit_length(.7)
	return offset.normalized()*clampf(offset.length()/1.4,0,1)

func carry_target(index: int) -> Vector3:
	var p=game.players[index]
	var read := pressure_read(index)
	if carry_cache.has(index) and read.urgency<.35: return carry_cache[index]
	var forward: float=game.attack_sign(p.team)
	var target := Vector3(clampf(p.position.x*.65,-22,22),0,forward*48)
	if not game.autonomous_kicks(p.team): return target
	# All candidate directions see the same opponents and prediction times.
	# Read/predict each opponent once instead of 27 times under pressure.
	var far_positions := PackedVector2Array()
	var near_positions := PackedVector2Array()
	var turn_positions := PackedVector2Array()
	for q in game.players:
		if not q.visible or q.dismissed or q.team==p.team: continue
		var origin: Vector3=q.position
		var motion: Vector3=(q.velocity*Vector3(1,0,1)).limit_length(11)
		var far_point := origin+motion*.55
		var near_point := origin+motion*.26
		var turn_point := origin+motion*.3
		far_positions.append(Vector2(far_point.x,far_point.z))
		near_positions.append(Vector2(near_point.x,near_point.z))
		turn_positions.append(Vector2(turn_point.x,turn_point.z))
	var best := -INF
	var directions := [Vector3(0,0,forward),Vector3(-.65,0,forward).normalized(),Vector3(.65,0,forward).normalized(),Vector3(-1.15,0,forward).normalized(),Vector3(1.15,0,forward).normalized()]
	if read.urgency>.25:
		directions.append_array([Vector3.LEFT,Vector3.RIGHT,Vector3(-.8,0,-forward).normalized(),Vector3(.8,0,-forward).normalized()])
	for aim: Vector3 in directions:
		var at: Vector3=p.position+aim*5.5
		at.x=clampf(at.x,-(P.HALF_WIDTH-3),(P.HALF_WIDTH-3)); at.z=clampf(at.z,-47,47)
		var room := minf(sampled_clearance(at,far_positions),sampled_clearance(p.position+aim*2.2,near_positions)+1)
		var value: float=room*.8+(at.z-p.position.z)*forward*.5-absf(at.x)*.015
		var near_room := sampled_clearance(p.position+aim*2.2,turn_positions)
		value-=maxf(0,2.5-near_room)*(3+read.urgency*3)
		value-=maxf(0,absf(p.position.x+aim.x*7)-(P.HALF_WIDTH-2))*3
		if value>best: best=value; target=at
	carry_cache[index]=target
	return target

func receiving_target(index: int) -> Vector3:
	var p=game.players[index]
	var ball=game.ball
	var velocity: Vector3=ball.kick_velocity if ball.pending_kick else ball.linear_velocity
	if ball.position.y>.6 or velocity.y>2:
		return aerial_target(index,ball.position+velocity*.25)
	var motion: Vector3=velocity*Vector3(1,0,1)
	var speed := motion.length()
	var resistance: Vector2=game.Passing.Motion.profile(game.weather,ball.position)
	var point: Vector3=ball.position
	# Find a reachable point on the slowing ball's path. Running toward a fixed
	# fraction of its velocity makes receivers race past an incoming pass.
	# Arrive at a controllable pace even when the approach began at a sprint.
	# Exhaustion and individual pace can reduce this, never increase it.
	var pace: float=minf(6.2,p.movement_speed())
	for step in range(1,25):
		var time := step*.08
		point=ball.position+motion.normalized()*game.Passing.Motion.distance_at(speed,time,resistance)
		var offset: Vector3=(point-p.position)*Vector3(1,0,1)
		var initial := maxf(0,p.velocity.dot(offset.normalized()))
		var reach := maxf(0,pace*time-maxf(0,pace-initial)*minf(time,.25)*.5)
		if offset.length()<=reach+.65: break
	point.y=0
	point.x=clampf(point.x,-(P.HALF_WIDTH-1),(P.HALF_WIDTH-1)); point.z=clampf(point.z,-48.5,48.5)
	return point

func receiving_movement(index: int,target: Vector3) -> Vector3:
	var p=game.players[index]
	var offset: Vector3=(target-p.position)*Vector3(1,0,1)
	# Brake before the meeting point, including momentum from the previous run.
	# The usual player acceleration, stamina and first-touch physics still apply.
	var arrival_speed := minf(offset.length()*4.5,sqrt(20*offset.length()))
	var velocity: Vector3=offset.normalized()*arrival_speed-p.velocity*Vector3(1,0,1)*.35
	return (velocity/maxf(1,p.movement_speed())).limit_length(1)

func shot_quality(point: Vector3,team: int) -> float:
	var goal := Vector3(0,0,game.attack_sign(team)*50)
	var distance: float=game.flat_distance(point,goal)
	if distance>31 or point.z*game.attack_sign(team)>49: return 0
	var quality := clampf(1.12-distance*.025-absf(point.x)*.019,0,1)
	for q in game.players:
		if not q.visible or q.dismissed or q.keeper or q.team==team: continue
		var near := Geometry3D.get_closest_point_to_segment(q.position*Vector3(1,0,1),point*Vector3(1,0,1),goal)
		if game.flat_distance(near,q.position)<1 and game.flat_distance(point,q.position)>1:
			quality*=.45
	return quality

func square_choice(index: int) -> Dictionary:
	var p=game.players[index]
	if level(p.team)==0: return {}
	var best: float=shot_quality(p.position,p.team)+.18
	var result: Dictionary={}
	for j in range(game.players.size()):
		if j==index or not onside(j,p.team): continue
		var q=game.players[j]
		var distance: float=game.flat_distance(p.position,q.position)
		if distance<4 or distance>23: continue
		var quality := shot_quality(q.position,p.team)
		if quality<best or clearance(q.position,p.team)<2: continue
		var route: Dictionary=game.Passing.plan(game.ball.position,q.position,q.velocity,false,game.weather)
		var kind := "square"
		if absf(p.position.x)>17 and p.position.z*game.attack_sign(p.team)>40:
			route=game.Passing.driven_cross(game.ball.position,q.position,q.velocity,game.weather); kind="driven_cross"
		if game.Passing.risk(game.ball.position,route,p.team,game.players)>.30: continue
		best=quality; result=pass_choice(kind,route,j)
	return result

func defend(index: int) -> bool:
	var p=game.players[index]
	var gap: float=game.flat_distance(p.position,game.ball.position)
	if gap>=2.7: return false
	if p.keeper or p.dismissed or p.action_timer>0 or p.tackle_cooldown>0 or p.ai_think<game.management.reaction(p.team,index,true) or game.ball.held_by!=null or game.ball.pending_kick or game.foul_cooldown>0: return false
	var speed: float=game.ball.linear_velocity.length()
	if level(p.team)>0 and game.last_touch!=p.team and game.dribbler<0 and gap<2.7 and speed>6 and game.ball.position.y<.7:
		var future: Vector3=game.ball.position+game.ball.linear_velocity*.14
		if game.flat_distance(p.position,future)<1.15 and game.flat_distance(p.position,future)<gap:
			if game.defending.intercept(index): record("intercept"); return true
	var owner: int=game.dribbler
	if level(p.team)<1 or owner<0 or game.players[owner].team==p.team or gap>1.4: return false
	var q=game.players[owner]
	if p.yellow_cards>0 or q.position.z*game.attack_sign(p.team)<-30: return false
	var side: Vector3=((p.position-q.position)*Vector3(1,0,1)).normalized()
	if game.flat_distance(p.position,q.position)<1.05 and absf(side.dot(q.facing))<.3 and p.velocity.dot(q.velocity)>6 and game.duels.ball_exposed(index,owner):
		if game.defending.shoulder(index): record("shoulder"); return true
	return false

func distribute(index: int) -> bool:
	var p=game.players[index]
	if not game.autonomous_kicks(p.team) or game.ball.held_by!=p: return false
	var choice := delivery.outlets(index,game.ball.position,"keeper",.34)
	if choice.is_empty():
		# Wait briefly for a short outlet before choosing a measured long ball.
		if game.goalkeeping.hold_age<3.0: return false
		choice=delivery.clearance(index)
		choice.kind="punt"
	var aim: Vector3=((choice.route.target-p.position)*Vector3(1,0,1)).normalized()
	if game.keeper_distribution.queue(index,choice.kind,aim,.55,choice.route.velocity):
		game.keeper_distribution.pending.ai_choice=choice
		return true
	return false

func pass_choice(kind: String,route: Dictionary,receiver: int,one_two: bool=false) -> Dictionary:
	route.receiver=receiver
	return {"kind":kind,"route":route,"receiver":receiver,"one_two":one_two}

func keeper_foot_pass(index: int) -> bool:
	if not game.autonomous_kicks(game.players[index].team) or not game.can_touch(index,1.15): return false
	var choice := delivery.outlets(index,game.ball.position,"feet",.065)
	if choice.is_empty(): choice=delivery.clearance(index)
	choice=pass_choice(choice.kind,choice.route,choice.receiver)
	if not game.strike(index,choice.route.velocity): return false
	if not game.kick_contact.pending.is_empty() and game.kick_contact.pending.index==index: game.kick_contact.pending.ai_choice=choice
	else: kick_completed(index,choice)
	return true

func cross_choice(index: int) -> Dictionary:
	var p=game.players[index]
	var forward: float=game.attack_sign(p.team)
	if absf(p.position.x)<17 or p.position.z*forward<26: return {}
	var best := -1
	var value := -INF
	for j in range(game.players.size()):
		if j==index or not onside(j,p.team): continue
		var q=game.players[j]
		if absf(q.position.x)>13 or q.position.z*forward<27: continue
		var cost: float=clearance(q.position,p.team)*1.6-absf(q.position.z*forward-41)*.5
		if cost>value: value=cost; best=j
	if best<0: return {}
	var receiver=game.players[best]
	var ground: Dictionary=game.Passing.driven_cross(game.ball.position,receiver.position,receiver.velocity,game.weather)
	var risk: float=game.Passing.risk(game.ball.position,ground,p.team,game.players)
	var byline: bool=p.position.z*forward>41 and receiver.position.z*forward<p.position.z*forward-1
	if risk<.38 and (byline or game.flat_distance(p.position,receiver.position)<19):
		return pass_choice("driven_cross",ground,best)
	var target: Vector3=receiver.position+(receiver.velocity*Vector3(1,0,1)).limit_length(5)*.45
	target.x=clampf(target.x,-13,13); target.z=clampf(target.z,-46,46)
	target.y=game.heading.head_point(receiver).y+.18
	var flight := clampf(game.flat_distance(game.ball.position,target)/18,.95,1.65)
	var route := {"target":target,"velocity":game.Passing.Motion.lob_velocity(game.ball.position,target,flight,game.weather),"flight":flight,"lob":true,"cross":true}
	if game.Passing.risk(game.ball.position,route,p.team,game.players)<.72:
		return pass_choice("cross",route,best)
	return {}

func shot_choice(index: int) -> Dictionary:
	var p=game.players[index]
	var forward: float=game.attack_sign(p.team)
	var goal := Vector3(0,0,forward*50)
	var distance: float=game.flat_distance(game.ball.position,goal)
	if distance>26+(game.team_tactics.plan_for(p.team)-1)*2 or absf(p.position.x)>18: return {}
	var target := Vector3(-signf(p.position.x+.001)*2.2,0,forward*50)
	var keeper=game.players[11 if p.team==0 else 0]
	if level(p.team)>0 and absf(keeper.position.x)>.65: target.x=-signf(keeper.position.x)*2.55
	var aim: Vector3=((target-game.ball.position)*Vector3(1,0,1)).normalized()
	var power := clampf((distance-6)/26,.30,.78)
	var shot: Dictionary={"kind":"shot","velocity":game.shot_velocity(aim,power,false,false,index),"curve":0.0,"power":power}
	# An advancing keeper opens a chip; it still travels through the ordinary ball solver.
	if game.flat_distance(keeper.position,goal)>5.0 and distance>10 and distance<24 and (keeper.position-game.ball.position).dot(aim)>1:
		var flight := clampf(distance/15,.95,1.55)
		shot.kind="chip"
		shot.velocity=game.Passing.Motion.lob_velocity(game.ball.position,target+Vector3.UP*1.0,flight,game.weather)
		shot.power=.45
		return shot
	# One covered corner does not close the entire goal. Look at the other
	# corner before giving up the shot, using defenders' visible positions.
	if shot_blocked(index,target) and distance>7:
		var other := Vector3(-target.x,0,target.z)
		if shot_blocked(index,other): return {}
		target=other
		aim=((target-game.ball.position)*Vector3(1,0,1)).normalized()
		shot.velocity=game.shot_velocity(aim,power,false,false,index)
	if absf(p.position.x)>6 and distance>14:
		shot.kind="finesse"
		shot.curve=-signf(aim.signed_angle_to(Vector3(0,0,forward),Vector3.UP))*game.FINESSE_CURVE*game.curl_factor(index)
		shot.velocity=game.shot_velocity(aim.rotated(Vector3.UP,signf(shot.curve)*.10),power,true,false,index)
		# On the strong-foot side, a technical finisher can wrap the outside of the boot.
		var strong_side: float=-1 if p.attributes.preferred_foot==0 else 1
		if level(p.team)==2 and p.attributes.control>=84 and p.position.x*forward*strong_side< -9 and clearance(p.position,p.team)>3:
			shot={"kind":"outside","aim":aim,"power":power,"advanced":true}
	elif level(p.team)>0 and distance<13 and clearance(p.position,p.team)>2.4:
		shot={"kind":"low","aim":aim,"power":.62,"advanced":true}
	elif level(p.team)>0 and distance>20 and clearance(p.position,p.team)>6.5 and p.attributes.finishing>=78 and p.energy>.4:
		shot={"kind":"power","aim":aim,"power":.64,"advanced":true}
	return shot

func shot_blocked(index: int,target: Vector3) -> bool:
	var p=game.players[index]
	for q in game.players:
		if not q.visible or q.dismissed or q.keeper or q.team==p.team: continue
		var near := Geometry3D.get_closest_point_to_segment(q.position*Vector3(1,0,1),game.ball.position*Vector3(1,0,1),target)
		if game.flat_distance(near,q.position)<.8 and game.flat_distance(p.position,q.position)>1: return true
	return false

func decide(index: int) -> Dictionary:
	decisions.game=game
	return decisions.select(index,options(index))

func skill_choice(index: int,read: Dictionary) -> Dictionary:
	var p=game.players[index]
	if team_skill_in[p.team]>0 or read.gap<1.25 or read.gap>3.5 or p.position.z*game.attack_sign(p.team)<-20: return {}
	var nearby := 0
	for q in game.players:
		if q.visible and not q.dismissed and q.team!=p.team and game.flat_distance(q.position,p.position)<3.6: nearby+=1
	# A skill solves a one-on-one, not a swarm. Keep passing/carrying options
	# available and inspect the actual exit of each move relative to the body.
	if nearby!=1: return {}
	var kinds: Array[String]=["roll"]
	if p.velocity.length()>2.5 and read.closing>1: kinds.append("stop_go")
	if read.gap>1.7 and p.attributes.pace>=74 and p.energy>.4: kinds.append("knock_around")
	if level(p.team)==2 and p.attributes.control>=83:
		if read.gap<2.15 and read.closing>1: kinds.append("roulette")
		if p.velocity.length()>3.8: kinds.append("elastico")
		if absf(p.position.x)>24: kinds.append("scoop")
		if p.attributes.control>=90 and read.gap>2 and read.closing>3.5 and flourish_in[p.team]<=0: kinds.append("rainbow")
		if read.gap<2.3 and read.closing>1.5: kinds.append("spin")
	if level(p.team)>=1:
		if read.gap<1.9 and read.closing<1.5: kinds.append("nutmeg")
		if p.velocity.length()>3: kinds.append("heel_to_heel")
		if read.gap<2.2 and read.closing>1: kinds.append("ball_roll_cut")
	var best := -INF
	var result: Dictionary={}
	for kind in kinds:
		# The same skill-star limits apply to both teams.
		if not p.Attributes.can_perform(p,kind): continue
		for side in [-1.0,1.0]:
			var aim: Vector3=game.skills.exit_direction(kind,p.facing,side)
			# A nutmeg's first space is behind the defender it goes through.
			var near: Vector3=p.position+aim*(2.8 if kind=="nutmeg" else 1.1)
			var exit: Vector3=p.position+aim*2.5
			if absf(exit.x)>P.HALF_WIDTH-1.5 or absf(exit.z)>48: continue
			var near_room := future_clearance(near,p.team,.22)
			var exit_room := future_clearance(exit,p.team,.5)
			if near_room<1.05 or exit_room<1.8: continue
			if kind=="knock_around":
				var ball_exit: Vector3=p.position+p.facing*3.5+p.facing.cross(Vector3.UP)*side*1.1
				if future_clearance(ball_exit,p.team,.5)<1.5 or absf(ball_exit.x)>P.HALF_WIDTH-1: continue
			var value: float=minf(5,exit_room)+minf(3,near_room)*.6+aim.z*game.attack_sign(p.team)*.35
			if kind=="rainbow": value-=1.5
			if value>best:
				best=value; result={"kind":kind,"side":side,"exit":exit}
	if not result.is_empty() and result.kind=="roll" and (level(p.team)==0 or p.attributes.control<80): result.kind="feint"
	return result

func hold_choice(index: int,read: Dictionary) -> Dictionary:
	var p=game.players[index]
	if game.dribbler!=index or hold_cooldown.get(index,0.0)>0 or p.energy<.2 or read.opponent<0: return {}
	if read.gap<1.2 or read.gap>4.0 or read.closing>5 or p.position.z*game.attack_sign(p.team)<-28: return {}
	var behind: Vector3=(game.players[read.opponent].position-p.position)*Vector3(1,0,1)
	# Wait only when a teammate is actually moving into a useful outlet.
	var outlet := -1
	for j in range(game.players.size()):
		if j==index or not onside(j,p.team): continue
		var q=game.players[j]
		var distance: float=game.flat_distance(p.position,q.position)
		if distance>5 and distance<20 and q.velocity.length()>1.2 and clearance(q.position+q.velocity*.5,p.team)>2.4:
			outlet=j; break
	if outlet<0: return {}
	return {"kind":"shield" if behind.normalized().dot(p.facing)<.1 else "invite", "outlet":outlet}

func holding_action(index: int) -> bool:
	if not holds.has(index): return false
	var p=game.players[index]
	var read := pressure_read(index)
	var h: Dictionary=holds[index]
	# Pressure is an invitation, not immunity. A second defender or a tackle
	# forces an immediate new decision through the ordinary pass/skill scorer.
	var near := 0
	for q in game.players:
		if q.visible and q.team!=p.team and game.flat_distance(q.position,p.position)<3: near+=1
	if game.dribbler!=index or h.age>.65 or read.gap<1.15 or read.closing>4 or near>1:
		holds.erase(index); think_in[index]=0; return false
	p.protecting=true; p.sprinting=false
	p.facing=game.duels.shield_direction(index)
	p.desired=p.facing*.12
	return true

func options(index: int) -> Array[Dictionary]:
	var p=game.players[index]
	var risk_bias: float=game.team_tactics.plan_for(p.team)-1
	var forward: float=game.attack_sign(p.team)
	var position: Vector3=p.position
	var read := pressure_read(index)
	var pressure := minf(clearance(position,p.team),lerpf(8,1,read.urgency))
	var isolated: bool=through_on_goal(index)
	var result: Array[Dictionary]=[{"kind":"carry"}]
	var hold := hold_choice(index,read)
	if not hold.is_empty(): result.append(hold)
	var return_to: int=game.support.return_option(index)
	if return_to>=0 and not isolated:
		var runner=game.players[return_to]
		var route: Dictionary=game.Passing.plan(game.ball.position,runner.position,runner.velocity,false,game.weather)
		var run: Dictionary=game.support.runs[return_to]
		if run.get("explicit",false):
			# The runner will brake at the end of the agreed give-and-go. Do not
			# lead a return pass past that point as though the sprint continued.
			var remaining: Vector3=(run.target-runner.position)*Vector3(1,0,1)
			if (route.target-runner.position).dot(remaining)>remaining.length_squared():
				route=game.Passing.plan(game.ball.position,run.target,Vector3.ZERO,false,game.weather)
		result.append(pass_choice("return_pass",route,return_to))
	for choice in [square_choice(index),shot_choice(index),cross_choice(index)]:
		if not choice.is_empty(): result.append(choice)
	# Collect feasible routes before comparing them. Candidate order must not
	# make a mediocre through ball override a clear shot or an open teammate.
	for j in range(game.players.size()):
		if j==index or not onside(j,p.team): continue
		var q=game.players[j]
		var distance: float=game.flat_distance(position,q.position)
		var progress: float=(q.position.z-position.z)*forward
		if isolated and progress<2.0: continue
		if distance<4 or distance>52: continue
		if q.velocity.z*forward>1.4 and distance<29 and progress>2 and progress<23:
			var through: Dictionary=game.Passing.through_to(game.ball.position,q,.35,forward,game.weather)
			var risk: float=game.Passing.risk(game.ball.position,through,p.team,game.players)
			if risk<.43+risk_bias*.07 and clearance(through.target,p.team)>2.2:
				result.append(pass_choice("through",through,j))
			elif level(p.team)>0 and pressure>2.0:
				var loft: Dictionary=game.Passing.plan(game.ball.position,through.target,Vector3.ZERO,true,game.weather)
				if game.Passing.risk(game.ball.position,loft,p.team,game.players)<.38:
					result.append(pass_choice("lob_through",loft,j))
		if absf(position.x)>10 and position.z*forward<32 and pressure<7 and skill_in.get(index,0.0)<=0 and q.position.x*position.x<0 and absf(q.position.x-position.x)>29 and clearance(q.position,p.team)>4.2 and progress> -12:
			var loft: Dictionary=game.Passing.plan(game.ball.position,q.position,q.velocity,true,game.weather)
			if game.Passing.risk(game.ball.position,loft,p.team,game.players)<.55: result.append(pass_choice("switch",loft,j))
		if distance>42: continue
		var route: Dictionary=game.Passing.plan(game.ball.position,q.position,q.velocity,false,game.weather)
		var risk: float=game.Passing.risk(game.ball.position,route,p.team,game.players)
		if risk>.58+risk_bias*.08: continue
		result.append(pass_choice("pass",route,j))
		if level(p.team)>0 and pressure<5 and distance>17:
			var driven: Dictionary=game.Passing.driven_pass(game.ball.position,q.position,q.velocity,game.weather)
			if game.Passing.risk(game.ball.position,driven,p.team,game.players)<.28: result.append(pass_choice("driven_pass",driven,j))
	if not isolated and pressure<6.0 and pressure>2.3 and p.energy>.28 and position.z*forward> -18 and not game.support.runs.has(index) and skill_in.get(index,0.0)<=0:
		var wall: Dictionary=game.Passing.one_two_plan(game.ball.position,Vector3(0,0,forward),p.team,index,game.players,forward,game.rules.offside_line(p.team),game.weather)
		if not wall.is_empty() and game.Passing.risk(game.ball.position,wall,p.team,game.players)<.4:
			result.append(pass_choice("one_two",wall,wall.receiver,true))
	if game.dribbler==index and skill_in.get(index,0.0)<=0 and p.skill_cooldown<=0 and p.energy>.25:
		var skill := skill_choice(index,read)
		if not skill.is_empty(): result.append(skill)
		if pressure>7 and position.z*forward<28 and clearance(position+Vector3(0,0,forward*7),p.team)>5:
			result.append({"kind":"push"})
	if position.z*forward< -28 and pressure<3.2:
		var outlet := delivery.clearance(index)
		result.append(pass_choice("clearance",outlet.route,outlet.receiver))
	return result

func act(index: int) -> bool:
	var p=game.players[index]
	if holding_action(index): return true
	var read := pressure_read(index)
	if game.dribbler>=0 and game.dribbler!=index: return false
	# Finish the touch already in progress before choosing another action.
	if p.ball_actions.contact_pending or p.ball_actions.control_grace>0 or p.receive_timer>0 and game.dribbler!=index: return false
	var urgent: bool=read.closing>2 and read.urgency>.4
	var reaction: float=game.management.reaction(p.team,index)*(.7 if urgent else 1.0)
	var return_to: int=game.support.return_option(index)
	# An agreed give-and-go is read during the incoming pass. First-touch and
	# contact guards still apply; avoid waiting until the runner has stopped.
	if return_to>=0 and game.support.runs[return_to].get("explicit",false): reaction=minf(reaction,.30)
	if urgent and think_in.get(index,0.0)>.24: think_in[index]=.24
	if not game.autonomous_kicks(p.team) or game.state!="playing" or p.action_timer>0 or game.skills.active.has(index) or not game.can_touch(index,1.15) or game.ball.pending_kick or game.kick_lock>0 or p.touch_cooldown>0 or p.ai_think<reaction or think_in.get(index,0.0)>0: return false
	think_in[index]=.24 if urgent else (game.management.pick([1.0,.58,.36],.28) if p.team==1 else .58)*[1.45,1.0,.72][game.management.detail(p.team,"tempo")]*lerpf(1.30,.72,game.management.identity.quality(index))
	var choice := decide(index)
	if choice.is_empty(): return false
	var kind: String=choice.kind
	if kind in ["shield","invite"]:
		holds[index]={"age":0.0,"kind":kind}; hold_cooldown[index]=3.0
		record(kind); return holding_action(index)
	if choice.get("advanced",false):
		finishing.game=game
		var error: float=game.management.pass_error(p.team,index,true)
		var aim: Vector3=choice.aim.rotated(Vector3.UP,game.rng.randf_range(-error,error))
		if finishing.queue(index,aim,choice.power,kind): record(kind); return true
		return false
	if kind in ["roll","stop_go","knock_around","roulette","elastico","scoop","rainbow","heel","flick","heel_to_heel","ball_roll_cut","nutmeg","spin"]:
		if game.skills.start(index,kind,choice.side):
			skill_in[index]=2.2 if kind in ["roll","stop_go","knock_around"] else [8.0,7.0,6.0][level(p.team)]
			team_skill_in[p.team]=.8 if kind in ["roll","stop_go","knock_around"] else 3.6
			if kind=="rainbow": flourish_in[p.team]=24.0
			record(kind); return true
		return false
	if kind in ["feint","push"]:
		p.facing=Vector3(clampf(-p.position.x*.015,-.3,.3),0,game.attack_sign(p.team)).normalized()
		if kind=="feint":
			game.duels.feint(index,choice.get("side",1.0))
			team_skill_in[p.team]=2.5
			record(kind)
		else:
			game.duels.push_ahead(index)
			if game.kick_contact.pending.is_empty() or game.kick_contact.pending.index!=index: return false
			game.kick_contact.pending.ai_choice=choice
		skill_in[index]=3.8
		return true
	var velocity: Vector3=choice.velocity if choice.has("velocity") else choice.route.velocity
	var error: float=game.management.pass_error(p.team,index,choice.has("velocity"))
	velocity=velocity.rotated(Vector3.UP,game.rng.randf_range(-error,error))
	if choice.has("velocity"): p.strike_effort=float(choice.get("power",-1.0))
	if not game.strike(index,velocity,choice.get("curve",0.0),false,"shot" if choice.has("velocity") else ("cross" if kind=="cross" else "kick")): return false
	if not game.kick_contact.pending.is_empty() and game.kick_contact.pending.index==index:
		game.kick_contact.pending.ai_choice=choice
	else:
		kick_completed(index,choice)
	return true

func kick_completed(index: int,choice: Dictionary) -> void:
	# Runs, receiver assignments and statistics belong to the actual boot
	# contact. A tackled or missed windup must not launch a phantom pass.
	var p=game.players[index]
	var kind: String=choice.kind
	record(kind)
	if kind=="push":
		game.ai_receivers[p.team]=index
		game.ai_pass_time[p.team]=2.5
		return
	if choice.has("velocity"):
		game.shots[p.team]+=1
	else:
		game.passes[p.team]+=1
		var receiver: int=choice.receiver
		if kind=="return_pass": game.support.end_run(receiver)
		if receiver>=0:
			game.support.passed(index,receiver,choice.one_two)
			game.ai_receivers[p.team]=receiver
			game.ai_pass_time[p.team]=float(choice.route.flight)+2
			if p.team==0: game.team_control.follow_pass(receiver,choice.route)
	if kind in ["one_two","switch"]: skill_in[index]=4.0

func try_header(index: int) -> bool:
	var p=game.players[index]
	if not game.autonomous_kicks(p.team) or not game.heading.can_request(index) or p.ai_think<game.management.reaction(p.team,index): return false
	var forward: float=game.attack_sign(p.team)
	# A routine lofted pass is brought down. Heading it straight back to the
	# passer caused unopposed midfield deliveries to become endless loose balls.
	if game.first_touch.expected(index) and p.position.z*forward<27: return false
	var intent := "shot"
	var receiver := -1
	var aim := Vector3(-p.position.x*.08,0,forward).normalized()
	if p.position.z*forward>27 and absf(p.position.x)<18:
		aim=(Vector3(game.rng.randf_range(-2.3,2.3),0,forward*50)-p.position).normalized()
		if game.volleys.window(index,aim).get("kind","")=="bicycle": return try_volley(index)
	elif p.position.z*forward< -20:
		intent="clearance"
		aim=Vector3(0.65 if p.position.x>=0 else -.65,0,forward).normalized()
	else:
		intent="pass"
		var best := INF
		for j in range(game.players.size()):
			if j==index or not onside(j,p.team): continue
			var q=game.players[j]
			var distance: float=game.flat_distance(p.position,q.position)
			if distance>5 and distance<18 and clearance(q.position,p.team)>2 and distance<best:
				best=distance; receiver=j; aim=(q.position-p.position).normalized()
		if receiver<0: return false
	if game.heading.arm(index,aim,.55,false,intent,receiver):
		record("header_"+intent)
		return true
	return false

func try_volley(index: int) -> bool:
	var p=game.players[index]
	if not game.autonomous_kicks(p.team) or game.aerial_shot_active(index): return false
	var forward: float=game.attack_sign(p.team)
	if p.position.z*forward<26 or absf(p.position.x)>17 or not game.volleys.can_request(index) or p.ai_think<game.management.reaction(p.team,index): return false
	var aim: Vector3=(Vector3(game.rng.randf_range(-2.2,2.2),0,forward*50)-p.position).normalized()
	if game.volleys.arm(index,aim,.58,false):
		record("volley")
		return true
	return false

func aerial_target(index: int,fallback: Vector3) -> Vector3:
	if game.ball.held_by!=null: return fallback
	var p=game.players[index]
	var velocity: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
	if game.ball.position.y<.6 and velocity.y<2: return fallback
	var head: float=game.heading.head_point(p).y
	var attacking: bool=p.position.z*game.attack_sign(p.team)>27 and game.autonomous_kicks(p.team)
	var height: float=head+.30 if attacking else p.position.y+p.body_scale.y*1.25
	var pace: float=minf(6.2,p.movement_speed())*(1-game.weather.mud_at(p.position)*.16)
	var points=game.Passing.Motion.sample_flight(game.ball.position,velocity,game.ball.spin,3.0,75,game.weather)
	var result: Vector3=points[points.size()-1]
	for sample in range(1,points.size()):
		var point: Vector3=points[sample]
		var time := sample*.04
		if points[sample-1].y>height and point.y<=height:
			var fraction: float=inverse_lerp(points[sample-1].y,point.y,height)
			point=points[sample-1].lerp(point,fraction)
			time=(sample-1+fraction)*.04
		result=point
		# Meet the descending ball at an attainable height, not at the first
		# point underneath a high cross. Use the ball's actual drag and spin.
		if point.y>height+.001 or point.y>points[sample-1].y: continue
		if game.flat_distance(p.position,point)<=maxf(0,pace*(time-.10))+.45 or point.y<=game.ball.RADIUS: break
	result.x=clampf(result.x,-(P.HALF_WIDTH-2),(P.HALF_WIDTH-2)); result.y=0; result.z=clampf(result.z,-48,48)
	return result
