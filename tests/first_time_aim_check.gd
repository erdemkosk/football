extends "res://tests/volley_check.gd"

func aim_input(direction: Vector2,device: String) -> void:
	if device=="keyboard":
		for code in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]: key(false,code)
		if direction.x<0: key(true,KEY_LEFT)
		if direction.x>0: key(true,KEY_RIGHT)
		if direction.y<0: key(true,KEY_UP)
		if direction.y>0: key(true,KEY_DOWN)
	else:
		for axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
			var event := InputEventJoypadMotion.new()
			event.device=0; event.axis=axis; event.axis_value=direction.x if axis==JOY_AXIS_LEFT_X else direction.y
			Input.parse_input_event(event); Input.flush_buffered_events()

func shoot_input(pressed: bool,device: String) -> void:
	if device=="keyboard": key(pressed)
	else: button(pressed)

func prepare_case(kind: String,device: String,camera: String="pitch",half: int=1) -> void:
	aim_input(Vector2.ZERO,"keyboard")
	var offset := Vector3(-4,2.85,-.1) if kind=="header" else Vector3(-3,1.5,-.55)
	var velocity := Vector3(11,0,0)
	if kind=="half_volley": offset=Vector3(-2.6,.85,-.55); velocity=Vector3(10,-3,0)
	if kind=="approach": offset=Vector3(-6,2.3,-1.7)
	await reset(offset,velocity)
	game.half=half; game.match_camera.select(camera); game.update_camera(0)
	if device!="keyboard": game.controller.adopt_device(0,device)
	game.last_direction=Vector3.FORWARD

func request_aim() -> Vector3:
	if game.aerial_assist.active(9): return game.aerial_assist.pending.aim
	if game.heading.active(9): return game.heading.requests[9].aim
	if game.volleys.active(9): return game.volleys.requests[9].aim
	return Vector3.ZERO

func finish_case(kind: String,device: String,direction: Vector2,camera: String="pitch",half: int=1) -> void:
	await prepare_case(kind,device,camera,half)
	shoot_input(true,device); await tick(2); shoot_input(false,device)
	check(game.aerial_shot_active(9) and not game.charging,"Early shot release keeps the incoming finish queued: %s %s" % [kind,device])
	var power: float=game.heading.requests[9].power if game.heading.active(9) else (game.volleys.requests[9].power if game.volleys.active(9) else game.aerial_assist.pending.power)
	aim_input(direction,device); await tick()
	var expected: Vector3=game.match_camera.orient(Vector3(direction.x,0,direction.y)).normalized()
	check(game.shot_direction.dot(expected)>.99999 and request_aim().dot(expected)>.99999,"Direction selected after the shot tap immediately reaches the finish: %s %s %s" % [kind,device,direction])
	aim_input(Vector2.ZERO,device); await tick()
	check(request_aim().dot(expected)>.99999,"Neutral preserves the chosen finish direction")
	check(game.aim_direction().dot(expected)>.99999 and is_equal_approx(game.aerial_shot_power(9),power),"The queued shot guide retains its aim and released power")
	var retained_power: float=game.heading.requests[9].power if game.heading.active(9) else (game.volleys.requests[9].power if game.volleys.active(9) else game.aerial_assist.pending.power)
	check(is_equal_approx(power,retained_power),"Changing a released finish's aim does not recharge its power")
	await tick(140)
	var intended: Vector3=(game.strike_quality.last.get("intended",Vector3.ZERO)*Vector3(1,0,1)).normalized()
	var exact_launch: bool=game.ball.kick_velocity.is_equal_approx(game.strike_quality.last.get("velocity",Vector3.INF))
	check(contacts==1 and intended.dot(expected)>.99999 and exact_launch,"Actual %s contact launches along the chosen direction plus its recorded contact error, %s camera=%s half=%d" % [kind,device,camera,half])
	if kind=="half_volley": check(bounced_before_contact and contact_kind=="half_volley","The aimed half-volley follows a real ground bounce")
	var launched: Vector3=game.ball.kick_velocity
	aim_input(-direction,device); await tick(2); aim_input(Vector2.ZERO,device)
	check(game.ball.kick_velocity==launched,"Direction changes after contact cannot steer the outgoing ball")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-first-time-aim.cfg"; p=game.players[9]
	for device in ["keyboard","Xbox Controller","DualSense"]:
		for kind in ["header","volley","half_volley"]:
			await finish_case(kind,device,Vector2.RIGHT)
	for direction in [Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1)]:
		await finish_case("header","keyboard",direction)
	await finish_case("volley","Xbox Controller",Vector2(.37,-.81))
	await finish_case("header","Xbox Controller",Vector2.RIGHT,"sideline",2)
	await finish_case("volley","keyboard",Vector2.UP,"end",2)
	await finish_case("approach","keyboard",Vector2.UP)
	for kind in ["header","volley"]:
		for device in ["keyboard","Xbox Controller"]:
			await prepare_case(kind,device)
			shoot_input(true,device); await tick(2); aim_input(Vector2.RIGHT,device)
			for frame in range(100):
				await tick()
				if contacts>0: break
			var aimed: Vector3=game.strike_quality.last.get("intended",Vector3.ZERO)
			check(contacts==1 and game.ball.kick_velocity.x>9 and aimed.x>9 and absf(aimed.z)<.01 and game.ball.kick_velocity.is_equal_approx(game.strike_quality.last.velocity),"Holding shot and direction together completes an aimed %s, %s" % [kind,device])
			shoot_input(false,device); aim_input(Vector2.ZERO,device)
	# An aim event and button release can arrive before the next physics tick.
	await prepare_case("header","keyboard")
	key(true); aim_input(Vector2.LEFT,"keyboard"); key(false)
	check(request_aim().dot(Vector3.LEFT)>.99999,"Release reads the latest same-frame keyboard direction")
	aim_input(Vector2.ZERO,"keyboard"); await tick(100)
	check(contacts==1 and game.ball.kick_velocity.x<-9,"Same-frame aiming reaches the real header contact")
	# Independent aiming keeps its priority even while the left stick moves.
	await prepare_case("header","Xbox Controller")
	button(true); button(false); button(true,JOY_BUTTON_DPAD_RIGHT); await tick()
	button(false,JOY_BUTTON_DPAD_RIGHT); aim_input(Vector2.LEFT,"Xbox Controller"); await tick()
	check(request_aim().dot(Vector3.RIGHT)>.99999,"Releasing independent aim never snaps a queued finish back to the running direction")
	aim_input(Vector2.ZERO,"Xbox Controller"); await tick(100)
	check(contacts==1 and game.ball.kick_velocity.x>9,"Independent aim controls the physical queued header")
	# Grounded first-time finishes also use the selected heading immediately.
	for device in ["keyboard","Xbox Controller"]:
		aim_input(Vector2.ZERO,"keyboard")
		await reset(Vector3(0,game.ball.GROUND_HEIGHT,-1.0),Vector3.BACK*6)
		if device!="keyboard": game.controller.adopt_device(0,device)
		shoot_input(true,device); aim_input(Vector2.RIGHT,device); game.update_control(DT)
		check(game.charging and game.shot_direction.dot(Vector3.RIGHT)>.99999,"A grounded first-time shot immediately follows the selected direction: "+device)
		shoot_input(false,device); aim_input(Vector2.ZERO,device)
		var struck: Vector3=game.strike_quality.last.get("intended",Vector3.ZERO)
		check(game.shots[0]==1 and game.ball.kick_velocity.x>15 and struck.x>15 and absf(struck.z)<.01 and game.ball.kick_velocity.is_equal_approx(game.strike_quality.last.velocity),"The incoming ground ball is struck along that direction")
		await tick(15)
		check(game.ball.position.x>1 and game.ball.linear_velocity.x>5,"The physical first-time ground shot travels toward the chosen side")
	print("FIRST TIME AIM CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
