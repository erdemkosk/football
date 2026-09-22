extends SceneTree
var game
var failures := 0
var assertions := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	assertions+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func button(code: int,down: bool,device: int=0) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index=code; e.pressed=down; e.device=device
	Input.parse_input_event(e); Input.flush_buffered_events()
func axis(code: int,value: float,device: int=0) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis=code; e.axis_value=value; e.device=device
	Input.parse_input_event(e); Input.flush_buffered_events()
func stick(x: float,y: float,right: bool=false) -> void:
	axis(JOY_AXIS_RIGHT_X if right else JOY_AXIS_LEFT_X,x)
	axis(JOY_AXIS_RIGHT_Y if right else JOY_AXIS_LEFT_Y,y)
func hold(seconds: float,rate: int=120) -> void:
	for frame in range(roundi(seconds*rate)): game.update_control(1.0/rate)
func setup() -> void:
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false)
	game.match_camera.select("pitch")
	game.update_camera(0)
	game.controller.device=0; game.controller.stick=Vector2.ZERO
	game.controller.held.clear(); game.controller.menus.reset()
	game.controller.reset_bindings()
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false
	game.ball.position=Vector3(0,0.23,-0.8)
	game.ball.linear_velocity=Vector3.ZERO
	game.kick_lock=0
	game.last_direction=Vector3.FORWARD
	game.players[9].position=Vector3.ZERO
	game.players[9].velocity=Vector3.ZERO
	game.aiming_mouse=false
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.update_camera(1); game.hud.queue_redraw()
	for frame in range(3): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/shot-direction-"+label+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/football-shot-direction-settings.cfg"
	setup()
	stick(-1,0); hold(0.1)
	button(JOY_BUTTON_X,true)
	check(game.charging and game.shot_direction.x< -0.99,"A normal shot starts from the leftward running direction")
	button(JOY_BUTTON_DPAD_RIGHT,true)
	var before: Vector3=game.shot_direction
	hold(1.0/120)
	check(before.angle_to(game.shot_direction)<=game.SHOT_PAD_RATE/120+0.001,"D-pad changes aim smoothly, without an instant reversal")
	hold(1.7)
	check(game.shot_direction.x>0.999 and game.players[9].desired.x< -0.5,"D-pad aims right while the left stick continues running left")
	check(game.players[9].facing.x>0.99,"The shooting stance turns toward the actual shot direction")
	button(JOY_BUTTON_DPAD_RIGHT,false)
	stick(0,0)
	hold(0.3)
	check(game.shot_direction.x>0.999,"Releasing D-pad holds aim instead of snapping back to the running direction")
	await capture("opposite")
	var shown: Vector3=game.shot_direction
	button(JOY_BUTTON_X,false)
	check(game.shots[0]==1 and (game.ball.kick_velocity*Vector3(1,0,1)).normalized().is_equal_approx(shown),"X release fires in the displayed direction")
	# Verify the rigid ball really travels right, not only its preview vector.
	game.ball.freeze=false
	for frame in range(24): await physics_frame
	check(game.ball.position.x>2 and game.ball.linear_velocity.x>5,"The physical ball actually travels right after the leftward-running shot")
	setup()
	var runner=game.players[9]
	runner.facing=Vector3.LEFT; runner.velocity=Vector3.LEFT*4
	game.ball.position=Vector3(-0.82,0.23,0)
	game.ball.freeze=false; game.ball.linear_velocity=Vector3.LEFT*4
	game.dribbler=9; game.dribble_direction=Vector3.LEFT
	game.last_touch=0; game.last_kicker=9
	stick(-1,0); button(JOY_BUTTON_DPAD_RIGHT,true); button(JOY_BUTTON_X,true)
	for frame in range(80):
		game.update_control(1.0/120)
		runner.step(1.0/120)
		game.update_contacts(1.0/120)
		await physics_frame
	check(runner.position.x< -1 and runner.velocity.x< -2 and game.shot_direction.x>0.99 and game.can_touch(9,2),"A physically running player retains the ball while winding up in the opposite direction")
	await capture("running")
	var ball_before: Vector3=game.ball.position
	button(JOY_BUTTON_X,false)
	for frame in range(24): await physics_frame
	check(game.shots[0]==1 and game.ball.position.x>ball_before.x+2,"A live dribble-to-shot sequence releases the ball to the opposite side")
	setup(); stick(-1,0); button(JOY_BUTTON_X,true)
	stick(1,0,true); hold(1.7)
	check(game.shot_direction.x>0.999 and game.players[9].desired.x<0,"Right stick also aims independently from movement")
	stick(0,0,true); hold(0.2)
	check(game.shot_direction.x>0.999,"Centering the right stick retains the chosen shot direction")
	setup(); stick(-1,0); button(JOY_BUTTON_X,true)
	stick(1,0); hold(2.5)
	check(game.shot_direction.x>0.999,"Left-stick-only players can reverse shot direction beyond the old 14-degree limit")
	stick(0,0); hold(0.2)
	check(game.shot_direction.x>0.999,"Centering the left stick also preserves aim")
	setup(); button(JOY_BUTTON_X,true); stick(0.5,0)
	before=game.shot_direction; hold(0.1)
	check(before.angle_to(game.shot_direction)>deg_to_rad(.5) and before.angle_to(game.shot_direction)<deg_to_rad(1.2),"A light left-stick input trims aim by less than 1.2 degrees in 100 ms")
	setup(); button(JOY_BUTTON_X,true); stick(0.1,0.1,true); hold(0.5)
	check(game.shot_direction==Vector3.FORWARD and not game.shot_separate_aim,"Right-stick drift does not steal or move aim")
	for target in [Vector3.FORWARD,Vector3.BACK,Vector3(-1,0,-1).normalized(),Vector3(1,0,1).normalized()]:
		setup(); button(JOY_BUTTON_X,true)
		if target.x!=0: button(JOY_BUTTON_DPAD_LEFT if target.x<0 else JOY_BUTTON_DPAD_RIGHT,true)
		button(JOY_BUTTON_DPAD_UP if target.z<0 else JOY_BUTTON_DPAD_DOWN,true)
		hold(1.7)
		check(game.shot_direction.dot(target)>0.999,"D-pad supports full vertical/diagonal aim: "+str(target))
	setup(); button(JOY_BUTTON_X,true)
	button(JOY_BUTTON_DPAD_LEFT,true); button(JOY_BUTTON_DPAD_RIGHT,true)
	before=game.shot_direction; hold(0.3)
	check(game.shot_direction.is_equal_approx(before),"Opposing D-pad directions cancel rather than selecting an arbitrary side")
	setup(); stick(-1,0); button(JOY_BUTTON_DPAD_RIGHT,true); button(JOY_BUTTON_X,true)
	check(game.shot_direction.x>0.999,"A separate aim held before X is respected from the start")
	setup(); button(JOY_BUTTON_X,true); stick(1,0,true); hold(0.2,30)
	var at_30: Vector3=game.shot_direction
	setup(); button(JOY_BUTTON_X,true); stick(1,0,true); hold(0.2,120)
	check(game.shot_direction.distance_to(at_30)<0.00001,"Aim response is consistent at 30 and 120 updates per second")
	setup(); game.half=2; button(JOY_BUTTON_X,true); button(JOY_BUTTON_DPAD_RIGHT,true); hold(1.7)
	check(game.shot_direction.x>0.999,"Right remains screen-right after the teams change ends")
	setup(); button(JOY_BUTTON_X,true); axis(JOY_AXIS_RIGHT_X,1,1); button(JOY_BUTTON_DPAD_RIGHT,true,1)
	hold(0.3)
	check(game.shot_direction==Vector3.FORWARD,"A second controller cannot change the shooter's aim")
	button(JOY_BUTTON_DPAD_RIGHT,true); stick(1,0,true)
	button(JOY_BUTTON_START,true); button(JOY_BUTTON_START,false)
	check(game.state=="paused" and not game.charging and not game.controller.has_separate_aim(),"Pausing cancels the shot and clears independent aim")
	button(JOY_BUTTON_DPAD_RIGHT,false); button(JOY_BUTTON_X,false)
	button(JOY_BUTTON_B,true); button(JOY_BUTTON_B,false)
	check(game.state=="playing" and not game.charging and game.shots[0]==0,"Menu releases cannot fire the cancelled shot")
	setup(); button(JOY_BUTTON_X,true); button(JOY_BUTTON_DPAD_RIGHT,true); stick(1,0,true)
	game.controller.connection_changed(0,false)
	check(game.state=="paused" and not game.charging and not game.controller.has_separate_aim(),"Disconnect clears both D-pad and right-stick shot aim")
	setup(); game.training=false
	game.begin_restart("SERBEST VURUŞ",0,Vector3(-8,0,-25))
	game.state="set_piece"; game.set_pieces.ready_age=0
	before=game.set_pieces.direction
	button(JOY_BUTTON_DPAD_RIGHT,true); game.set_pieces.update(0.1)
	check(game.set_pieces.direction!=before,"D-pad also makes directional corrections at a free kick")
	if "--visual" in OS.get_cmdline_user_args():
		game.controls_help.open_panel()
		game.controls_help.select_page(0)
		game.controls_help.select_device(true)
		await capture("guide")
	print("SHOT DIRECTION PAD CHECK: %d checks, %d failures" % [assertions,failures])
	game.free(); quit(0 if failures==0 else 1)
