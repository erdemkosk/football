extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.set_process(false); game.set_physics_process(false)
	check(is_equal_approx(game.Player.MOVEMENT_PACE,.68) and is_equal_approx(game.Player.ACCEL_PACE,.78) and is_equal_approx(game.Player.SPRINT_SPEED_SCALE,1.20),"Original running, acceleration and sprint tuning restored")
	for phase in ["playing","restart","set_piece","goal","shootout"]:
		game.state=phase
		check(is_equal_approx(Engine.time_scale,.8),"Shared match clock slows in "+phase)
	for phase in ["paused","menu","setup","career","replay","halftime","finished"]:
		game.state=phase
		check(is_equal_approx(Engine.time_scale,1),"Normal interface/playback clock in "+phase)
	game.menu_match.running=true; game.state="playing"
	check(is_equal_approx(Engine.time_scale,1),"Background menu match does not slow the interface")
	game.menu_match.running=false
	# Measure a real rigid body, not just the assigned clock value.
	var body:=RigidBody3D.new(); body.gravity_scale=0; body.linear_damp=0
	body.collision_layer=0; body.collision_mask=0
	root.add_child(body); body.position=Vector3(0,100,0); body.linear_velocity=Vector3.RIGHT*10
	var distances: Array[float]=[]
	var deltas: Array[float]=[]
	for phase in ["menu","playing"]:
		game.state=phase
		for i in range(3): await physics_frame
		var start: float=body.position.x
		for i in range(30): await physics_frame
		distances.append(body.position.x-start)
		deltas.append(body.get_physics_process_delta_time())
	check(absf(distances[1]/distances[0]-.8)<.025,"Rigid-body travel slows by 20 percent at unchanged velocity")
	check(absf(deltas[1]/deltas[0]-.8)<.001,"Script and animation delta uses the same 20 percent slowdown")
	game.state="paused"; game.state="playing"
	check(is_equal_approx(Engine.time_scale,.8),"Resuming restores match tempo")
	body.free(); game.free()
	check(is_equal_approx(Engine.time_scale,1),"Leaving the game restores the global clock")
	print("MATCH TEMPO CHECK: failures=",failures)
	quit(1 if failures else 0)
