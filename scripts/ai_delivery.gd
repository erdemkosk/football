extends RefCounted
## Shared AI delivery judgement. Reads visible motion, never controller input.
const Passing = preload("res://scripts/passing.gd")
const P = preload("res://scripts/pitch_dimensions.gd")
const Native=preload("res://scripts/native_match.gd")
var game

func arrival(player,point: Vector3,reaction: float=0.0) -> float:
	var motion: Vector3=player.velocity*Vector3(1,0,1)
	return arrival_from(player.position,motion,player.movement_speed(),point,reaction)

func arrival_from(position: Vector3,motion: Vector3,movement_speed: float,point: Vector3,reaction: float=0.0) -> float:
	var offset: Vector3=(point-position-motion*reaction)*Vector3(1,0,1)
	var distance := maxf(0,offset.length()-.85)
	var closing := maxf(0,motion.dot(offset.normalized()))
	var pace: float=clampf(maxf(movement_speed,closing),1.0,8.8)
	var initial := minf(closing,pace)
	var acceleration := 12.0
	var accelerating := (pace*pace-initial*initial)/(2*acceleration)
	if distance<accelerating: return reaction+(sqrt(initial*initial+2*acceleration*distance)-initial)/acceleration
	return reaction+(pace-initial)/acceleration+(distance-accelerating)/pace

func assess(index: int,route: Dictionary,receiver: int,origin: Vector3=Vector3.INF,delay: float=0.0) -> Dictionary:
	if not origin.is_finite(): origin=game.ball.position
	var team: int=game.players[index].team
	var flight: float=route.flight
	var target: Vector3=route.target
	var risk: float=Passing.risk(origin,route,team,game.players)
	var lane_risk := risk
	var recipient=game.players[receiver] if receiver>=0 else null
	if recipient!=null and (not recipient.visible or recipient.dismissed or recipient.team!=team): return {"risk":1.0,"lane_risk":lane_risk,"margin":-10.0,"reachable":false}
	var own_time := arrival(recipient,target) if recipient!=null else 10.0
	var opponent_time := 10.0
	var reaction: float=[.38,.30,.24][game.ai_attack.level(team)]
	var positions: Array[Vector3]=[]
	var motions: Array[Vector3]=[]
	var paces: Array[float]=[]
	for q in game.players:
		if not q.visible or q.dismissed or q.team==team: continue
		positions.append(q.position); motions.append(q.velocity*Vector3(1,0,1)); paces.append(q.movement_speed())
		var last := positions.size()-1
		opponent_time=minf(opponent_time,arrival_from(positions[last],motions[last],paces[last],target,reaction))
	var reachable := recipient==null or own_time<=flight+delay+.22
	if not reachable: risk=maxf(risk,.95)
	# Look along the travelling ball, including when a lob descends. A defender
	# five metres off the drawn line may still arrive before a slow delivery.
	var steps := 12
	var airborne: bool=route.get("lob",false)
	var points := Passing.Motion.sample_flight(origin,route.velocity,0,flight,steps,game.weather) if airborne else PackedVector3Array()
	var resistance := Passing.Motion.along(game.weather,origin,target)
	var speed: float=(route.velocity*Vector3(1,0,1)).length()
	var aim := ((target-origin)*Vector3(1,0,1)).normalized()
	var interceptors: Array[int]=[]
	for i in range(positions.size()):
		if (positions[i]-origin).dot(aim)>=-.45 or game.flat_distance(positions[i],origin)<=.8: interceptors.append(i)
	var receiver_position: Vector3=recipient.position if recipient!=null else Vector3.ZERO
	var receiver_motion: Vector3=recipient.velocity*Vector3(1,0,1) if recipient!=null else Vector3.ZERO
	var receiver_pace: float=recipient.movement_speed() if recipient!=null else 0.0
	var kernel := Native.get_kernel()
	if kernel!=null and risk<1.0:
		var samples := PackedVector3Array()
		var times := PackedFloat64Array()
		samples.resize(steps); times.resize(steps)
		for step in range(1,steps+1):
			var time := flight*step/steps
			var point: Vector3=points[step] if airborne else origin+aim*Passing.Motion.distance_at(speed,time,resistance)
			if not airborne: point.y=Passing.BallSize.GROUND_HEIGHT
			samples[step-1]=point; times[step-1]=time
		risk=kernel.interception_risk(positions,motions,paces,interceptors,samples,times,reaction,delay,receiver_position,receiver_motion,receiver_pace,recipient!=null,risk)
		return {"risk":risk,"lane_risk":lane_risk,"margin":opponent_time-own_time,"reachable":reachable}
	for step in range(1,steps+1):
		# Remaining samples only take max(risk, a value clamped to [0, 1]).
		# Once saturated they cannot change any field of the returned assessment.
		if risk>=1.0: break
		var time := flight*step/steps
		var point: Vector3=points[step] if airborne else origin+aim*Passing.Motion.distance_at(speed,time,resistance)
		if not airborne: point.y=Passing.BallSize.GROUND_HEIGHT
		if point.y>1.9: continue
		var receiver_time := arrival_from(receiver_position,receiver_motion,receiver_pace,point) if recipient!=null else 10.0
		for i in interceptors:
			var intercept_time := arrival_from(positions[i],motions[i],paces[i],point,reaction)
			if intercept_time+.10<time+delay and intercept_time+.12<receiver_time:
				risk=maxf(risk,clampf(.65+(time+delay-intercept_time)*.75,0,1))
				if risk>=1.0: break
	return {"risk":risk,"lane_risk":lane_risk,"margin":opponent_time-own_time,"reachable":reachable}

func safe(index: int,route: Dictionary,receiver: int,origin: Vector3=Vector3.INF,delay: float=0.0) -> bool:
	var read := assess(index,route,receiver,origin,delay)
	return read.reachable and read.risk<.72 and (receiver<0 or read.margin>-.12)

func outlets(index: int,origin: Vector3,context: String,delay: float=0.0) -> Dictionary:
	var p=game.players[index]
	var forward: float=game.attack_sign(p.team)
	var best := -INF
	var result: Dictionary={}
	var direct_restart := context in ["KALE VURUŞU","TAÇ","KORNER"]
	for j in range(game.players.size()):
		var q=game.players[j]
		if j==index or not q.visible or q.dismissed or q.team!=p.team or q.keeper or q.action_timer>0: continue
		if not direct_restart and not game.ai_attack.onside(j,p.team): continue
		var distance: float=game.flat_distance(origin,q.position)
		var limit := 30.0 if context=="TAÇ" else (34.0 if context=="keeper" else 48.0)
		if distance<3.5 or distance>limit: continue
		for lob in [false,true]:
			if context=="TAÇ" and not lob: continue
			if context=="keeper" and not lob and distance>17: continue
			var route := Passing.plan(origin,q.position,q.velocity,lob,game.weather)
			var read := assess(index,route,j,origin,delay)
			if not read.reachable or read.risk>.55 or read.margin<.12: continue
			var progress: float=(route.target.z-origin.z)*forward
			var value: float=minf(4,read.margin)*2.5-read.risk*26-float(route.flight)*2+clampf(progress,-18,28)*.16
			if not lob: value+=3
			if context=="KORNER": value+=game.ai_attack.shot_quality(route.target,p.team)*15
			if value>best:
				best=value; result={"kind":"throw" if context=="keeper" and lob else ("roll" if context=="keeper" else ("cross" if lob else "pass")),"route":route,"receiver":j}
	return result

func clearance(index: int,origin: Vector3=Vector3.INF,max_range: float=0.0) -> Dictionary:
	if not origin.is_finite(): origin=game.ball.position
	var team: int=game.players[index].team
	var forward: float=game.attack_sign(team)
	var best := -INF
	var result: Dictionary={}
	# Emergency balls go forward toward the best contested or empty channel,
	# not to the same flank regardless of who is waiting there.
	for side in [-1.0,1.0]:
		for length in [24.0,38.0]:
			var target := Vector3(side*(P.HALF_WIDTH-6),Passing.BallSize.GROUND_HEIGHT,clampf(origin.z+forward*length,-44,44))
			if max_range>0:
				target=origin+((target-origin)*Vector3(1,0,1)).limit_length(max_range)
				target.y=Passing.BallSize.GROUND_HEIGHT
			var route := Passing.plan(origin,target,Vector3.ZERO,true,game.weather)
			var teammate := -1
			var our_time := 10.0
			var their_time := 10.0
			for j in range(game.players.size()):
				var q=game.players[j]
				if j==index or not q.visible or q.dismissed: continue
				var time := arrival(q,target,.25)
				if q.team==team and not q.keeper and time<our_time: our_time=time; teammate=j
				elif q.team!=team: their_time=minf(their_time,time)
			var value: float=clampf(their_time-our_time,-4,4)*3+minf(4,their_time)*2-Passing.risk(origin,route,team,game.players)*10+(target.z-origin.z)*forward*.035
			if value>best:
				best=value; result={"kind":"clearance","route":route,"receiver":teammate if our_time<float(route.flight)+.5 else -1}
	return result
