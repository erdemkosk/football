extends SceneTree
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func record_goal() -> void:
	game.replay.reset(); game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	game.frontend.hide(); game.match_menu.hide(); game.ball.freeze=true
	game.ball.pending_reset=false; game.goal_team=0; game.score=[1,0]
	game.weather.select(0,true)
	for i in range(101):
		var progress := minf(1,i/80.0)
		game.ball.position=Vector3(5*sin(progress*TAU),.24+sin(progress*PI)*1.5,-22-progress*29)
		game.players[9].position=Vector3(game.ball.position.x,0,maxf(-47,game.ball.position.z+2))
		game.players[9].run_phase=progress*30; game.players[9].velocity=Vector3(0,0,-5)
		game.players[9].animate(.05)
		game.replay.capture(.05)
	game.state="goal"

func capture(label: String) -> void:
	game.hud.replay_frame.sync(); game.hud.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/replay-comfort-"+label+".png")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.controller.set_process(false); game.hud.replay_frame.set_process(false)
	game.match_menu.config_path="res://tests/replay-comfort-settings.tmp"
	var visual := "--visual" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless"
	if visual:
		game.match_menu.display.set_fullscreen(false)
		game.match_menu.display.select_resolution(Vector2i(1440,900))
	for rate in ([60] if visual else [30,60,120]):
		record_goal()
		var live_ball: Transform3D=game.ball.transform
		check(game.replay.begin() and game.replay.transition_alpha()>.99,"Replay entry masks its timeline/camera change at %d FPS" % rate)
		var previous_eye: Vector3=game.camera.position
		var previous_forward: Vector3=-game.camera.global_basis.z
		var previous_fov: float=game.camera.fov
		var previous_cut := 0; var last_cut := -10.0; var wall := 0.0
		var safe_cuts := true; var gentle := true; var horizon := true; var visible_ball := true; var fixed_side := true; var goal_visible := true
		var cuts: Array[int]=[0]; var captured: Array[int]=[]
		var max_speed := 0.0; var max_turn := 0.0
		var delta: float=1.0/rate
		while game.state=="replay":
			game.replay.update(delta); wall+=delta
			if game.state!="replay": break
			var forward: Vector3=-game.camera.global_basis.z
			if game.replay.cut!=previous_cut:
				safe_cuts=safe_cuts and game.replay.transition_alpha()>.995 and wall-last_cut>=game.replay.CUT_HOLD
				last_cut=wall; cuts.append(game.replay.cut)
			else:
				max_speed=maxf(max_speed,game.camera.position.distance_to(previous_eye)/delta)
				max_turn=maxf(max_turn,rad_to_deg(previous_forward.angle_to(forward))/delta)
				gentle=gentle and game.camera.position.distance_to(previous_eye)<=8*delta+.001 and is_equal_approx(previous_fov,game.camera.fov)
			horizon=horizon and absf(game.camera.global_basis.x.dot(Vector3.UP))<.0001
			fixed_side=fixed_side and signf(game.camera.position.x)==game.replay.camera_side
			var to_ball: Vector3=game.ball.position-game.camera.position
			visible_ball=visible_ball and forward.dot(to_ball.normalized())>.8
			if absf(game.replay.age-game.replay.goal_at)<.18: goal_visible=goal_visible and game.replay.transition_alpha()<.01
			previous_eye=game.camera.position; previous_forward=forward; previous_fov=game.camera.fov; previous_cut=game.replay.cut
			if visual:
				game.hud.replay_frame.sync()
				if wall>.6 and game.replay.transition_alpha()<.01 and game.replay.cut not in captured:
					captured.append(game.replay.cut); await capture("angle-"+str(game.replay.cut))
				await process_frame
		print("CAMERA rate=",rate," cuts=",cuts," max_mps=",max_speed," max_deg_s=",max_turn)
		check(safe_cuts and cuts==[0,1,2],"Three deliberate angles switch under full fade, with a minimum hold")
		check(gentle and max_turn<65,"Tracking has bounded translation, gentle rotation and no visible FOV pumping")
		check(horizon and fixed_side,"The horizon stays level and the camera never jumps across the ball's centre line")
		check(visible_ball,"The ball stays in the camera's forward viewing cone")
		check(goal_visible,"No camera transition covers the ball crossing the goal line")
		check(game.ball.transform==live_ball and game.score==[1,0],"Automatic completion restores the live scene and score exactly")
		check(game.replay.exit_left>0 and game.replay.transition_alpha()>.99,"Return to live play is covered by the exit fade")
		game.replay.update_outro(.3); game.hud.replay_frame.sync()
		check(not game.hud.replay_frame.visible,"Exit overlay clears after the short transition")
	record_goal(); game.replay.begin(); game.replay.update(1.3)
	var age: float=game.replay.age; var phase: float=game.replay.cut_transition
	game.before_pause="replay"; game.state="paused"; game.simulate_match(.2); game.hud.replay_frame.sync()
	check(game.replay.age==age and game.replay.cut_transition==phase and not game.hud.replay_frame.visible,"Pausing freezes replay and its transition without covering the pause UI")
	game.state="replay"; game.replay.finish(); game.replay.reset()
	check(game.replay.exit_left==0 and game.replay.pending_cut==-1,"Reset clears pending cuts and fades before a new match")
	print("REPLAY COMFORT: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
