extends "res://tests/advanced_play_check.gd"
## Strafe dribble, contain, controlled sprint, the newer skill moves and the
## first touch into space, through real key input and the shared physics.

func release_all() -> void:
	for code in [KEY_E,KEY_W,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_SHIFT,KEY_V]: key(code,false)

func sprint_run(controlled_sprint: bool) -> Dictionary:
	await reset()
	p.position=Vector3(0,0,20); game.ball.place(p.position+Vector3(0,game.ball.GROUND_HEIGHT,-.6))
	await physics_frame; await physics_frame
	key(KEY_UP); key(KEY_W)
	if controlled_sprint: key(KEY_SHIFT)
	await tick(150)
	var gap := 0.0
	var speed := 0.0
	for n in range(60):
		await tick()
		gap+=game.flat_distance(p.position,game.ball.position)/60.0
		speed=maxf(speed,Vector2(p.velocity.x,p.velocity.z).length())
	release_all()
	return {"gap":gap,"speed":speed,"kept":game.dribbler==9 or game.flat_distance(p.position,game.ball.position)<1.4}

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-controls-depth.cfg"
	# Strafe dribble keeps the body square while the ball travels sideways.
	await reset()
	var heading: Vector3=p.facing
	key(KEY_E); key(KEY_W); key(KEY_RIGHT)
	await tick(96)
	check(p.strafing and p.facing.dot(heading)>.98 and p.velocity.x>1.2,"E + W strafes sideways without turning the body")
	check(game.flat_distance(p.position,game.ball.position)<1.3 and not p.active_sprint,"The strafing carrier keeps the ball close and does not sprint")
	release_all(); await tick(2)
	check(not p.strafing,"Releasing the keys ends the strafe")
	# Contain: without the ball, E + W closes to a goal-side point.
	await reset()
	var carrier=game.players[20]
	carrier.visible=true; carrier.collision_layer=2
	carrier.position=p.position+Vector3(4,0,-9); carrier.velocity=Vector3.ZERO; carrier.facing=Vector3(0,0,game.attack_sign(1))
	game.ball.place(carrier.position+Vector3(0,game.ball.GROUND_HEIGHT,game.attack_sign(1)*.6)); await physics_frame; await physics_frame
	game.dribbler=20; game.carrier=20; game.last_touch=1
	key(KEY_E); key(KEY_W)
	var start_gap: float=game.flat_distance(p.position,carrier.position)
	await tick(180)
	var goal_side: float=(p.position-carrier.position).dot(Vector3(0,0,game.attack_sign(1)))
	check(game.flat_distance(p.position,carrier.position)<start_gap and game.flat_distance(p.position,carrier.position)<3.2,"Contain closes the distance to the carrier")
	check(goal_side>.8,"Contain arrives on the goal side of the carrier")
	check(p.facing.dot(((game.ball.position-p.position)*Vector3(1,0,1)).normalized())>.8,"The containing defender faces the ball")
	release_all()
	# Controlled sprint: a little slower, the ball clearly closer.
	var open: Dictionary=await sprint_run(false)
	var tight: Dictionary=await sprint_run(true)
	check(tight.speed<open.speed*.96 and tight.speed>open.speed*.8,"Controlled sprint trades a little pace: %.2f vs %.2f m/s" % [tight.speed,open.speed])
	check(tight.gap<open.gap and tight.kept,"Controlled sprint keeps shorter touches: %.2f vs %.2f m" % [tight.gap,open.gap])
	# The newer skill moves run as physical touches for a five-star player.
	for move in ["heel_to_heel","ball_roll_cut","spin"]:
		await reset()
		p.attributes["skill_moves"]=5
		var started: bool=game.skills.start(9,move,1.0)
		var close := true
		for n in range(80):
			await tick()
			if game.flat_distance(p.position,game.ball.position)>2.2: close=false
		check(started and close,"%s starts and keeps the ball within reach" % move)
	await reset()
	p.attributes["skill_moves"]=2
	check(not game.skills.start(9,"spin",1.0),"A two-star player cannot attempt the McGeady spin")
	# Nutmeg: the touch passes the square defender's stance.
	await reset()
	p.attributes["skill_moves"]=5
	var defender=game.players[14]
	defender.visible=true; defender.collision_layer=2
	defender.position=p.position+p.facing*1.35; defender.velocity=Vector3.ZERO; defender.facing=-p.facing
	await physics_frame
	check(game.skills.start(9,"nutmeg",1.0),"The nutmeg starts against a square defender")
	await tick(50)
	var beyond: float=(game.ball.position-defender.position).dot(p.facing)
	check(beyond>.3,"The nutmeg touch goes through and beyond the defender: %.2f m" % beyond)
	defender.visible=false; defender.collision_layer=0
	# First touch into space: V + direction before the ball arrives.
	await reset()
	game.dribbler=-1; game.carrier=-1
	game.ball.place(p.position+Vector3(0,game.ball.GROUND_HEIGHT,-7),Vector3(0,0,9)); await physics_frame
	game.last_touch=0; game.last_kicker=8
	# Like a player: press just before the ball arrives, with a direction.
	for n in range(160):
		if game.flat_distance(p.position,game.ball.position)<2.0: break
		await tick()
	key(KEY_RIGHT); key(KEY_V)
	var armed: bool=game.first_touch.knocks.has(9)
	var lead := 0.0
	var released := false
	for n in range(40):
		await tick()
		lead=maxf(lead,game.ball.linear_velocity.x-p.velocity.x)
		if not game.first_touch.knocks.has(9) and game.dribbler!=9: released=true
	check(armed and released and lead>1.5,"V before the pass knocks the first touch into space: +%.1f m/s over the runner" % lead)
	release_all()
	print("CONTROLS DEPTH CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
