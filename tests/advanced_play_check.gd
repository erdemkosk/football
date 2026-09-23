extends SceneTree
const DT := 1.0/120.0
var game
var p
var checks := 0
var failures := 0
var visual := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func key(code: int,pressed: bool=true,ctrl: bool=false,shift: bool=false,alt: bool=false) -> void:
	var e := InputEventKey.new()
	e.keycode=code; e.physical_keycode=code; e.pressed=pressed
	e.ctrl_pressed=ctrl; e.shift_pressed=shift; e.alt_pressed=alt
	Input.parse_input_event(e); Input.flush_buffered_events()

func button(code: int,pressed: bool=true) -> void:
	var e := InputEventJoypadButton.new()
	e.device=0; e.button_index=code; e.pressed=pressed
	Input.parse_input_event(e); Input.flush_buffered_events()

func axis(code: int,value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device=0; e.axis=code; e.axis_value=value
	Input.parse_input_event(e); Input.flush_buffered_events()

func reset(owner: int=9) -> void:
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false); game.hud.hide()
	game.controller.reset_bindings(); game.controller.held.clear(); game.controller.clear_shot_aim()
	game.controller.stick=Vector2.ZERO; game.controller.using_gamepad=false
	game.controlled=owner; p=game.players[owner]
	for i in range(game.players.size()):
		var q=game.players[i]
		q.visible=i==owner; q.collision_layer=2 if q.visible else 0; q.collision_mask=1
		q.position=Vector3(20+i,0,25); q.velocity=Vector3.ZERO; q.desired=Vector3.ZERO
		q.dummy_time=0; q.body_language.enabled=false; q.body_language.reset(q)
	p.position=Vector3(0,0,-30); p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO
	game.last_direction=Vector3.FORWARD; game.last_touch=0; game.last_kicker=owner
	game.kick_lock=0; game.dribbler=owner; game.carrier=owner; game.boundary_grace=1
	game.feedback.reset(); game.match_camera.select("pitch"); game.update_camera(0)
	for i in range(5): p.step(DT); await physics_frame
	game.ball.place(p.position+Vector3(0,.23,-.70))
	await physics_frame; await physics_frame

func tick(count: int=1) -> void:
	for n in range(count):
		game.kick_lock=maxf(0,game.kick_lock-DT)
		game.controller.combos.update(DT)
		game.advanced_controls.update(DT)
		game.update_control(DT)
		game.defending.update(DT); game.skills.update(DT); game.finishing.prepare(DT); game.keeper_distribution.update(DT)
		game.kick_contact.prepare(DT)
		for q in game.players:
			if q.visible: q.step(DT)
		game.kick_contact.resolve()
		game.defending.resolve(); game.finishing.resolve(); game.keeper_distribution.resolve()
		game.update_contacts(DT)
		await physics_frame

func capture(label: String) -> void:
	if not visual: return
	var velocity: Vector3=game.ball.linear_velocity
	var spin: Vector3=game.ball.angular_velocity
	game.ball.freeze=true
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/advanced-"+label+".png")
	game.ball.freeze=false; game.ball.linear_velocity=velocity; game.ball.angular_velocity=spin

func held_ball() -> void:
	game.dribbler=-1; game.carrier=-1
	game.ball.place(p.hand_center())
	await physics_frame; await physics_frame
	game.ball.hold(p); game.goalkeeping.holding=game.controlled; game.goalkeeping.hold_age=0
	p.set_piece_pose="carry"
	for n in range(30):
		game.goalkeeping.update(game.controlled,DT); p.step(DT); await physics_frame

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-advanced-test.cfg"
	var outputs: Array[Vector3]=[]
	for number in range(4):
		await reset()
		var energy: float=p.energy
		var before: Vector3=game.ball.position
		key(KEY_1+number); key(KEY_1+number,false)
		check(game.skills.active.has(9),"Keyboard starts "+["roulette","ball roll","elastico","scoop"][number])
		check(game.ball.position==before and p.energy<energy,"Skill spends stamina without teleporting the ball")
		var peak := 0.0
		var lean := 0.0
		for frame in range(100):
			await tick(); peak=maxf(peak,game.ball.position.y)
			lean=maxf(lean,absf(p.spine.rotation.z))
			if frame==24:
				outputs.append(game.ball.position)
				if visual:
					game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=40
					game.camera.position=p.position+Vector3(4,3,-5); game.camera.look_at(p.position+Vector3.UP)
					await capture("skill-"+str(number))
		check(game.skills.active.is_empty() and p.skill_move.is_empty(),"Skill ends and returns normal dribbling")
		check(lean<.40,"Skill balance stays anatomically bounded throughout the animation")
		if number==3: check(peak>.35,"Scoop physically lifts the ball")
	check(outputs[0].distance_to(outputs[1])>.15 and outputs[1].distance_to(outputs[2])>.10,"Skill types produce distinct physical ball paths")
	var flick_peak := {"rainbow":0.0,"heel":0.0,"flick":0.0}
	for kind in ["rainbow","heel","flick"]:
		await reset()
		var energy: float=p.energy
		var before: Vector3=game.ball.position
		key({"rainbow":KEY_6,"heel":KEY_7,"flick":KEY_8}[kind]); key({"rainbow":KEY_6,"heel":KEY_7,"flick":KEY_8}[kind],false)
		check(game.skills.active.has(9) and p.skill_move.kind==kind,"Keyboard starts a "+kind)
		check(game.ball.position==before and p.energy<energy,kind+" spends stamina without teleporting the ball")
		for frame in range(110):
			await tick(); flick_peak[kind]=maxf(flick_peak[kind],game.ball.position.y)
		check(game.skills.active.is_empty() and p.skill_move.is_empty(),kind+" ends and returns normal dribbling")
	check(flick_peak.rainbow>.80,"Rainbow lifts the ball over the player")
	check(flick_peak.flick>.45,"Flick up pops the ball for a follow-up")
	check(flick_peak.rainbow>flick_peak.heel,"Rainbow climbs higher than a heel flick")
	await reset()
	game.controller.held[100+JOY_AXIS_TRIGGER_LEFT]=KEY_E
	game.advanced_controls.skill_gesture(-p.facing)
	check(game.skills.active.has(9) and p.skill_move.kind=="rainbow","LT + right-stick back starts a rainbow")
	await reset()
	game.controller.held[100+JOY_AXIS_TRIGGER_LEFT]=KEY_E
	game.advanced_controls.skill_gesture(p.facing)
	check(game.skills.active.has(9) and p.skill_move.kind=="heel","LT + right-stick forward starts a heel flick")
	await reset()
	game.controller.held[100+JOY_AXIS_TRIGGER_LEFT]=KEY_E
	game.advanced_controls.skill_gesture(p.facing.cross(Vector3.UP))
	check(game.skills.active.has(9) and p.skill_move.kind=="flick","LT + right-stick lateral starts a flick up")
	await reset()
	game.controller.adopt_device(0,"Xbox Controller")
	axis(JOY_AXIS_RIGHT_X,1); axis(JOY_AXIS_RIGHT_X,0); await tick(25)
	check(game.skills.active.has(9) and p.skill_move.kind=="roll","Right-stick lateral gesture performs a ball roll")
	await reset()
	game.controller.adopt_device(0,"DualSense")
	axis(JOY_AXIS_RIGHT_X,1); axis(JOY_AXIS_RIGHT_X,0); axis(JOY_AXIS_RIGHT_X,-1)
	check(game.skills.active.has(9) and p.skill_move.kind=="elastico","Opposite right-stick gestures perform an elastico on PlayStation")
	await reset()
	game.controller.adopt_device(0,"Xbox Controller")
	button(JOY_BUTTON_X); axis(JOY_AXIS_RIGHT_X,1)
	check(game.charging and game.controller.aim_stick.x>.9 and game.skills.active.is_empty(),"Right stick retains aiming during shot preparation")
	button(JOY_BUTTON_X,false)
	await reset()
	game.players[6].visible=true; game.players[6].position=p.position+Vector3(12,0,0)
	game.players[7].visible=true; game.players[7].position=p.position+Vector3(0,0,-3)
	check(game.defending.directional_choice(Vector3.RIGHT)==6,"Directional selection favors the aimed teammate over the nearest teammate")
	game.dribbler=-1; game.carrier=-1; game.last_touch=1
	game.ball.place(Vector3(0,.23,-12)); await physics_frame; await physics_frame
	game.controller.adopt_device(0,"Xbox Controller"); axis(JOY_AXIS_RIGHT_X,1)
	check(game.controlled==6,"A defensive right-stick flick selects that teammate")
	game.controlled=9
	key(KEY_SPACE); await tick(1)
	check(game.defending.presser>=0 and game.defending.presser!=9,"Second-man pressure selects a teammate rather than taking over the user")
	var presser: int=game.defending.presser
	var energy: float=game.players[presser].energy
	await tick(80)
	check(game.players[presser].energy<energy and game.controlled==9,"Second-man pressure consumes stamina and preserves user control")
	key(KEY_SPACE,false); await tick()
	check(game.defending.presser<0,"Releasing the pressure command releases the teammate")
	await reset()
	var opponent=game.players[20]
	opponent.visible=true; opponent.position=p.position+Vector3(.82,0,0); opponent.facing=Vector3.FORWARD
	var velocity: Vector3=opponent.velocity
	check(game.defending.shoulder(9) and opponent.velocity.distance_to(velocity)>.5,"A legal side-on shoulder creates bounded physical displacement")
	check(p.contest_weight>0 and opponent.contest_weight>0,"Both players react to the shoulder challenge")
	await reset()
	game.dribbler=-1; game.carrier=-1; game.last_touch=1; game.last_kicker=20
	game.ball.place(p.position+Vector3(0,.28,-2.1),Vector3(0,0,10))
	await physics_frame; await physics_frame
	key(KEY_L); key(KEY_L,false); await tick(40)
	check(game.last_touch==0 and game.last_kicker==9,"Timed interception cushions a real incoming low pass")
	await reset()
	game.dribbler=-1; game.carrier=-1; game.last_kicker=6
	game.ball.place(p.position+Vector3(0,.23,-2),Vector3(0,0,10))
	await physics_frame; await physics_frame
	key(KEY_U); key(KEY_U,false)
	check(game.advanced_controls.dummy.has(9),"Dummy opens a brief leave-the-pass window")
	await tick(45)
	check(game.ball.position.z>p.position.z+.5 and game.last_kicker==6,"Dummy lets the original pass run through without touching or redirecting it")
	await tick(50)
	check(p.dummy_time<=0 and not game.ball.get_collision_exceptions().has(p),"Dummy restores normal ball collisions and reception")
	await reset()
	game.dribbler=-1; game.carrier=-1; game.last_kicker=6
	game.ball.place(p.position+Vector3(0,.23,-2),Vector3(0,0,10))
	await physics_frame; await physics_frame
	game.advanced_controls.start_dummy(9); game.reset_advanced_play()
	check(p.dummy_time==0 and not game.ball.get_collision_exceptions().has(p),"Canceling a dummy also clears the pose and collision exception immediately")
	for through in [false,true]:
		await reset()
		var code := KEY_Y if through else KEY_S
		key(code,true,true); await tick(25)
		var preview: Dictionary=game.pass_preview.duplicate()
		check(game.pass_driven and preview.velocity.length()>18 and preview.velocity.y<.2,"Driven pass has its own fast, low preview")
		key(code,false)
		await tick(10)
		check(game.passes[0]==1 and game.ball.kick_velocity.distance_to(preview.velocity)<.001,"Driven pass release exactly uses the displayed route")
	for style in ["low","power","outside","timed"]:
		await reset()
		if style=="timed": key(KEY_5); key(KEY_5,false)
		key(KEY_D,true,style=="low",style=="power",style=="outside")
		await tick(20)
		check(game.finishing.style==style,"Keyboard selects "+style+" shot")
		key(KEY_D,false)
		check(game.finishing.active(9) and game.shots[0]==0,"Special shot waits for the boot instead of changing a flying ball")
		var delay: float=game.finishing.pending.contact
		var remaining := int((delay-.045)/DT)
		if visual and style=="power":
			await tick(12); remaining-=12
			game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=40
			game.camera.position=p.position+Vector3(4,2.8,-5); game.camera.look_at(p.position+Vector3.UP)
			await capture("power-windup")
		await tick(remaining)
		if visual and style=="power":
			game.match_camera.select("pitch"); game.update_camera(0); game.hud.show()
			await capture("timing"); game.hud.hide()
		key(KEY_D); key(KEY_D,false)
		check(game.finishing.pending.get("quality",0)>1,"Second press in the green window rewards timing")
		await tick(65)
		print("SPECIAL ",style," shots=",game.shots[0]," output=",game.ball.kick_velocity," spin=",game.ball.spin)
		check(game.shots[0]==1 and game.finishing.pending.is_empty(),"Special shot makes one physical contact and one shot")
		if style=="low": check(game.ball.kick_velocity.y<1,"Low driven shot stays low")
		if style=="power": check(game.ball.kick_velocity.length()>38,"Power shot delivers its higher speed after the longer preparation")
		if style=="outside": check(absf(game.ball.spin)>.5,"Outside-foot shot applies its own physical curve")
	await reset()
	key(KEY_D,true,true); key(KEY_D,false); key(KEY_D); key(KEY_D,false)
	check(game.finishing.pending.quality<.9,"An early second press reduces quality rather than guaranteeing a better shot")
	await reset()
	key(KEY_D,true,false,true); key(KEY_D,false)
	game.ball.place(Vector3(6,.23,-30),Vector3(4,0,0)); await physics_frame; await physics_frame
	await tick(90)
	check(game.shots[0]==0 and game.finishing.pending.is_empty(),"A dispossessed power shot misses without a remote strike")
	for family in ["Xbox Controller","DualSense"]:
		for style in ["low","power","outside","timed"]:
			await reset(); game.controller.adopt_device(0,family)
			if style in ["power","outside"]: button(JOY_BUTTON_LEFT_SHOULDER)
			if style=="low": button(JOY_BUTTON_RIGHT_SHOULDER)
			if style=="power": axis(JOY_AXIS_TRIGGER_RIGHT,1)
			if style=="outside": axis(JOY_AXIS_TRIGGER_LEFT,1)
			if style=="timed": button(JOY_BUTTON_LEFT_STICK); button(JOY_BUTTON_LEFT_STICK,false)
			button(JOY_BUTTON_X); await tick(15)
			check(game.finishing.style==style,family+" selects "+style+" using the documented chord")
			button(JOY_BUTTON_X,false)
			if style in ["power","outside"]: button(JOY_BUTTON_LEFT_SHOULDER,false)
			if style=="low": button(JOY_BUTTON_RIGHT_SHOULDER,false)
			if style=="power": axis(JOY_AXIS_TRIGGER_RIGHT,0)
			if style=="outside": axis(JOY_AXIS_TRIGGER_LEFT,0)
			await tick(110)
			check(game.shots[0]==1 and game.controlled==9,family+" chord makes one shot without accidental player switching")
		await reset(); game.controller.adopt_device(0,family)
		button(JOY_BUTTON_RIGHT_SHOULDER); button(JOY_BUTTON_A); await tick(20)
		check(game.pass_driven,family+" supports a charged driven pass")
		button(JOY_BUTTON_A,false); button(JOY_BUTTON_RIGHT_SHOULDER,false)
		check(game.passes[0]==1,family+" driven pass releases normally")
		await reset(); game.controller.adopt_device(0,family)
		game.dribbler=-1; game.carrier=-1; game.last_touch=1; game.last_kicker=20
		game.ball.place(p.position+Vector3(0,.28,-2.1),Vector3(0,0,10))
		await physics_frame; await physics_frame
		axis(JOY_AXIS_TRIGGER_LEFT,1); button(JOY_BUTTON_X); button(JOY_BUTTON_X,false); axis(JOY_AXIS_TRIGGER_LEFT,0)
		check(p.pose=="intercept",family+" LT + shot requests a pass interception")
		await tick(40)
		check(game.last_touch==0,family+" interception uses real foot contact")
	for kind in ["roll","throw","punt","drop"]:
		await reset(0); await held_ball()
		var before: Vector3=game.ball.position
		if kind=="drop":
			key(KEY_V); key(KEY_V,false)
			check(game.ball.held_by==null and game.ball.position==before,"Keeper drop releases the real held ball without relocating it")
			await tick(80)
			check(game.ball.position.y<.5,"Dropped ball falls to the turf")
			continue
		var code: int={"roll":KEY_S,"throw":KEY_Y,"punt":KEY_D}[kind]
		key(code); await tick(22); key(code,false)
		check(not game.keeper_distribution.pending.is_empty(),"Keeper command queues "+kind+" rather than choosing a teammate")
		await tick(140)
		print("KEEPER ",kind," passes=",game.passes[0]," output=",game.ball.kick_velocity," position=",game.ball.position)
		check(game.ball.held_by==null and game.passes[0]==1,"Keeper "+kind+" completes exactly one physical distribution")
		if kind=="throw": check(game.ball.kick_velocity.y>2,"Long throw has an aerial hand-release trajectory")
		if kind=="punt": check(game.ball.kick_velocity.y>6 and game.shots[0]==0,"Punt uses foot contact and counts as distribution, not a shot")
	await reset()
	game.controls_help.open_panel()
	check(game.controls_help.TITLES.size()==8,"The in-game command list has dedicated skills, finishing, passing and keeper pages")
	for page in [1,4,5,6,7]:
		game.controls_help.select_page(page)
		check(game.controls_help.rows().size()>=5,"Command page "+str(page)+" contains usable action descriptions")
		if visual:
			game.hud.show(); game.controls_help.select_device(true); await capture("commands-"+str(page))
	game.controls_help.close_panel()
	game.finishing.timed_armed=true; game.defending.pressing=true
	game.state="paused"; game.simulate_match(DT)
	check(not game.finishing.timed_armed and not game.defending.pressing,"Pausing clears held advanced actions")
	print("ADVANCED PLAY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
