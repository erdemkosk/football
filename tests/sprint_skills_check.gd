extends "res://tests/advanced_play_check.gd"

func running_move(kind: String,side: float,half: int) -> void:
	await reset()
	game.controller.set_process(false); game.controller.adopt_device(0,"Xbox Controller")
	game.half=half
	var forward := Vector3(0,0,game.attack_sign(0))
	p.position=Vector3.ZERO; p.facing=forward; p.rig.rotation.y=atan2(-forward.x,-forward.z)
	game.ball.place(forward*.7+Vector3.UP*game.ball.GROUND_HEIGHT)
	await physics_frame; await physics_frame
	game.controller.stick=Vector2(0,forward.z)
	game.controller.held[JOY_BUTTON_RIGHT_SHOULDER]=KEY_W
	await tick(90)
	var label := "%s side %.0f half %d" % [kind,side,half]
	check(p.active_sprint and p.velocity.length()>6 and game.dribbler==9,"Enter the move from a real sustained sprint: "+label)
	var started := false
	if kind in ["roll","elastico"]:
		var lateral := forward.cross(Vector3.UP)*side
		game.advanced_controls.skill_gesture(lateral)
		if kind=="elastico":
			await tick(6); game.advanced_controls.skill_gesture(-lateral)
		else: await tick(24)
		started=game.skills.active.get(9,{}).get("kind","")==kind
	else: started=game.skills.start(9,kind,side)
	check(started,"Sprint input starts the requested move: "+label)
	var move: Dictionary=game.skills.active.get(9,{})
	var peak_gap := 0.0
	var peak_height := 0.0
	for frame in range(144):
		await tick()
		peak_gap=maxf(peak_gap,game.flat_distance(p.position,game.ball.position))
		peak_height=maxf(peak_height,game.ball.position.y)
	check(move.get("age",0)>=move.get("duration",INF),"The contact completes without an early out-of-reach cancellation: "+label)
	check(peak_gap<1.3 and game.dribbler==9 and game.flat_distance(p.position,game.ball.position)<1.0,"Holding sprint through the exit retains a reachable live ball: "+label+" gap="+str(peak_gap))
	if kind in ["roll","stop_go"]:
		check(move.get("contacts",0)==(2 if kind=="stop_go" else 1) and move.get("hit_gap",INF)<=.34,"The direction change still requires measured boot contact: "+label)
	if kind=="scoop": check(peak_height>.3 and peak_height<.7,"A sprint scoop stays a low touch with gravity: "+label+" height="+str(peak_height))

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/football-sprint-skills-test.cfg"
	for family in ["Xbox Controller","DualSense"]:
		for side in [-1.0,1.0]:
			await reset(); game.controller.set_process(false); game.controller.adopt_device(0,family)
			game.controller.held[JOY_BUTTON_RIGHT_SHOULDER]=KEY_W
			var lateral: Vector3=p.facing.cross(Vector3.UP)*side
			game.advanced_controls.skill_gesture(lateral); game.advanced_controls.update(.19)
			check(game.skills.active.get(9,{}).get("kind","")=="roll",family+" sprint lateral gesture keeps the ball instead of opening it")
			await reset(); game.controller.adopt_device(0,family)
			game.controller.held[JOY_BUTTON_RIGHT_SHOULDER]=KEY_W
			game.advanced_controls.skill_gesture(lateral); game.advanced_controls.skill_gesture(-lateral)
			check(game.skills.active.get(9,{}).get("kind","")=="elastico",family+" sprint preserves an outside-inside gesture")
	for half in [1,2]:
		for side in [-1.0,1.0]:
			for kind in ["roll","stop_go","roulette","elastico","scoop"]:
				await running_move(kind,side,half)
	print("SPRINT SKILLS CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
