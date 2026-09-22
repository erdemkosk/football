extends RefCounted
## A short shot intent waits for a real head/ball contact, never for possession.
const REACH := 0.47
const BUFFER := 0.85
var game
var requests: Dictionary = {}

func reset() -> void:
	for index in requests.keys(): cancel(index)

func cancel(index: int) -> void:
	if active(index) and requests[index].user and game.controlled==index:
		game.charging=false; game.charge=0
	requests.erase(index)

func active(index: int) -> bool:
	return requests.has(index)

func head_point(p) -> Vector3:
	return p.head_joint.to_global(Vector3(0,0.16,-0.09))

func window(index: int) -> Dictionary:
	var p=game.players[index]
	var ball=game.ball
	if game.state!="playing" or not p.visible or p.dismissed or p.keeper or p.action_timer>0 or p.kick_timer>0 or p.touch_cooldown>0 or ball.held_by!=null: return {}
	if ball.position.y<1.15 or game.flat_distance(p.position,ball.position)>11: return {}
	var head := head_point(p)
	var velocity: Vector3=ball.kick_velocity if ball.pending_kick else ball.linear_velocity
	if head.distance_to(ball.position)<0.65: return {"time":0.0,"jump":0.0}
	var travel: Vector3=p.velocity*Vector3(1,0,1)
	var jump_limit: float=lerpf(4.4,6.2,p.energy)*p.Attributes.multiplier(p.attributes.heading,.07)
	for sample in range(1,14):
		var time := sample*0.05
		var point: Vector3=ball.position+velocity*time+Vector3.DOWN*4.905*time*time
		var standing := head+travel*time
		if game.flat_distance(point,standing)>0.56 or point.y<standing.y-0.28: continue
		var jump := (point.y-standing.y+10*time*time)/time
		if jump>=0 and jump<=jump_limit: return {"time":time,"jump":jump}
	return {}

func can_request(index: int) -> bool:
	return active(index) or not window(index).is_empty()

func arm(index: int,aim: Vector3,power: float=0.0,user: bool=true,intent: String="shot",receiver: int=-1) -> bool:
	if active(index) or window(index).is_empty(): return false
	requests[index]={"age":0.0,"aim":aim,"power":power,"user":user,"released":not user,"launched":false,"ball":game.ball.position,"head":head_point(game.players[index]),"intent":intent,"receiver":receiver}
	game.players[index].receive_timer=0
	game.players[index].shot_preparation=0
	return true

func release(index: int,aim: Vector3,power: float) -> void:
	if not active(index): return
	requests[index].aim=aim; requests[index].power=power; requests[index].released=true

func prepare(delta: float) -> void:
	if game.state!="playing": reset(); return
	for index in requests.keys():
		var request: Dictionary=requests[index]
		var p=game.players[index]
		request.age+=delta
		if request.age>BUFFER or not p.visible or p.dismissed or game.ball.held_by!=null or (request.user and game.controlled!=index) or (p.action_timer>0 and p.pose!="header"):
			cancel(index); continue
		if request.user and not request.released:
			if not game.charging: cancel(index); continue
			request.aim=game.shot_direction; request.power=game.charge
		if request.launched: continue
		var plan := window(index)
		if plan.is_empty() or plan.time>0.36: continue
		p.begin_header(plan.jump,request.aim)
		request.launched=true
		request.ball=game.ball.position; request.head=head_point(p)

func launch_velocity(index: int,aim: Vector3,power: float,quality: float=1.0) -> Vector3:
	var p=game.players[index]
	var incoming: Vector3=game.ball.linear_velocity
	var speed := clampf((lerpf(8.5,16,power)+incoming.length()*0.27)*lerpf(0.72,1.0,quality)*p.Attributes.multiplier(p.attributes.heading,.10),9,23)
	var direction := (aim*Vector3(1,0,1)).normalized()
	if direction.length()<0.1: direction=Vector3(0,0,game.attack_sign(p.team))
	var toward: float=direction.z*game.attack_sign(p.team)
	var distance: float=absf(game.attack_sign(p.team)*50-game.ball.position.z)
	var time := clampf(distance/maxf(speed*toward,6),0.18,1.35)
	var lift := clampf((lerpf(0.65,1.25,power)-game.ball.position.y+4.905*time*time)/time,-4.5,3.2)
	lift+=(1-quality)*1.3
	return direction*speed+Vector3.UP*lift

func resolve() -> void:
	if game.state!="playing" or game.ball.pending_kick or game.ball.held_by!=null or game.kick_lock>0: return
	var best := -1
	var closest := REACH
	for index in requests.keys():
		var request: Dictionary=requests[index]
		var p=game.players[index]
		if not request.launched or p.pose!="header" or p.action_timer<=0: continue
		var head := head_point(p)
		# Sweep relative ball/head motion to retain fast crosses between ticks.
		var from: Vector3=request.ball-request.head
		var to: Vector3=game.ball.position-head
		var segment := to-from
		var fraction := clampf(-from.dot(segment)/maxf(segment.length_squared(),0.00001),0,1)
		var distance := (from+segment*fraction).length()
		request.ball=game.ball.position; request.head=head
		if distance<closest: closest=distance; best=index
	if best<0: return
	var request: Dictionary=requests[best]
	var p=game.players[best]
	var quality := clampf(1-closest/REACH*0.35-game.first_touch.pressure(best)*0.18-(1-p.energy)*0.12-p.contest_weight*.10,0.3,1)
	var velocity := launch_velocity(best,request.aim,request.power,quality)
	var intent: String=request.get("intent","shot")
	if intent!="shot":
		var direction: Vector3=(request.aim*Vector3(1,0,1)).normalized()
		velocity=direction*(18 if intent=="clearance" else 11)*lerpf(.8,1,quality)+Vector3.UP*(3.2 if intent=="clearance" else 1.2)
	cancel(best)
	if request.user:
		game.charging=false; game.charge=0; game.shot_chip=false; game.shot_finesse=false
	if game.strike(best,velocity,0,false,"header" if intent=="shot" else "header_"+intent):
		p.header_hit_age=0
		if intent=="shot": game.shots[p.team]+=1
		elif intent=="pass":
			game.passes[p.team]+=1
			game.ai_receivers[p.team]=request.receiver
			game.ai_pass_time[p.team]=2
		game.announce("KAFA VURUŞU" if intent=="shot" else ("KAFAYLA UZAKLAŞTIRDI" if intent=="clearance" else "KAFA PASI"))
