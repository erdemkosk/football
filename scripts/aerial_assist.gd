extends RefCounted
## A short, user-requested approach to an incoming ball. Only the existing
## animated head/boot contact can strike; this helper never moves the ball.
const Motion = preload("res://scripts/ball_motion.gd")
const STEP := 1.0/60.0
const BUFFER := 1.15
const MAX_APPROACH := 3.0
var game
var pending: Dictionary = {}

func active(index: int) -> bool:
	return not pending.is_empty() and pending.index==index

func reset() -> void:
	if not pending.is_empty(): cancel(pending.index)

func cancel(index: int) -> void:
	if not active(index): return
	game.players[index].aerial_preparing=false
	if pending.get("motion","")!="":
		game.heading.cancel(index); game.volleys.cancel(index)
	if game.controlled==index: game.charging=false; game.charge=0
	pending.clear()

func plan(index: int,aim: Vector3) -> Dictionary:
	var p=game.players[index]
	var ball=game.ball
	if game.state!="playing" or index!=game.controlled or not p.visible or p.dismissed or p.keeper or p.action_timer>0 or p.kick_timer>0 or p.touch_cooldown>0 or ball.held_by!=null or ball.pending_reset or game.dribbler==index: return {}
	var velocity: Vector3=ball.kick_velocity if ball.pending_kick else ball.linear_velocity
	if (ball.position.y<.4 and absf(velocity.y)<1.5) or game.flat_distance(p.position,ball.position)>14: return {}
	var point: Vector3=ball.position
	var spin: float=ball.spin
	var bounced: bool=ball.ground_bounce_age<.28
	var drag := Motion.air_drag(game.weather)
	var speed: float=minf(6.0,p.movement_speed())*(1-game.weather.mud_at(p.position)*.16)
	var head_height: float=game.heading.head_point(p).y-p.position.y
	var direction := (aim*Vector3(1,0,1)).normalized()
	if direction.length()<.1: direction=p.facing
	var best: Dictionary={}
	var best_cost := INF
	for sample in range(1,55):
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
		if time<.12: continue
		var height: float=point.y-p.position.y
		var kind := ""
		if height>=.3 and height<=p.body_scale.y*1.40+.20:
			kind="half_volley" if bounced and height<.85 else "volley"
		elif height>=head_height-.22 and height<=head_height+lerpf(.35,.75,p.energy): kind="header"
		if kind=="": continue
		var target: Vector3=point-direction*(.10 if kind=="header" else .48)
		target.y=p.position.y
		var distance: float=game.flat_distance(p.position,target)
		# Leave time for planting the support foot / taking off. No distant runs
		# or unlimited pursuit if a cross is intercepted after the button press.
		var travel_time := maxf(0,time-(.18 if kind=="header" else .14))
		if distance>minf(MAX_APPROACH,travel_time*speed*.85+.20): continue
		if active(index) and game.flat_distance(target,pending.origin)>MAX_APPROACH: continue
		var cost := distance+time*.45+maxf(0,height-head_height)*.20
		if cost>=best_cost: continue
		best_cost=cost
		best={"time":time,"point":point,"target":target,"kind":kind}
	return best

func can_request(index: int) -> bool:
	return active(index) or not plan(index,game.last_direction).is_empty()

func arm(index: int,aim: Vector3,power: float) -> bool:
	var approach := plan(index,aim)
	if active(index) or approach.is_empty(): return false
	pending={"index":index,"age":0.0,"aim":aim,"power":power,"released":false,"origin":game.players[index].position,"plan":approach,"lost":0.0,"motion":""}
	game.players[index].receive_timer=0
	game.players[index].shot_preparation=0
	return true

func release(index: int,aim: Vector3,power: float) -> void:
	if not active(index): return
	pending.aim=aim; pending.power=power; pending.released=true
	if pending.motion!="":
		var motion=game.heading if pending.motion=="header" else game.volleys
		motion.release(index,aim,power)

func update(delta: float) -> void:
	if pending.is_empty(): return
	var index: int=pending.index
	var p=game.players[index]
	pending.age+=delta
	if game.state!="playing" or game.controlled!=index or pending.age>BUFFER or not p.visible or p.dismissed or (p.action_timer>0 and p.pose not in ["header","volley"]) or p.touch_cooldown>0 or game.ball.held_by!=null or game.ball.pending_reset:
		cancel(index); return
	if not pending.released:
		if not game.charging: cancel(index); return
		pending.aim=game.shot_direction; pending.power=game.charge
	if pending.motion!="":
		var motion=game.heading if pending.motion=="header" else game.volleys
		if not motion.active(index): pending.clear(); return
		var request: Dictionary=motion.requests[index]
		if request.launched:
			var remaining: float=pending.contact_at-pending.age
			if pending.motion!="header": remaining=p.volley_motion.contact_time-(p.volley_motion.duration-p.action_timer)
			if remaining>0:
				steer(p,pending.plan.target,remaining,pending.aim)
			return
	var approach := plan(index,pending.aim)
	if approach.is_empty():
		pending.lost+=delta
		if pending.lost>.12: cancel(index)
		return
	pending.lost=0.0; pending.plan=approach
	steer(p,approach.target,approach.time-.12,pending.aim)
	if pending.motion!="": return
	var motion=game.heading if approach.kind=="header" else game.volleys
	var window: Dictionary=motion.window(index)
	if window.is_empty() or window.time>.25 or game.flat_distance(p.position,approach.target)>.5: return
	if not motion.arm(index,pending.aim,pending.power): return
	if pending.released: motion.release(index,pending.aim,pending.power)
	game.finishing.style=""
	pending.motion=approach.kind
	pending.contact_at=pending.age+window.time

func steer(p,target: Vector3,time: float,aim: Vector3) -> void:
	var offset: Vector3=(target-p.position)*Vector3(1,0,1)
	# Normal acceleration, stamina and collision resolution still apply.
	# A short arrival slows the run before the actual contact animation.
	var speed: float=maxf(1,p.movement_speed())
	var desired_velocity: Vector3=offset/maxf(.10,time)
	p.desired=desired_velocity.limit_length(6.0)/speed
	p.sprinting=false; p.protecting=false; p.jockeying=false
	p.facing=aim; p.aerial_preparing=true
