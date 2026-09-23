extends SceneTree
const DT := 1.0/120.0
var game
var p
var checks := 0
var failures := 0
var peak := 0.0
var contacts := 0
var contact_gap := INF
var visual := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=KEY_D; event.physical_keycode=KEY_D; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()

func button(pressed: bool,code: int=JOY_BUTTON_X) -> void:
	var event := InputEventJoypadButton.new()
	event.device=0; event.button_index=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()

func reset(height: float=2.85) -> void:
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false); game.hud.hide()
	game.controller.held.clear(); game.controller.stick=Vector2.ZERO; game.controller.clear_shot_aim()
	game.controller.using_gamepad=false
	game.match_camera.select("pitch"); game.update_camera(0)
	game.charging=false; game.charge=0; game.kick_lock=0; game.boundary_grace=0
	game.dribbler=-1; game.carrier=-1; game.last_kicker=-1
	game.ai_receivers=[-1,-1]; game.ai_pass_time=[0.0,0.0]
	for q in game.players:
		q.visible=q==p; q.collision_layer=2 if q==p else 0; q.collision_mask=1
		q.desired=Vector3.ZERO; q.velocity=Vector3.ZERO
	p.position=Vector3(0,0,-42); p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO
	p.head_joint.rotation=Vector3.ZERO; p.shot_ready_blend=0; p.receive_timer=0
	p.body_language.reset(p); p.body_language.enabled=false
	p.animate(1.0)
	for i in range(5): p.step(DT); await physics_frame
	game.ball.place(p.position+Vector3(-4,height,-0.1),Vector3(11,0,0))
	await physics_frame; await physics_frame
	game.previous_ball=game.ball.position
	peak=0; contacts=0; contact_gap=INF

func tick(count: int=1,boundaries: bool=false) -> void:
	for i in range(count):
		game.kick_lock=maxf(0,game.kick_lock-DT)
		game.update_control(DT)
		game.kick_contact.prepare(DT)
		game.heading.prepare(DT)
		p.step(DT)
		if not game.kick_contact.pending.is_empty() and game.kick_contact.pending.index!=9:
			game.players[game.kick_contact.pending.index].step(DT)
		game.kick_contact.resolve()
		peak=maxf(peak,p.position.y)
		var before: Vector3=game.ball.position
		var old_shots: int=game.shots[0]
		game.heading.resolve()
		if game.shots[0]>old_shots:
			contacts+=1
			contact_gap=game.heading.head_point(p).distance_to(game.ball.position)
			check(game.ball.position==before,"Heading changes velocity without teleporting the ball")
		if game.state=="playing": game.update_contacts(DT)
		await physics_frame
		if boundaries and game.state=="playing": game.check_boundaries()
		game.previous_ball=game.ball.position

func capture(label: String) -> void:
	if not visual: return
	# Rendering may take several physics ticks. Keep ball and manually stepped
	# player on the same simulation frame while saving the close-up.
	var frozen: bool=game.ball.freeze
	var velocity: Vector3=game.ball.linear_velocity
	var spin: Vector3=game.ball.angular_velocity
	game.ball.freeze=true
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=40
	game.camera.position=p.position+Vector3(4.5,2.8,-5.5)
	game.camera.look_at(p.position+Vector3(0,1.3,0))
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/header-"+label+".png")
	game.ball.freeze=frozen
	game.ball.linear_velocity=velocity; game.ball.angular_velocity=spin

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-heading-test.cfg"
	p=game.players[9]
	await reset()
	check(game.heading.can_request(9) and not game.can_touch(9,1.8),"An approaching cross is eligible before ordinary foot reach")
	check(game.hud.action_hints()[0][1]=="Kafa","The contextual shot prompt identifies a header")
	key(true)
	check(game.charging and game.heading.active(9),"Keyboard D queues a header instead of ignoring the aerial ball")
	await tick(14)
	check(p.pose=="header" and p.position.y>0.03 and p.kick_timer==0,"The player physically rises with no foot-kicking animation")
	await capture("rise")
	key(false)
	check(game.heading.active(9) and not game.ball.pending_kick,"Release before arrival keeps a short intent without kicking remotely")
	for i in range(65):
		await tick()
		if contacts>0: break
	print("HEADER CONTACT gap=",contact_gap," peak=",peak," velocity=",game.ball.kick_velocity)
	check(contacts==1 and contact_gap<0.54,"The cross is headed only on actual head contact")
	check(game.ball.kick_velocity.z< -9 and game.last_kicker==9 and game.last_touch==0,"A header redirects the real ball toward the aimed goal and records its scorer")
	check(game.feedback.last_kind=="header" and game.reactions.shooter==9,"Header contact triggers shot feedback and the match reaction system")
	await tick(8)
	await capture("contact")
	await tick(130,true)
	check(game.practice_goals==1,"The physical headed ball crosses the goal line and scores")
	check(game.shots[0]==1 and not game.heading.active(9),"A held/released command creates exactly one shot")
	check(p.position.y<0.06 and p.action_timer==0,"The player lands and returns to normal movement")
	await reset()
	var winger=game.players[6]
	winger.visible=true; winger.position=Vector3(-25,0,-42.1)
	game.controlled=6; game.last_direction=Vector3.RIGHT; game.player_lock=true
	game.ball.place(winger.position+Vector3(0.6,0.23,0))
	await physics_frame; await physics_frame
	game.controller.adopt_device(0,"Xbox Controller")
	button(true,JOY_BUTTON_B); game.controller.combos.update(.57); button(false,JOY_BUTTON_B)
	game.controller.combos.update(0.24)
	# Crosses now leave the foot after the short physical contact approach.
	await tick(12)
	check(game.passes[0]==1 and game.ball.kick_velocity.y>3,"Xbox B produces the game's normal cross trajectory")
	game.team_control.select(9,true); game.last_direction=Vector3.FORWARD
	var requested := false
	var held := 0
	for frame in range(330):
		if not requested and game.heading.can_request(9):
			button(true); requested=true
		if requested:
			held+=1
			if held==18: button(false)
		await tick(1,true)
		if game.practice_goals>0: break
	check(requested and contacts==1 and game.practice_goals==1,"A real B cross, receiver selection and X header can produce a goal")
	for family in ["xbox","playstation"]:
		await reset(3.30)
		game.controller.adopt_device(0,"DualSense" if family=="playstation" else "Xbox Controller")
		button(true)
		check(game.heading.active(9) and p.pose!="poke","The "+family+" shot button prioritizes heading over a standing tackle")
		await tick(12); button(false)
		await tick(60)
		check(contacts==1 and peak>0.35,"The "+family+" shot button can finish a higher cross with a jumping header")
	await reset()
	game.controller.adopt_device(0,"Xbox Controller")
	button(true,JOY_BUTTON_DPAD_RIGHT); button(true)
	await tick(12); button(false); button(false,JOY_BUTTON_DPAD_RIGHT)
	await tick(55)
	check(contacts==1 and game.ball.kick_velocity.x>9 and absf(game.ball.kick_velocity.z)<0.05,"Independent D-pad aim redirects the actual header, not just its preview")
	await reset()
	game.ball.place(game.heading.head_point(p)+Vector3(0,0,-0.36),Vector3(0,0,3))
	await physics_frame; await physics_frame
	key(true); key(false); await tick(10)
	var sole: float=minf(p.left_knee.to_global(Vector3(0,-0.42,-0.05)).y,p.right_knee.to_global(Vector3(0,-0.42,-0.05)).y)
	check(contacts==1 and p.position.y<0.05 and absf(sole-p.boot_ground_height())<0.03,"A head-height ball can be headed while the support foot stays on the turf")
	await reset()
	key(true); await tick(6); key(false)
	game.ball.place(Vector3(8,3,-42),Vector3(5,0,0))
	await physics_frame; await physics_frame
	await tick(120)
	check(game.shots[0]==0 and not game.heading.active(9) and not game.charging,"A mistimed/intercepted cross expires without a remote header or automatic ground shot")
	await reset()
	game.ball.place(p.position+Vector3(0,7,-0.3),Vector3(0,-1,0))
	await physics_frame; await physics_frame
	check(not game.heading.can_request(9),"An unreachable overhead ball cannot trigger an impossible jump")
	await reset()
	game.ball.place(p.position+Vector3(0,0.23,-0.65))
	await physics_frame; await physics_frame
	key(true); await tick(10); key(false)
	check(game.shots[0]==1 and p.kick_timer>0 and not game.heading.active(9),"The same key still produces the ordinary foot shot on the ground")
	await reset()
	game.training=false; game.rules.candidates.assign([9])
	key(true); await tick(10); key(false); await tick(55)
	check(game.restart_type=="ENDİREKT VURUŞ" and game.shots[0]==0,"Offside is enforced before a headed contact can become a shot")
	await reset()
	key(true); key(false)
	game.state="paused"; game.simulate_match(DT)
	check(not game.heading.active(9),"Pausing discards the pending header")
	await reset()
	key(true); key(false)
	game.players[6].visible=true; game.team_control.select(6,true)
	check(not game.heading.active(9),"Changing player cancels the previous player's pending header")
	await reset()
	game.training=false; game.controlled=6; game.players[6].visible=true; game.players[6].position=Vector3(20,0,0)
	p.ai_think=3; game.update_ai(DT)
	check(not game.heading.active(9),"An unselected teammate never heads without the user's command")
	game.controlled=9
	var weak: Vector3=game.heading.launch_velocity(9,Vector3.RIGHT,0.1,1)
	var strong: Vector3=game.heading.launch_velocity(9,Vector3.RIGHT,0.9,1)
	check(strong.x>weak.x+4 and absf(strong.z)<0.01,"Header power and an independent aiming direction affect the outgoing ball")
	game.heading.arm(9,Vector3.FORWARD); game.reset_practice()
	check(game.heading.requests.is_empty(),"A new practice clears all queued aerial actions")
	if visual:
		game.hud.show(); game.controls_help.open_panel(); game.controls_help.select_page(0); game.controls_help.select_device(true)
		await process_frame; RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://tests/header-guide.png")
	print("HEADING CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
