extends RefCounted
const GRAVITY := 9.81
const ROLLING_DECELERATION := 1.15

static func manual_plan(origin: Vector3,direction: Vector3,power: float,team: int,passer: int,players: Array) -> Dictionary:
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
			var distance := Vector2(target.x-origin.x,target.z-origin.z).length()
			var arrival := sqrt(maxf(1,speed*speed-2*ROLLING_DECELERATION*distance))
			var flight := 2*distance/(speed+arrival)
			target=runner.position+Vector3(runner.velocity.x,0,runner.velocity.z).limit_length(8.7)*minf(flight,1.7)*0.82
			target.x=clampf(target.x,-30.5,30.5)
			target.z=clampf(target.z,-48,48)
			target.y=0.23
		var correction := aim.signed_angle_to((target-origin)*Vector3(1,0,1),Vector3.UP)
		aim=aim.rotated(Vector3.UP,clampf(correction,-deg_to_rad(32),deg_to_rad(32)))
		# Preview follows the actual assisted heading, including its turn limit.
		target=origin+aim*Vector2(target.x-origin.x,target.z-origin.z).length()
		target.y=0.23
	var distance := Vector2(target.x-origin.x,target.z-origin.z).length()
	var arrival := sqrt(maxf(1,speed*speed-2*ROLLING_DECELERATION*distance))
	return {"target":target,"velocity":aim*speed+Vector3.UP*0.32,"flight":2*distance/(speed+arrival),"lob":false,"receiver":receiver}

static func plan(origin: Vector3,receiver: Vector3,run: Vector3,lob: bool) -> Dictionary:
	var target := receiver
	var flight := 0.6
	var speed := 12.0
	var motion := Vector3(run.x,0,run.z).limit_length(8.7)
	for i in range(4):
		var distance := Vector2(target.x-origin.x,target.z-origin.z).length()
		if lob:
			flight = clampf(0.9+distance*0.028,1.0,2.15)
		else:
			speed = clampf(9+distance*0.47,10,25)
			var arrival := sqrt(maxf(1,speed*speed-2*ROLLING_DECELERATION*distance))
			flight = 2*distance/maxf(1,speed+arrival)
		target = receiver+motion*minf(flight,2.2)*0.82
		target.x = clampf(target.x,-30.5,30.5)
		target.z = clampf(target.z,-48,48)
		target.y = 0.23
	var offset := Vector3(target.x-origin.x,0,target.z-origin.z)
	var velocity := offset.normalized()*speed+Vector3.UP*0.32
	if lob:
		velocity = offset/maxf(flight,0.1)+Vector3.UP*((0.23-origin.y)/flight+0.5*GRAVITY*flight)
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
