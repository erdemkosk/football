extends RefCounted
## Buffered shot intent. Only a swept contact with the animated boot can strike.
const Motion = preload("res://scripts/ball_motion.gd")
const Context = preload("res://scripts/contextual_finish.gd")
const REACH := 0.36
const BUFFER := 0.85
const STEP := 1.0/60.0
var game
var requests: Dictionary = {}

func reset() -> void:
	for index in requests.keys(): cancel(index)

func active(index: int) -> bool:
	return requests.has(index)

func cancel(index: int) -> void:
	if active(index) and requests[index].launched:
		var p=game.players[index]
		if p.pose=="volley" and not p.volley_motion.hit:
			p.action_timer=0; p.aerial_preparing=false
	if active(index) and requests[index].user and game.controlled==index:
		game.charging=false; game.charge=0
	requests.erase(index)

func window(index: int,aim: Vector3=Vector3.ZERO) -> Dictionary:
	var p=game.players[index]
	var ball=game.ball
	if game.state!="playing" or not p.visible or p.dismissed or p.keeper or p.action_timer>0 or p.kick_timer>0 or p.touch_cooldown>0 or ball.held_by!=null or ball.pending_reset: return {}
	var velocity: Vector3=ball.kick_velocity if ball.pending_kick else ball.linear_velocity
	if ball.position.y<0.34 and absf(velocity.y)<1.2: return {}
	if game.dribbler==index or game.flat_distance(p.position,ball.position)>8: return {}
	var point: Vector3=ball.position
	var spin: float=ball.spin
	var bounced: bool=ball.ground_bounce_age<0.28
	var travel: Vector3=p.velocity*Vector3(1,0,1)
	var drag := Motion.air_drag(game.weather)
	if aim.length()<.1: aim=game.shot_direction if game.is_user_player(index) and game.charging else Vector3(0,0,game.attack_sign(p.team))
	for sample in range(1,34):
		velocity=Motion.apply_spin(Motion.air_velocity(velocity,STEP,drag),spin,STEP)
		velocity.y-=Motion.GRAVITY*STEP
		point+=velocity*STEP
		spin=Motion.decay_spin(spin,STEP,true)
		if point.y<ball.RADIUS:
			if bounced: break
			point.y=ball.RADIUS
			velocity.y=absf(velocity.y)*game.weather.ball_bounce(point)
			bounced=true
		var time := sample*STEP
		var technique := Context.technique(game,p,point,velocity,aim,time,bounced)
		if technique=="bicycle": return {"time":time,"point":point,"jump":2.2,"kind":technique}
		var hop := maxf(0,point.y-p.position.y-p.body_scale.y*1.40)
		if time<0.085 or point.y<0.27 or hop>0.20: continue
		var future: Vector3=p.position+travel*minf(time,0.12)
		var offset := point-future
		var relative: Vector3=velocity-travel
		if Vector3(offset.x,0,offset.z).dot(relative*Vector3(1,0,1))>1.0: continue
		var local: Vector3=p.rig.to_local(point-(future-p.position)-Vector3.UP*hop)
		if local.z>0.34: continue
		var hip := Vector3(-0.14 if local.x<0 else 0.14,0.85,0)
		if (local-hip).length()>0.84: continue
		var jump := (hop+10*time*time)/time if hop>.025 else 0.0
		return {"time":time,"point":point,"jump":jump,"kind":technique}
	return {}

func can_request(index: int) -> bool:
	return active(index) or not window(index).is_empty()

func label(index: int) -> String:
	var plan: Dictionary=requests[index] if active(index) else window(index)
	return {"half_volley":"Yarım vole","side_volley":"Yan vole","bicycle":"Röveşata"}.get(plan.get("kind",""),"Vole")

func arm(index: int,aim: Vector3,power: float=0.0,user: bool=true) -> bool:
	var plan := window(index,aim)
	if active(index) or plan.is_empty() or game.heading.active(index): return false
	requests[index]={"age":0.0,"aim":aim,"power":power,"user":user,"released":not user,"launched":false,"kind":plan.kind,"ball":game.ball.position,"boot":Vector3.ZERO}
	game.players[index].receive_timer=0
	game.players[index].shot_preparation=0
	return true

func release(index: int,aim: Vector3,power: float) -> void:
	if active(index):
		requests[index].aim=aim; requests[index].power=power; requests[index].released=true

func prepare(delta: float) -> void:
	if game.state!="playing": reset(); return
	for index in requests.keys():
		var request: Dictionary=requests[index]
		var p=game.players[index]
		request.age+=delta
		if request.age>BUFFER or not p.visible or p.dismissed or game.ball.held_by!=null or game.ball.pending_reset or (request.user and game.controlled!=index) or (p.action_timer>0 and p.pose!="volley"):
			cancel(index); continue
		if request.user and not request.released:
			if not game.charging: cancel(index); continue
			request.aim=game.shot_direction; request.power=game.charge
		if request.launched:
			if p.action_timer<=0: cancel(index); continue
			var remaining: float=p.volley_motion.contact_time-(p.volley_motion.duration-p.action_timer)
			if remaining>0:
				p.volley_motion.target=contact_prediction(remaining)
				var travel: Vector3=p.velocity*Vector3(1,0,1)*remaining
				var target: Vector3=p.rig.to_local(p.volley_motion.target-travel)
				var unreachable: bool=game.flat_distance(p.position,p.volley_motion.target)>.95 or p.volley_motion.target.y-p.position.y>2.15 if request.kind=="bicycle" else (target-Vector3(0,.85,0)).length()>1.18
				if unreachable:
					cancel(index); continue
			p.volley_motion.aim=request.aim
			continue
		var plan := window(index,request.aim)
		if plan.is_empty() or plan.time>0.24: continue
		p.volley_motion.begin(p,plan,request.aim)
		request.kind=plan.kind; request.launched=true
		request.ball=game.ball.position; request.boot=p.volley_motion.boot(p)

func contact_prediction(time: float) -> Vector3:
	var point: Vector3=game.ball.position
	var velocity: Vector3=game.ball.linear_velocity
	var drag := Motion.air_drag(game.weather)
	while time>0:
		var step := minf(time,STEP)
		velocity=Motion.air_velocity(velocity,step,drag)
		velocity.y-=Motion.GRAVITY*step
		point+=velocity*step
		if point.y<game.ball.RADIUS:
			point.y=game.ball.RADIUS
			velocity.y=absf(velocity.y)*game.weather.ball_bounce(point)
		time-=step
	return point

func launch_velocity(index: int,aim: Vector3,power: float,quality: float=1.0) -> Vector3:
	var p=game.players[index]
	var direction := (aim*Vector3(1,0,1)).normalized()
	if direction.length()<0.1: direction=Vector3(0,0,game.attack_sign(p.team))
	var foot: int=p.volley_motion.foot if p.pose=="volley" and p.action_timer>0 else p.ball_actions.choose_foot(p,game.ball.position)
	var weak: float=1.0 if foot==p.attributes.preferred_foot else lerpf(.88,.99,(p.attributes.weak_foot-1)/4.0)
	var ability: float=weak*p.Attributes.multiplier(p.attributes.finishing,.055)*(1-p.contest_weight*.045)
	var speed := (lerpf(18,30,power)+minf(game.ball.linear_velocity.length()*0.16,3))*ability*lerpf(0.78,1,quality)
	# A raised foot drives through the ball; it does not add a ground-shot lob.
	var height: float=game.ball.position.y
	var lift := lerpf(1.2,3.4,power)-smoothstep(0.55,1.65,height)*2.4+(1-quality)*1.2
	return direction*speed+Vector3.UP*lift

func resolve() -> void:
	if game.state!="playing" or game.ball.pending_kick or game.ball.held_by!=null or game.kick_lock>0: return
	var best := -1
	var closest := REACH
	for index in requests.keys():
		var request: Dictionary=requests[index]
		var p=game.players[index]
		if not request.launched or p.pose!="volley" or p.action_timer<=0: continue
		var boot: Vector3=p.volley_motion.boot(p)
		var from: Vector3=request.ball-request.boot
		var to: Vector3=game.ball.position-boot
		var segment := to-from
		var fraction := clampf(-from.dot(segment)/maxf(segment.length_squared(),0.00001),0,1)
		var distance := (from+segment*fraction).length()
		request.ball=game.ball.position; request.boot=boot
		var age: float=p.volley_motion.duration-p.action_timer
		if age<p.volley_motion.contact_time*0.45 or age>p.volley_motion.contact_time+0.10: continue
		if distance<closest: closest=distance; best=index
	if best<0: return
	var request: Dictionary=requests[best]
	var p=game.players[best]
	# The prediction can anticipate a bounce, but the announced finish follows
	# the actual ground contact, including deflections after the request.
	if request.kind!="bicycle": request.kind=Context.technique(game,p,game.ball.position,game.ball.linear_velocity,request.aim,0,game.ball.ground_bounce_age<.28)
	p.volley_motion.kind=request.kind
	var quality := clampf(1-closest/REACH*0.22-game.first_touch.pressure(best)*0.16-(1-p.energy)*0.12-p.contest_weight*0.12,0.35,1)
	var velocity := launch_velocity(best,request.aim,request.power,quality)
	# A successful contact keeps its short follow-through; a failed approach
	# above releases the locomotion immediately instead of playing an air kick.
	p.volley_motion.hit=true
	p.volley_motion.follow_position=p.position
	cancel(best)
	if request.user:
		game.charging=false; game.charge=0; game.shot_chip=false; game.shot_finesse=false
	if game.strike(best,velocity,0,false,"half_volley" if request.kind=="half_volley" else "volley"):
		p.volley_motion.hit=true
		p.volley_motion.target=game.ball.position
		game.shots[p.team]+=1
		game.hint({"half_volley":"YARIM VOLE","side_volley":"YAN VOLE","bicycle":"RÖVEŞATA"}.get(request.kind,"VOLE"))
