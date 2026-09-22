extends RefCounted
var game
var runs: Dictionary = {}
var targets: Dictionary = {}
var roles: Dictionary = {}
var shape := preload("res://scripts/attack_shape.gd").new()
const ONE_TWO_DISTANCE := 12.0
const ONE_TWO_TIME := 3.0

func reset() -> void:
	runs.clear()
	targets.clear()
	roles.clear()
	shape.reset()

func passed(passer: int,receiver: int,one_two: bool=false) -> void:
	if receiver<0 or game.players[passer].keeper: return
	if receiver in runs and runs[receiver].receiver==passer: end_run(receiver)
	runs[passer]={"receiver":receiver,"time":3.6,"origin":game.players[passer].position}
	if one_two:
		var p=game.players[passer]
		var target: Vector3=p.position+Vector3(clampf(-p.position.x,-4,4),0,game.attack_sign(p.team)*9)
		target.x=clampf(target.x,-29,29); target.z=clampf(target.z,-46,46)
		runs[passer].merge({"explicit":true,"time":ONE_TWO_TIME,"target":target,"previous":p.position,"distance":0.0},true)
		p.call_timer=ONE_TWO_TIME

func follow_run(index: int) -> Vector3:
	if not runs.has(index) or not runs[index].get("explicit",false): return Vector3.ZERO
	var offset: Vector3=(runs[index].target-game.players[index].position)*Vector3(1,0,1)
	return offset.normalized()*clampf(offset.length()/1.4,0,1)

func end_run(index: int) -> void:
	if runs.get(index,{}).get("explicit",false): game.players[index].call_timer=0
	runs.erase(index)
	targets.erase(index)
	roles.erase(index)

func update(delta: float) -> void:
	for i in runs.keys():
		runs[i].time-=delta
		var p=game.players[i]
		if runs[i].time<=0 or not p.visible or p.dismissed or game.last_touch!=p.team:
			end_run(i)
			continue
		if runs[i].get("explicit",false):
			runs[i].distance+=game.flat_distance(p.position,runs[i].previous)
			runs[i].previous=p.position
			if runs[i].distance>=ONE_TWO_DISTANCE or game.flat_distance(p.position,runs[i].target)<0.8 or game.dribbler==i or (game.controlled==i and game.movement_input().length()>0.1): end_run(i)
	targets.clear()
	roles.clear()
	var owner: int=game.dribbler if game.dribbler>=0 else game.nearest_to_ball(1.4)
	var team: int=game.players[owner].team if owner>=0 else game.last_touch
	if game.state!="playing" or owner<0 and game.ai_pass_time[team]<=0:
		shape.reset(); return
	var ball: Vector3=game.ball.position
	var forward: float = game.attack_sign(team)
	var line: float=game.rules.offside_line(team)-0.8
	var wing := absf(ball.x)>14
	var side := signf(ball.x)
	for i in range(game.players.size()):
		var p=game.players[i]
		if not p.visible or p.dismissed or p.keeper or p.team!=team or i==owner: continue
		var target: Vector3=p.home+Vector3(ball.x*0.18,0,ball.z*0.35+forward*7)
		var role := "support"
		if i in runs:
			if runs[i].get("explicit",false):
				target=runs[i].target
				target.z=forward*minf(target.z*forward,maxf(0,line))
				targets[i]=target
				roles[i]="one_two"
				continue
			target=runs[i].origin+Vector3(3 if p.position.x<ball.x else -3,0,forward*13)
			role="give_go"
		elif wing and ball.z*forward> -15 and p.number in [2,5] and signf(p.home.x)==side:
			target=Vector3(side*28,0,ball.z+forward*13)
			role="overlap"
		elif wing and ball.z*forward>25 and p.number in [7,8,10,11]:
			match p.number:
				10: target=Vector3(side*3.5,0,forward*43)
				11: target=Vector3(-side*5.5,0,forward*41)
				8: target=Vector3(0,0,forward*36)
				7: target=Vector3(-side*11,0,forward*30)
			role="box"
		elif p.number>=6:
			target=Vector3(p.home.x*0.8+ball.x*0.2,0,ball.z+forward*(8 if p.number>=10 else -6))
		if game.career.in_match and role!="one_two":
			target.x*=([.84,1.0,1.12][game.management.detail(team,"width")])
			if game.management.slot_role(i)>=2: target.z+=forward*(game.management.detail(team,"runs")-1)*4
			if game.management.slot_role(i)>=2: target.z+=forward*(game.management.detail(team,"tempo")-1)*2
			if p.number==7 and game.management.detail(team,"anchor")>0:
				target.z=forward*minf(target.z*forward,ball.z*forward-9); role="cover_attack"
			if p.number in [2,5]:
				var fullback: int=game.management.detail(team,"fullbacks")
				if fullback==0: target.z=forward*minf(target.z*forward,ball.z*forward-15); role="support"
				elif fullback==2 and absf(ball.x)>12: target.z=ball.z+forward*10; role="overlap"
		if team==1:
			var plan: int=game.team_tactics.plan_for(team)
			var group: int=game.management.slot_role(i)
			# Keep a central pair behind attacks so one loss does not expose the keeper.
			if group==1 and absf(p.home.x)<18:
				target.z=forward*minf(target.z*forward,ball.z*forward-(9 if plan==2 else 14))
				role="cover_attack"
			elif plan==0 and role=="overlap":
				target.z=ball.z-forward*9; role="support"
			# A low outlet and a wide outlet help play around sustained user pressing.
			elif game.opponent_coach.escape_press and group==2 and role=="support":
				target.x=signf(p.home.x+.01)*clampf(absf(p.home.x)+5,10,27)
				target.z=ball.z+forward*(-7 if i%2==0 else 5)
		# Sample receiving space and the passing lane; each role keeps its own
		# region instead of everybody converging on the nearest empty point.
		var best := target
		var best_value := -INF
		for offset in [Vector3.ZERO,Vector3(-4,0,0),Vector3(4,0,0),Vector3(0,0,-forward*4)]:
			var candidate: Vector3=target+offset
			candidate.x=clampf(candidate.x,-29,29)
			candidate.z=forward*minf(clampf(candidate.z*forward,-43,46),maxf(0,line))
			var clearance := 8.0
			var lane := 5.0
			for q in game.players:
				if not q.visible or q.team==team: continue
				clearance=minf(clearance,game.flat_distance(q.position,candidate))
				var near := Geometry3D.get_closest_point_to_segment(q.position*Vector3(1,0,1),ball*Vector3(1,0,1),candidate)
				lane=minf(lane,game.flat_distance(near,q.position))
			var value: float=clearance+lane*0.6-offset.length()*0.5
			if value>best_value: best_value=value; best=candidate
		targets[i]=best
		roles[i]=role
	shape.game=game
	shape.update(delta,owner,team,self)

func return_option(holder: int) -> int:
	for i in runs:
		if runs[i].receiver!=holder or game.players[i].action_timer>0: continue
		var p=game.players[i]
		var distance: float=game.flat_distance(p.position,game.ball.position)
		if distance<4 or distance>23: continue
		var forward: float = game.attack_sign(p.team)
		# Ordinary support runs are an option, not an automatic bounce back to
		# the previous passer. Explicit one-twos retain their quick return.
		if not runs[i].get("explicit",false) and (p.position.z-game.players[holder].position.z)*forward<2.5: continue
		if p.position.z*forward>game.rules.offside_line(p.team)-0.2: continue
		var route=game.Passing.plan(game.ball.position,p.position,p.velocity,false,game.weather)
		if game.Passing.risk(game.ball.position,route,p.team,game.players)<0.35: return i
	return -1
