extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: print("PASS: "+description)
	else: failures+=1; push_error("FAIL: "+description)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	check(game.players.size()==22,"11 versus 11 roster")
	game.start_match(false,false)
	game.set_physics_process(false)
	for p in game.players: p.collision_layer = 0
	var ball = game.ball
	ball.active = true
	ball.place(Vector3(15,3,0))
	await frames(35)
	check(ball.position.y<2.9 and ball.linear_velocity.y<0,"Gravity acts on an airborne ball")
	await frames(130)
	check(ball.position.y>=0.18 and ball.position.y<2,"Ball bounces on the physical pitch")
	ball.place(Vector3(0,0.23,0),Vector3(10,0,0))
	await frames(140)
	check(ball.position.x>3 and ball.linear_velocity.x<10,"Rolling friction dissipates momentum")
	var rolled=ball.position.x
	await frames(100)
	check(ball.position.x>rolled,"Ball continues freely after a touch")
	ball.place(Vector3(-12,0.23,0))
	await frames(4)
	ball.strike(Vector3(0,8,-20),2)
	await frames(70)
	check(ball.position.y>2 and ball.position.z < -5,"Lofted shot follows a physical trajectory")
	check(ball.position.x>-11.9,"Spin bends the airborne trajectory")
	ball.place(Vector3(3.66,0.23,-46),Vector3(0,0,-20))
	await frames(45)
	check(ball.linear_velocity.z>0,"Goalpost collision rebounds the ball")
	game.state="playing"
	game.boundary_grace=0
	ball.place(Vector3(0,0.23,-50.5))
	await frames(3)
	game.previous_ball=Vector3(0,0.23,-49.5)
	game.check_boundaries()
	check(game.score[0]==1 and game.state=="goal","Whole ball crosses under crossbar for a goal")
	game.state="playing"
	game.boundary_grace=0
	ball.place(Vector3(0,3.3,-50.5))
	await frames(3)
	game.previous_ball=Vector3(0,3.3,-49.5)
	game.last_touch=0
	game.check_boundaries()
	check(game.score[0]==1 and game.restart_type=="KALE VURUŞU","Overbar shot is not a goal")
	check(game.state=="restart" and ball.active,"Out-of-play ball keeps its physics during restart preparation")
	game.state="playing"
	ball.active=true
	game.last_touch=0
	ball.place(Vector3(33,0.23,12))
	await frames(3)
	game.check_boundaries()
	check(game.restart_type=="TAÇ" and game.restart_team==1,"Touchline awards the other team a throw-in")
	check(game.state=="restart" and ball.active,"Throw-in stops play while the ball remains physical")
	game.state="playing"
	ball.active=true
	game.last_touch=1
	ball.place(Vector3(12,0.23,-51))
	await frames(3)
	game.check_boundaries()
	check(game.restart_type=="KORNER" and game.restart_team==0,"Defender touch over goal line awards corner")
	check(game.state=="restart","Corner stops play while players take positions")
	game.execute_restart()
	await frames(3)
	check(game.controlled<11 and absf(ball.position.x)<32,"Corner sets a valid restart taker and ball")
	game.start_match(true)
	await frames(5)
	check(game.players.filter(func(p): return p.visible).size()==2,"Training isolates striker and goalkeeper")
	game.charge=1
	game.shoot()
	await frames(5)
	check(game.shots[0]==1 and ball.linear_velocity.length()>25,"Charged input launches a powerful shot")
	game.start_match(false,false)
	await frames(5)
	var pass_event=InputEventKey.new()
	# Manual passing follows the selected heading, including at kickoff.
	game.last_direction=(game.players[10].position-game.ball.position)*Vector3(1,0,1)
	game.last_direction=game.last_direction.normalized()
	pass_event.keycode=KEY_S
	pass_event.pressed=true
	Input.parse_input_event(pass_event)
	await frames(2)
	pass_event = pass_event.duplicate()
	pass_event.pressed=false
	Input.parse_input_event(pass_event)
	await frames(5)
	check(game.passes[0]==1 and game.controlled!=9,"Pass selects its receiver")
	game.start_match(false,false)
	await frames(5)
	var cross_event=InputEventKey.new()
	cross_event.keycode=KEY_A
	cross_event.pressed=true
	Input.parse_input_event(cross_event)
	await frames(2)
	cross_event = cross_event.duplicate()
	cross_event.pressed=false
	Input.parse_input_event(cross_event)
	await frames(3)
	# A short lob needs less lift than a long cross; assert actual airborne delivery.
	check(game.passes[0]==1 and ball.linear_velocity.y>3 and ball.position.y>0.23,"A sends a lofted cross at a height appropriate to its range")
	var sprint_event=InputEventKey.new()
	sprint_event.physical_keycode=KEY_W
	sprint_event.keycode=KEY_W
	sprint_event.pressed=true
	Input.parse_input_event(sprint_event)
	await frames(2)
	game.update_control(0)
	check(game.players[game.controlled].sprinting and game.players[game.controlled].desired==Vector3.ZERO,"W enables sprint without selecting a movement direction")
	sprint_event = sprint_event.duplicate()
	sprint_event.pressed=false
	Input.parse_input_event(sprint_event)
	game.state="playing"
	game.match_time=game.LENGTH-0.001
	game._physics_process(0.01)
	check(game.state=="finished","Final whistle stops the match")
	game.start_match(false,false)
	check(game.score==[0,0] and game.shots==[0,0],"Rematch resets score and statistics")
	game.start_match(true)
	game.set_physics_process(true)
	await frames(8)
	var move_event=InputEventKey.new()
	move_event.physical_keycode=KEY_UP
	move_event.keycode=KEY_UP
	move_event.pressed=true
	Input.parse_input_event(move_event)
	var shot_event=InputEventKey.new()
	shot_event.keycode=KEY_D
	shot_event.physical_keycode=KEY_D
	shot_event.pressed=true
	Input.parse_input_event(shot_event)
	await frames(130)
	shot_event.pressed=false
	Input.parse_input_event(shot_event)
	move_event.pressed=false
	Input.parse_input_event(move_event)
	await frames(3)
	check(game.shots[0]==1,"Charging while moving keeps the ball within shooting reach")
	game.free()
	print("RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)
