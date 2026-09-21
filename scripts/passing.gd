extends RefCounted
const GRAVITY := 9.81
const Motion = preload("res://scripts/ball_motion.gd")

static func manual_plan(origin: Vector3,direction: Vector3,power: float,team: int,passer: int,players: Array,surface=null) -> Dictionary:
	var reach := lerpf(8,36,power)
	var speed := lerpf(10.5,23,power)
	var aim := Vector3(direction.x,0,direction.z).normalized()
	var target := origin+aim*reach
	target.y = 0.23
	var receiver := -1
	var best := INF
	for i in range(players.size()):
		var p = players[i]
		if i==passer or not p.visible or p.team!=team: continue
		var offset: Vector3 = p.position-origin
		offset.y = 0
		var distance := offset.length()
		if distance<3 or absf(distance-reach)>5+power*5: continue
		# Eight-way input is forgiving, but never redirects behind the player.
		var angle := absf(aim.signed_angle_to(offset.normalized(),Vector3.UP))
		if angle>deg_to_rad(32): continue
		var value := angle*14+absf(distance-reach)*0.65
		if value<best:
			best=value
			receiver=i
	if receiver>=0:
		var runner = players[receiver]
		target=runner.position
		for i in range(3):
			var flight := flight_time(origin,target,speed,surface)
			target=runner.position+Vector3(runner.velocity.x,0,runner.velocity.z).limit_length(10.4)*minf(flight,1.7)*0.82
			target.x=clampf(target.x,-30.5,30.5)
			target.z=clampf(target.z,-48,48)
			target.y=0.23
		var correction := aim.signed_angle_to((target-origin)*Vector3(1,0,1),Vector3.UP)
		aim=aim.rotated(Vector3.UP,clampf(correction,-deg_to_rad(32),deg_to_rad(32)))
		# Preview follows the actual assisted heading, including its turn limit.
		target=origin+aim*Vector2(target.x-origin.x,target.z-origin.z).length()
		target.y=0.23
	return {"target":target,"velocity":aim*speed+Vector3.UP*0.32,"flight":flight_time(origin,target,speed,surface),"lob":false,"receiver":receiver}

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
		if opponent.team==team or not opponent.visible: continue
		var offset: Vector3 = opponent.position-origin
		offset.y = 0
		var fraction := clampf(offset.dot(segment)/length_squared,0,1)
		var time: float = fraction*pass_plan.flight
		var predicted: Vector3 = opponent.position+Vector3(opponent.velocity.x,0,opponent.velocity.z)*minf(time*0.45,0.6)
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
	if assistance<=0: return free_plan(origin,aim,power,through,surface)
	var reach := lerpf(8,36,power)
	var best := INF
	var receiver := -1
	var chosen: Dictionary={}
	var cone := deg_to_rad(lerpf(28,48,assistance))
	for i in range(players.size()):
		var p=players[i]
		if i==passer or not p.visible or p.dismissed or p.team!=team or p.action_timer>0: continue
		if through and (p.keeper or p.position.z*forward>offside+0.18): continue
		var offset: Vector3=(p.position-origin)*Vector3(1,0,1)
		var distance := offset.length()
		if distance<2.5 or distance>43: continue
		var angle := absf(aim.signed_angle_to(offset,Vector3.UP))
		if angle>cone: continue
		var route := through_to(origin,p,power,forward,surface) if through else plan(origin,p.position,p.velocity,false,surface)
		# Power expresses intent (near/far); assistance supplies the necessary pace.
		var cost := angle*18+absf(distance-reach)*0.55+risk(origin,route,team,players)*1.6
		if through and p.velocity.z*forward>1.0: cost-=1.2
		if cost<best: best=cost; receiver=i; chosen=route
	if receiver<0:
		return free_plan(origin,aim,power,through,surface)
	var distance: float=Vector2(chosen.target.x-origin.x,chosen.target.z-origin.z).length()
	var heading: Vector3=((chosen.target-origin)*Vector3(1,0,1)).normalized()
	var speed := lerpf(10.5,23,power)
	var recommended: float=chosen.velocity.length()
	if through: speed=recommended
	else: speed=lerpf(speed,recommended,assistance)
	# Retain intentional aim. A runner cannot drag an assisted pass backwards.
	var turn := clampf(aim.signed_angle_to(heading,Vector3.UP),-cone,cone)
	heading=aim.rotated(Vector3.UP,turn)
	chosen.target=origin+heading*distance
	chosen.target.y=0.23
	chosen.velocity=heading*speed+Vector3.UP*0.32
	chosen.flight=flight_time(origin,chosen.target,speed,surface)
	chosen.receiver=receiver
	chosen.through=through
	return chosen

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

static func switch_plan(origin: Vector3,direction: Vector3,power: float,team: int,passer: int,players: Array,assistance: float,forward: float,offside: float,surface=null) -> Dictionary:
	var aim := (direction*Vector3(1,0,1)).normalized()
	if aim.length()<0.1: aim=Vector3(0,0,forward)
	var reach := lerpf(18,60,power)
	var receiver := -1
	var best := INF
	if assistance>0:
		for i in range(players.size()):
			var p=players[i]
			if i==passer or p.team!=team or not p.visible or p.dismissed or p.keeper or p.action_timer>0: continue
			var offset: Vector3=(p.position-origin)*Vector3(1,0,1)
			var distance := offset.length()
			if distance<8 or distance>65 or p.position.z*forward>offside+0.18: continue
			var angle := absf(aim.signed_angle_to(offset,Vector3.UP))
			if angle>deg_to_rad(lerpf(28,48,assistance)): continue
			var cost := angle*24+absf(distance-reach)*0.8-absf(p.position.x)*0.04
			if cost<best: best=cost; receiver=i
	var target: Vector3=players[receiver].position if receiver>=0 else origin+aim*reach
	var runner: Vector3=players[receiver].velocity*Vector3(1,0,1) if receiver>=0 else Vector3.ZERO
	var base := target
	var flight := 1.3
	for i in range(4):
		var distance := Vector2(target.x-origin.x,target.z-origin.z).length()
		flight=clampf(1.1+distance*0.031,1.3,3.0)
		target=base+runner.limit_length(10.4)*minf(flight,2.2)*0.72
		target.x=clampf(target.x,-30.5,30.5); target.z=clampf(target.z,-48,48); target.y=0.23
	return {"target":target,"velocity":Motion.lob_velocity(origin,target,flight,surface),"flight":flight,"receiver":receiver,"lob":true,"switch":true}
