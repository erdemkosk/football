extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func scenario(kind: String,team: int,collector: int,ball_position: Vector3,point: Vector3) -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	for i in range(22):
		game.players[i].position=Vector3(-24+(i%11)*4,0,10 if i<11 else -10)
	game.players[collector].position=ball_position*Vector3(1,0,1)+Vector3(0,0,-1.6 if ball_position.z>0 else 1.6)
	game.players[collector].energy=0.27
	game.players[collector].recovery_delay=0.6
	game.ball.place(ball_position,Vector3(0,0.5,0.4))
	await physics_frame
	await physics_frame
	var before: Vector3=game.ball.position
	game.begin_restart(kind,team,point)
	var recovery=game.set_pieces.recovery
	var taker: int=game.set_pieces.taker
	check(recovery.collector==collector,kind+": nearest player from either team collects the ball")
	check(game.players[taker].team==team,kind+": the restart still belongs to the awarded team")
	check(game.ball.position==before and not game.ball.pending_reset,kind+": assigning the collector preserves ball physics")
	var held := false
	var handoff := false
	var recollected := false
	var max_ball_step := 0.0
	var minimum_energy := 1.0
	var ready := false
	for frame in range(9000):
		before=game.ball.position
		game._physics_process(1.0/120)
		await physics_frame
		minimum_energy=minf(minimum_energy,game.players[collector].energy)
		held=held or game.ball.held_by==game.players[collector]
		handoff=handoff or recovery.relayed
		recollected=recollected or (handoff and recovery.phase=="retrieve" and game.flat_distance(game.ball.position,game.restart_point)>4)
		max_ball_step=maxf(max_ball_step,game.ball.position.distance_to(before))
		if game.state=="set_piece": ready=true; break
		if frame%1800==0: print("%s team=%d %.1fs worker=%d phase=%s ball=%s collector=%s taker=%s" % [kind,team,frame/120.0,recovery.worker,recovery.phase,game.ball.position,game.players[collector].position,game.players[taker].position])
	check(held and (handoff or collector==taker),kind+": collector picks up and delivers the actual ball")
	check(not recollected,kind+": returning players leave the delivered ball in place")
	check(minimum_energy>=0.27-0.00001 and not game.players[collector].stamina_free_movement,kind+": retrieval and return spend no stamina and leave no permanent exemption")
	check(max_ball_step<0.6,kind+": delivery never teleports the ball")
	check(ready and game.set_pieces.formation_ready(),kind+": delivery finishes with a legal protected restart")
	if kind=="TAÇ": check(game.ball.held_by==game.players[taker] and game.ball.position.y>1.7,"The correct thrower takes over and raises the delivered ball")
	if kind=="KALE VURUŞU": check(game.players[taker].keeper,"A nearby outfielder may fetch, but the designated goalkeeper still takes the goal kick")
	if ready:
		game.set_pieces.button=KEY_D if kind=="PENALTI" else KEY_S
		game.set_pieces.power=0.35
		game.set_pieces.commit()
		for frame in range(40):
			game._physics_process(1.0/120)
			await physics_frame
		check(game.state=="playing" and game.last_touch==team,kind+": lawful taker puts the delivered ball into play")
		var p=game.players[collector]
		p.energy=0.7
		p.exhausted=false
		p.desired=Vector3.RIGHT
		p.sprinting=false
		p.step(0.1)
		check(p.energy<0.7,kind+": normal stamina consumption resumes during play")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await scenario("TAÇ",0,17,Vector3(33,0.5,18),Vector3(32,0,18))
	await scenario("TAÇ",1,6,Vector3(-33,0.5,-18),Vector3(-32,0,-18))
	await scenario("SERBEST VURUŞ",0,18,Vector3(8,0.5,-28),Vector3(8,0,-28))
	await scenario("KORNER",1,3,Vector3(24,0.5,53),Vector3(31.6,0,49.6))
	await scenario("KALE VURUŞU",1,8,Vector3(-7,0.5,-53),Vector3(0,0,-45))
	await scenario("PENALTI",0,12,Vector3(-15,0.5,-35),Vector3(0,0,-39))
	await scenario("TAÇ",0,9,Vector3(33,0.5,-18),Vector3(32,0,-18))
	print("NEAREST COLLECTOR CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
