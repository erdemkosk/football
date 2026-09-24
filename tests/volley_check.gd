extends SceneTree
const DT := 1.0/120.0
var game
var p
var checks := 0
var failures := 0
var contacts := 0
var contact_gap := INF
var support_height := 0.0
var contact_height := 0.0
var contact_kind := ""
var bounced_before_contact := false
var visual := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func key(pressed: bool,code: int=KEY_D) -> void:
	var event := InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()

func button(pressed: bool,code: int=JOY_BUTTON_X) -> void:
	var event := InputEventJoypadButton.new()
	event.device=0; event.button_index=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()

func reset(offset: Vector3=Vector3(-3,1.5,-0.55),velocity: Vector3=Vector3(11,0,0)) -> void:
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
	p.position=Vector3(0,0,-40); p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO
	p.head_joint.rotation=Vector3.ZERO; p.shot_ready_blend=0; p.receive_timer=0
	p.body_language.reset(p); p.body_language.enabled=false
	p.animate(1.0)
	for i in range(5): p.step(DT); await physics_frame
	game.last_direction=Vector3.FORWARD
	game.ball.place(p.position+offset,velocity)
	await physics_frame; await physics_frame
	game.previous_ball=game.ball.position
	contacts=0; contact_gap=INF; contact_kind=""; contact_height=0; bounced_before_contact=false

func tick(count: int=1,boundaries: bool=false) -> void:
	for i in range(count):
		game.kick_lock=maxf(0,game.kick_lock-DT)
		game.update_control(DT)
		game.heading.prepare(DT); game.volleys.prepare(DT)
		p.step(DT)
		var before: Vector3=game.ball.position
		var old_shots: int=game.shots[p.team]
		var bounce_age: float=game.ball.ground_bounce_age
		game.heading.resolve(); game.volleys.resolve()
		if game.shots[p.team]>old_shots:
			contacts+=1
			contact_gap=p.volley_motion.boot(p).distance_to(game.ball.position)
			contact_height=game.ball.position.y
			contact_kind=p.volley_motion.kind
			bounced_before_contact=bounce_age<0.28
			support_height=(p.right_knee if p.volley_motion.foot==0 else p.left_knee).to_global(Vector3(0,-.42,-.05)).y
			check(game.ball.position==before,"Aerial contact changes velocity without moving the ball")
			await capture("half" if contact_kind=="half_volley" else "contact")
		if game.state=="playing": game.update_contacts(DT)
		await physics_frame
		if boundaries and game.state=="playing": game.check_boundaries()
		game.previous_ball=game.ball.position

func capture(label: String) -> void:
	if not visual: return
	var velocity: Vector3=game.ball.linear_velocity
	var spin: Vector3=game.ball.angular_velocity
	game.ball.freeze=true
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=40
	game.camera.position=p.position+Vector3(-4.5,2.8,-5.5)
	game.camera.look_at(p.position+Vector3(0,1.1,0))
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/volley-"+label+".png")
	game.ball.freeze=false; game.ball.linear_velocity=velocity; game.ball.angular_velocity=spin

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-volley-test.cfg"
	p=game.players[9]
	await reset()
	check(game.volleys.can_request(9) and not game.heading.can_request(9),"A waist-height cross offers a volley rather than a header")
	check(game.hud.action_hints()[0][1]=="Yan vole","The shot icon describes the lateral volley technique")
	key(true)
	check(game.volleys.active(9) and game.charging,"Keyboard D buffers a volley before the ball reaches the foot")
	await tick(8); key(false); await tick(85)
	print("CONTACT: gap=",contact_gap," height=",contact_height," support=",support_height," foot=",p.volley_motion.foot," kind=",contact_kind)
	check(contacts==1 and contact_gap<0.40 and contact_height>0.7,"A fast waist-height cross is struck once by the animated boot")
	check(p.volley_motion.foot==0 and absf(support_height-.102)<.035,"The nearer left foot strikes while the other foot remains planted")
	check(p.action_timer==0 and p.pose=="run" and not game.volleys.active(9),"The volley recovers into ordinary movement")
	await reset(Vector3(3,1.5,-0.55),Vector3(-11,0,0))
	key(true); key(false); await tick(90)
	check(contacts==1 and p.volley_motion.foot==1,"A cross from the opposite side uses the right foot")
	await reset(Vector3(-2.6,.60,-.55),Vector3(9,-2.8,0))
	key(true); key(false); await tick(100)
	print("BOUNCE CONTACT: gap=",contact_gap," height=",contact_height," kind=",contact_kind)
	check(contacts==1 and contact_kind=="half_volley" and contact_height<.85 and bounced_before_contact,"A ball bouncing off the real turf produces a low half-volley")
	await reset(Vector3(-3,.95,-.55),Vector3(13,0,0))
	key(true); key(false); await tick(45)
	print("LOW CONTACT: ",contact_kind," ",contact_height," ",contacts," launch=",game.ball.kick_velocity)
	check(contacts==1 and contact_kind=="side_volley" and contact_height<1.05,"A low lateral airborne volley is not mislabeled as a bounced half-volley")
	for frame in range(100):
		await tick(1,true)
		if game.practice_goals>0: break
	check(game.practice_goals==1,"The physical volley can cross the goal line and score normally")
	await reset()
	key(true); key(false)
	game.ball.place(p.position+Vector3(7,1.5,0),Vector3(6,1,0))
	await physics_frame; await physics_frame; await tick(110)
	check(contacts==0 and game.shots[0]==0 and not game.volleys.active(9),"An intercepted cross expires without a remote volley or automatic ground shot")
	await reset(Vector3(0,.23,-.65),Vector3.ZERO)
	key(true); await tick(10); key(false)
	check(game.shots[0]==1 and p.kick_timer>0 and not game.volleys.active(9),"A grounded ball still uses the responsive ordinary shot")
	await reset(Vector3(0,.23,-.65),Vector3.ZERO)
	key(true)
	game.ball.place(p.position+Vector3(-2,1.5,-.55),Vector3(11,0,0))
	await physics_frame; await physics_frame; await tick(1)
	check(game.volleys.active(9),"A shot held before an incoming deflection adapts to the new ball height")
	key(false); await tick(80)
	check(contacts==1,"The adapted shot still waits for an actual boot contact")
	await reset(Vector3(-3,3,-.1),Vector3(11,0,0))
	key(true)
	check(game.heading.active(9) and not game.volleys.active(9),"A high cross still selects the existing header")
	key(false)
	for family in ["Xbox Controller","DualSense"]:
		await reset()
		game.controller.adopt_device(0,family)
		button(true)
		check(game.volleys.active(9) and p.pose!="poke",family+" shot button chooses volley instead of a standing tackle")
		await tick(8); button(false); await tick(80)
		check(contacts==1,family+" can complete a physical volley")
	await reset()
	game.controller.adopt_device(0,"Xbox Controller")
	button(true,JOY_BUTTON_DPAD_RIGHT); button(true)
	var aimed: Vector3=game.shot_direction
	await tick(8); button(false); button(false,JOY_BUTTON_DPAD_RIGHT); await tick(80)
	var intended: Vector3=(game.strike_quality.last.get("intended",Vector3.ZERO)*Vector3(1,0,1)).normalized()
	var launched: bool=game.ball.kick_velocity.is_equal_approx(game.strike_quality.last.get("velocity",Vector3.INF))
	check(contacts==1 and game.ball.kick_velocity.x>12 and intended.dot(aimed)>.9999 and launched,"Independent controller aim redirects the actual volley along the camera-relative aim")
	await reset()
	var weak: Vector3=game.volleys.launch_velocity(9,Vector3.RIGHT,.1)
	var strong: Vector3=game.volleys.launch_velocity(9,Vector3.RIGHT,.9)
	check(strong.x>weak.x+6 and absf(strong.z)<.01,"Shot power and aim affect the volley velocity")
	key(true); key(false); game.state="paused"; game.simulate_match(DT)
	check(not game.volleys.active(9),"Pausing clears a buffered volley")
	await reset()
	key(true); key(false); game.players[6].visible=true; game.team_control.select(6,true)
	check(not game.volleys.active(9),"Selecting another player cancels the old shot intent")
	await reset()
	key(true); key(false); key(true,KEY_S); key(false,KEY_S)
	check(not game.volleys.active(9),"A new pass command cancels the buffered volley")
	await reset()
	game.training=false; game.controlled=6; game.players[6].visible=true; game.players[6].position=Vector3(20,0,0)
	p.ai_think=3; game.update_ai(DT)
	check(not game.volleys.active(9),"An unselected teammate cannot shoot without the user's command")
	game.controlled=9
	game.volleys.arm(9,Vector3.FORWARD); game.reset_practice()
	check(game.volleys.requests.is_empty(),"Practice reset removes pending aerial shots")
	await reset()
	game.training=false; game.rules.candidates.assign([9])
	key(true); key(false); await tick(70)
	check(game.restart_type=="ENDİREKT VURUŞ" and game.shots[0]==0,"Offside is checked before a volley can count as a shot")
	p=game.players[20]
	await reset()
	game.training=false; p.position.z=40; p.facing=Vector3.BACK; p.rig.rotation.y=PI
	game.ball.place(p.position+Vector3(3,1.5,.55),Vector3(-11,0,0))
	await physics_frame; await physics_frame
	p.ai_think=3
	check(game.ai_attack.try_volley(20) and game.volleys.active(20),"An opponent can choose a volley in a real shooting position")
	await tick(80)
	check(contacts==1 and game.shots[1]==1,"Opponent volleys use the same animated boot contact and shot accounting")
	await reset(Vector3(0,6,-.55),Vector3(0,-1,0))
	check(not game.volleys.can_request(20),"An unreachable overhead ball cannot trigger an impossible high kick")
	print("VOLLEY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
