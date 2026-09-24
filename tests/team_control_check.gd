extends SceneTree
const Passing=preload("res://scripts/passing.gd")
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func button(code: int,pressed: bool=true) -> void:
	var event := InputEventJoypadButton.new()
	event.device=0; event.button_index=code; event.pressed=pressed
	game._input(event)
func setup() -> void:
	game.start_match(false,false)
	game.set_physics_process(false); game.set_process(false)
	game.controller.reset_bindings(); game.controller.device=0; game.controller.stick=Vector2.ZERO
	game.pass_assistance=1
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false; game.ball.pending_touch=false
	game.ball.position=Vector3(0,0.23,0); game.ball.linear_velocity=Vector3.ZERO
	game.kick_lock=0; game.last_direction=Vector3.FORWARD
	for p in game.players:
		p.visible=false; p.collision_layer=0; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	for i in [9,6,7,11,14]: game.players[i].visible=true
	game.players[9].position=Vector3(0,0,0.8)
	game.players[6].position=Vector3(1,0,-8)
	game.players[7].position=Vector3(2,0,-29)
	game.players[11].position=Vector3(0,0,-48)
	game.players[14].position=Vector3(12,0,-40)
func contact() -> void:
	for frame in range(20):
		if game.kick_contact.pending.is_empty(): return
		var actor=game.players[game.kick_contact.pending.index]
		game.kick_contact.prepare(1.0/120)
		actor.step(1.0/120)
		game.kick_contact.resolve()
func hold(seconds: float) -> void:
	for n in range(roundi(seconds*120)): game.update_control(1.0/120)
func capture(name: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.camera.position=Vector3(0,39,13); game.camera.look_at(Vector3(0,0,-13)); game.camera.size=42
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/team-control-"+name+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	setup()
	check(not game.player_lock,"New matches start with whole-team control")
	button(JOY_BUTTON_A); var velocity: Vector3=game.kick_contact.pending.velocity
	button(JOY_BUTTON_A,false)
	contact()
	check(game.controlled==9 and game.last_kicker==9 and game.ball.kick_velocity.is_equal_approx(velocity),"A passes physically and leaves the passer selected")
	game.players[9].touch_cooldown=0; game.ball.linear_velocity=game.ball.kick_velocity
	game.team_control.update(0.1)
	check(game.controlled==6,"Outgoing pass selects the teammate who can receive its physical trajectory")
	game.update_ai(0.01)
	check(game.players[6].desired.length()>0.1 or game.players[7].desired.length()>0.1,"A teammate near the aimed landing can still run to contest the pass")
	game.controller.stick=Vector2(1,0); game.update_control(0.01)
	check(game.controlled==6 and game.players[6].desired.length()>0.1,"Stick immediately steers the incoming receiver")
	setup()
	button(JOY_BUTTON_B); button(JOY_BUTTON_B,false)
	game.controller.combos.update(0.24)
	check(game.controlled==9,"Crosses keep the passer selected instead of locking a named recipient")
	setup()
	game.players[6].visible=false; game.players[7].visible=false; game.players[0].visible=true
	game.players[0].position=Vector3(0,0,8); game.last_direction=Vector3.BACK
	game.players[9].facing=Vector3.BACK
	button(JOY_BUTTON_A); button(JOY_BUTTON_A,false)
	contact()
	check(game.controlled==9 and game.ball.kick_velocity.z>0,"A backpass follows the aimed heading without taking control away from the passer")
	game.ball.pending_kick=false; game.kick_lock=0; game.ball.linear_velocity=Vector3.ZERO
	game.ball.position=Vector3(0,0.23,7.2); game.ai_pass_time[0]=0; game.dribbler=-1
	game.team_control.update(0.01)
	check(game.controlled==0,"The keeper becomes controllable once the ball is at his feet")
	game.update_contacts(0.01)
	check(game.dribbler==0,"A controlled goalkeeper can acquire the ball at his feet")
	for frame in range(16):
		game.players[0].step(1.0/120)
		game.update_contacts(1.0/120)
		await physics_frame
	check(game.players[0].dribble_motion.contacts>0,"The goalkeeper controls the grounded ball with an animated foot contact")
	setup()
	game.match_camera.select("pitch")
	game.update_camera(0)
	game.players[9].position=Vector3(0,0,22); game.players[6].position=Vector3(0,0,0.7)
	game.players[6].desired=Vector3.RIGHT; game.players[6].velocity=Vector3.RIGHT*4
	game.players[6].touch_cooldown=0; game.players[6].action_timer=0
	game.controller.stick=Vector2(0,-1)
	game.dribbler=6
	game.team_control.update(0.01); game.update_control(0.01); game.update_ai(0.01)
	check(game.controlled==6,"A moving teammate gaining possession becomes controlled")
	check(game.shots[0]==0 and game.players[6].desired==Vector3.FORWARD,"The new cursor takes the stick before AI can play the ball")
	setup()
	game.players[9].position=Vector3(0,0,25)
	game.players[6].position=Vector3(0,0,4)
	game.players[17].visible=true; game.players[17].position=Vector3(0,0,-0.5); game.dribbler=17; game.last_touch=1
	game.team_control.update(0.01)
	check(game.controlled==6,"Losing possession selects the substantially better placed defender")
	game.players[7].position=Vector3(0.1,0,4)
	for n in range(240): game.team_control.update(1.0/120)
	check(game.controlled==6,"Similar nearby defenders do not cause cursor hopping")
	button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_LEFT_SHOULDER,false)
	var manual: int=game.controlled
	game.players[6].position=Vector3(0,0,0.5); game.dribbler=6
	game.team_control.update(0.3); game.update_contacts(0.01)
	check(game.controlled==6 and manual!=6,"Actual possession overrides the earlier LB choice immediately")
	game.team_control.update(1.2)
	check(game.controlled==6,"Possession control resumes after the manual selection grace period")
	game.players[6].visible=false; game.players[6].dismissed=true; game.dribbler=-1
	game.team_control.update(0.01)
	check(game.controlled!=6 and game.players[game.controlled].visible,"A dismissed player cannot retain control")
	setup()
	game.player_lock=true; button(JOY_BUTTON_A); button(JOY_BUTTON_A,false)
	contact()
	check(game.controlled==9,"Optional single-player mode still preserves the selected player")

	setup()
	game.players[9].position=Vector3(0,0,.9)
	game.players[17].visible=true; game.players[17].position=Vector3(0,0,-0.5); game.dribbler=17
	button(JOY_BUTTON_X)
	check(game.players[9].pose=="poke" and game.duels.attempts.has(9) and not game.rules.tackles.has(9) and not game.charging,"Off-ball Xbox X begins a standing foot challenge, never a slide")
	var tackle_time: float=game.players[9].action_timer
	button(JOY_BUTTON_X)
	check(game.players[9].action_timer==tackle_time,"Holding X cannot repeatedly restart a challenge")
	game.players[9].step(.13)
	game.duels.resolve(0.13)
	check(game.ball.pending_kick and game.ball.kick_velocity.length()<6 and game.last_kicker==9,"A clean standing challenge physically pokes the ball away")
	game.dribbler=9; game.ball.position=game.players[9].position+Vector3(0,0.23,-0.7)
	button(JOY_BUTTON_X,false)
	check(game.shots[0]==0 and not game.charging,"Gaining the ball during an X challenge does not shoot on release")
	setup()
	game.players[9].position=Vector3(0,0,0.9)
	game.players[17].visible=true; game.players[17].position=Vector3(0,0,-0.6); game.dribbler=17
	button(JOY_BUTTON_X); button(JOY_BUTTON_X,false)
	check(game.players[9].pose=="poke" and game.shots[0]==0,"X challenges an opponent's possession even when the ball is within shooting reach")
	setup()
	button(JOY_BUTTON_X); hold(0.2); button(JOY_BUTTON_X,false)
	contact()
	check(game.shots[0]==1 and game.ball.kick_velocity.length()>19,"Xbox X still charges and shoots in possession")
	setup()
	game.players[9].position=Vector3(0,0,12)
	button(JOY_BUTTON_B); button(JOY_BUTTON_B,false)
	check(game.players[9].pose=="slide","Off-ball B keeps its separate slide action")

	setup()
	game.players[7].visible=false; game.players[6].velocity=Vector3(2,0,-4)
	button(JOY_BUTTON_Y)
	check(game.pass_charging and game.pass_through and game.players[9].feint_time==0,"Y prepares a through ball without triggering a feint")
	var short_target: Vector3=game.pass_preview.target
	check(game.pass_preview.receiver==-1 and absf(short_target.x-game.ball.position.x)<.001 and short_target.z<game.players[6].position.z-3,"A short Y pass targets free space along the chosen direction")
	button(JOY_BUTTON_A,false)
	check(game.pass_charging,"Releasing A cannot accidentally release a held Y pass")
	hold(0.65)
	check(game.pass_preview.target.distance_to(game.players[6].position)>short_target.distance_to(game.players[6].position)+4,"Holding Y sends the ball farther along the chosen ray")
	await capture("through")
	var through: Dictionary=game.pass_preview.duplicate(); var origin: Vector3=game.ball.position
	button(JOY_BUTTON_Y,false)
	contact()
	check(game.controlled==9 and game.passes[0]==1 and game.ball.position==origin and game.ball.kick_velocity.is_equal_approx(through.velocity),"Y release uses the visible physical trajectory and leaves the passer selected")
	var original_kick: Vector3=game.ball.kick_velocity
	game.players[6].position.x+=15; game.update_control(0.01)
	check(game.ball.kick_velocity==original_kick,"Changing the runner's direction after the kick cannot steer the ball in flight")
	setup()
	game.half=2; game.last_direction=Vector3.BACK; game.players[6].position=Vector3(1,0,8)
	game.players[9].facing=Vector3.BACK
	game.players[7].visible=false; game.players[14].position.z=40; game.players[11].position.z=48
	button(JOY_BUTTON_Y)
	check(game.pass_preview.receiver==-1 and absf(game.pass_preview.velocity.x)<.001 and game.pass_preview.target.z>game.players[6].position.z,"Through balls preserve the chosen backward heading in the second half")
	setup()
	game.players[6].position=Vector3(0,0,-44); game.players[7].visible=false
	button(JOY_BUTTON_Y)
	check(game.pass_preview.receiver==-1 and absf(game.pass_preview.velocity.x)<0.001,"An offside runner cannot redirect a freely aimed through ball")
	setup()
	game.players[9].position=Vector3(0,0,-14); game.players[6].position=Vector3(0,0,0.8)
	game.players[7].visible=false
	button(JOY_BUTTON_Y); button(JOY_BUTTON_Y,false)
	check(game.requested_receiver==9 and game.request_through and game.passes[0]==0,"Off-ball Y asks a teammate for a through ball without kicking remotely")
	game.update_pass_request(0.3); game.update_ai(0.01)
	contact()
	check(game.passes[0]==1 and game.last_kicker==6 and game.ball.kick_velocity.z<0,"A teammate can answer the through-ball request")

	setup()
	game.players[6].position=Vector3(6,0,-8); game.players[7].visible=false
	var manual_pass := Passing.quick_plan(game.ball.position,Vector3.FORWARD,0,9,game.players,0,-1,100,game.weather)
	var assisted := Passing.quick_plan(game.ball.position,Vector3.FORWARD,0,9,game.players,.65,-1,100,game.weather)
	check(manual_pass.receiver==-1 and manual_pass.velocity.x==0 and assisted.receiver==6,"Manual mode keeps the heading while assisted normal passing selects the teammate in its cone")
	check(assisted.velocity.x>0,"Automatic normal passing aims at the selected teammate")
	game.players[6].position=Vector3(0,0,8); game.begin_pass()
	check(game.ai_receivers[0]<0 and game.kick_contact.pending.velocity.z<0,"Assistance never redirects a forward pass behind the user")

	setup()
	game.match_menu.config_path="res://tests/flow-team-controls.cfg"
	var old := ConfigFile.new()
	var legacy: Dictionary=game.controller.bindings.duplicate(); legacy[JOY_BUTTON_Y]=KEY_Z
	old.set_value("pad","bindings",legacy); old.save(game.match_menu.config_path)
	game.match_menu.load_settings()
	check(game.controller.bindings[JOY_BUTTON_Y]==KEY_Y,"Existing saved Y-feint bindings migrate to through ball")
	game.pass_assistance=2; game.controller.rebind(KEY_D,JOY_BUTTON_Y); game.match_menu.save_settings()
	game.pass_assistance=0; game.controller.reset_bindings(); game.match_menu.load_settings()
	check(game.pass_assistance==2 and game.controller.bindings[JOY_BUTTON_Y]==KEY_D and game.controller.bindings[JOY_BUTTON_X]==KEY_Y,"New assistance settings and custom through-ball bindings survive reload")
	game.match_menu.open_menu(); game.match_menu.show_page(3); await capture("settings"); game.match_menu.close_menu()

	# Exercise actual RigidBody travel and controlled reception, not only launch math.
	setup()
	game.players[7].visible=false; game.ball.freeze=false; game.ball.place(Vector3(0,0.23,0))
	await physics_frame; await physics_frame
	button(JOY_BUTTON_Y); button(JOY_BUTTON_Y,false)
	contact()
	var received := false
	for n in range(300):
		await physics_frame
		game.kick_lock=maxf(0,game.kick_lock-1.0/120)
		for p in game.players: p.touch_cooldown=maxf(0,p.touch_cooldown-1.0/120)
		game.update_pass_request(1.0/120); game.team_control.update(1.0/120); game.update_control(1.0/120); game.update_ai(1.0/120)
		game.players[6].step(1.0/120)
		if game.controlled!=6: game.players[game.controlled].step(1.0/120)
		game.update_contacts(1.0/120)
		if game.dribbler==6: received=true; break
	check(received and game.players[6].position.distance_to(Vector3(1,0,-8))>1,"The intended runner physically reaches and controls a through ball into space")
	setup()
	game.players[7].visible=false; game.players[17].visible=true; game.players[17].position=Vector3(0.5,0,-4)
	game.ball.freeze=false; game.ball.place(Vector3(0,0.23,0))
	await physics_frame; await physics_frame
	button(JOY_BUTTON_A); button(JOY_BUTTON_A,false)
	contact()
	var intercepted := false
	for n in range(180):
		await physics_frame
		game.kick_lock=maxf(0,game.kick_lock-1.0/120)
		for p in game.players: p.touch_cooldown=maxf(0,p.touch_cooldown-1.0/120)
		game.update_contacts(1.0/120)
		# A stretched first touch may spill instead of granting perfect possession.
		if game.last_kicker==17 and game.last_touch==1: intercepted=true; break
	check(intercepted,"A defender physically intercepts an assisted pass through a blocked lane, with control or a first-touch deflection")
	print("TEAM CONTROL CHECK: %d failures" % failures)
	DirAccess.remove_absolute(game.match_menu.config_path)
	game.free(); await process_frame; quit(0 if failures==0 else 1)
