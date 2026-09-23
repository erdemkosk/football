extends SceneTree
const P = preload("res://scripts/pitch_dimensions.gd")
const DT := 1.0/120
var game
var checks := 0
var failures := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func key(code: int,pressed: bool=true) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func pad(code: int,pressed: bool) -> void:
	var event := InputEventJoypadButton.new(); event.device=0; event.button_index=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func tap(code: int) -> void: pad(code,true); pad(code,false)
func click(control: Control) -> void:
	var at: Vector2=root.get_final_transform()*control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=at; event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		Input.parse_input_event(event); Input.flush_buffered_events()
func tick(count: int=1) -> void:
	for i in range(count):
		game.simulate_match(DT)
		await physics_frame
func capture(label: String) -> void:
	if not visual: return
	var freeze: bool=game.ball.freeze
	var velocity: Vector3=game.ball.linear_velocity
	game.ball.freeze=true
	game.update_camera(0); game.hud.queue_redraw(); game.training_menu.queue_redraw()
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/training-"+label+".png")
	game.ball.freeze=freeze; game.ball.linear_velocity=velocity
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_physics_process(false); game.set_process(false)
	game.match_menu.config_path="/tmp/sefc-training-check.cfg"
	game.controller.device=0
	key(KEY_T); key(KEY_T,false)
	check(game.training_menu.visible and game.training_menu.selected==0 and game.ball.freeze,"T opens three training choices with free practice selected")
	check(game.training_menu.DESCRIPTIONS[0][1].contains("oto seçim") and game.training_menu.DESCRIPTIONS[0][0].contains("ON BİR"),"Free practice copy describes the full team and automatic selection")
	key(KEY_F1); key(KEY_F1,false)
	check(game.controls_help.visible and game.controls_help.get_index()>game.training_menu.get_index(),"The control guide opens above the training selector")
	key(KEY_ESCAPE); key(KEY_ESCAPE,false)
	check(game.training_menu.visible and game.state=="training_setup" and not game.controls_help.visible,"Closing the guide restores the training selection")
	await capture("selection")
	tap(JOY_BUTTON_B)
	check(not game.training_menu.visible and game.state=="menu" and not game.ball.freeze,"B cancels the selector and restores the main menu")
	key(KEY_T); key(KEY_T,false); key(KEY_ENTER); key(KEY_ENTER,false)
	check(game.training and game.state=="playing" and game.training_drills.mode=="free","Enter starts the unchanged free practice mode")
	check(game.players.filter(func(p): return p.visible and p.team==0).size()==11 and game.players[11].visible and game.controlled==9,"Free practice fields the full team against a goalkeeper")
	check(game.team_control.automatic(),"Free practice uses the same automatic player selection as a match")
	await tick(5)
	key(KEY_T); key(KEY_T,false)
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(game.training_menu.selected==1 and game.training_menu.cards[1].has_focus(),"Controller right selects the cross exercise")
	pad(JOY_BUTTON_A,true); pad(JOY_BUTTON_A,true); pad(JOY_BUTTON_A,false)
	check(game.training_drills.mode=="cross" and game.state=="playing" and not game.pass_charging,"Controller A starts crosses without leaking a pass or duplicate activation")
	check(game.players[8].visible and game.players.filter(func(p): return p.visible).size()==3 and game.controlled==9 and not game.team_control.automatic(),"A teammate joins on the wing while control stays on the finisher")
	await tick(20)
	var pending: Vector3=game.ball.position
	key(KEY_S); key(KEY_S,false)
	check(not game.pass_charging and game.training_drills.age>=1.5,"The pass button asks the exercise partner for a cross")
	await tick(75)
	check(game.training_drills.phase=="live" and game.passes[0]==1 and game.last_kicker==8 and game.players[8].kick_timer>=0,"The teammate performs one real kick to launch the cross")
	check(game.ball.position.distance_to(pending)>2 and game.ball.position.y>1.3 and game.ball.linear_velocity.length()>5,"The cross physically travels through the air")
	await capture("cross")
	var requested := false
	var shots_before: int=game.shots[0]
	for frame in range(190):
		if not requested and game.heading.can_request(9):
			key(KEY_D); requested=true
		if requested and game.charge>.35: key(KEY_D,false)
		await tick()
		if game.shots[0]>shots_before: break
	key(KEY_D,false)
	check(requested and game.shots[0]>shots_before and game.last_kicker==9,"The delivered exercise cross can be headed using the normal shot button")
	var first_side: float=game.training_drills.station.x
	key(KEY_R); key(KEY_R,false); await tick(4)
	check(game.training_drills.attempt==2 and game.training_drills.station.x*first_side<0 and game.heading.requests.is_empty(),"Retry alternates wings and clears the previous aerial action")
	var age: float=game.training_drills.age
	tap(JOY_BUTTON_START); await tick(120)
	check(game.state=="paused" and game.training_drills.age==age,"Pausing freezes the delivery countdown")
	game.hud.sync_navigation(); game.hud.nav_buttons[1].grab_focus(); tap(JOY_BUTTON_A)
	check(game.training_drills.attempt==3 and game.state=="playing","The pause menu offers a controller-accessible new attempt")
	tap(JOY_BUTTON_BACK)
	check(game.training_menu.visible and game.training_menu.selected==1,"View opens training choices during an exercise")
	tap(JOY_BUTTON_DPAD_RIGHT); tap(JOY_BUTTON_A)
	check(game.training_drills.mode=="free_kick" and not game.training_menu.visible,"The controller switches directly to free-kick practice")
	await tick(20)
	check(game.training_drills.placing() and game.state=="restart" and game.players.filter(func(p): return p.visible).is_empty(),"Free-kick practice waits for the user to place only the ball")
	var start_spot: Vector3=game.training_drills.place_point
	game.controller.stick=Vector2(1,0)
	await tick(18)
	game.controller.stick=Vector2.ZERO
	check(game.training_drills.place_point.distance_to(start_spot)>1.0,"The stick moves the chosen free-kick spot")
	var confirm := InputEventKey.new(); confirm.keycode=KEY_S; confirm.pressed=true
	check(game.training_drills.handle(confirm),"A confirms the chosen spot")
	await tick(20)
	check(game.state=="set_piece" and game.set_pieces.taker==9 and game.controlled==9,"Free-kick practice reaches the normal user-controlled set-piece state")
	check(game.set_pieces.wall.size()==4 and game.set_pieces.formation_ready() and game.players.filter(func(p): return p.visible).size()==6,"A legal four-player wall and a goalkeeper are set up without a full match")
	check(game.ball.position.distance_to(game.restart_point+Vector3.UP*.23)<.2 and game.ball.linear_velocity.length()<.2,"The free-kick ball is physically settled at the spot")
	await capture("free-kick")
	var old_point: Vector3=game.restart_point
	key(KEY_R); key(KEY_R,false); await tick(20)
	check(game.training_drills.placing() and game.training_drills.attempt==2 and game.training_drills.place_point.distance_to(old_point)<0.25,"Retry returns to spot selection and keeps the last mark")
	game.training_drills.place_point=Vector3(-5,0,-12)
	game.training_drills.confirm_place(); await tick(20)
	check(game.set_pieces.wall.size()>=4 and game.restart_point.distance_to(Vector3(0,0,game.attack_sign(0)*50))>36,"A distant training free kick still forms a wall")
	pad(JOY_BUTTON_X,true); await tick(38); pad(JOY_BUTTON_X,false); await tick(40)
	check(game.state=="playing" and game.shots[0]==1 and game.last_kicker==9 and game.ball.linear_velocity.length()>8,"Controller X takes a physical free kick through the existing run-up and power system")
	check(game.training_drills.phase=="live","A taken free kick enters the rebound phase")
	var wall_i: int=game.training_drills.wall[0]
	var block: Vector3=game.players[wall_i].position+Vector3(0,0.35,-0.15)
	game.previous_ball=block; game.ball.place(block); game.ball.linear_velocity=Vector3.ZERO
	await tick(90)
	check(game.training_drills.placing() and game.training_drills.attempt==3,"A wall block ends the attempt like an out")
	game.state="playing"; game.training_drills.phase="live"; game.training_drills.age=0.2; game.training_drills.finish_wait=-1
	game.last_kicker=11; game.saves[1]+=1
	game.previous_ball=game.ball.position; game.ball.linear_velocity=Vector3.ZERO
	await tick(90)
	check(game.training_drills.placing() and game.training_drills.attempt==4,"A keeper save ends the attempt like an out")
	game.goal(0); game.skip_to_kickoff(); await tick(60)
	check(game.training_drills.placing() and game.practice_goals==1 and game.training_drills.mode=="free_kick","Skipping a training goal returns to spot selection")
	game.begin_restart("TAÇ",1,Vector3((P.HALF_WIDTH+0),0,-30)); await tick(400)
	check(game.training_drills.placing() and game.training_drills.mode=="free_kick","An out-of-play ball automatically returns to spot selection")
	game.start_match(true,true,false,"cross"); await tick(260)
	game.ball.hold(game.players[11]); game.goalkeeping.holding=11; game.goalkeeping.hold_age=0; await tick(125)
	check(game.training_drills.attempt==2 and game.training_drills.phase=="waiting","A keeper holding the ball automatically triggers the next delivery")
	game.training_menu.open_menu(); var saved_attempt: int=game.training_drills.attempt; var saved_age: float=game.training_drills.age
	await tick(100); tap(JOY_BUTTON_B)
	check(game.training_drills.attempt==saved_attempt and game.training_drills.age==saved_age and game.state=="playing","Cancelling the mode menu resumes the same attempt and countdown")
	game.controller.adopt_device(0,"DualSense Wireless Controller")
	tap(JOY_BUTTON_BACK); tap(JOY_BUTTON_DPAD_LEFT)
	check(game.training_menu.selected==0 and game.controller.family=="playstation","PlayStation navigation selects free practice with the same menu controls")
	await capture("selection-playstation")
	tap(JOY_BUTTON_A)
	check(game.training_drills.mode=="free" and game.state=="playing","PlayStation confirm starts the selected mode")
	key(KEY_T); key(KEY_T,false)
	click(game.training_menu.cards[2]); click(game.training_menu.start_button); await tick(60)
	check(game.training_drills.mode=="free_kick" and game.training_drills.placing(),"Mouse selection and the start button open the selected exercise")
	key(KEY_T); key(KEY_T,false); game.training_menu.back_button.grab_focus(); key(KEY_ENTER); key(KEY_ENTER,false)
	check(not game.training_menu.visible and game.training_drills.placing() and not game.ball.freeze,"Enter on Back returns to the current free kick without restarting it")
	game.return_menu()
	check(not game.training and game.training_drills.mode=="free" and not game.training_menu.visible and game.players.filter(func(p): return p.visible).size()==22,"Returning to the main menu cleans up all practice fixtures")
	game.start_match(false,false)
	check(not game.autonomous_kicks(0) and not game.training_drills.manages(8),"The exercise partner's automation never changes teammate authority in a match")
	print("TRAINING MODES CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
