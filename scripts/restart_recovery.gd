extends RefCounted
## Dead ball is still physical: approach, stoop, lift, carry, lower and release.
var owner_ref: WeakRef
var setup:
	get: return owner_ref.get_ref() if owner_ref!=null else null
var phase := ""
var age := 0.0
var pickup_point := Vector3.ZERO
var delivery := Vector3.ZERO
var rest_age := 0.0

func reset() -> void:
	phase=""
	age=0
	rest_age=0

func begin(owner) -> void:
	owner_ref=weakref(owner)
	phase="retrieve"
	age=0
	delivery=setup.targets[setup.taker] if setup.game.restart_type=="TAÇ" else setup.game.restart_point-setup.direction*0.42

func enter(next: String) -> void:
	phase=next
	age=0
	if next=="arrange": rest_age=0

func step(delta: float) -> void:
	var game=setup.game
	var p=game.players[setup.taker]
	var ball=game.ball
	age+=delta
	setup.settle(delta,setup.taker)
	var destination: Vector3=p.position
	var rate := 0.9
	if phase=="retrieve":
		p.set_piece_pose=""
		var lead: float=clampf(game.flat_distance(p.position,ball.position)/8,0,0.65)
		destination=ball.position+Vector3(ball.linear_velocity.x,0,ball.linear_velocity.z)*lead
		destination.y=0
		destination.x=clampf(destination.x,-35.0,35.0)
		destination.z=clampf(destination.z,-55.1,55.1)
		var approach: Vector3=(destination-p.position)*Vector3(1,0,1)
		if approach.length()>0.01: destination-=approach.normalized()*0.43
		# A ball against the inside back/side net must be approached from
		# inside the goal. The stand-off offset must not cross the side net.
		if absf(ball.position.x)<3.66 and absf(ball.position.z)>=50 and absf(ball.position.z)<52.5:
			destination=Vector3(clampf(ball.position.x,-3.1,3.1),0,signf(ball.position.z)*minf(absf(ball.position.z),51.9))
		if ball.position.y<0.72 and ball.linear_velocity.length()<4.5 and game.flat_distance(p.position,ball.position)<0.95 and p.action_timer<=0:
			pickup_point=ball.position*Vector3(1,0,1)
			p.facing=(pickup_point-p.position).normalized()
			enter("pickup")
	elif phase=="pickup":
		p.set_piece_pose="pickup"
		p.handling_blend=smoothstep(0,0.38,age)
		destination=pickup_point-p.facing*0.43
		rate=0.3
		if game.flat_distance(p.position,ball.position)>1.25 or ball.position.y>0.95:
			enter("retrieve")
		elif age>0.4:
			if p.hand_center().distance_to(ball.position)<0.6 and ball.linear_velocity.length()<4.5:
				ball.hold(p)
				enter("lift")
			elif age>0.95: enter("retrieve")
	elif phase=="lift":
		p.set_piece_pose="pickup"
		p.handling_blend=1-smoothstep(0,0.5,age)
		if age>0.58: enter("carry")
	elif phase=="carry":
		p.set_piece_pose="carry"
		p.handling_blend=0
		destination=delivery
		rate=0.82
		if game.flat_distance(p.position,delivery)<0.13 and Vector2(p.velocity.x,p.velocity.z).length()<0.6:
			p.facing=setup.direction
			enter("raise" if game.restart_type=="TAÇ" else "place")
	elif phase=="raise":
		p.set_piece_pose="throw"
		p.handling_blend=smoothstep(0,0.6,age)
		p.facing=setup.direction
		destination=delivery
		if age>0.8 and p.hand_center().distance_to(ball.position)<0.18: enter("arrange")
	elif phase=="place":
		p.set_piece_pose="pickup"
		p.handling_blend=smoothstep(0,0.48,age)
		p.facing=setup.direction
		destination=delivery
		if age>0.65 and ball.position.y<0.44 and p.hand_center().distance_to(ball.position)<0.2:
			ball.release_hold()
			enter("stand")
	elif phase=="stand":
		p.set_piece_pose="pickup"
		p.handling_blend=1-smoothstep(0,0.45,age)
		if age>0.5:
			p.set_piece_pose=""
			enter("arrange")
	elif phase=="arrange":
		destination=setup.targets[setup.taker]
		p.facing=setup.direction
		if ball.position.y<0.235 and Vector2(ball.linear_velocity.x,ball.linear_velocity.z).length()<0.1 and absf(ball.linear_velocity.y)<0.35:
			rest_age+=delta
		else: rest_age=0
		if game.restart_type!="TAÇ" and game.flat_distance(ball.position,game.restart_point)>0.3 and age>0.6:
			# An actual collision can disturb placement; retrieve it again, never snap it back.
			enter("retrieve")
		elif can_ready():
			setup.ready()
	# Avoid cutting through the goal mouth/net on the way to a ball behind it.
	destination=around_goal(p.position,destination)
	setup.move_player(setup.taker,destination,delta,rate)
	if phase in ["pickup","lift","raise","place","stand","arrange"]:
		var facing: Vector3=setup.direction if phase not in ["pickup","lift"] else (pickup_point-p.position)*Vector3(1,0,1)
		if facing.length()>0.01: p.facing=facing.normalized()
	if ball.held_by==p: ball.hold_target=p.hand_center()

func around_goal(from: Vector3,to: Vector3) -> Vector3:
	for side in [-1.0,1.0]:
		var a: float = from.z*side
		var b: float = to.z*side
		if maxf(a,b)<49.7 or minf(a,b)>52.55: continue
		var route_x := 4.8*(1 if from.x+to.x>=0 else -1)
		var from_inside := absf(from.x)<3.5 and a>=49.7 and a<52.55
		var to_inside := absf(to.x)<3.5 and b>=49.7 and b<52.55
		if to_inside:
			# The goal mouth is open. Enter it from the pitch instead of circling
			# endlessly around a side net when the ball has stopped in the goal.
			if from_inside or (a<50 and absf(from.x)<3.4): return to
			if a>52.55 and absf(from.x)<4.5: return Vector3(route_x,0,53.5*side)
			if a>=49.7: return Vector3(route_x,0,49.1*side)
			return Vector3(clampf(to.x,-2.8,2.8),0,49.1*side)
		if from_inside: return Vector3(from.x,0,49.1*side)
		if absf(from.x)>4.5 and absf(to.x)>4.5 and signf(from.x)==signf(to.x): continue
		if absf(from.x)<4.5:
			return Vector3(route_x,0,(49.1 if a<50 else 53.5)*side)
		if absf(to.x)<4.5:
			if b>52.55 and a<52.55: return Vector3(route_x,0,53.5*side)
			if b<49.7 and a>49.7: return Vector3(route_x,0,49.1*side)
	return to

func can_ready() -> bool:
	var game=setup.game
	var ball=game.ball
	var p=game.players[setup.taker]
	if game.flat_distance(p.position,setup.targets[setup.taker])>0.16: return false
	if game.restart_type=="TAÇ":
		if ball.held_by!=p or ball.position.y<1.7: return false
	else:
		if ball.held_by!=null or rest_age<0.25: return false
		if game.flat_distance(ball.position,game.restart_point)>0.3: return false
	return setup.formation_ready()

func description() -> String:
	match phase:
		"retrieve": return "TOP ALINIYOR"
		"pickup","lift": return "OYUNCU TOPU ALIYOR"
		"carry": return "TOP DURAN TOP NOKTASINA GÖTÜRÜLÜYOR"
		"place","stand": return "TOP YERE YERLEŞTİRİLİYOR"
		"raise": return "TAÇ İÇİN HAZIRLANIYOR"
	return "OYUNCULAR YERLEŞİYOR · DÜDÜĞÜ BEKLE"
