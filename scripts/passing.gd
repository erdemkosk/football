extends RefCounted
const GRAVITY := 9.81
const Motion = preload("res://scripts/ball_motion.gd")

static func hint_along(origin: Vector3,aim: Vector3,reach: float,team: int,passer: int,players: Array,cone_deg: float,window: float,through: bool=false,forward: float=-1,offside: float=100) -> int:
	var heading := (aim*Vector3(1,0,1)).normalized()
	if heading.length()<0.1: return -1
	var best := INF
	var chosen := -1
	var cone := deg_to_rad(cone_deg)
	for i in range(players.size()):
		var p=players[i]
		if i==passer or not p.visible or p.dismissed or p.team!=team or p.action_timer>0: continue
		if p.position.z*forward>offside+0.18: continue
		if through and p.keeper: continue
		var offset: Vector3=(p.position-origin)*Vector3(1,0,1)
		var distance := offset.length()
		if distance<2.5 or absf(distance-reach)>window: continue
		var angle := absf(heading.signed_angle_to(offset,Vector3.UP))
		if angle>cone: continue
		var value := angle*16+absf(distance-reach)*0.5
		if value<best:
			best=value
			chosen=i
	return chosen

static func nudge_heading(origin: Vector3,aim: Vector3,reach: float,team: int,passer: int,players: Array,assistance: float,through: bool=false,forward: float=-1,offside: float=100) -> Vector3:
	var heading := (aim*Vector3(1,0,1)).normalized()
	if heading.length()<0.1 or assistance<=0: return heading
	var hint := hint_along(origin,heading,reach,team,passer,players,lerpf(10,16,assistance),lerpf(4,8,assistance),through,forward,offside)
	if hint<0: return heading
	var offset: Vector3=(players[hint].position-origin)*Vector3(1,0,1)
	if offset.length()<0.1: return heading
	var turn := heading.signed_angle_to(offset.normalized(),Vector3.UP)
	return heading.rotated(Vector3.UP,clampf(turn,-deg_to_rad(lerpf(6,12,assistance)),deg_to_rad(lerpf(6,12,assistance))))

static func manual_plan(origin: Vector3,direction: Vector3,power: float,team: int,passer: int,players: Array,surface=null) -> Dictionary:
	var reach := lerpf(8,36,power)
	var speed := lerpf(10.5,23,power)
	var aim := nudge_heading(origin,direction,reach,team,passer,players,0.35)
	var target := origin+aim*reach
	target.y=0.23
	return {"target":target,"velocity":aim*speed+Vector3.UP*0.32,"flight":flight_time(origin,target,speed,surface),"lob":false,"receiver":-1}

static func plan(origin: Vector3,receiver: Vector3,run: Vector3,lob: bool,surface=null) -> Dictionary:
	var target := receiver
	var flight := 0.6
	var speed := 12.0
	var motion := Vector3(run.x,0,run.z).limit_length(10.4)
	var resistance := Motion.along(surface,origin,receiver)
	for i in range(4):
		var distance := Vector2(target.x-origin.x,target.z-origin.z).length()
		if lob:
			flight = clampf(0.9+distance*0.028,1.0,2.15)
		else:
			speed=Motion.passing_speed(clampf(9+distance*0.47,10,25),distance,resistance)
			flight=Motion.travel_time(speed,distance,resistance)
		target = receiver+motion*minf(flight,2.2)*0.82
		target.x = clampf(target.x,-30.5,30.5)
		target.z = clampf(target.z,-48,48)
		target.y = 0.23
	var offset := Vector3(target.x-origin.x,0,target.z-origin.z)
	var velocity := offset.normalized()*speed+Vector3.UP*0.32
	if lob:
		velocity=Motion.lob_velocity(origin,target,flight,surface)
	return {"target":target,"velocity":velocity,"flight":flight,"lob":lob}

static func risk(origin: Vector3,pass_plan: Dictionary,team: int,players: Array) -> float:
	var target: Vector3 = pass_plan.target
	var segment := Vector3(target.x-origin.x,0,target.z-origin.z)
	var length_squared := segment.length_squared()
	if length_squared<0.1: return 1.0
	var result := 0.0
	for opponent in players:
		if opponent.team==team or not opponent.visible or opponent.dismissed: continue
		var offset: Vector3 = opponent.position-origin
		offset.y = 0
		var fraction := clampf(offset.dot(segment)/length_squared,0,1)
		var time: float = fraction*pass_plan.flight
		var predicted: Vector3 = opponent.position+Vector3(opponent.velocity.x,0,opponent.velocity.z)*minf(time*0.45,0.6)
		# A marker behind a departing ball cannot block every escape direction.
		# Keep immediate boot-range pressure, and all defenders ahead of the kick.
		if (predicted-origin).dot(segment.normalized())<-.45 and Vector2(predicted.x-origin.x,predicted.z-origin.z).length()>.7: continue
		fraction = clampf((predicted-origin).dot(segment)/length_squared,0,1)
		time = fraction*pass_plan.flight
		var height: float = maxf(0.23,origin.y+pass_plan.velocity.y*time-0.5*GRAVITY*time*time)
		if height>1.9: continue
		var intercept := origin+segment*fraction
		var gap := Vector2(predicted.x-intercept.x,predicted.z-intercept.z).length()
		var reach := 1.0+minf(1.3,time*0.7)
		result = maxf(result,clampf((reach+0.65-gap)/maxf(reach,0.1),0,1))
	return result

static func assisted_plan(origin: Vector3,direction: Vector3,power: float,team: int,passer: int,players: Array,assistance: float=0.65,through: bool=false,forward: float=-1,offside: float=100,surface=null) -> Dictionary:
	var aim := (direction*Vector3(1,0,1)).normalized()
	if aim.length()<0.1: aim=Vector3(0,0,forward)
	var reach := lerpf(8,36,power)+(5 if through else 0)
	aim=nudge_heading(origin,aim,reach,team,passer,players,assistance,through,forward,offside)
	return free_plan(origin,aim,power,through,surface)

static func free_plan(origin: Vector3,aim: Vector3,power: float,through: bool,surface=null) -> Dictionary:
	var distance := lerpf(8,36,power)+(5 if through else 0)
	var speed := lerpf(13,25,power) if through else lerpf(10.5,23,power)
	var target := origin+aim*distance
	target.y=0.23
	return {"target":target,"velocity":aim*speed+Vector3.UP*0.32,"flight":flight_time(origin,target,speed,surface),"lob":false,"receiver":-1,"through":through}

static func through_to(origin: Vector3,runner,power: float,forward: float,surface=null) -> Dictionary:
	var motion: Vector3=runner.velocity*Vector3(1,0,1)
	var run_direction := motion.normalized() if motion.length()>1.0 else Vector3(0,0,forward)
	var space: float=lerpf(4.5,10.5,power)
	var target: Vector3=runner.position+run_direction*space
	target.x=clampf(target.x,-30,30)
	target.z=clampf(target.z,-47.5,47.5)
	target.y=0.23
	var distance: float=Vector2(target.x-origin.x,target.z-origin.z).length()
	var speed: float=Motion.passing_speed(clampf(10+distance*0.48+power*1.5,12,27),distance,Motion.along(surface,origin,target))
	return {"target":target,"velocity":((target-origin)*Vector3(1,0,1)).normalized()*speed+Vector3.UP*0.32,"flight":flight_time(origin,target,speed,surface),"lob":false,"through":true}

static func flight_time(origin: Vector3,target: Vector3,speed: float,surface=null) -> float:
	return Motion.travel_time(speed,Vector2(target.x-origin.x,target.z-origin.z).length(),Motion.along(surface,origin,target))

static func one_two_plan(origin: Vector3,direction: Vector3,team: int,passer: int,players: Array,forward: float,offside: float,surface=null) -> Dictionary:
	var aim := (direction*Vector3(1,0,1)).normalized()
	var chosen: Dictionary={}
	var best := INF
	for i in range(players.size()):
		var p=players[i]
		if i==passer or not p.visible or p.dismissed or p.keeper or p.team!=team or p.action_timer>0: continue
		var offset: Vector3=(p.position-origin)*Vector3(1,0,1)
		var distance := offset.length()
		if distance<3 or distance>23 or p.position.z*forward>offside+0.18: continue
		var angle := absf(aim.signed_angle_to(offset,Vector3.UP))
		if angle>deg_to_rad(62): continue
		var route := plan(origin,p.position,p.velocity,false,surface)
		var cost := angle*16+distance*0.3+risk(origin,route,team,players)*5
		if cost<best:
			best=cost; chosen=route; chosen.receiver=i
	return chosen

static func driven_cross(origin: Vector3,receiver: Vector3,run: Vector3,surface=null) -> Dictionary:
	var target := receiver
	var speed := 28.0
	var flight := 1.0
	for i in range(4):
		var distance := Vector2(target.x-origin.x,target.z-origin.z).length()
		speed=clampf(26+distance*0.12,27,31)
		flight=flight_time(origin,target,speed,surface)
		target=receiver+(run*Vector3(1,0,1)).limit_length(10.4)*minf(flight,1.8)*0.8
		target.x=clampf(target.x,-30.5,30.5); target.z=clampf(target.z,-48,48); target.y=0.23
	var aim := ((target-origin)*Vector3(1,0,1)).normalized()
	return {"target":target,"velocity":aim*speed+Vector3.UP*0.12,"flight":flight,"lob":false,"driven":true}

static func driven_pass(origin: Vector3,receiver: Vector3,run: Vector3,surface=null) -> Dictionary:
	var target := receiver
	var speed := 18.0
	var flight := .7
	for i in range(4):
		var distance := Vector2(target.x-origin.x,target.z-origin.z).length()
		speed=Motion.passing_speed(clampf(13+distance*.30,17,23),distance,Motion.along(surface,origin,target))
		flight=flight_time(origin,target,speed,surface)
		target=receiver+(run*Vector3(1,0,1)).limit_length(10.4)*minf(flight,2.2)*.82
		target.x=clampf(target.x,-30,30); target.z=clampf(target.z,-48,48); target.y=.23
	return {"target":target,"velocity":((target-origin)*Vector3(1,0,1)).normalized()*speed+Vector3.UP*.12,"flight":flight,"lob":false,"driven":true}

static func switch_plan(origin: Vector3,direction: Vector3,power: float,team: int,passer: int,players: Array,assistance: float,forward: float,offside: float,surface=null) -> Dictionary:
	var aim := (direction*Vector3(1,0,1)).normalized()
	if aim.length()<0.1: aim=Vector3(0,0,forward)
	var reach := lerpf(18,60,power)
	aim=nudge_heading(origin,aim,reach,team,passer,players,assistance,false,forward,offside)
	var target := origin+aim*reach
	target.x=clampf(target.x,-30.5,30.5)
	target.z=clampf(target.z,-48,48)
	target.y=0.23
	var distance := Vector2(target.x-origin.x,target.z-origin.z).length()
	var flight := clampf(1.1+distance*0.031,1.3,3.0)
	return {"target":target,"velocity":Motion.lob_velocity(origin,target,flight,surface),"flight":flight,"receiver":-1,"lob":true,"switch":true}
