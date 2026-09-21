extends RefCounted
## Aim estimate only: the launched rigid body remains responsible for collisions.
const Motion = preload("res://scripts/ball_motion.gd")
const RADIUS := 0.22
var cached: Dictionary = {}
var updated_at := -1000
var last_origin := Vector3.INF
var last_velocity := Vector3.INF
var last_spin := INF
var last_goal := INF
var last_destination := Vector3.INF
var last_landing := false
var last_duration := 3.0

func preview(origin: Vector3,velocity: Vector3,spin: float,goal_z: float,surface,destination: Vector3=Vector3.INF,landing: bool=false,duration: float=3.0) -> Dictionary:
	var now := Time.get_ticks_msec()
	if cached.is_empty() or now-updated_at>=33 or origin.distance_to(last_origin)>0.15 or velocity.distance_to(last_velocity)>0.35 or spin!=last_spin or goal_z!=last_goal or destination.is_finite()!=last_destination.is_finite() or destination.distance_to(last_destination)>0.3 or landing!=last_landing or absf(duration-last_duration)>0.1:
		cached=predict(origin,velocity,spin,goal_z,surface,destination,landing,duration)
		last_origin=origin; last_velocity=velocity; last_spin=spin; last_goal=goal_z; updated_at=now
		last_destination=destination; last_landing=landing; last_duration=duration
	return cached

func pass_preview(origin: Vector3,plan: Dictionary,surface) -> Dictionary:
	return preview(origin,plan.velocity,0,INF,surface,plan.target,plan.get("lob",false),clampf(plan.get("flight",3.0)+0.8,2.0,6.0))

static func predict(origin: Vector3,velocity: Vector3,spin: float,goal_z: float,surface=null,destination: Vector3=Vector3.INF,landing: bool=false,duration: float=3.0) -> Dictionary:
	var points := PackedVector3Array([origin])
	var position := origin
	var dt := 1.0/120
	var drag := Motion.air_drag(surface)
	var crossed := false
	var bounced := false
	var has_destination := destination.is_finite()
	var heading := ((destination-origin)*Vector3(1,0,1)).normalized() if has_destination else Vector3.ZERO
	var reach := Vector2(destination.x-origin.x,destination.z-origin.z).length() if has_destination else INF
	for frame in range(ceili(duration/dt)):
		var previous := position
		var resistance := Motion.profile(surface,position)
		var rolling := position.y<RADIUS+0.08 and absf(velocity.y)<1.2
		if rolling:
			var speed := Vector2(velocity.x,velocity.z).length()
			var horizontal := Vector2(velocity.x,velocity.z).normalized()*Motion.rolling_speed(speed,dt,resistance)
			velocity.x=horizontal.x; velocity.z=horizontal.y
		else:
			velocity=Motion.apply_spin(Motion.air_velocity(velocity,dt,drag),spin,dt)
		spin=Motion.decay_spin(spin,dt,not rolling,resistance.x)
		velocity.y-=Motion.GRAVITY*dt
		position+=velocity*dt
		if position.y<RADIUS:
			if landing and previous.y>RADIUS+0.001 and frame>2:
				position=previous.lerp(position,(RADIUS-previous.y)/(position.y-previous.y))
				bounced=true
				break
			position.y=RADIUS
			var bounce: float=surface.ball_bounce(position) if is_instance_valid(surface) else 0.56
			velocity.y=-velocity.y*clampf(bounce+0.05,0,1) if velocity.y< -1.2 else 0.0
			bounced=true
		if has_destination and not landing and (position-origin).dot(heading)>=reach:
			var step := (position-previous).dot(heading)
			if step>0.0001: position=previous.lerp(position,(reach-(previous-origin).dot(heading))/step)
			break
		if is_finite(goal_z) and (goal_z-previous.z)*(goal_z-position.z)<=0 and absf(position.z-previous.z)>0.0001:
			position=previous.lerp(position,(goal_z-previous.z)/(position.z-previous.z))
			crossed=true
			points.append(position)
			break
		if frame%4==3: points.append(position)
		if position.distance_to(origin)>75 or absf(position.x)>34 or absf(position.z)>52 or velocity.length()<0.5: break
	if points[-1].distance_to(position)>0.001: points.append(position)
	return {"points":points,"target":position,"goal_plane":crossed,"on_target":crossed and absf(position.x)<3.44 and position.y<2.22,"bounced":bounced}
