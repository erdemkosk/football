extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func button(code: int,pressed: bool,device: int=0) -> void:
	var event := InputEventJoypadButton.new()
	event.device=device
	event.button_index=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func axis(code: int,value: float,device: int=0) -> void:
	var event := InputEventJoypadMotion.new()
	event.device=device
	event.axis=code
	event.axis_value=value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func stick(x: float,y: float) -> void:
	axis(JOY_AXIS_LEFT_X,x)
	axis(JOY_AXIS_LEFT_Y,y)
func setup() -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	game.match_camera.select("pitch")
	game.update_camera(0)
	game.controller.device=0
	game.controller.stick=Vector2.ZERO
	game.controller.held.clear()
	game.ball.freeze=true
	game.ball.pending_reset=false
	game.ball.pending_kick=false
	game.ball.position=Vector3(0,0.23,0)
	game.kick_lock=0
	game.last_direction=Vector3.FORWARD
	for p in game.players:
		p.visible=false
		p.collision_layer=0
		p.velocity=Vector3.ZERO
		p.desired=Vector3.ZERO
	game.players[9].visible=true
	game.players[9].position=Vector3(0,0,0.8)
	game.players[6].visible=true
	game.players[6].position=Vector3(1,0,-8)
	game.players[7].visible=true
	game.players[7].position=Vector3(2,0,-29)
	game.player_lock=true
func hold(seconds: float) -> void:
	for n in range(int(seconds*120)): game.update_control(1.0/120)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	if "--playstation" in OS.get_cmdline_user_args():
		game.controller.adopt_device(0,"DualSense Wireless Controller",{"vendor_id":0x054c})
		check(game.controller.family=="playstation","DualSense selects PlayStation prompts for the normalized gameplay controls")
	print("CONNECTED CONTROLLERS: ",Input.get_connected_joypads())
	setup()
	stick(0.1,0.1)
	game.update_control(0.1)
	check(game.players[9].desired==Vector3.ZERO,"Small stick drift does not move the player")
	stick(0.5,0)
	game.update_control(0.1)
	check(game.players[9].desired.x>0.35 and game.players[9].desired.x<0.45,"Half stick produces a proportional walking speed")
	check(game.last_direction==Vector3.RIGHT,"Analog strength does not weaken the stored shot heading")
	stick(1,-1)
	game.update_control(0.1)
	check(is_equal_approx(game.players[9].desired.length(),1) and game.players[9].desired.z<0,"Diagonal stick movement is normalized and has no speed boost")
	stick(0,0)
	game.update_control(0.1)
	check(game.players[9].desired==Vector3.ZERO,"Releasing the stick stops movement input")
	axis(JOY_AXIS_RIGHT_X,1)
	check(game.controller.movement()==Vector3.ZERO,"Right-stick aim cannot move the player")
	axis(JOY_AXIS_LEFT_X,1,1)
	button(JOY_BUTTON_X,true,1)
	check(game.controller.movement()==Vector3.ZERO and not game.charging,"A second controller cannot hijack the active player")
	setup()
	stick(0,-0.6)
	button(JOY_BUTTON_A,true)
	hold(0.1)
	check(game.pass_charging and game.passes[0]==0,"Xbox A holds a pass preview before release")
	if "--visual" in OS.get_cmdline_user_args():
		game.hud.queue_redraw()
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://tests/gamepad-pass.png")
	var power: float=game.pass_power
	button(JOY_BUTTON_A,true)
	check(game.pass_power==power,"Duplicate held-button events do not reset power")
	var predicted: Vector3=game.pass_preview.velocity
	button(JOY_BUTTON_A,false)
	check(game.passes[0]==1 and game.ball.kick_velocity.is_equal_approx(predicted),"Xbox A release kicks the previewed pass")
	setup()
	game.players[9].position=Vector3(0,0,-14)
	game.players[6].position=Vector3(0,0,0.8)
	button(JOY_BUTTON_A,true)
	check(game.requested_receiver==9 and not game.pass_charging,"Off-ball A requests a teammate's pass")
	button(JOY_BUTTON_A,false)
	setup()
	button(JOY_BUTTON_B,true)
	game.controller.combos.update(0.24)
	check(game.passes[0]==1 and game.ball.kick_velocity.y>3,"Xbox B delivers an airborne cross")
	button(JOY_BUTTON_B,false)
	setup()
	game.players[9].position=Vector3(0,0,-14)
	game.players[6].position=Vector3(0,0,0.8)
	button(JOY_BUTTON_B,true)
	check(game.players[9].pose=="slide" and game.rules.tackles.has(9) and game.requested_receiver==-1,"Off-ball B slides instead of requesting a lofted pass")
	var slide_time: float=game.players[9].action_timer
	button(JOY_BUTTON_B,true)
	check(game.players[9].action_timer==slide_time,"Holding B does not repeatedly restart a slide")
	button(JOY_BUTTON_B,false)
	setup()
	button(JOY_BUTTON_X,true)
	game.ball.position=Vector3(6,0.23,0)
	stick(1,0)
	button(JOY_BUTTON_B,true)
	check(game.players[9].pose=="slide" and not game.charging and game.players[9].shot_preparation==0,"Sliding after losing possession cancels the charged shot")
	check(game.players[9].facing.x>0.9,"Off-ball B slides in the current left-stick direction")
	button(JOY_BUTTON_B,false)
	button(JOY_BUTTON_X,false)
	check(game.shots[0]==0 and game.passes[0]==0,"Releasing the buttons after a slide does not kick the ball")
	setup()
	stick(0,-0.5)
	game.aiming_mouse=true
	button(JOY_BUTTON_X,true)
	check(game.charging and not game.shot_mouse_aim and game.players[9].pose!="slide","Xbox X charges a shot instead of sliding or using mouse aim")
	stick(0.5,0)
	hold(0.1)
	check(game.shot_offset<0 and absf(game.shot_offset)<deg_to_rad(3),"Partial stick gently adjusts a charged shot")
	stick(1,0)
	hold(2)
	check(game.shot_direction.dot(Vector3.RIGHT)>0.999,"A deliberate stick direction can fully redirect a shot beyond the old fourteen-degree limit")
	var shot: Vector3=game.shot_direction
	button(JOY_BUTTON_X,false)
	check(game.shots[0]==1 and (game.ball.kick_velocity*Vector3(1,0,1)).normalized().is_equal_approx(shot),"Xbox X release shoots in the displayed direction")
	setup()
	button(JOY_BUTTON_Y,true)
	button(JOY_BUTTON_START,true)
	check(game.state=="paused" and not game.charging and not game.pass_charging,"Xbox Start pauses without kicking")
	button(JOY_BUTTON_START,false)
	button(JOY_BUTTON_Y,false)
	setup()
	stick(0,-1)
	button(JOY_BUTTON_RIGHT_SHOULDER,true)
	game.update_control(0.1)
	var runner=game.players[game.controlled]
	var energy: float=runner.energy
	runner.update_stamina(0.5)
	check(runner.sprinting and runner.active_sprint and runner.energy<energy,"Holding RB activates sprint and spends stamina")
	button(JOY_BUTTON_RIGHT_SHOULDER,false)
	game.update_control(0.1)
	runner.update_stamina(0.1)
	check(not runner.sprinting and not runner.active_sprint,"Releasing RB returns to ordinary running")
	runner.energy=0.01
	runner.exhausted=true
	button(JOY_BUTTON_RIGHT_SHOULDER,true)
	game.update_control(0.1)
	runner.update_stamina(0.1)
	check(not runner.active_sprint,"RB cannot bypass exhaustion")
	button(JOY_BUTTON_RIGHT_SHOULDER,false)
	setup()
	var selected: int=game.controlled
	button(JOY_BUTTON_LEFT_SHOULDER,true)
	button(JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.controlled!=selected and game.players[game.controlled].team==0,"LB selects a suitable teammate")
	button(JOY_BUTTON_LEFT_SHOULDER,true)
	selected=game.controlled
	button(JOY_BUTTON_LEFT_SHOULDER,true)
	button(JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.controlled==selected,"Holding or releasing defensive LB does not switch repeatedly")
	setup()
	game.begin_restart("SERBEST VURUŞ",0,Vector3(0,0,-28))
	game.state="set_piece"
	game.set_pieces.direction=(game.match_camera.ground_forward()+game.match_camera.ground_right()*0.4).normalized()
	button(JOY_BUTTON_X,true)
	stick(0,-0.8)
	var before: Vector3=game.set_pieces.direction
	game.set_pieces.update(0.1)
	check(game.set_pieces.button==KEY_D and game.set_pieces.power>0 and game.set_pieces.direction.dot(game.match_camera.ground_forward())>before.dot(game.match_camera.ground_forward()),"X and the left stick charge and aim a free kick toward the camera")
	button(JOY_BUTTON_X,false)
	check(game.set_pieces.runup>=0,"Releasing X commits the free kick")
	for mapping in [[JOY_BUTTON_A,KEY_S],[JOY_BUTTON_B,KEY_A]]:
		setup()
		game.begin_restart("TAÇ",0,Vector3(32,0,0))
		game.state="set_piece"
		button(mapping[0],true)
		check(game.set_pieces.button==mapping[1],"A/B select short/long throw-in actions")
		button(mapping[0],false)
	setup()
	game.half=2
	game.begin_restart("PENALTI",0,Vector3.ZERO)
	game.state="set_piece"
	button(JOY_BUTTON_A,true)
	check(game.set_pieces.button==0,"A cannot accidentally take a penalty as a pass")
	button(JOY_BUTTON_A,false)
	button(JOY_BUTTON_X,true)
	stick(0.5,0)
	game.set_pieces.update(0.1)
	check(game.set_pieces.direction.z>0.9,"Second-half penalty stick aim stays toward the correct goal")
	button(JOY_BUTTON_X,false)
	game.half=1
	setup()
	button(JOY_BUTTON_X,true)
	button(JOY_BUTTON_RIGHT_SHOULDER,true)
	game.controller.connection_changed(0,false)
	check(game.state=="paused" and not game.charging and game.controller.movement()==Vector3.ZERO and not game.controller.held.has(JOY_BUTTON_RIGHT_SHOULDER),"Disconnect pauses and cancels a charged shot without firing")
	game.controller.connection_changed(0,true)
	button(JOY_BUTTON_A,true)
	button(JOY_BUTTON_A,false)
	check(game.state=="playing" and not game.pass_charging and game.shots[0]==0,"Reconnect and A resume safely without passing or shooting")
	game.return_menu()
	button(JOY_BUTTON_A,true)
	button(JOY_BUTTON_A,false)
	check(game.state=="setup" and game.frontend.stage=="teams","A opens quick-match team selection")
	await process_frame
	button(JOY_BUTTON_A,true)
	button(JOY_BUTTON_A,false)
	check(game.frontend.stage=="tactics","A continues to pre-match tactics without skipping team selection")
	await process_frame
	button(JOY_BUTTON_A,true)
	button(JOY_BUTTON_A,false)
	check(game.state=="ceremony","A starts the prepared match from tactics")
	button(JOY_BUTTON_A,true)
	button(JOY_BUTTON_A,false)
	check(game.state=="playing" and not game.pass_charging,"A skips ceremony without leaking its release into a pass")
	game.interval.begin()
	button(JOY_BUTTON_A,true)
	button(JOY_BUTTON_A,false)
	check(game.half==2 and game.restart_type=="SANTRA","A continues from halftime to the second-half kickoff")
	print("GAMEPAD CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
