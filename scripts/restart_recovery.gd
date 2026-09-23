extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
## Collect at the actual resting ball, relay through the air, then prepare the restart.
var owner_ref: WeakRef
var setup:
	get: return owner_ref.get_ref() if owner_ref!=null else null
var phase := ""
var age := 0.0
var pickup_point := Vector3.ZERO
var delivery := Vector3.ZERO
var rest_age := 0.0
var collector := -1
var worker := -1
var relayed := false
var receive_point := Vector3.ZERO
var flight_time := 0.0
var helpers: Dictionary = {}

func reset() -> void:
	phase=""
	age=0
	rest_age=0
	collector=-1
	worker=-1
	relayed=false
	helpers.clear()

func begin(owner) -> void:
	owner_ref=weakref(owner)
	phase="watch"
	age=0
	relayed=false
	choose_collector()
	set_delivery()

func choose_collector() -> void:
	var nearest := INF
	var chosen := -1
	for i in range(setup.game.players.size()):
		var p=setup.game.players[i]
		if not p.visible or p.dismissed: continue
		var distance: float=setup.game.flat_distance(p.position,setup.game.ball.position)
		if distance<nearest: nearest=distance; chosen=i
	if chosen<0: chosen=setup.taker
	if collector>=0 and collector!=chosen:
		setup.game.players[collector].set_piece_pose="wall" if collector in setup.wall else ""
	collector=chosen
	worker=chosen
	helpers[chosen]=true

func set_delivery() -> void:
	delivery=setup.targets[setup.taker] if setup.game.restart_type=="TAÇ" and worker==setup.taker else setup.game.restart_point-setup.direction*0.42

func is_retriever(index: int) -> bool:
	return phase!="" and (index in helpers or index==worker)

func clear_delivered_ball(from: Vector3,to: Vector3) -> Vector3:
	# Returning players must walk around the ball already placed for the taker.
	var point: Vector3=setup.game.restart_point
	var start := from*Vector3(1,0,1)
	var end := to*Vector3(1,0,1)
	if start.distance_to(point)>4 or end.distance_to(point)<1.8: return to
	# Back away from the placement stance before turning across the ball.
	if start.distance_to(point)<1.2:
		return point+(start-point).normalized()*1.4
	var near := Geometry3D.get_closest_point_to_segment(point,start,end)
	if near.distance_to(point)>1.1: return to
	var path := (end-start).normalized()
	var side := Vector3(-path.z,0,path.x)
	if side.dot(start-point)<0: side=-side
	return point+side*1.5+(start-point).normalized()*0.65

func sideline_claim() -> bool:
	var lines=setup.game.stadium.sidelines
	return is_instance_valid(lines) and lines.claim_throw_in()

func enter(next: String) -> void:
	phase=next
	age=0
	if next=="arrange": rest_age=0

func step(delta: float) -> void:
	var game=setup.game
	# The boy may claim the ball after the original player was dispatched.
	# Transfer the recovery job as well: a player cannot pick up a held ball.
	var lines=game.stadium.sidelines
	if phase in ["watch","retrieve","pickup","receive"] and game.restart_type=="TAÇ" and is_instance_valid(lines) and lines.is_fetching():
		if game.ball.held_by==lines.fetch_boy or phase in ["watch","retrieve","pickup"]:
			enter("sideline")
	# Let the out-of-play ball finish its flight/roll before sending anyone on
	# a long chase. Re-evaluate at its real position, never at the whistle spot.
	if phase=="watch":
		age+=delta
		for i in setup.targets: setup.move_player(i,game.players[i].position,delta)
		var settled: bool=game.ball.position.y<0.7 and game.ball.linear_velocity.length()<2.0
		var tired: bool=age>2.2 and game.ball.position.y<1.1 and game.ball.linear_velocity.length()<5.5
		if age>0.15 and (settled or tired):
			if sideline_claim():
				enter("sideline")
			else:
				choose_collector()
				set_delivery()
				enter("retrieve")
		return
	var moving_index := worker
	var p=game.players[moving_index]
	var ball=game.ball
	age+=delta
	setup.settle(delta,moving_index)
	var destination: Vector3=p.position
	var rate := 0.9
	if phase=="sideline":
		for i in setup.targets: setup.move_player(i,setup.targets[i],delta)
		if not is_instance_valid(lines) or (not lines.is_fetching() and ball.held_by==null):
			choose_collector()
			set_delivery()
			enter("retrieve")
			return
		if ball.held_by==game.players[setup.taker]:
			worker=setup.taker
			helpers[worker]=true
			set_delivery()
			enter("raise")
			return
		var taker=game.players[setup.taker]
		if is_instance_valid(lines.fetch_boy) and ball.held_by==lines.fetch_boy:
			ball.hold_target=lines.fetch_boy.hand_center()
			if game.flat_distance(taker.position,setup.targets[setup.taker])<0.45 and game.flat_distance(lines.fetch_boy.position,taker.position)<2.8:
				ball.hold(taker)
				worker=setup.taker
				helpers[worker]=true
				set_delivery()
				enter("raise")
		return
	if phase=="retrieve":
		p.set_piece_pose=""
		var gap: float=game.flat_distance(p.position,ball.position)
		rate=1.05 if gap>6.0 else (0.72 if gap>1.6 else 0.34)
		var lead: float=clampf(gap/8,0,0.45)
		destination=ball.position+Vector3(ball.linear_velocity.x,0,ball.linear_velocity.z)*lead
		destination.y=0
		destination.x=clampf(destination.x,-(P.HALF_WIDTH+3),(P.HALF_WIDTH+3))
		destination.z=clampf(destination.z,-55.1,55.1)
		var approach: Vector3=(destination-p.position)*Vector3(1,0,1)
		if approach.length()>0.35: destination-=approach.normalized()*0.16
		# A ball against the inside back/side net must be approached from
		# inside the goal. The stand-off offset must not cross the side net.
		if absf(ball.position.x)<3.66 and absf(ball.position.z)>=50 and absf(ball.position.z)<52.5:
			destination=Vector3(clampf(ball.position.x,-3.1,3.1),0,signf(ball.position.z)*minf(absf(ball.position.z),51.9))
		if ball.position.y<0.9 and ball.linear_velocity.length()<6.0 and gap<1.2 and p.action_timer<=0:
			pickup_point=ball.position*Vector3(1,0,1)
			p.facing=(pickup_point-p.position).normalized()
			enter("pickup")
	elif phase=="pickup":
		p.set_piece_pose="pickup"
		p.handling_blend=smoothstep(0,0.38,age)
		pickup_point=ball.position*Vector3(1,0,1)
		destination=pickup_point-p.facing*0.16
		rate=0.28
		var reach: float=game.flat_distance(p.position,ball.position)
		if reach>2.2 or ball.position.y>1.2:
			enter("retrieve")
		elif age>0.28 and ball.linear_velocity.length()<7.0 and (p.hand_center().distance_to(ball.position)<0.85 or reach<0.75):
			ball.hold(p)
			enter("lift")
		elif age>0.7 and reach<1.05:
			ball.hold(p)
			enter("lift")
	elif phase=="lift":
		p.set_piece_pose="pickup"
		p.handling_blend=1-smoothstep(0,0.5,age)
		if age>0.58:
			enter("relay_prepare" if worker!=setup.taker and not relayed else "carry")
	elif phase=="relay_prepare":
		p.set_piece_pose="carry"
		p.handling_blend=0
		var recipient=game.players[setup.taker]
		receive_point=setup.targets[setup.taker]
		# Step out of a goal before throwing so the physical net cannot trap it.
		if absf(p.position.x)<4.6 and absf(p.position.z)>49.0:
			destination=Vector3(p.position.x,0,signf(p.position.z)*48.6)
		elif game.flat_distance(p.position,receive_point)<2.4:
			var clear: Vector3=(p.position-receive_point)*Vector3(1,0,1)
			if clear.length()<0.01: clear=Vector3.RIGHT
			destination=receive_point+clear.normalized()*2.6
		else:
			var look: Vector3=(recipient.position-p.position)*Vector3(1,0,1)
			if look.length()>0.01: p.facing=look.normalized()
			if game.flat_distance(recipient.position,receive_point)<0.3 and Vector2(recipient.velocity.x,recipient.velocity.z).length()<0.6:
				enter("relay_throw")
	elif phase=="relay_throw":
		p.set_piece_pose="throw"
		p.handling_blend=smoothstep(0,0.45,age)*0.72
		var recipient=game.players[setup.taker]
		var look: Vector3=(recipient.position-p.position)*Vector3(1,0,1)
		if look.length()>0.01: p.facing=look.normalized()
		if age>0.65 and p.hand_center().distance_to(ball.position)<0.2:
			var target: Vector3=recipient.hand_center()
			var distance: float=game.flat_distance(ball.position,target)
			flight_time=clampf(distance/16.0,0.45,3.5)
			var velocity: Vector3=ball.Motion.lob_velocity(ball.position,target,flight_time,game.weather)
			ball.strike(velocity)
			p.wall_hold=0.45
			relayed=true
			worker=setup.taker
			helpers[worker]=true
			set_delivery()
			enter("receive")
	elif phase=="receive":
		p.set_piece_pose="receive"
		p.handling_blend=0
		var look: Vector3=(ball.position-p.position)*Vector3(1,0,1)
		if look.length()>0.01: p.facing=look.normalized()
		destination=receive_point
		# Correct a small miss locally, instead of running back to the collector.
		if age>flight_time*0.65:
			var landing: Vector3=ball.position+ball.linear_velocity*maxf(0,flight_time-age)
			var correction: Vector3=(landing-receive_point)*Vector3(1,0,1)
			destination+=correction.limit_length(2.0)
		if ball.position.y>0.55 and p.hand_center().distance_to(ball.position)<1.15:
			ball.hold(p)
			p.set_piece_pose="carry"
			enter("carry")
		elif age>flight_time+0.35 and game.flat_distance(ball.position,receive_point)<1.8 and ball.position.y<0.95:
			ball.hold(p)
			p.set_piece_pose="carry"
			enter("carry")
		elif age>flight_time+0.6 and ball.position.y<0.75:
			p.set_piece_pose=""
			enter("retrieve")
	elif phase=="carry":
		p.set_piece_pose="carry"
		p.handling_blend=0
		destination=delivery
		rate=0.82
		if game.flat_distance(p.position,delivery)<0.28 and Vector2(p.velocity.x,p.velocity.z).length()<1.1:
			p.facing=setup.direction
			enter("raise" if game.restart_type=="TAÇ" and worker==setup.taker else "place")
	elif phase=="raise":
		p.set_piece_pose="throw"
		p.handling_blend=smoothstep(0,0.6,age)
		p.facing=setup.direction
		destination=delivery
		if ball.held_by==p and age>0.55: enter("arrange")
	elif phase=="place":
		p.set_piece_pose="pickup"
		p.handling_blend=smoothstep(0,0.48,age)
		p.facing=setup.direction
		destination=delivery
		var mark: Vector3=game.restart_point+Vector3(0,0.23,0)
		if age>0.5 and (ball.position.distance_to(mark)<0.28 or age>0.85):
			ball.place(mark)
			enter("stand")
	elif phase=="stand":
		p.set_piece_pose="pickup"
		p.handling_blend=1-smoothstep(0,0.45,age)
		if age>0.5:
			p.set_piece_pose=""
			enter("handoff" if worker!=setup.taker else "arrange")
	elif phase=="handoff":
		# Put down the same physical ball, then walk clear before the lawful
		# taker approaches. Opponents never gain the right to take the restart.
		destination=setup.targets[moving_index]
		if game.flat_distance(p.position,game.restart_point)>1.8:
			p.set_piece_pose="wall" if moving_index in setup.wall else ""
			worker=setup.taker
			set_delivery()
			enter("retrieve" if game.restart_type=="TAÇ" else "arrange")
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
	setup.move_player(moving_index,destination,delta,rate)
	if phase in ["pickup","lift","raise","place","stand","arrange"]:
		var facing: Vector3=setup.direction if phase not in ["pickup","lift"] else (pickup_point-p.position)*Vector3(1,0,1)
		if facing.length()>0.01: p.facing=facing.normalized()
	if ball.held_by==p:
		ball.hold_target=game.restart_point+Vector3(0,0.23,0) if phase=="place" else p.hand_center()

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
		"watch": return "TOPUN DURDUĞU YERE EN YAKIN OYUNCU HAZIRLANIYOR"
		"sideline": return "TOP TOPLAYICI TOPU ALIYOR"
		"retrieve": return "EN YAKIN OYUNCU TOPU ALIYOR"
		"relay_prepare","relay_throw": return "TOP VURUŞU KULLANACAK OYUNCUYA ATILIYOR"
		"receive": return "OYUNCU TOPU KARŞILIYOR"
		"pickup","lift": return "OYUNCU TOPU ALIYOR"
		"carry": return "TOP DURAN TOP NOKTASINA GÖTÜRÜLÜYOR"
		"place","stand": return "TOP YERE YERLEŞTİRİLİYOR"
		"handoff": return "TOP TESLİM EDİLDİ · VURUŞU KULLANACAK OYUNCU GELİYOR"
		"raise": return "TAÇ İÇİN HAZIRLANIYOR"
	return "OYUNCULAR YERLEŞİYOR · DÜDÜĞÜ BEKLE"
