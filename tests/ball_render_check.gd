extends SceneTree
class Tracker extends Node:
	var ball
	var before:=Vector3.ZERO
	var after:=Vector3.ZERO
	func _physics_process(_delta: float) -> void:
		before=after; after=ball.position
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func run() -> void:
	var world:=Node3D.new(); world.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF; root.add_child(world)
	var ball=load("res://scripts/ball.gd").new(); world.add_child(ball)
	ball.collision_mask=0; ball.gravity_scale=0
	var tracker:=Tracker.new(); tracker.ball=ball; world.add_child(tracker)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=240
	check(bool(ProjectSettings.get_setting("physics/common/physics_interpolation")),"Render interpolation is enabled without changing physics frequency")
	for airborne in [false,true]:
		ball.place(Vector3(0,5 if airborne else ball.GROUND_HEIGHT,0),Vector3(22,0,-12))
		for i in range(8): await physics_frame
		await process_frame
		var partial:=0; var samples:=0; var error:=0.0; var backwards:=0
		var old: Vector3=ball.get_global_transform_interpolated().origin
		var biggest_shape:=0.0
		for frame in range(90):
			await process_frame
			var rendered: Vector3=ball.get_global_transform_interpolated().origin
			var expected: Vector3=tracker.before.lerp(tracker.after,Engine.get_physics_interpolation_fraction())
			error=maxf(error,rendered.distance_to(expected))
			if rendered.distance_to(tracker.after)>.005 and rendered.distance_to(tracker.before)>.005: partial+=1
			if (rendered-old).dot(Vector3(22,0,-12))<-.001: backwards+=1
			old=rendered; samples+=1
			biggest_shape=maxf(biggest_shape,maxf(ball.skin.basis.x.length(),maxf(ball.skin.basis.y.length(),ball.skin.basis.z.length())))
		print("BALL airborne=",airborne," interpolation_error=",error," partial=",partial," backwards=",backwards," shape=",biggest_shape)
		check(error<.005 and partial>20 and backwards==0,"Fast ball renders between physics samples without backward jitter: airborne="+str(airborne))
		check(biggest_shape<1.11,"Motion keeps a compact, stable ball silhouette")
		var hidden:=true
		for ghost in ball.ghosts: hidden=hidden and not ghost.visible
		check(hidden,"Fast travel never draws displaced duplicate balls")
	ball.place(Vector3(30,2,10)); await physics_frame; await physics_frame; await process_frame
	check(ball.get_global_transform_interpolated().origin.distance_to(ball.position)<.01,"Restart clears the old interpolation path")
	print("BALL RENDER: failures=",failures)
	world.free(); quit(1 if failures else 0)
