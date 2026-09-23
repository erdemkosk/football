extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
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
var support_time := 0.0
var support_rest := 0.0
var support_owner := -1
var support_player := -1

func reset() -> void:
	targets.clear(); roles.clear(); pressers=[-1,-1]; age=0; last_opponent_plan=-1
	observed_owner=-1; observed_ball=Vector3.ZERO; observed_velocity=Vector3.ZERO; observation_age=0
	support_time=0; support_rest=0; support_owner=-1; support_player=-1

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
	support_rest=maxf(0,support_rest-delta)
	if support_time>0:
		support_time=maxf(0,support_time-delta)
		if support_time<=0: support_rest=3.8; support_player=-1
	observation_age+=delta
	age-=delta
	var owner: int=game.dribbler if game.dribbler>=0 else game.carrier
	if owner!=support_owner:
		if support_time>0: support_rest=maxf(support_rest,2.2)
		support_time=0; support_player=-1; support_owner=owner
	if age>0 and owner==observed_owner:
		if incoming_delivery(): incoming_cover()
		return
	if owner<0 or (owner>=0 and not game.players[owner].visible):
		age=.20
		observed_owner=owner
		if incoming_delivery():
			observed_ball=game.ball.position
			var flight: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
			observed_velocity=flight*Vector3(1,0,1)
			observation_age=0
			incoming_cover()
		else:
			targets.clear(); roles.clear(); pressers=[-1,-1]
		return
	var defending_team: int=1-game.players[owner].team
	age=([.48,.32,.22][game.opponent_coach.level()] if defending_team==1 else .28)*lerpf(1.30,.74,game.management.identity.team_quality(defending_team,true))
	var previous_presser: int=pressers[1]
	targets.clear(); roles.clear(); pressers=[-1,-1]
	observed_owner=-1
	for team in range(2): plans[team]=plan_for(team)
	if plans[1]!=last_opponent_plan:
		if last_opponent_plan>=0: game.stadium.sidelines.instruct(1,["defend","balance","attack"][plans[1]])
		last_opponent_plan=plans[1]
	if game.training or game.state!="playing": return
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
	var cohesion: float=game.management.identity.team_quality(team,true)
	var closest := INF
	for i in range(team*11+1,team*11+11):
		var p=game.players[i]
		if not p.visible or p.dismissed: continue
		var group: int=game.management.slot_role(i)
		var depth: float=line+([0,0,1,2][group])*lerpf(13,9.5,cohesion)
		var bias: float=game.opponent_coach.wing_bias*3.0 if team==1 else 0.0
		var at := Vector3(clampf(p.home.x*.78+ball.x*.24+bias,-(P.HALF_WIDTH-5),(P.HALF_WIDTH-5)),0,forward*clampf(depth,-43,36))
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
	if presser<0:
		incoming_cover()
		return
	var trigger: bool=absf(ball.x)>22*P.WIDTH_RATIO or carrier.receive_timer>0 or carrier.energy<.28
	var press := press_level(team)
	if team==1 and game.opponent_coach.level()==0: press=mini(press,1)
	var reach: float=[6.0,10.0,18.0][press]+(4 if trigger else 0)
	var in_box: bool=ball.z*forward< -33.5 and absf(ball.x)<20.16
	if game.flat_distance(game.players[presser].position,ball)>reach:
		pressers[team]=-1
		if team==1: opponent_duties(owner,-1,-1,false,in_box)
		spread_cover(ball,in_box,-1)
		incoming_cover()
		return
	# Approach from the goal side, screening the central pass as we close.
	var exposed: bool=game.duels.ball_opened(owner)
	targets[presser]=ball+goal_side*(.65 if exposed else (1.35 if in_box else 1.12))
	if team==1:
		var gap: float=game.flat_distance(game.players[presser].position,ball)
		var anticipation: float=[.10,.24,.34][game.opponent_coach.level()]*clampf(gap/4,.5,1.5)*lerpf(.70,1.22,game.management.identity.quality(presser,true))
		# Read visible travel, never the human's pending input. Meet the running
		# lane from the goal side instead of following yesterday's ball position.
		targets[presser]+=observed_velocity*anticipation
	roles[presser]="press"
	var covering := -1
	var cover_cost := INF
	var hole: Vector3=game.players[presser].position+Vector3(0,0,-forward*5)
	if team==1: hole=targets[presser]+goal_side*5.6
	for i in targets:
		if i==presser: continue
		var q=game.players[i]
		var cost: float=game.flat_distance(q.position,hole)+(7 if game.management.slot_role(i)==3 else 0)
		if cost<cover_cost: covering=i; cover_cost=cost
	if covering>=0:
		targets[covering]=Vector3(clampf(hole.x,-(P.HALF_WIDTH-7),(P.HALF_WIDTH-7)),0,forward*clampf(hole.z*forward,-44,30))
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
	spread_cover(ball,in_box,presser)
	incoming_cover()
	for i in targets:
		targets[i].x=clampf(targets[i].x,-(P.HALF_WIDTH-1),(P.HALF_WIDTH-1))
		targets[i].z=clampf(targets[i].z,-48,48)

func incoming_delivery() -> bool:
	if game.training or game.state!="playing": return false
	if game.ball.held_by!=null or game.ball.pending_reset: return false
	var velocity: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
	var air: bool=game.ball.position.y>.85 or velocity.y>1.6
	var driven: bool=velocity.length()>7.5 and game.dribbler<0
	if not air and not driven: return false
	var point: Vector3=game.second_balls.landing()
	for team in range(2):
		if game.last_touch==team: continue
		var forward: float=game.attack_sign(team)
		var toward: float=velocity.dot(Vector3(0,0,-forward))
		if toward<2.0 and point.z*forward>-26.0: continue
		if point.z*forward<-22.0 and absf(point.x)<24.0: return true
		if game.ball.position.z*forward<-28.0 and absf(game.ball.position.x)<22.0 and toward>3.0: return true
	return false

func incoming_cover() -> void:
	if not incoming_delivery(): return
	var point: Vector3=game.second_balls.landing()
	var attack: int=game.last_touch if game.last_touch in [0,1] else 0
	var team: int=1-attack
	var forward: float=game.attack_sign(team)
	if point.z*forward>-18.0 and game.ball.position.z*forward>-22.0: return
	var drop := Vector3(clampf(point.x,-(P.HALF_WIDTH-3),(P.HALF_WIDTH-3)),0,forward*clampf(minf(point.z*forward,point.z*forward-1.2),-47,8))
	var best := -1
	var best_cost := INF
	var present := false
	for i in range(team*11+1,team*11+11):
		var p=game.players[i]
		if not p.visible or p.dismissed or p.keeper: continue
		var gap: float=game.flat_distance(p.position,drop)
		if gap<2.4: present=true
		var cost: float=gap+(0.0 if game.management.slot_role(i)==1 else 2.4)
		if i==pressers[team] and game.dribbler>=0: cost+=8.0
		if cost<best_cost: best_cost=cost; best=i
	var side: float
	if absf(point.x)>8.0: side=signf(point.x)
	elif absf(game.ball.position.x)>6.0: side=-signf(game.ball.position.x)
	else: side=-1.0
	if side==0.0: side=-1.0
	var far := -1
	var far_score := -INF
	for i in range(team*11+1,team*11+11):
		if i==best or i==pressers[team]: continue
		var p=game.players[i]
		if not p.visible or p.dismissed or p.keeper or game.management.slot_role(i)==3: continue
		var width: float=p.home.x*side
		if width<4.0: continue
		var score: float=width-absf(p.position.z*forward-drop.z*forward)*.12
		if score>far_score: far_score=score; far=i
	if best>=0 and (not present or best_cost>1.8):
		targets[best]=drop
		roles[best]="recover"
	if far>=0 and far!=best and not present:
		var post_x: float=clampf(point.x+side*3.6,-(P.HALF_WIDTH-3),(P.HALF_WIDTH-3))
		if absf(point.x)<8.0: post_x=side*5.5
		targets[far]=Vector3(post_x,0,forward*clampf(minf(drop.z*forward,-33.5),-47,-26))
		roles[far]="recover"

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
	var hold_distance: bool=mark and gap<3.3 and speed<5.5
	p.sprinting=(p.sprinting or chasing or covering) and not hold_distance and p.energy>.3 and not p.exhausted
	p.jockeying=mark and gap<3.4 and not p.sprinting
	if p.jockeying: p.facing=((observed_ball-p.position)*Vector3(1,0,1)).normalized()
	# Match the runner's velocity while holding the blocking position. Pure
	# arrival steering slows to a walk precisely when the attacker runs past.
	var offset: Vector3=(target-p.position)*Vector3(1,0,1)
	if mark:
		offset+=observed_velocity*minf(observation_age,.26)
		var tracking: Vector3=observed_velocity+offset*4.2
		var pace: float=10.4 if p.sprinting else 6.2
		var movement := (tracking/pace).limit_length(1)
		# A committed running defender must plant before reversing. Standing
		# jockeys remain responsive; no skill button grants a stun or immunity.
		var motion: Vector3=p.velocity*Vector3(1,0,1)
		if gap<5 and motion.length()>2.0 and movement.length()>.1:
			p.defensive_turn_load=clampf((.72-motion.normalized().dot(movement.normalized()))/1.4,0,1)
		return movement
	return offset.normalized()*clampf(offset.length()/1.4,0,1)

func spread_cover(ball: Vector3,in_box: bool,presser: int) -> void:
	# Duties describe different jobs: non-challengers screen a lane from depth,
	# rather than forming a second ring of bodies at the carrier's feet.
	for i in targets:
		if i==presser or roles[i]=="press_support": continue
		var gap: Vector3=(targets[i]-ball)*Vector3(1,0,1)
		var distance := 3.4 if in_box else 4.8
		if roles[i]=="cover": distance=4.4 if in_box else 5.8
		if gap.length()<distance:
			var goal_side := Vector3(0,0,-game.attack_sign(game.players[i].team))
			var lane: float=signf(game.players[i].home.x)
			if lane==0: lane=-1.0 if i%2==0 else 1.0
			var direction := gap.normalized() if gap.length()>1.0 else (goal_side+Vector3(lane*.7,0,0)).normalized()
			targets[i]=ball+direction*distance

func opponent_duties(owner: int,presser: int,covering: int,trigger: bool,in_box: bool) -> void:
	var brain=game.opponent_coach
	var ball: Vector3=game.ball.position
	var forward: float=game.attack_sign(1)
	if in_box and presser>=0: roles[presser]="contain"
	# The second defender closes the escape lane; the cover stays behind both.
	var trapped: bool=absf(ball.x)>P.HALF_WIDTH-7 or (game.duels.ball_opened(owner) and trigger)
	var double_press: bool=presser>=0 and brain.level()>0 and press_level(1)==2 and (trapped or brain.transition>0) and not in_box
	if double_press and (support_time>0 or support_rest<=0):
		var helper := -1
		var best := 10.0 if brain.level()==2 else 7.0
		for i in targets:
			if i in [presser,covering] or game.players[i].energy<.38 or game.management.slot_role(i)==1: continue
			var gap: float=game.flat_distance(game.players[i].position,ball)
			if i==support_player: gap-=.8
			if gap<best: best=gap; helper=i
		if helper>=0:
			if support_time<=0: support_time=1.45 if brain.level()==2 else 1.1
			support_player=helper
			var exit := Vector3(-signf(ball.x)*2.7,0,-forward*1.3)
			if absf(ball.x)<5: exit=Vector3(2.7 if game.players[presser].position.x<ball.x else -2.7,0,-forward*1.3)
			targets[helper]=ball+exit; roles[helper]="press_support"
	elif support_time>0:
		support_time=0; support_rest=3.8; support_player=-1
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
			targets[i]=Vector3(clampf(target.x,-(P.HALF_WIDTH-4),(P.HALF_WIDTH-4)),0,forward*clampf(target.z*forward,-47,15))
			roles[i]="recover" if game.players[i].position.z*forward>target.z*forward+2 else "track"
