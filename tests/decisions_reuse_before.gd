extends RefCounted
## Compare feasible actions on a shared scale. Evaluation reads the pitch only;
## ball contact, errors, attributes and stamina still use the normal game systems.
var game
var rankings: Dictionary = {}

func reset() -> void:
	rankings.clear()

func select(index: int,options: Array[Dictionary]) -> Dictionary:
	var scored: Array[Dictionary]=[]
	# This context lives for one synchronous evaluation only, never across ticks.
	var context: Dictionary={}
	for option in options:
		if option.is_empty(): continue
		var entry := option.duplicate()
		entry.value=value(index,option,context)+game.management.identity.decision_bias(index,option)
		scored.append(entry)
	scored.sort_custom(func(a,b): return a.value>b.value)
	rankings[index]=scored
	if scored.is_empty() or scored[0].kind=="carry": return {}
	return scored[0]

func value(index: int,choice: Dictionary,context: Dictionary={}) -> float:
	var p=game.players[index]
	var brain=game.ai_attack
	var forward: float=game.attack_sign(p.team)
	if context.is_empty():
		context.pressure=brain.clearance(p.position,p.team)
		context.danger=brain.pressure_read(index)
		context.isolated=brain.through_on_goal(index)
	var pressure: float=context.pressure
	var kind: String=choice.kind
	var mentality: int=game.team_tactics.plan_for(p.team)
	var danger: Dictionary=context.danger
	var isolated: bool=context.isolated
	if kind in ["shield","invite"]:
		return 35+minf(4,pressure)*1.2+(float(p.attributes.balance)-72)*.1-danger.urgency*maxf(0,danger.closing-2)*4
	if kind in ["carry","push","feint","roll","stop_go","knock_around","roulette","elastico","scoop","rainbow","heel","flick"]:
		# Keep carry_target's cache update even when the option has its own exit.
		var at: Vector3=choice.get("exit",brain.carry_target(index))
		var room: float=minf(8,brain.clearance(at,p.team))
		var crowd: float=brain.clearance(p.position,p.team,false) if isolated else pressure
		var threat: Dictionary=brain.pressure_read(index,false) if isolated else danger
		var score: float=20+room*1.3+(at.z-p.position.z)*forward*.6-maxf(0,3-crowd)*8
		if kind=="push": score+=5+(float(p.attributes.pace)-72)*.10
		elif kind!="carry": score+=7+(float(p.attributes.control)-72)*.16-maxf(0,.4-p.energy)*12
		# A crowded own third is a poor place for a speculative individual run.
		if p.position.z*forward< -25 and pressure<3: score-=9
		# A sprinting presser several metres away can be more urgent than a
		# stationary marker. Release a safe pass before the challenge arrives.
		score-=threat.urgency*clampf(threat.closing,0,8)*2.2
		if kind in ["roll","stop_go","knock_around","feint"] and danger.opponent>=0:
			var defender=game.players[danger.opponent]
			var exit_direction: Vector3=((at-p.position)*Vector3(1,0,1)).normalized()
			var committed: float=maxf(0,-defender.velocity.dot(exit_direction))
			score+=minf(9,committed*2.2)+(5 if defender.pose=="poke" and defender.action_timer>0 else 0)
		if isolated: score+=12
		return score
	if choice.has("velocity") or choice.get("advanced",false):
		var quality: float=brain.shot_quality(p.position,p.team)
		var score: float=25+quality*64+(float(p.attributes.finishing)-72)*.15
		score-=game.first_touch.pressure(index)*5+(1-p.energy)*4
		if kind=="power": score-=maxf(0,9-pressure)*2.2
		if kind=="chip": score+=8
		if isolated: score+=16
		return score
	var route: Dictionary=choice.route
	var risk := 0.0
	if kind=="clearance": return 12+maxf(0,3.5-pressure)*10+(8 if p.position.z*forward< -33 else 0)
	var receiver: int=choice.receiver
	if receiver<0: return -INF
	var read: Dictionary=brain.delivery.assess(index,route,receiver,game.ball.position,.065)
	if not read.reachable or read.risk>=.72 or read.margin<=-.12: return -INF
	risk=read.lane_risk # Reuse lane scoring without changing interception safety.
	var q=game.players[receiver]
	var destination: Vector3=route.target
	var progress: float=(destination.z-game.ball.position.z)*forward
	var free_space := receiving_space(receiver,destination,float(route.flight))
	var own_third: float=clampf((-p.position.z*forward-15)/30,0,1)
	var risk_cost: float=40+own_third*16-(mentality-1)*5
	var score: float=25+clampf(progress,-20,24)*(.65+(mentality-1)*.12)+minf(8,free_space)*1.3-risk*risk_cost-float(route.flight)*3
	if isolated and progress<2.0 and brain.shot_quality(destination,p.team)+.18<brain.shot_quality(p.position,p.team):
		return -INF
	if not isolated:
		score+=danger.urgency*clampf(danger.closing,0,8)*(1-risk)*1.8
		score+=maxf(0,4-pressure)*3
	score+=(float(p.attributes.get("passing",p.attributes.control))-72)*.07
	score+=(float(q.attributes.control)-72)*.06
	score+=brain.shot_quality(destination,p.team)*24
	# A nominally open destination is useless if the receiver cannot reach it.
	var arrival: float=game.flat_distance(q.position,destination)
	var pace: float=minf(6.2,q.movement_speed())
	var reach: float=maxf(0,pace*float(route.flight)-1.2)+1.1
	score-=maxf(0,arrival-reach)*5+maxf(0,2.0-free_space)*8
	if kind in ["cross","driven_cross"]:
		score+=10+brain.shot_quality(destination,p.team)*15
		if kind=="cross": score+=(float(q.attributes.heading)-72)*.15
	elif kind in ["through","lob_through"]: score+=7
	elif kind=="one_two": score+=7
	elif kind=="return_pass": score+=7 if game.support.runs.get(receiver,{}).get("explicit",false) else 2
	elif kind=="switch": score+=6
	elif kind=="driven_pass": score+=1.5
	# A safe layoff can be valuable because it opens a second pass. Evaluate
	# that next lane from predicted positions, without requiring its execution.
	if brain.level(p.team)>0 and not route.get("cross",false):
		score+=continuation(index,receiver,destination,float(route.flight))*(.65 if brain.level(p.team)==1 else 1.0)*lerpf(.45,1.25,game.management.identity.quality(index))
	return score

func receiving_space(index: int,point: Vector3,flight: float) -> float:
	var p=game.players[index]
	var closest := 20.0
	for q in game.players:
		if not q.visible or q.dismissed or q.team==p.team: continue
		var predicted: Vector3=q.position+(q.velocity*Vector3(1,0,1)).limit_length(10.4)*minf(.55,flight*.55)
		closest=minf(closest,game.flat_distance(predicted,point))
	return closest

func continuation(passer: int,receiver: int,origin: Vector3,flight: float) -> float:
	var team: int=game.players[passer].team
	var forward: float=game.attack_sign(team)
	var best := 0.0
	for j in range(game.players.size()):
		if j==passer or j==receiver or not game.ai_attack.onside(j,team): continue
		var q=game.players[j]
		var future: Vector3=q.position+(q.velocity*Vector3(1,0,1)).limit_length(8)*minf(flight,.65)
		var progress: float=(future.z-origin.z)*forward
		var distance: float=game.flat_distance(origin,future)
		if distance<4 or distance>25 or progress<3: continue
		var lane := 5.0
		for opponent in game.players:
			if not opponent.visible or opponent.dismissed or opponent.team==team: continue
			var at: Vector3=opponent.position+opponent.velocity*Vector3(1,0,1)*minf(.45,flight*.4)
			var near := Geometry3D.get_closest_point_to_segment(at*Vector3(1,0,1),origin*Vector3(1,0,1),future*Vector3(1,0,1))
			lane=minf(lane,game.flat_distance(at,near))
		if lane<1.5: continue
		var value: float=minf(12,progress)*.55+game.ai_attack.shot_quality(future,team)*6
		best=maxf(best,value*smoothstep(1.5,3.5,lane))
	return minf(11,best)
