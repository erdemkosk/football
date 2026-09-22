extends RefCounted
## Team-level duties are assigned once; individual AI follows them without kicking.
var game
var targets: Dictionary = {}
var roles: Dictionary = {}
var pressers := [-1,-1]
var plans := [1,1]
var age := 0.0
var last_opponent_plan := -1
var observed_owner := -1
var observed_ball := Vector3.ZERO
var observed_velocity := Vector3.ZERO
var observation_age := 0.0

func reset() -> void:
	targets.clear(); roles.clear(); pressers=[-1,-1]; age=0; last_opponent_plan=-1
	observed_owner=-1; observed_ball=Vector3.ZERO; observed_velocity=Vector3.ZERO; observation_age=0

func plan_for(team: int) -> int:
	if team==0: return game.management.mentality
	var base: int=game.opponent_coach.mentality
	if game.opponent_coach.reason=="ten_men": return base
	if game.match_time>game.LENGTH*.68:
		var margin: int=game.score[team]-game.score[1-team]
		if margin<0: return 2
		if margin>0: return 0
	return base

func press_level(team: int) -> int:
	return game.management.pressing if team==0 else game.opponent_coach.press_level()

func update(delta: float) -> void:
	observation_age+=delta
	age-=delta
	var owner: int=game.dribbler if game.dribbler>=0 else game.carrier
	if age>0 and owner==observed_owner: return
	age=[.26,.17,.11][game.opponent_coach.level()] if owner>=0 and game.players[owner].team==0 else .16
	var previous_presser: int=pressers[1]
	targets.clear(); roles.clear(); pressers=[-1,-1]
	observed_owner=-1
	for team in range(2): plans[team]=plan_for(team)
	if plans[1]!=last_opponent_plan:
		if last_opponent_plan>=0: game.stadium.sidelines.instruct(1,["defend","balance","attack"][plans[1]])
		last_opponent_plan=plans[1]
	if game.training or game.state!="playing": return
	if owner<0 or not game.players[owner].visible: return
	var team: int=1-game.players[owner].team
	var forward: float=game.attack_sign(team)
	var ball: Vector3=game.ball.position
	var carrier=game.players[owner]
	observed_owner=owner; observed_ball=ball
	observed_velocity=carrier.velocity*Vector3(1,0,1); observation_age=0
	var goal_side := Vector3(-ball.x*.018,0,-forward).normalized()
	var plan: int=plans[team]
	var height: int=game.management.line_height if team==0 else game.opponent_coach.line_height
	var line := clampf(ball.z*forward-14+float(height-1)*6+float(plan-1)*2,-42,6)
	var closest := INF
	for i in range(team*11+1,team*11+11):
		var p=game.players[i]
		if not p.visible or p.dismissed: continue
		var group: int=game.management.slot_role(i)
		var depth: float=line+([0,0,11,22][group])
		var bias: float=game.opponent_coach.wing_bias*3.0 if team==1 else 0.0
		var at := Vector3(clampf(p.home.x*.78+ball.x*.24+bias,-27,27),0,forward*clampf(depth,-43,36))
		targets[i]=at; roles[i]="block"
		var cost: float=game.flat_distance(p.position,ball)+(1-p.energy)*3
		if team==1:
			# A nearby player behind the runner is not necessarily able to stop him.
			var ahead: float=(p.position-ball).dot(goal_side)
			if ahead<-.3: cost+=minf(7,2.5-ahead*1.5)
			elif i==previous_presser: cost-=.9
			if p.tackle_cooldown>0: cost+=p.tackle_cooldown*2
		if cost<closest and p.action_timer<=0: closest=cost; pressers[team]=i
	var presser: int=pressers[team]
	if presser<0: return
	var trigger: bool=absf(ball.x)>22 or carrier.receive_timer>0 or carrier.energy<.28
	var press := press_level(team)
	if team==1 and game.opponent_coach.level()==0: press=mini(press,1)
	var reach: float=[8.0,14.0,24.0][press]+(5 if trigger else 0)
	var in_box: bool=ball.z*forward< -33.5 and absf(ball.x)<20.16
	if game.flat_distance(game.players[presser].position,ball)>reach:
		pressers[team]=-1
		if team==1: opponent_duties(owner,-1,-1,false,in_box)
		return
	# Approach from the goal side, screening the central pass as we close.
	targets[presser]=ball+goal_side*(1.0 if team==1 and in_box else (.50 if trigger or press==2 else .95))
	if team==1:
		var gap: float=game.flat_distance(game.players[presser].position,ball)
		var anticipation: float=[.10,.24,.34][game.opponent_coach.level()]*clampf(gap/4,.5,1.5)
		# Read visible travel, never the human's pending input. Meet the running
		# lane from the goal side instead of following yesterday's ball position.
		targets[presser]+=observed_velocity*anticipation
	roles[presser]="press"
	var covering := -1
	var cover_cost := INF
	var hole: Vector3=game.players[presser].position+Vector3(0,0,-forward*5)
	if team==1: hole=targets[presser]+goal_side*4.5
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
	if team==1: opponent_duties(owner,presser,covering,trigger,in_box)
	for i in targets:
		targets[i].x=clampf(targets[i].x,-31,31)
		targets[i].z=clampf(targets[i].z,-48,48)

func defensive_movement(index: int,target: Vector3) -> Vector3:
	var p=game.players[index]
	var duty: String=roles[index]
	var mark: bool=duty in ["press","press_support","contain"]
	var forward: float=game.attack_sign(p.team)
	var speed := observed_velocity.length()
	var gap: float=game.flat_distance(p.position,observed_ball)
	var beaten: bool=(p.position.z-observed_ball.z)*forward>.2
	var chasing: bool=mark and (beaten or speed>6.4 or gap>5.0 and press_level(p.team)>0)
	var covering: bool=duty=="cover" and (target-p.position).length()>3 and (speed>5.5 or beaten)
	p.sprinting=(p.sprinting or chasing or covering) and p.energy>.3 and not p.exhausted
	p.jockeying=mark and gap<3.4 and not p.sprinting
	if p.jockeying: p.facing=((observed_ball-p.position)*Vector3(1,0,1)).normalized()
	# Match the runner's velocity while holding the blocking position. Pure
	# arrival steering slows to a walk precisely when the attacker runs past.
	var offset: Vector3=(target-p.position)*Vector3(1,0,1)
	if mark:
		offset+=observed_velocity*minf(observation_age,.26)
		var tracking: Vector3=observed_velocity+offset*4.2
		var pace: float=10.4 if p.sprinting else 6.2
		return (tracking/pace).limit_length(1)
	return offset.normalized()*clampf(offset.length()/1.4,0,1)

func opponent_duties(owner: int,presser: int,covering: int,trigger: bool,in_box: bool) -> void:
	var brain=game.opponent_coach
	var ball: Vector3=game.ball.position
	var forward: float=game.attack_sign(1)
	if in_box and presser>=0: roles[presser]="contain"
	# The second defender closes the escape lane; the cover stays behind both.
	if presser>=0 and brain.level()>0 and press_level(1)==2 and (trigger or brain.transition>0) and not in_box:
		var helper := -1
		var best := 10.0 if brain.level()==2 else 7.0
		for i in targets:
			if i in [presser,covering] or game.players[i].energy<.38 or game.management.slot_role(i)==1: continue
			var gap: float=game.flat_distance(game.players[i].position,ball)
			if gap<best: best=gap; helper=i
		if helper>=0:
			var exit := Vector3(-signf(ball.x)*1.7,0,-forward*.6)
			if absf(ball.x)<5: exit=Vector3(1.7 if game.players[presser].position.x<ball.x else -1.7,0,-forward)
			targets[helper]=ball+exit; roles[helper]="press_support"
	# Pick up dangerous runners goal-side, without dragging every centre back out.
	var assigned: Array=[]
	for i in targets:
		if i==presser or (i==covering and not in_box) or roles[i]=="press_support" or game.management.slot_role(i)!=1: continue
		var best := 0.0
		var runner := -1
		for j in range(1,11):
			var q=game.players[j]
			if j==owner or j in assigned or not q.visible or q.dismissed: continue
			var danger: float=-q.position.z*forward
			if danger<18 or absf(q.position.x)>25: continue
			var score: float=danger-game.flat_distance(game.players[i].position,q.position)*1.2
			if score>best: best=score; runner=j
		if runner>=0 and (brain.level()>0 or in_box):
			assigned.append(runner)
			var q=game.players[runner]
			var target: Vector3=q.position+q.velocity*([.08,.25,.42][brain.level()])+Vector3(0,0,-forward*1.3)
			targets[i]=Vector3(clampf(target.x,-28,28),0,forward*clampf(target.z*forward,-47,15))
			roles[i]="recover" if game.players[i].position.z*forward>target.z*forward+2 else "track"
