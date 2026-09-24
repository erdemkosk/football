extends SceneTree
const Ball=preload("res://scripts/ball.gd")
const G=preload("res://scripts/geometry.gd")
const Weather=preload("res://scripts/weather.gd")
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

func flight(launch: Vector3,rate: int,wet: bool,curve: float=0) -> void:
	Engine.physics_ticks_per_second=rate
	surface.wetness=1.0 if wet else 0.0; surface.rain=surface.wetness
	ball.place(Vector3(-20,3,30))
	for frame in range(3): await physics_frame
	ball.strike(launch,curve)
	await physics_frame; await physics_frame
	var previous: Vector3=ball.linear_velocity
	var previous_rebound := INF
	var max_gain := 0.0
	var bounces := 0
	var dissipative := true
	var lower_bounces := true
	for frame in range(rate*8):
		await physics_frame
		var current: Vector3=ball.linear_velocity
		var before := Vector2(previous.x,previous.z).length()
		var after := Vector2(current.x,current.z).length()
		max_gain=maxf(max_gain,after-before)
		if previous.y< -1 and current.y>.1:
			bounces+=1
			if before>.5: dissipative=dissipative and after<before-.015
			lower_bounces=lower_bounces and current.y<previous_rebound+.03
			previous_rebound=current.y
		previous=current
	var label := "%s at %d Hz, wet=%s, curve=%.1f" % [launch,rate,wet,curve]
	print("BOUNCE SAMPLE ",label," contacts=",bounces," max_horizontal_gain=",max_gain)
	check(bounces>0 and max_gain<.02,"Every free-flight/contact step preserves decreasing horizontal pace: "+label)
	check(dissipative and lower_bounces,"Successive turf bounces lose forward pace and rebound height: "+label)

func run() -> void:
	world=Node3D.new(); root.add_child(world)
	# Match the real turf material, with no players or perimeter walls to add
	# impulses. Use the real weather calculations without its visual scene.
	var turf=G.collision_box(world,Vector3(1000,1,1000),Vector3(0,-.5,0),.05)
	turf.physics_material_override.friction=.65
	surface=Weather.new()
	ball=Ball.new(); world.add_child(ball); ball.surface=surface
	for rate in [30,60,120]:
		for wet in [false,true]:
			for launch in [Vector3(22,12,0),Vector3(30,5,0),Vector3(8,-14,0),Vector3(0,10,0)]:
				await flight(launch,rate,wet)
			await flight(Vector3(18,9,3),rate,wet,1.4)
	Engine.physics_ticks_per_second=120
	# The fix must not clamp a new, deliberate kick or touch to the previous
	# free ball's speed, even after a long sequence of bounces.
	ball.place(Vector3(15,Ball.GROUND_HEIGHT,0))
	for frame in range(3): await physics_frame
	ball.strike(Vector3(28,4,0))
	await physics_frame; await physics_frame
	check(ball.linear_velocity.x>27 and ball.linear_velocity.y>3.7,"A new kick retains its intended power after earlier bounces")
	ball.touch(Vector3(33,3,0),100)
	await physics_frame; await physics_frame
	check(ball.linear_velocity.x>32,"An explicit player impulse is not mistaken for bounce acceleration")
	# Exercise the penetration recovery path separately from native contacts.
	ball.place(Vector3(15,-.06,0),Vector3(10,-8,0))
	await physics_frame; await physics_frame
	check(ball.position.y>=Ball.RADIUS-.005 and ball.linear_velocity.x<9.9 and ball.linear_velocity.y<8,"Turf penetration recovery also loses pace without a second energy source")
	print("BALL BOUNCE CHECK: %d checks, %d failures" % [checks,failures])
	world.free(); surface.free(); await process_frame; quit(1 if failures else 0)
