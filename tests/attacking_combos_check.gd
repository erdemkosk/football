extends SceneTree
var game
var failures := 0
var count := 0
const DT := 1.0/120
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	count+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func button(code: int,pressed: bool=true,device: int=0) -> void:
	var event := InputEventJoypadButton.new(); event.device=device; event.button_index=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func tap(code: int) -> void: button(code); button(code,false)
func setup(second_half: bool=false) -> void:
	game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	game.controller.device=0; game.controller.stick=Vector2.ZERO; game.controller.held.clear(); game.controller.reset_bindings()
	game.controller.combos.cancel(); game.controller.menus.reset()
	game.half=2 if second_half else 1
	var forward: float=game.attack_sign(0)
	for p in game.players:
		p.visible=false; p.collision_layer=0; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
		p.kick_timer=0; p.touch_cooldown=0; p.shot_preparation=0
	for index in [9,6,7,11,14]: game.players[index].visible=true
	game.players[9].position=Vector3(20,0,15*forward)
	game.players[6].position=Vector3(15,0,23*forward)
	game.players[7].position=Vector3(-10,0,30*forward)
	game.players[11].position=Vector3(0,0,49*forward)
	game.players[14].position=Vector3(10,0,44*forward)
	game.ball.freeze=true; game.ball.position=Vector3(20,0.23,15.75*forward)
	game.ball.pending_reset=false; game.ball.pending_kick=false; game.ball.pending_touch=false; game.ball.linear_velocity=Vector3.ZERO
	game.last_direction=Vector3(0,0,forward); game.kick_lock=0
	game.dribbler=9; game.controlled=9
	game.rules.reset()
func combo() -> void:
	button(JOY_BUTTON_LEFT_SHOULDER); tap(JOY_BUTTON_A); button(JOY_BUTTON_LEFT_SHOULDER,false)
func capture(name: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.camera.size=32; game.camera.position=Vector3(12,45,0); game.camera.look_at(Vector3(12,0,-24))
	game.hud.queue_redraw()
	await process_frame; await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/combo-"+name+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	setup()
	button(JOY_BUTTON_LEFT_SHOULDER)
	check(game.controlled==9,"Holding LB in possession leaves the passer selected for the chord")
	button(JOY_BUTTON_A)
	check(game.passes[0]==1 and game.shots[0]==0 and not game.charging,"LB + A makes a ground one-two instead of a normal pass")
	check(game.last_kicker==9 and game.controlled==6 and game.ball.kick_velocity.y<0.5,"The original passer plays physically and control moves to the wall player")
	check(game.support.runs.has(9) and game.support.runs[9].get("explicit",false),"Only the original passer receives the explicit one-two run")
	var target: Vector3=game.support.runs[9].target
	check(target.x<20 and target.z< -23 and target.distance_to(game.players[9].position)<10,"One-two cuts inside toward a fixed target about ten metres away")
	button(JOY_BUTTON_A); button(JOY_BUTTON_A,false); button(JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.passes[0]==1 and game.controlled==6 and game.shots[0]==0,"Holding or releasing the chord cannot repeat the pass, switch again, or shoot")
	var origin: Vector3=game.players[9].position
	var energy: float=game.players[9].energy
	game.ball.pending_kick=false; game.ball.position=game.players[6].position+Vector3(0,0.23,-0.75)
	game.dribbler=6; game.ai_receivers[0]=-1
	for tick in range(480):
		game.update_ai(DT); game.players[9].step(DT)
		await physics_frame
		if tick==60: await capture("one-two")
		if not game.support.runs.has(9): break
	var travelled: float=game.flat_distance(origin,game.players[9].position)
	check(travelled>7 and travelled<=12.15 and not game.support.runs.has(9),"The real footballer reaches the short run's endpoint and the command ends")
	check(game.players[9].energy<energy,"The attacking run spends normal stamina")
	setup(true); combo()
	check(game.support.runs[9].target.z>23 and game.support.runs[9].target.x<20,"Second-half one-two runs reverse toward the correct goal and still cut inside")
	setup(); combo(); game.last_touch=1; game.support.update(DT)
	check(not game.support.runs.has(9),"Opponent possession cancels the attacking run")
	setup(); combo(); game.dribbler=6
	for i in range(40): game.support.update(0.1)
	check(not game.support.runs.has(9),"An obstructed runner times out rather than running forever")
	setup(); combo(); game.dribbler=6
	for i in range(7):
		game.players[9].position.x+=2 if i%2==0 else -2
		game.support.update(0.05)
	check(not game.support.runs.has(9),"The distance budget counts detours, not just straight-line displacement")
	setup(); combo(); game.begin_restart("TAÇ",0,Vector3(32,0,-15))
	check(game.support.runs.is_empty(),"A whistle cancels the one-two run")
	setup(); combo(); game.team_control.select(9,true); game.controller.stick=Vector2(1,0); game.support.update(DT)
	check(not game.support.runs.has(9),"Taking manual control of the runner cancels the automatic run")
	setup(); button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.controlled!=9,"Tapping LB alone still switches players on release")
	setup(); button(JOY_BUTTON_A); game.update_control(0.1); button(JOY_BUTTON_LEFT_SHOULDER)
	check(game.passes[0]==1 and game.shots[0]==0 and not game.charging,"Near-simultaneous A then LB also resolves as a one-two")
	button(JOY_BUTTON_A,false); button(JOY_BUTTON_LEFT_SHOULDER,false)
	setup(); button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_X); game.update_control(0.08)
	check(game.charging and game.shot_chip and game.passes[0]==0 and game.shots[0]==0,"LB + X prepares a chip shot instead of a one-two")
	var chip_aim: Vector3=game.shot_direction
	game.charge=0.55
	button(JOY_BUTTON_X,false)
	var chip: Vector3=game.ball.kick_velocity
	check(game.shots[0]==1 and chip.y>6.5 and chip.length()<24 and is_zero_approx(game.ball.spin),"Releasing X chips the ball over the keeper line without curl")
	check((chip*Vector3(1,0,1)).normalized().distance_to(chip_aim)<0.0001,"The chip keeps the aimed heading")
	button(JOY_BUTTON_LEFT_SHOULDER,false)
	setup(); game.players[6].visible=false; game.players[7].visible=false; combo()
	check(game.passes[0]==0 and game.shots[0]==0 and game.support.runs.is_empty(),"No teammate means no forced shot, remote pass, or phantom run")
	setup(); game.players[6].position.z=-48; combo()
	check(game.passes[0]==0,"One-two target selection avoids an offside wall player")

	setup(); tap(JOY_BUTTON_B)
	check(game.passes[0]==0 and not game.ball.pending_kick,"The first B starts a short wind-up before committing a cross")
	game.update_control(DT)
	check(game.players[9].shot_preparation>0,"The waiting cross has a visible kicking preparation")
	game.controller.combos.update(0.24)
	check(game.passes[0]==1 and game.ball.kick_velocity.y>3,"One B still releases a normal airborne cross after the double-tap window")
	setup(); tap(JOY_BUTTON_B); game.controller.combos.update(0.1); tap(JOY_BUTTON_B)
	var velocity: Vector3=game.ball.kick_velocity
	check(game.passes[0]==1 and velocity.y<0.2 and velocity.length()>=27,"Two quick B presses produce one hard ground cross")
	check(game.controlled==game.ai_receivers[0] and game.controlled==6 and game.shots[0]==0,"Driven cross transfers receiver control and counts as a pass")
	tap(JOY_BUTTON_B)
	check(game.passes[0]==1 and game.players[6].pose!="slide","A third rapid tap cannot cause a second kick or an accidental receiver slide")
	setup(); button(JOY_BUTTON_B); button(JOY_BUTTON_B)
	game.controller.combos.update(0.24); button(JOY_BUTTON_B,false)
	check(game.passes[0]==1 and game.ball.kick_velocity.y>3,"Holding B is a single lob, not a double tap")
	setup(); tap(JOY_BUTTON_B); game.ball.position+=Vector3(6,0,0); game.controller.combos.update(0.1); tap(JOY_BUTTON_B)
	check(game.passes[0]==0 and game.players[9].pose!="slide","Losing the ball during the wind-up cancels the cross without a remote kick or slide")
	setup(); tap(JOY_BUTTON_B); tap(JOY_BUTTON_START); tap(JOY_BUTTON_A); game.controller.combos.update(0.5)
	check(game.state=="playing" and game.passes[0]==0,"Pause and resume discard a pending cross")
	setup(); tap(JOY_BUTTON_B); game.controller.connection_changed(0,false); game.controller.combos.update(0.5)
	check(game.state=="paused" and game.passes[0]==0,"Disconnect discards the pending cross")
	setup(); tap(JOY_BUTTON_B); button(JOY_BUTTON_X,true,1); game.controller.combos.update(0.24)
	check(game.passes[0]==1 and game.ball.kick_velocity.y>3,"A second controller cannot alter or cancel the first controller's gesture")
	setup(); game.players[9].position+=Vector3(8,0,0); game.dribbler=6
	tap(JOY_BUTTON_B)
	check(game.players[9].pose=="slide","Ordinary off-ball B still slides immediately")
	setup(); game.begin_restart("TAÇ",0,Vector3(32,0,-15)); game.state="set_piece"; button(JOY_BUTTON_B)
	check(game.set_pieces.button==KEY_A and game.controller.combos.cross_player<0,"Set-piece B still uses the existing throw/cross control")
	button(JOY_BUTTON_B,false)

	# Let the actual RigidBody roll: low height, slowing from weather friction,
	# and no homing even if the chosen receiver changes direction afterwards.
	setup(); game.ball.freeze=false; game.ball.place(Vector3(20,0.23,-15.75))
	await physics_frame; await physics_frame
	tap(JOY_BUTTON_B); game.controller.combos.update(0.1); tap(JOY_BUTTON_B)
	var launch: Vector3=game.ball.kick_velocity
	game.players[6].position.x=-22
	var peak := 0.0
	for tick in range(90):
		await physics_frame
		peak=maxf(peak,game.ball.position.y)
		if tick==20: await capture("driven-cross")
	check(peak<0.48 and game.flat_distance(game.ball.position,Vector3(20,0,-15.75))>12,"The real driven cross skims the turf instead of becoming an aerial cross")
	check(game.ball.linear_velocity.length()<launch.length()-1 and game.ball.linear_velocity.length()>15,"Ground friction slows the hard cross naturally")
	check((game.ball.linear_velocity*Vector3(1,0,1)).normalized().dot((launch*Vector3(1,0,1)).normalized())>0.99,"Moving the receiver after launch cannot redirect the physical ball")
	print("ATTACKING COMBOS CHECK: %d checks, %d failures" % [count,failures])
	game.free(); quit(0 if failures==0 else 1)
