extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: print("PASS: "+description)
	else: failures+=1; push_error("FAIL: "+description)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func key(code: int,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func advance(seconds: float,steps: int) -> void:
	for i in range(steps): game.update_control(seconds/steps)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_match(true)
	game.set_physics_process(false)
	await frames(4)
	key(KEY_D,true)
	await frames(2)
	check(game.charging,"D begins a charged shot")
	var anchor: Vector3=game.shot_direction
	key(KEY_RIGHT,true)
	await frames(2)
	advance(0.1,12)
	var angle=rad_to_deg(anchor.angle_to(game.shot_direction))
	check(angle>1.8 and angle<2.2 and game.shot_direction.x>0,"100 ms right tap corrects aim by only two degrees")
	check(game.last_direction==Vector3.FORWARD,"Strafing during a shot does not replace its starting heading")
	key(KEY_RIGHT,false)
	await frames(2)
	var held: Vector3=game.shot_direction
	advance(0.25,30)
	check(game.shot_direction.distance_to(held)<0.00001,"Releasing the arrow retains the adjusted aim")
	key(KEY_LEFT,true)
	await frames(2)
	advance(0.1,12)
	check(anchor.angle_to(game.shot_direction)<0.002,"Opposite tap smoothly corrects back to the centre")
	advance(2,240)
	check(absf(rad_to_deg(anchor.angle_to(game.shot_direction))-14)<0.1,"Long hold cannot swing the shot sideways beyond fourteen degrees")
	key(KEY_LEFT,false)
	key(KEY_RIGHT,true)
	await frames(2)
	var preview: Vector3=game.shot_direction
	game.charge=0.6
	key(KEY_D,false)
	await frames(3)
	var kick: Vector3=game.ball.kick_velocity
	kick.y=0
	check(game.shots[0]==1 and kick.normalized().distance_to(preview)<0.0001,"Release uses the displayed aim even if the opposite arrow was just pressed")
	check(is_zero_approx(game.ball.spin),"Aiming during a shot does not add curl")
	key(KEY_RIGHT,false)
	await frames(2)
	game.start_match(true)
	await frames(4)
	game.ball.place(Vector3(10,0.23,-0.82))
	game.players[game.controlled].position=Vector3(10,0,-0.05)
	game.last_direction=Vector3(0,0,-1)
	game.begin_shot()
	key(KEY_E,true)
	await frames(2)
	advance(0.35,42)
	check(game.charging and game.shot_finesse,"E during a charged shot is finesse, not shielding")
	check(not game.players[game.controlled].protecting,"Finesse does not start a shield")
	var headed: Vector3=game.shot_direction
	var curl: float=game.finesse_curve(headed)
	check(absf(curl)>=game.FINESSE_CURVE*0.99,"Finesse applies full inside-foot curl toward the far post")
	game.charge=0.7
	key(KEY_D,false)
	await frames(3)
	check(absf(game.ball.spin)>1.4 and signf(game.ball.spin)==signf(curl),"Release keeps the aimed heading and applies the finesse spin")
	check(headed.distance_to((game.ball.kick_velocity*Vector3(1,0,1)).normalized())<0.0001,"Finesse does not steer the shot with E")
	key(KEY_E,false)
	await frames(2)
	game.start_match(true)
	await frames(4)
	game.ball.place(Vector3(10,0.23,-0.82))
	game.players[game.controlled].position=Vector3(10,0,-0.05)
	game.last_direction=Vector3(0,0,-1)
	game.begin_shot()
	key(KEY_Q,true)
	await frames(2)
	advance(0.35,42)
	check(game.charging and game.shot_chip and not game.shot_finesse,"Q during a charged shot is a chip, not a player switch or finesse")
	check(game.controlled==9,"Holding Q while shooting does not change the shooter")
	var chip_heading: Vector3=game.shot_direction
	var driven: Vector3=game.shot_velocity(chip_heading,0.6,false,false)
	var lofted: Vector3=game.shot_velocity(chip_heading,0.6,false,true)
	check(lofted.y>driven.y+3.5 and lofted.length()<driven.length(),"A chip is slower and much higher than a driven shot")
	key(KEY_E,true)
	await frames(2)
	advance(0.1,12)
	check(game.shot_chip and not game.shot_finesse,"Chip wins if both Q and E are held")
	game.charge=0.6
	key(KEY_D,false)
	await frames(3)
	check(game.shots[0]==1 and game.ball.kick_velocity.y>7 and is_zero_approx(game.ball.spin),"Release chips without adding curl")
	check(chip_heading.distance_to((game.ball.kick_velocity*Vector3(1,0,1)).normalized())<0.0001,"Chip does not steer the shot with Q")
	key(KEY_Q,false)
	key(KEY_E,false)
	await frames(2)
	game.start_match(true)
	await frames(4)
	game.begin_shot()
	key(KEY_RIGHT,true)
	await frames(2)
	advance(0.4,12)
	var at_30: Vector3=game.shot_direction
	game.charging=false
	game.begin_shot()
	advance(0.4,48)
	check(at_30.distance_to(game.shot_direction)<0.00001,"Aim response is identical at 30 and 120 updates per second")
	key(KEY_LEFT,true)
	await frames(2)
	var neutral: Vector3=game.shot_direction
	advance(0.3,36)
	check(neutral.distance_to(game.shot_direction)<0.00001,"Pressing both arrows produces no extra turn")
	key(KEY_LEFT,false)
	key(KEY_RIGHT,false)
	await frames(2)
	game.shot_mouse_aim=true
	var mouse_before: Vector3=game.shot_direction
	game.update_shot_aim(0.01)
	check(mouse_before.angle_to(game.shot_direction)<=game.SHOT_MOUSE_RATE*0.01+0.0001,"Mouse aim also respects the turn-rate limit")
	game.free()
	await process_frame
	print("SHOT CONTROLS: %d failures" % failures)
	quit(0 if failures==0 else 1)
