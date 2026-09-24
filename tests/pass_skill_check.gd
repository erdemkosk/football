extends "res://tests/team_control_check.gd"
const DT := 1.0/120

func key(code: int,pressed: bool=true,ctrl: bool=false) -> void:
	var event := InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=pressed; event.ctrl_pressed=ctrl
	game._input(event)

func setup() -> void:
	super.setup()
	game.controller.held.clear(); game.controller.using_gamepad=false
	game.match_camera.select("pitch"); game.update_camera(0)
	game.players[9].facing=Vector3.FORWARD
	game.players[9].rig.rotation=Vector3.ZERO; game.players[9].animate(1)
	game.last_touch=0; game.last_kicker=9; game.dribbler=9; game.carrier=9
	game.ball.pending_touch=false
	game.weather.select(0,true)

func incoming() -> void:
	setup()
	game.players[9].position=Vector3.ZERO
	game.players[6].visible=false
	game.players[7].position=Vector3(8,0,0)
	game.ball.position=Vector3(0,game.ball.GROUND_HEIGHT,-2.8)
	game.ball.linear_velocity=Vector3.BACK*12
	game.dribbler=-1; game.carrier=-1; game.last_kicker=6
	game.ai_receivers[0]=9; game.ai_pass_time[0]=2
	game.controller.using_gamepad=true; game.controller.stick=Vector2.RIGHT

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-quick-passing-check.cfg"
	for pad in [false,true]:
		setup()
		if pad: button(JOY_BUTTON_A)
		else: key(KEY_S)
		check(game.passes[0]==1 and not game.pass_charging and game.pass_preview.is_empty(),"One press queues a normal pass without a power bar, pad=%s" % pad)
		check(not game.kick_contact.pending.is_empty() and not game.ball.pending_kick,"Immediate input still waits for real boot contact")
		check(game.ai_receivers[0]==6,"A normal forward pass chooses the nearby on-direction teammate")
		contact()
		var launch: Vector3=game.ball.kick_velocity
		check(game.last_kicker==9 and launch.z< -10,"The automatic pass leaves the actual passer's foot")
		hold(.8)
		if pad: button(JOY_BUTTON_A,false)
		else: key(KEY_S,false)
		check(game.passes[0]==1 and game.ball.kick_velocity==launch,"Holding and releasing cannot charge or repeat a normal pass")

	setup()
	game.players[6].position=Vector3(0,0,-20); game.players[7].visible=false
	key(KEY_S); var far_speed: float=game.kick_contact.pending.velocity.length(); contact()
	setup()
	game.players[6].position=Vector3(0,0,-5); game.players[7].visible=false
	key(KEY_S)
	check(far_speed>game.kick_contact.pending.velocity.length()+3,"Automatic power increases for a farther teammate")
	setup()
	game.players[6].position=Vector3(8,0,0); game.players[7].position=Vector3(0,0,-4)
	game.controller.stick=Vector2.RIGHT; button(JOY_BUTTON_A)
	check(game.ai_receivers[0]==6 and game.kick_contact.pending.velocity.x>10,"Stick direction chooses the lateral teammate over the nearest forward player")
	setup()
	game.players[6].position=Vector3(0,0,8); game.players[7].visible=false
	game.players[9].facing=Vector3.BACK
	key(KEY_S)
	check(game.kick_contact.pending.velocity.z>0,"With no direction input, the pass follows the player's facing")
	setup()
	game.players[6].position=Vector3(12,0,0); game.players[7].position=Vector3(0,0,8)
	key(KEY_S)
	check(game.ai_receivers[0]<0 and absf(game.kick_contact.pending.velocity.x)<.001 and game.kick_contact.pending.velocity.z<0,"An empty aimed direction produces a loose pass, never a sideways or backwards rescue")
	setup()
	game.players[6].position=Vector3(0,0,-8); game.players[17].visible=true; game.players[17].position=Vector3(0,0,-4)
	key(KEY_S)
	check(game.ai_receivers[0]==6,"A blocked lane does not redirect the user's normal pass to another player")
	setup()
	game.players[6].position=Vector3(0,0,-8); game.players[7].position=Vector3(0,0,-18)
	key(KEY_S)
	check(game.ai_receivers[0]==6,"Collinear teammates resolve to the nearer normal pass option")
	setup()
	game.pass_assistance=0; game.players[6].position=Vector3(2,0,-8)
	key(KEY_S)
	check(absf(game.kick_contact.pending.velocity.x)<.001,"Manual assistance setting preserves the exact aimed heading")

	for half in [1,2]:
		for weather in [0,2]:
			setup(); game.half=half; game.weather.select(weather,true)
			var forward: float=game.attack_sign(0)
			game.players[9].position=Vector3(0,0,-forward*.8); game.players[9].facing=Vector3(0,0,forward)
			game.players[6].position=Vector3(1,0,forward*10); game.players[7].visible=false
			game.players[11].position.z=forward*48; game.players[14].position.z=forward*40
			game.players[6].velocity=Vector3(4,0,forward*4)
			key(KEY_Y)
			var short: Dictionary=game.pass_preview.duplicate()
			check(short.receiver==-1 and absf(short.velocity.x)<.001,"Through aim stays on the chosen ray beside a diagonal runner, half=%d weather=%d" % [half,weather])
			game.players[6].velocity.x=-4; game.update_pass_preview()
			check(game.pass_preview.target.is_equal_approx(short.target) and game.pass_preview.velocity.is_equal_approx(short.velocity),"Reversing a teammate run cannot pull the held through-pass arrow")
			game.players[6].velocity.x=4; hold(1.5)
			check(game.pass_preview.target.distance_to(game.ball.position)>short.target.distance_to(game.ball.position)+10 and absf(game.pass_preview.velocity.x)<.001,"Holding through pass increases distance along the same freely chosen heading")
			var route: Dictionary=game.pass_preview.duplicate()
			key(KEY_Y,false); contact()
			var intended: Vector3=game.strike_quality.last.get("intended",Vector3.ZERO)
			check(game.passes[0]==1 and intended.is_equal_approx(route.velocity) and game.ball.kick_velocity.is_equal_approx(game.strike_quality.last.velocity),"Through release commits the previewed physical trajectory plus its recorded contact error")
			var launched: Vector3=game.ball.kick_velocity
			game.players[6].velocity.x=-8; game.players[6].position.x-=12
			game.update_control(DT)
			check(game.ball.kick_velocity==launched,"Runner changes after release cannot steer the ball")
	setup(); button(JOY_BUTTON_Y); game.controller.stick=Vector2.RIGHT; hold(DT)
	check(game.pass_direction.dot(Vector3.RIGHT)>.99 and game.pass_power<.02,"Changing charged pass direction responds immediately without filling the power bar")
	game.controller.stick=Vector2.ZERO; game.players[6].position=Vector3(10,0,2); hold(.2)
	check(game.pass_direction.dot(Vector3.RIGHT)>.999999 and game.pass_preview.velocity.normalized().dot(Vector3.RIGHT)>.999,"Returning the stick to neutral preserves the chosen aim beside a teammate")
	setup(); game.players[6].visible=false; game.players[7].visible=false
	button(JOY_BUTTON_Y); hold(.2)
	check(game.pass_preview.receiver==-1 and game.pass_preview.velocity.z<0,"A through pass with no runner remains an aimed free ball")
	for assistance in [0,1,2]:
		for lob in [false,true]:
			setup(); game.pass_assistance=assistance
			game.players[6].position=Vector3(-1,0,-10); game.players[7].position=Vector3(1,0,-10)
			game.begin_pass(true,lob)
			for x in [-.015,.015,.5,-1.0]:
				game.pass_direction=Vector3(x,0,-1).normalized(); game.pass_power=.6; game.update_pass_preview()
				var shown: Vector3=(game.pass_preview.velocity*Vector3(1,0,1)).normalized()
				check(game.pass_preview.receiver==-1 and shown.dot(game.pass_direction)>.999999,"Every aim correction remains free between teammates, assistance=%d lob=%s x=%s" % [assistance,lob,x])
			game.ball.position=Vector3(29,game.ball.GROUND_HEIGHT,-46)
			game.pass_direction=Vector3(1,0,-1).normalized(); game.pass_power=.9; game.update_pass_preview()
			var edge_heading: Vector3=(game.pass_preview.velocity*Vector3(1,0,1)).normalized()
			check(edge_heading.dot(game.pass_direction)>.999999 and game.pass_preview.target.x>game.P.HALF_WIDTH,"A deliberate pass towards the touchline is not forced back infield")
	incoming(); game.ball.position.z=-1.4
	button(JOY_BUTTON_A); button(JOY_BUTTON_A,false)
	check(not game.pass_buffer.pending.is_empty() and game.kick_contact.pending.is_empty(),"A late early-input inside foot reach still waits for real reception")

	for reason in ["timeout","pause","opponent","selection","dismissal","disconnect","restart","shot"]:
		incoming(); button(JOY_BUTTON_A); button(JOY_BUTTON_A,false)
		check(not game.pass_buffer.pending.is_empty() and game.requested_receiver<0 and game.passes[0]==0,"Early input remembers a pass, not a pass request: "+reason)
		match reason:
			"timeout": game.update_control(.31)
			"pause": key(KEY_ESCAPE)
			"opponent": game.last_touch=1; game.pass_buffer.update(DT)
			"selection": game.team_control.select(7,true)
			"dismissal": game.players[9].dismissed=true; game.pass_buffer.update(DT)
			"disconnect": game.controller.connection_changed(0,false)
			"restart": game.begin_restart("TAÇ",0,Vector3(32,0,0))
			"shot": key(KEY_D)
		check(game.pass_buffer.pending.is_empty() and game.passes[0]==0,"Obsolete early input is canceled: "+reason)
	incoming(); game.players[9].position.z=14; game.ai_receivers[0]=-1; game.ai_pass_time[0]=0
	game.ball.linear_velocity=Vector3.ZERO; game.dribbler=7; game.players[7].position=Vector3(0,0,-2)
	key(KEY_S)
	check(game.requested_receiver==9 and game.pass_buffer.pending.is_empty(),"Off-ball input still requests a teammate's pass when no delivery is approaching")

	for through in [false,true]:
		incoming()
		game.controller.stick=Vector2.RIGHT
		game.ball.freeze=false; game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,-2.8),Vector3.BACK*12)
		await physics_frame; await physics_frame
		var contacts_before: int=game.kick_contact.contacts
		var code := JOY_BUTTON_Y if through else JOY_BUTTON_A
		button(code)
		game.controller.stick=Vector2.ZERO
		for frame in range(6): game.simulate_match(DT); await physics_frame
		button(code,false)
		var passed := false
		for frame in range(70):
			game.simulate_match(DT); await physics_frame
			if game.last_kicker==9 and game.passes[0]==1 and game.kick_contact.pending.is_empty():
				passed=game.ball.kick_velocity.x>5 and game.kick_contact.contacts>contacts_before
				break
		check(passed,"An early %s input becomes one outgoing physical pass after real reception" % ("through" if through else "normal"))
		check(game.requested_receiver<0 and game.pass_buffer.pending.is_empty(),"Successful first-time input leaves no request or repeated command")
	for half in [1,2]:
		for weather in [0,2]:
			setup(); game.half=half; game.weather.select(weather,true)
			var forward: float=game.attack_sign(0)
			game.players[9].position=Vector3(0,0,-forward*.8); game.players[9].facing=Vector3(0,0,forward)
			game.players[9].rig.rotation.y=0 if forward<0 else PI; game.players[9].animate(1)
			game.players[6].position=Vector3(0,0,forward*10); game.players[6].velocity=Vector3(0,0,forward*4)
			game.players[6].facing=Vector3(0,0,-forward); game.players[7].visible=false
			game.players[11].position.z=forward*48; game.players[14].position=Vector3(24,0,forward*40)
			game.players[9].collision_layer=2; game.players[6].collision_layer=2
			game.ball.freeze=false; game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,0))
			await physics_frame; await physics_frame
			game.begin_pass(true); game.pass_power=.2; game.update_pass_preview(); game.release_pass()
			var received := false
			for frame in range(360):
				game.simulate_match(DT); await physics_frame
				if game.dribbler==6: received=true; break
			check(received,"A teammate reaches and controls a manually aimed through pass, half=%d weather=%d" % [half,weather])
	print("PASS SKILL CHECK: %d failures" % failures)
	game.free(); await process_frame; quit(1 if failures else 0)
