extends SceneTree
const Ball=preload("res://scripts/ball.gd")
const Motion=preload("res://scripts/ball_motion.gd")
const Weather=preload("res://scripts/weather.gd")
const Geometry=preload("res://scripts/geometry.gd")
var world: Node3D
var ball
var surface
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func launch(wetness: float,rate: int,bouncing: bool=false) -> Dictionary:
	Engine.physics_ticks_per_second=rate
	surface.wetness=wetness; surface.rain=wetness
	var origin := Vector3(15,3 if bouncing else Ball.GROUND_HEIGHT,-25)
	ball.place(origin)
	for tick in range(3): await physics_frame
	ball.strike(Vector3(0,-7,14) if bouncing else Vector3(0,0,8))
	await physics_frame; await physics_frame
	var previous: Vector3=ball.linear_velocity
	var first_hit: Dictionary={}
	var age := 0.0
	var monotonic := true
	for tick in range(rate*6):
		await physics_frame; age+=1.0/rate
		var velocity: Vector3=ball.linear_velocity
		monotonic=monotonic and Vector2(velocity.x,velocity.z).length()<=Vector2(previous.x,previous.z).length()+.02
		if bouncing and previous.y< -1 and velocity.y>.1 and first_hit.is_empty():
			first_hit={"horizontal":Vector2(velocity.x,velocity.z).length(),"vertical":velocity.y}
		previous=velocity
		if velocity.length()<.015: break
	var distance: float=Vector2(ball.position.x-origin.x,ball.position.z-origin.z).length()
	print("RAIN SAMPLE wet=%.2f rate=%d bounce=%s distance=%.3f time=%.3f first=%s" % [wetness,rate,bouncing,distance,age,first_hit])
	return {"distance":distance,"time":age,"first":first_hit,"monotonic":monotonic}

func run() -> void:
	world=Node3D.new(); root.add_child(world)
	var turf=Geometry.collision_box(world,Vector3(1000,1,1000),Vector3(0,-.5,0),.05)
	turf.physics_material_override.friction=.65
	surface=Weather.new(); ball=Ball.new(); world.add_child(ball); ball.surface=surface
	var dry := await launch(0,120)
	var rain := await launch(.55,120)
	var heavy := await launch(1,120)
	check(rain.distance<dry.distance*.75 and heavy.distance<rain.distance*.8,"Rain and heavy rain progressively shorten a physical rolling ball's range")
	check(heavy.distance<dry.distance*.55 and heavy.time<dry.time*.65,"Heavy rain brings the same kick to rest substantially sooner")
	check(dry.monotonic and rain.monotonic and heavy.monotonic,"All weather levels slow smoothly without reacceleration")
	for rate in [30,60]:
		var sample := await launch(1,rate)
		check(absf(sample.distance-heavy.distance)<.18,"Wet stopping distance is consistent at %d Hz" % rate)
	var dry_bounce := await launch(0,120,true)
	var wet_bounce := await launch(1,120,true)
	check(not dry_bounce.first.is_empty() and not wet_bounce.first.is_empty(),"Both airborne shots make a real turf rebound")
	if not dry_bounce.first.is_empty() and not wet_bounce.first.is_empty():
		check(wet_bounce.first.horizontal<dry_bounce.first.horizontal*.8,"The first wet bounce removes substantially more forward speed")
		check(wet_bounce.first.vertical<dry_bounce.first.vertical*.75,"The first wet rebound is lower as well as slower")
	check(wet_bounce.distance<dry_bounce.distance*.65 and wet_bounce.monotonic,"Successive wet contacts sharply reduce total travel without injecting speed")
	for wet in [0.0,.55,1.0]:
		surface.wetness=wet
		for point in [Vector3(15,0,-25),Vector3(0,0,47)]:
			check(Motion.profile(surface,point).is_equal_approx(Vector2(surface.ball_drag(point),surface.ball_rolling_damping(point))),"Physical and predictive resistance agree at wetness %.2f" % wet)
	surface.wetness=0; surface.rain=0
	check(Motion.profile(surface,Vector3.ZERO)==Vector2(2,.12) and surface.ball_bounce(Vector3.ZERO)==.56,"Dry rolling and rebound coefficients remain unchanged")
	print("RAIN BALL CHECK: %d checks, %d failures" % [checks,failures])
	world.free(); surface.free(); await process_frame; quit(1 if failures else 0)
