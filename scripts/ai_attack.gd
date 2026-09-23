extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
## Opponent decisions use the same ball, pass planners, stamina and contact windows.
var game
var think_in: Dictionary = {}
var skill_in: Dictionary = {}
var uses: Dictionary = {}
var last_decision := ""
var finishing := preload("res://scripts/advanced_finishing.gd").new()
var decisions := preload("res://scripts/attack_decisions.gd").new()
var carry_cache: Dictionary = {}
var carry_age := 0.0

func reset() -> void:
	think_in.clear(); skill_in.clear(); uses.clear(); last_decision=""
	finishing.reset(); decisions.reset(); carry_cache.clear(); carry_age=0

func update(delta: float) -> void:
	finishing.game=game
	if game.state!="playing": finishing.reset(); return
	carry_age-=delta
	if carry_age<=0: carry_cache.clear(); carry_age=.22
	for i in think_in: think_in[i]=maxf(0,think_in[i]-delta)
	for i in skill_in: skill_in[i]=maxf(0,skill_in[i]-delta)

func record(kind: String) -> void:
	last_decision=kind
	uses[kind]=int(uses.get(kind,0))+1

func clearance(point: Vector3,team: int) -> float:
	var distance := 20.0
	for q in game.players:
		if q.visible and not q.dismissed and q.team!=team: distance=minf(distance,game.flat_distance(q.position,point))
	return distance

func onside(index: int,team: int) -> bool:
	var p=game.players[index]
	return p.visible and not p.dismissed and p.team==team and not p.keeper and p.position.z*game.attack_sign(team)<=game.rules.offside_line(team)+.10

func level(team: int) -> int:
	return game.opponent_coach.level() if team==1 else 1

func pressure_read(index: int) -> Dictionary:
	var p=game.players[index]
	var result := {"gap":20.0,"closing":0.0,"time":10.0,"urgency":0.0,"opponent":-1}
	var horizon: float=[.28,.52,.72][level(p.team)]
	for j in range(game.players.size()):
		var q=game.players[j]
		if not q.visible or q.dismissed or q.team==p.team: continue
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
	var best := -INF
	var directions := [Vector3(0,0,forward),Vector3(-.65,0,forward).normalized(),Vector3(.65,0,forward).normalized(),Vector3(-1.15,0,forward).normalized(),Vector3(1.15,0,forward).normalized()]
	if read.urgency>.25:
		directions.append_array([Vector3.LEFT,Vector3.RIGHT,Vector3(-.8,0,-forward).normalized(),Vector3(.8,0,-forward).normalized()])
	for aim: Vector3 in directions:
		var at: Vector3=p.position+aim*5.5
		at.x=clampf(at.x,-(P.HALF_WIDTH-3),(P.HALF_WIDTH-3)); at.z=clampf(at.z,-47,47)
		var room := minf(future_clearance(at,p.team,.55),future_clearance(p.position+aim*2.2,p.team,.26)+1)
		var value: float=room*.8+(at.z-p.position.z)*forward*.5-absf(at.x)*.015
		var near_room := future_clearance(p.position+aim*2.2,p.team,.3)
		value-=maxf(0,2.5-near_room)*(3+read.urgency*3)
		value-=maxf(0,absf(p.position.x+aim.x*7)-(P.HALF_WIDTH-2))*3
		if value>best: best=value; target=at
	carry_cache[index]=target
	return target

func receiving_target(index: int) -> Vector3:
	var p=game.players[index]
	var ball=game.ball
	var velocity: Vector3=ball.kick_velocity if ball.pending_kick else ball.linear_velocity
	if ball.position.y>1.05 or velocity.y>2:
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
	if p.team!=1 or p.keeper or p.dismissed or p.action_timer>0 or p.tackle_cooldown>0 or p.ai_think<game.management.reaction(p.team) or game.ball.held_by!=null or game.ball.pending_kick or game.foul_cooldown>0: return false
	var gap: float=game.flat_distance(p.position,game.ball.position)
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
	var best := -INF
	var receiver := -1
	var delivery: Dictionary={}
	var kind := "roll"
	for j in range(game.players.size()):
		if j==index or not onside(j,p.team): continue
		var q=game.players[j]
		var distance: float=game.flat_distance(p.position,q.position)
		if distance<7 or distance>34 or clearance(q.position,p.team)<2.5: continue
		var route: Dictionary=game.Passing.plan(game.ball.position,q.position,q.velocity,false,game.weather)
		var action := "roll"
		if distance>17 or (p.team==1 and game.opponent_coach.escape_press):
			route=game.Passing.plan(game.ball.position,q.position,q.velocity,true,game.weather); action="throw"
		var risk: float=game.Passing.risk(game.ball.position,route,p.team,game.players)
		if risk>.32: continue
		var value: float=clearance(q.position,p.team)*.5-risk*8+(q.position.z-p.position.z)*game.attack_sign(p.team)*.13
		if value>best: best=value; receiver=j; delivery=route; kind=action
	if receiver>=0:
		var aim: Vector3=((delivery.target-p.position)*Vector3(1,0,1)).normalized()
		if game.keeper_distribution.queue(index,kind,aim,.55,delivery.velocity):
			game.ai_receivers[p.team]=receiver; game.ai_pass_time[p.team]=float(delivery.flight)+2.5
			record("keeper_"+kind); return true
	var aim := Vector3(.4 if p.position.x<=0 else -.4,0,game.attack_sign(p.team)).normalized()
	if game.keeper_distribution.queue(index,"punt",aim,.62): record("keeper_punt"); return true
	return false

func pass_choice(kind: String,route: Dictionary,receiver: int,one_two: bool=false) -> Dictionary:
	route.receiver=receiver
	return {"kind":kind,"route":route,"receiver":receiver,"one_two":one_two}

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
	var shot: Dictionary={"kind":"shot","velocity":game.shot_velocity(aim,power,false,false,index),"curve":0.0}
	# An advancing keeper opens a chip; it still travels through the ordinary ball solver.
	if game.flat_distance(keeper.position,goal)>5.0 and distance>10 and distance<24 and (keeper.position-game.ball.position).dot(aim)>1:
		var flight := clampf(distance/15,.95,1.55)
		shot.kind="chip"
		shot.velocity=game.Passing.Motion.lob_velocity(game.ball.position,target+Vector3.UP*1.0,flight,game.weather)
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
		shot.curve=-signf(aim.signed_angle_to(Vector3(0,0,forward),Vector3.UP))*game.FINESSE_CURVE
		shot.velocity=game.shot_velocity(aim.rotated(Vector3.UP,signf(shot.curve)*.10),power,true,false,index)
		# On the strong-foot side, a technical finisher can wrap the outside of the boot.
		var strong_side: float=-1 if p.attributes.preferred_foot==0 else 1
		if level(p.team)==2 and p.attributes.control>=84 and p.position.x*forward*strong_side< -9 and clearance(p.position,p.team)>3:
			shot={"kind":"outside","aim":aim,"power":power,"advanced":true}
	elif level(p.team)>0 and distance<13 and clearance(p.position,p.team)>2.4:
		shot={"kind":"low","aim":aim,"power":.62,"advanced":true}
	elif level(p.team)==2 and distance>22 and clearance(p.position,p.team)>7 and p.attributes.finishing>=80:
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

func options(index: int) -> Array[Dictionary]:
	var p=game.players[index]
	var risk_bias: float=game.team_tactics.plan_for(p.team)-1
	var forward: float=game.attack_sign(p.team)
	var position: Vector3=p.position
	var read := pressure_read(index)
	var pressure := minf(clearance(position,p.team),lerpf(8,1,read.urgency))
	var result: Array[Dictionary]=[{"kind":"carry"}]
	var return_to: int=game.support.return_option(index)
	if return_to>=0:
		result.append(pass_choice("return_pass",game.Passing.plan(game.ball.position,game.players[return_to].position,game.players[return_to].velocity,false,game.weather),return_to))
	for choice in [square_choice(index),shot_choice(index),cross_choice(index)]:
		if not choice.is_empty(): result.append(choice)
	# Collect feasible routes before comparing them. Candidate order must not
	# make a mediocre through ball override a clear shot or an open teammate.
	for j in range(game.players.size()):
		if j==index or not onside(j,p.team): continue
		var q=game.players[j]
		var distance: float=game.flat_distance(position,q.position)
		var progress: float=(q.position.z-position.z)*forward
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
	if pressure<6.0 and pressure>2.3 and p.energy>.28 and position.z*forward> -18 and not game.support.runs.has(index) and skill_in.get(index,0.0)<=0:
		var wall: Dictionary=game.Passing.one_two_plan(game.ball.position,Vector3(0,0,forward),p.team,index,game.players,forward,game.rules.offside_line(p.team),game.weather)
		if not wall.is_empty() and game.Passing.risk(game.ball.position,wall,p.team,game.players)<.4:
			result.append(pass_choice("one_two",wall,wall.receiver,true))
	if game.dribbler==index and skill_in.get(index,0.0)<=0 and p.skill_cooldown<=0 and p.energy>.25:
		if pressure>1.2 and pressure<2.4 and position.z*forward> -20:
			var side := Vector3(2.5 if position.x<0 else -2.5,0,forward*2)
			if clearance(position+side,p.team)>2:
				if level(p.team)>0 and p.attributes.control>=80:
					var kind := "roll"
					if level(p.team)==2 and p.attributes.control>=84 and pressure<1.5: kind="rainbow"
					elif level(p.team)==2 and pressure<1.7: kind="roulette"
					elif level(p.team)==2 and p.velocity.length()>4: kind="elastico"
					elif absf(position.x)>24: kind="scoop"
					result.append({"kind":kind,"side":signf(side.x)*forward})
				else: result.append({"kind":"feint"})
		if pressure>7 and position.z*forward<28 and clearance(position+Vector3(0,0,forward*7),p.team)>5:
			result.append({"kind":"push"})
	if position.z*forward< -28 and pressure<3.2:
		var target := Vector3((25 if position.x>=0 else -25)*P.WIDTH_RATIO,0,position.z+forward*32)
		result.append(pass_choice("clearance",game.Passing.plan(game.ball.position,target,Vector3.ZERO,true,game.weather),-1))
	return result

func act(index: int) -> bool:
	var p=game.players[index]
	var read := pressure_read(index)
	if game.dribbler>=0 and game.dribbler!=index: return false
	# Finish the touch already in progress before choosing another action.
	if p.ball_actions.contact_pending or p.ball_actions.control_grace>0 or p.receive_timer>0 and game.dribbler!=index: return false
	var urgent: bool=read.closing>2 and read.urgency>.4
	var reaction: float=game.management.reaction(p.team)*(.7 if urgent else 1.0)
	if urgent and think_in.get(index,0.0)>.12: think_in[index]=.12
	if not game.autonomous_kicks(p.team) or game.state!="playing" or p.action_timer>0 or game.skills.active.has(index) or not game.can_touch(index,1.15) or game.ball.pending_kick or game.kick_lock>0 or p.touch_cooldown>0 or p.ai_think<reaction or think_in.get(index,0.0)>0: return false
	think_in[index]=.12 if urgent else [.52,.30,.18][level(p.team)]*[1.45,1.0,.72][game.management.detail(p.team,"tempo")]
	var choice := decide(index)
	if choice.is_empty(): return false
	var kind: String=choice.kind
	if choice.get("advanced",false):
		finishing.game=game
		var error: float=game.management.pass_error(p.team)
		var aim: Vector3=choice.aim.rotated(Vector3.UP,game.rng.randf_range(-error,error))
		if finishing.queue(index,aim,choice.power,kind): record(kind); return true
		return false
	if kind in ["roll","roulette","elastico","scoop","rainbow","heel","flick"]:
		if game.skills.start(index,kind,choice.side):
			skill_in[index]=[5.0,4.0,3.2][level(p.team)]; record(kind); return true
		return false
	if kind in ["feint","push"]:
		p.facing=Vector3(clampf(-p.position.x*.015,-.3,.3),0,game.attack_sign(p.team)).normalized()
		if kind=="feint":
			game.duels.feint(index)
			record(kind)
		else:
			game.duels.push_ahead(index)
			if game.kick_contact.pending.is_empty() or game.kick_contact.pending.index!=index: return false
			game.kick_contact.pending.ai_choice=choice
		skill_in[index]=3.8
		return true
	var velocity: Vector3=choice.velocity if choice.has("velocity") else choice.route.velocity
	var error: float=game.management.pass_error(p.team)
	velocity=velocity.rotated(Vector3.UP,game.rng.randf_range(-error,error))
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
	if not game.autonomous_kicks(p.team) or p.ai_think<game.management.reaction(p.team) or not game.heading.can_request(index): return false
	var forward: float=game.attack_sign(p.team)
	var intent := "shot"
	var receiver := -1
	var aim := Vector3(-p.position.x*.08,0,forward).normalized()
	if p.position.z*forward>27 and absf(p.position.x)<18:
		aim=(Vector3(game.rng.randf_range(-2.3,2.3),0,forward*50)-p.position).normalized()
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
	if not game.autonomous_kicks(p.team) or game.aerial_shot_active(index) or p.ai_think<game.management.reaction(p.team): return false
	var forward: float=game.attack_sign(p.team)
	if p.position.z*forward<26 or absf(p.position.x)>17 or not game.volleys.can_request(index): return false
	var aim: Vector3=(Vector3(game.rng.randf_range(-2.2,2.2),0,forward*50)-p.position).normalized()
	if game.volleys.arm(index,aim,.58,false):
		record("volley")
		return true
	return false

func aerial_target(index: int,fallback: Vector3) -> Vector3:
	if game.ball.position.y<1.15 or game.ball.held_by!=null: return fallback
	var p=game.players[index]
	var velocity: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
	var head: float=game.heading.head_point(p).y
	var result := fallback
	for sample in range(1,25):
		var time := sample*.08
		var point: Vector3=game.ball.position+velocity*time+Vector3.DOWN*4.905*time*time
		if point.y<head-.2: break
		result=point
		if point.y<head+1.3 and game.flat_distance(p.position,point)<time*(7.5 if p.energy>.3 else 5.4)+.5: break
	result.x=clampf(result.x,-(P.HALF_WIDTH-2),(P.HALF_WIDTH-2)); result.y=0; result.z=clampf(result.z,-48,48)
	return result
