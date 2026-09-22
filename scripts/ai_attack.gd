extends RefCounted
## Opponent decisions use the same ball, pass planners, stamina and contact windows.
var game
var think_in: Dictionary = {}
var skill_in: Dictionary = {}
var uses: Dictionary = {}
var last_decision := ""

func reset() -> void:
	think_in.clear(); skill_in.clear(); uses.clear(); last_decision=""

func update(delta: float) -> void:
	if game.state!="playing": return
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
	var aim: Vector3=((target-game.ball.position)*Vector3(1,0,1)).normalized()
	var keeper=game.players[11 if p.team==0 else 0]
	var power := clampf((distance-6)/26,.30,.78)
	var shot: Dictionary={"kind":"shot","velocity":game.shot_velocity(aim,power,false,false,index),"curve":0.0}
	# An advancing keeper opens a chip; it still travels through the ordinary ball solver.
	if game.flat_distance(keeper.position,goal)>5.0 and distance>10 and distance<24 and (keeper.position-game.ball.position).dot(aim)>1:
		var flight := clampf(distance/15,.95,1.55)
		shot.kind="chip"
		shot.velocity=game.Passing.Motion.lob_velocity(game.ball.position,target+Vector3.UP*1.0,flight,game.weather)
		return shot
	# Avoid firing directly into a defender. Goalkeepers are handled by shooting accuracy.
	var blocked := false
	for q in game.players:
		if not q.visible or q.keeper or q.team==p.team: continue
		var near := Geometry3D.get_closest_point_to_segment(q.position*Vector3(1,0,1),game.ball.position*Vector3(1,0,1),target)
		if game.flat_distance(near,q.position)<.8 and game.flat_distance(p.position,q.position)>1: blocked=true
	if blocked and distance>13: return {}
	if absf(p.position.x)>6 and distance>14:
		shot.kind="finesse"
		shot.curve=-signf(aim.signed_angle_to(Vector3(0,0,forward),Vector3.UP))*game.FINESSE_CURVE
		shot.velocity=game.shot_velocity(aim.rotated(Vector3.UP,signf(shot.curve)*.10),power,true,false,index)
	return shot

func decide(index: int) -> Dictionary:
	var p=game.players[index]
	var risk_bias: float=game.team_tactics.plan_for(p.team)-1
	var forward: float=game.attack_sign(p.team)
	var position: Vector3=p.position
	var pressure := clearance(position,p.team)
	var return_to: int=game.support.return_option(index)
	if return_to>=0:
		return pass_choice("return_pass",game.Passing.plan(game.ball.position,game.players[return_to].position,game.players[return_to].velocity,false,game.weather),return_to)
	var shot := shot_choice(index)
	if not shot.is_empty(): return shot
	var cross := cross_choice(index)
	if not cross.is_empty(): return cross
	# Pass into a real forward run, evaluating the future space and the current offside line.
	var through: Dictionary={}
	var best_progress := 3.0
	for j in range(game.players.size()):
		if j==index or not onside(j,p.team): continue
		var q=game.players[j]
		if q.velocity.z*forward<1.4 or game.flat_distance(position,q.position)>29: continue
		var progress: float=(q.position.z-position.z)*forward
		if progress<2 or progress>23: continue
		var route: Dictionary=game.Passing.through_to(game.ball.position,q,.35,forward,game.weather)
		if game.Passing.risk(game.ball.position,route,p.team,game.players)<.43+risk_bias*.07 and clearance(route.target,p.team)>2.2 and progress>best_progress:
			best_progress=progress; through=pass_choice("through",route,j)
	if not through.is_empty(): return through
	if absf(position.x)>10 and position.z*forward<32 and pressure<7 and skill_in.get(index,0.0)<=0:
		for j in range(game.players.size()):
			if j==index or not onside(j,p.team): continue
			var q=game.players[j]
			if q.position.x*position.x>=0 or absf(q.position.x-position.x)<29 or clearance(q.position,p.team)<4.2: continue
			if (q.position.z-position.z)*forward< -12: continue
			var route: Dictionary=game.Passing.plan(game.ball.position,q.position,q.velocity,true,game.weather)
			if game.Passing.risk(game.ball.position,route,p.team,game.players)<.55: return pass_choice("switch",route,j)
	if pressure<6.0 and pressure>2.3 and p.energy>.28 and position.z*forward> -18 and not game.support.runs.has(index) and skill_in.get(index,0.0)<=0:
		var wall: Dictionary=game.Passing.one_two_plan(game.ball.position,Vector3(0,0,forward),p.team,index,game.players,forward,game.rules.offside_line(p.team),game.weather)
		if not wall.is_empty() and game.Passing.risk(game.ball.position,wall,p.team,game.players)<.4:
			return pass_choice("one_two",wall,wall.receiver,true)
	if game.dribbler==index and skill_in.get(index,0.0)<=0 and p.skill_cooldown<=0 and p.energy>.25:
		if pressure>1.2 and pressure<2.4 and position.z*forward> -20:
			var side := Vector3(2.5 if position.x<0 else -2.5,0,forward*2)
			if clearance(position+side,p.team)>2: return {"kind":"feint"}
		if pressure>7 and position.z*forward<28 and clearance(position+Vector3(0,0,forward*7),p.team)>5:
			return {"kind":"push"}
	if p.ai_think>game.management.reaction(p.team)*2.2 or pressure<3:
		var best: Dictionary={}
		var best_score := -INF
		for j in range(game.players.size()):
			if j==index or not onside(j,p.team): continue
			var q=game.players[j]
			var distance: float=game.flat_distance(position,q.position)
			if distance<4 or distance>42: continue
			var route: Dictionary=game.Passing.plan(game.ball.position,q.position,q.velocity,false,game.weather)
			var risk: float=game.Passing.risk(game.ball.position,route,p.team,game.players)
			if risk>.58+risk_bias*.08: continue
			var score: float=(q.position.z-position.z)*forward*(.24+risk_bias*.12)+clearance(q.position,p.team)*.5-risk*(10-risk_bias*2)-distance*.06
			if score>best_score: best_score=score; best=pass_choice("pass",route,j)
		if not best.is_empty(): return best
	if position.z*forward< -28 and pressure<3.2:
		var target := Vector3(25 if position.x>=0 else -25,0,position.z+forward*32)
		return pass_choice("clearance",game.Passing.plan(game.ball.position,target,Vector3.ZERO,true,game.weather),-1)
	return {}

func act(index: int) -> bool:
	var p=game.players[index]
	if not game.autonomous_kicks(p.team) or game.state!="playing" or not game.can_touch(index,1.15) or game.ball.pending_kick or game.kick_lock>0 or p.touch_cooldown>0 or p.ai_think<game.management.reaction(p.team) or think_in.get(index,0.0)>0: return false
	think_in[index]=.18
	var choice := decide(index)
	if choice.is_empty(): return false
	var kind: String=choice.kind
	if kind in ["feint","push"]:
		p.facing=Vector3(clampf(-p.position.x*.015,-.3,.3),0,game.attack_sign(p.team)).normalized()
		if kind=="feint": game.duels.feint(index)
		else: game.duels.push_ahead(index)
		skill_in[index]=3.8; record(kind)
		return true
	var velocity: Vector3=choice.velocity if choice.has("velocity") else choice.route.velocity
	var error: float=game.management.pass_error(p.team)
	velocity=velocity.rotated(Vector3.UP,game.rng.randf_range(-error,error))
	if not game.strike(index,velocity,choice.get("curve",0.0),false,"shot" if choice.has("velocity") else ("cross" if kind=="cross" else "kick")): return false
	record(kind)
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
	return true

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
	result.x=clampf(result.x,-30,30); result.y=0; result.z=clampf(result.z,-48,48)
	return result
