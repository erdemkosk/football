extends RefCounted
## Team-level duties are assigned once; individual AI follows them without kicking.
var game
var targets: Dictionary = {}
var roles: Dictionary = {}
var pressers := [-1,-1]
var plans := [1,1]
var age := 0.0
var last_opponent_plan := -1

func reset() -> void:
	targets.clear(); roles.clear(); pressers=[-1,-1]; age=0; last_opponent_plan=-1

func plan_for(team: int) -> int:
	if team==0: return game.management.mentality
	var base: int=[1,2,0,1,1,2,0,1][game.clubs.selected[team]]
	if game.match_time>game.LENGTH*.68:
		var margin: int=game.score[team]-game.score[1-team]
		if margin<0: return 2
		if margin>0: return 0
	return base

func press_level(team: int) -> int:
	return game.management.pressing if team==0 else plans[team]

func update(delta: float) -> void:
	age-=delta
	if age>0: return
	age=.16
	targets.clear(); roles.clear(); pressers=[-1,-1]
	for team in range(2): plans[team]=plan_for(team)
	if plans[1]!=last_opponent_plan:
		if last_opponent_plan>=0: game.stadium.sidelines.instruct(1,["defend","balance","attack"][plans[1]])
		last_opponent_plan=plans[1]
	if game.training or game.state!="playing": return
	var owner: int=game.dribbler if game.dribbler>=0 else game.carrier
	if owner<0 or not game.players[owner].visible: return
	var team: int=1-game.players[owner].team
	var forward: float=game.attack_sign(team)
	var ball: Vector3=game.ball.position
	var plan: int=plans[team]
	var height: int=game.management.line_height if team==0 else plan
	var line := clampf(ball.z*forward-14+float(height-1)*6+float(plan-1)*2,-42,6)
	var closest := INF
	for i in range(team*11+1,team*11+11):
		var p=game.players[i]
		if not p.visible or p.dismissed: continue
		var group: int=game.management.slot_role(i)
		var depth: float=line+([0,0,11,22][group])
		var at := Vector3(clampf(p.home.x*.78+ball.x*.24,-27,27),0,forward*clampf(depth,-43,36))
		targets[i]=at; roles[i]="block"
		var cost: float=game.flat_distance(p.position,ball)+(1-p.energy)*3
		if cost<closest and p.action_timer<=0: closest=cost; pressers[team]=i
	var presser: int=pressers[team]
	if presser<0: return
	var carrier=game.players[owner]
	var trigger: bool=absf(ball.x)>22 or carrier.receive_timer>0 or carrier.energy<.28
	var press := press_level(team)
	var reach: float=[8.0,14.0,24.0][press]+(5 if trigger else 0)
	if closest>reach: pressers[team]=-1; return
	# Approach from the goal side, screening the central pass as we close.
	var goal_side := Vector3(-ball.x*.018,0,-forward).normalized()
	targets[presser]=ball+goal_side*(.50 if trigger or press==2 else .95)
	roles[presser]="press"
	var covering := -1
	var cover_cost := INF
	var hole: Vector3=game.players[presser].position+Vector3(0,0,-forward*5)
	for i in targets:
		if i==presser: continue
		var q=game.players[i]
		var cost: float=game.flat_distance(q.position,hole)+(7 if game.management.slot_role(i)==3 else 0)
		if cost<cover_cost: covering=i; cover_cost=cost
	if covering>=0:
		targets[covering]=Vector3(clampf(hole.x,-25,25),0,forward*clampf(hole.z*forward,-44,30))
		roles[covering]="cover"
	# The remaining midfielders block lanes toward nearby attacking receivers.
	var assigned: Array=[]
	for i in targets:
		if i in [presser,covering] or game.management.slot_role(i)!=2: continue
		var choice := -1
		var best := 15.0
		for j in range((1-team)*11+1,(1-team)*11+11):
			var q=game.players[j]
			if j==owner or j in assigned or not q.visible: continue
			var screen: Vector3=ball.lerp(q.position,.72)
			var gap: float=game.flat_distance(targets[i],screen)
			if gap<best: best=gap; choice=j
		if choice>=0:
			assigned.append(choice)
			targets[i]=targets[i].lerp(ball.lerp(game.players[choice].position,.72),.65)
			roles[i]="screen"
