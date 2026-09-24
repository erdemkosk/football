extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
var game
var runs: Dictionary = {}
var targets: Dictionary = {}
var roles: Dictionary = {}
var shape := preload("res://scripts/attack_shape.gd").new()
var box := preload("res://scripts/box_support.gd").new()
const ONE_TWO_DISTANCE := 12.0
const ONE_TWO_TIME := 3.0
const PLAN_INTERVAL := .10
var plan_age := 0.0
var plan_elapsed := 0.0
var plan_owner := -2
var plan_ball := Vector3.INF
var plan_settings: Array=[]

func reset() -> void:
	runs.clear()
	targets.clear()
	roles.clear()
	shape.reset()
	box.reset()
	plan_age=0; plan_elapsed=0; plan_owner=-2; plan_settings.clear()

func passed(passer: int,receiver: int,one_two: bool=false) -> void:
	plan_age=0
	if receiver<0 or game.players[passer].keeper: return
	if receiver in runs and runs[receiver].receiver==passer: end_run(receiver)
	runs[passer]={"receiver":receiver,"time":3.6,"origin":game.players[passer].position}
	if one_two:
		var p=game.players[passer]
		var target: Vector3=p.position+Vector3(clampf(-p.position.x,-4,4),0,game.attack_sign(p.team)*9)
		target.x=clampf(target.x,-(P.HALF_WIDTH-3),(P.HALF_WIDTH-3)); target.z=clampf(target.z,-46,46)
		runs[passer].merge({"explicit":true,"time":ONE_TWO_TIME,"target":target,"previous":p.position,"distance":0.0},true)
		p.call_timer=ONE_TWO_TIME

func follow_run(index: int) -> Vector3:
	if not runs.has(index) or not runs[index].get("explicit",false): return Vector3.ZERO
	var offset: Vector3=(runs[index].target-game.players[index].position)*Vector3(1,0,1)
	return offset.normalized()*clampf(offset.length()/1.4,0,1)

func end_run(index: int) -> void:
	plan_age=0
	if runs.get(index,{}).get("explicit",false): game.players[index].call_timer=0
	runs.erase(index)
	targets.erase(index)
	roles.erase(index)

func command(come_short: bool=false) -> int:
	var owner: int=game.controlled
	if game.state!="playing" or not game.has_ball_control(owner) or game.ball.held_by!=null: return -1
	var p=game.players[owner]
	var aim: Vector3=game.pass_heading()
	var chosen := -1
	var best := INF
	for i in range(game.players.size()):
		var q=game.players[i]
		if i==owner or q.team!=p.team or q.keeper or not q.visible or q.dismissed or q.action_timer>0: continue
		var offset: Vector3=(q.position-p.position)*Vector3(1,0,1)
		var gap := offset.length()
		if gap<3 or gap>36 or offset.normalized().dot(aim)<.55: continue
		var score: float=(1-offset.normalized().dot(aim))*24+gap*.16
		if score<best: best=score; chosen=i
	if chosen<0: return -1
	# One forward request and one short option can coexist with a one-two.
	var kind := "come_short" if come_short else "directed_run"
	for i in runs.keys():
		if runs[i].get("command","")==kind: end_run(i)
	var runner=game.players[chosen]
	var point: Vector3=runner.position+Vector3(clampf(-runner.position.x,-3,3),0,game.attack_sign(p.team)*12)
	if come_short: point=p.position+(runner.position-p.position).normalized()*5.5
	assign_run(chosen,point,kind,3.5)
	runs[chosen].owner=owner
	return chosen

func assign_run(index: int,point: Vector3,kind: String,duration: float) -> void:
	var p=game.players[index]
	point.x=clampf(point.x,-(P.HALF_WIDTH-3),P.HALF_WIDTH-3); point.z=clampf(point.z,-46,46)
	runs[index]={"receiver":-1,"explicit":true,"command":kind,"time":duration,"target":point,"origin":p.position,"previous":p.position,"distance":0.0}
	p.call_timer=minf(duration,1.2)
	plan_age=0

func update(delta: float) -> void:
	if game.ball.held_by!=null:
		# Securing a save ends the preceding attack, including requested runs.
		for i in runs.keys(): end_run(i)
		reset()
		return
	for i in runs.keys():
		runs[i].time-=delta
		var p=game.players[i]
		if runs[i].time<=0 or not p.visible or p.dismissed or game.last_touch!=p.team:
			end_run(i)
			continue
		if runs[i].get("explicit",false):
			if runs[i].get("command","")=="come_short":
				var caller=game.players[runs[i].owner]
				if game.dribbler==runs[i].owner:
					runs[i].target=caller.position+(p.position-caller.position).normalized()*5.5
			runs[i].distance+=game.flat_distance(p.position,runs[i].previous)
			runs[i].previous=p.position
			var coming: bool=runs[i].get("command","")=="come_short"
			if runs[i].distance>=(30.0 if coming else ONE_TWO_DISTANCE) or (not coming and game.flat_distance(p.position,runs[i].target)<0.8) or game.dribbler==i or (game.controlled==i and game.movement_input().length()>0.1): end_run(i)
	plan_age-=delta; plan_elapsed+=delta
	var owner: int=game.dribbler if game.dribbler>=0 else game.nearest_to_ball(1.4)
	var team: int=game.players[owner].team if owner>=0 else game.last_touch
	var explicit_run := false
	for i in runs:
		if runs[i].get("explicit",false) and game.players[i].team==team: explicit_run=true; break
	if game.state!="playing" or owner<0 and game.ai_pass_time[team]<=0 and not explicit_run:
		targets.clear(); roles.clear(); shape.reset(); box.reset(); plan_age=0; plan_elapsed=0; return
	var ball: Vector3=game.ball.position
	var forward: float = game.attack_sign(team)
	var line: float=game.rules.offside_line(team)-0.8
	var intent: int=game.team_tactics.score_intent(team)
	var counter: bool=game.team_tactics.countering(team)
	var settings: Array=[game.half,game.controlled,game.management.formation,game.management.opponent_formation,game.team_tactics.plan_for(team),game.opponent_coach.escape_press,intent,counter]
	var available := 0
	for i in range(game.players.size()):
		if game.players[i].visible and not game.players[i].dismissed: available|=1<<i
	settings.append(available)
	# A newly committed receiver must leave its support assignment immediately.
	settings.append(game.ai_receivers[team] if game.ai_pass_time[team]>0 else -1)
	for key in ["width","tempo","runs","fullbacks","anchor"]: settings.append(game.management.detail(team,key))
	var valid := plan_age>0 and owner==plan_owner and settings==plan_settings and ball.distance_squared_to(plan_ball)<.8*.8
	if valid:
		# Movement, stamina and explicit-run lifetimes still advance at 120 Hz.
		# Recheck offside every tick even between spatial-planning samples.
		for i in targets: targets[i].z=forward*minf(targets[i].z*forward,maxf(0,line))
		return
	plan_age=PLAN_INTERVAL; plan_owner=owner; plan_ball=ball; plan_settings=settings
	var elapsed := plan_elapsed; plan_elapsed=0
	targets.clear(); roles.clear()
	var wing := absf(ball.x)>14
	var side := signf(ball.x)
	# The candidate search reads one immutable layout. Cache native positions
	# once and take square roots only for the two winning distances.
	var opponents := PackedVector2Array()
	for q in game.players:
		if q.visible and q.team!=team: opponents.append(Vector2(q.position.x,q.position.z))
	var ball_plane := Vector2(ball.x,ball.z)
	for i in range(game.players.size()):
		var p=game.players[i]
		if not p.visible or p.dismissed or p.keeper or p.team!=team or i==owner: continue
		var target: Vector3=p.home+Vector3(ball.x*0.18,0,ball.z*0.35+forward*7)
		var role := "support"
		var group: int=game.management.slot_role(i)
		var wide_back: bool=game.management.wide_defender(i)
		var awareness: float=game.management.identity.quality(i)
		if i in runs:
			if runs[i].get("explicit",false):
				target=runs[i].target
				target.z=forward*minf(target.z*forward,maxf(0,line))
				targets[i]=target
				roles[i]=runs[i].get("command","one_two")
				continue
			target=runs[i].origin+Vector3(3 if p.position.x<ball.x else -3,0,forward*13)
			role="give_go"
		elif wing and ball.z*forward> -15 and wide_back and signf(p.home.x)==side:
			target=Vector3(side*(P.HALF_WIDTH-4),0,ball.z+forward*13)
			role="overlap"
		elif wing and ball.z*forward>25 and (group==3 or group==2 and absf(p.home.x)<16):
			if group==3:
				var near_side: bool=signf(p.home.x)==side or absf(p.home.x)<1
				target=Vector3(side*3.5 if near_side else -side*5.5,0,forward*(43 if near_side else 41))
			else: target=Vector3(clampf(p.home.x*.6,-11,11),0,forward*(36 if p.home.z*forward> -15 else 30))
			role="box"
		elif group>=2:
			target=Vector3(p.home.x*0.8+ball.x*0.2,0,ball.z+forward*(8 if group==3 else -6))
		if role!="one_two":
			if game.management.slot_role(i)>=2: target.z+=forward*(game.management.detail(team,"runs")-1)*4
			if game.management.slot_role(i)>=2: target.z+=forward*(game.management.detail(team,"tempo")-1)*2
			if p.number==7 and game.management.detail(team,"anchor")>0:
				target.z=forward*minf(target.z*forward,ball.z*forward-9); role="cover_attack"
			if wide_back:
				var fullback: int=game.management.detail(team,"fullbacks")
				if fullback==0: target.z=forward*minf(target.z*forward,ball.z*forward-15); role="support"
				elif fullback==2 and absf(ball.x)>12 and signf(p.home.x)==side: target.z=ball.z+forward*10; role="overlap"
		var plan: int=game.team_tactics.plan_for(team)
		# Apply mentality inside planning, before cover and offside limits.
		# The final movement target must not receive a second depth adjustment.
		target.z+=forward*(plan-1)*(4 if group==1 else 6)
		var wide: bool=group>=2 and absf(p.home.x)>16 and not wide_back
		if wide and game.management.detail(team,"width")==2 and role not in ["give_go","box"]:
			target.x=signf(p.home.x)*(P.HALF_WIDTH-4)
			role="wing_outlet"
		if counter and (group==3 or wide) and role!="give_go":
			target.z=ball.z+forward*(17 if group==3 else 12)
			role="counter_run"
		# Late risk moves actual runners out of defensive cover. Both teams
		# retain centre backs, but the gap behind their fullbacks is exploitable.
		if intent>0 and (wide_back or group==2 and p.number!=7):
			target.z=ball.z+forward*(10 if wide_back else 13)
			role="commit"
		elif intent<0 and (wide_back or group==2):
			target.z=forward*minf(target.z*forward,ball.z*forward-(15 if wide_back else 8))
			role="cover_attack"
		if group==1 and not wide_back:
			target.z=forward*minf(target.z*forward,ball.z*forward-(9 if plan==2 else 18 if plan==0 else 14))
			role="cover_attack"
		elif plan==0 and role=="overlap":
			target.z=ball.z-forward*9; role="cover_attack"
		# A low outlet and a wide outlet help play around sustained user pressing.
		elif team==1 and game.opponent_coach.escape_press and group==2 and role=="support":
			target.x=signf(p.home.x+.01)*clampf(absf(p.home.x)+5,10,P.HALF_WIDTH-5)
			target.z=ball.z+forward*(-7 if i%2==0 else 5)
		# Individual instructions: hold or join the attack, drift inside or hold
		# the touchline. Explicit give-and-go runs are never overridden.
		var order: Dictionary=game.management.instruction(i)
		if not order.is_empty() and role not in ["give_go","one_two"]:
			var attack: int=int(order.get("attack",1))
			if attack==0:
				target.z=forward*minf(target.z*forward,ball.z*forward-(12.0 if group==1 else 4.0))
				if role in ["overlap","commit","counter_run","wing_outlet","box"]: role="cover_attack"
			elif attack==2:
				target.z+=forward*(9.0 if group==1 else 6.0)
				if wide_back and absf(ball.x)>8 and signf(p.home.x)==side: role="overlap"
				elif group==3 and role=="support": role="channel_run"
			var lane: int=int(order.get("width",1))
			if lane!=1 and absf(p.home.x)>6:
				var outer: float=absf(target.x)*.55 if lane==0 else maxf(absf(target.x),P.HALF_WIDTH-5)
				target.x=signf(p.home.x)*clampf(outer,3.0,P.HALF_WIDTH-3)
		# Sample receiving space and the passing lane; each role keeps its own
		# region instead of everybody converging on the nearest empty point.
		var best := target
		var best_value := -INF
		for offset in [Vector3.ZERO,Vector3(-4,0,0),Vector3(4,0,0),Vector3(0,0,-forward*4)]:
			var candidate: Vector3=target+offset
			candidate.x=clampf(candidate.x,-(P.HALF_WIDTH-3),(P.HALF_WIDTH-3))
			candidate.z=forward*minf(clampf(candidate.z*forward,-43,46),maxf(0,line))
			var clearance_squared := 64.0
			var lane_squared := 25.0
			var endpoint := Vector2(candidate.x,candidate.z)
			var segment := endpoint-ball_plane
			var length_squared := segment.length_squared()
			for opponent in opponents:
				clearance_squared=minf(clearance_squared,opponent.distance_squared_to(endpoint))
				var along := clampf((opponent-ball_plane).dot(segment)/length_squared,0,1) if length_squared>0 else 0.0
				lane_squared=minf(lane_squared,opponent.distance_squared_to(ball_plane+segment*along))
			var value: float=sqrt(clearance_squared)+sqrt(lane_squared)*lerpf(.35,.9,awareness)-offset.length()*0.5
			if value>best_value: best_value=value; best=candidate
		targets[i]=best
		roles[i]=role
	box.update(game,owner,team,self)
	shape.game=game
	shape.update(elapsed,owner,team,self)

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
