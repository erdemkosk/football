extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.pressed=true
	game._input(event)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match()
	game.set_physics_process(false)
	check(game.state=="ceremony" and game.ceremony.officials.size()==3,"Match starts with a ceremony led by three officials")
	var in_tunnel := true
	for p in game.players:
		in_tunnel=in_tunnel and p.position.x>=41 and absf(p.position.z)<1.2 and p.visible
	check(in_tunnel,"All 22 footballers begin in two tunnel queues")
	var previous: Array[Vector3]=[]
	for p in game.players: previous.append(p.position)
	var seen: Array[String]=[]
	var max_step := 0.0
	for frame in range(14400):
		var phase: String=game.ceremony.phase
		if not phase in seen:
			seen.append(phase)
			print("CEREMONY %.1fs %s" % [frame/120.0,phase])
			if phase=="presentation":
				var aligned := true
				for i in range(22): aligned=aligned and game.flat_distance(game.players[i].position,game.ceremony.lineup[i])<0.25
				check(aligned,"Both full teams reach their presentation lines by walking")
		if frame==180:
			var elapsed: float=game.ceremony.elapsed
			var position: Vector3=game.players[9].position
			key(KEY_ESCAPE)
			for tick in range(60): game._physics_process(1.0/120)
			check(game.state=="paused" and game.ceremony.elapsed==elapsed and game.players[9].position==position,"Pause freezes the walkout and resumes the same sequence")
			key(KEY_ESCAPE)
		game._physics_process(1.0/120)
		await physics_frame
		for i in range(22):
			max_step=maxf(max_step,previous[i].distance_to(game.players[i].position))
			previous[i]=game.players[i].position
		if game.state=="restart": break
		if frame%2400==0: print("phase=%s age=%.1f first=%s last=%s" % [game.ceremony.phase,game.ceremony.age,game.players[9].position,game.players[21].position])
	check(game.state=="restart" and game.restart_type=="SANTRA" and game.set_pieces.recovery.phase=="arrange" and "presentation" in seen and "formation" in seen,"The complete walkout reaches a protected kickoff with the ball already placed")
	check(max_step<0.16,"Unskipped ceremony moves continuously without teleporting players")
	check(game.match_time==0 and game.score==[0,0],"The match clock and score do not advance during the ceremony")
	var ready := true
	for i in range(22):
		var p=game.players[i]
		ready=ready and not p.prematch and p.energy==1 and p.collision_layer==2 and game.flat_distance(p.position,game.ceremony.kickoff[i])<0.25
	check(ready and game.ball.active and game.ball.visible,"Kickoff restores full stamina, legal formation, collisions and the real ball")
	for frame in range(600):
		game._physics_process(1.0/120)
		await physics_frame
		if game.state=="set_piece": break
	check(game.state=="set_piece" and game.match_time==0 and game.set_pieces.formation_ready(),"The unskipped ceremony settles into a legal kickoff without starting the clock")
	for stop in ["walkout","presentation","formation"]:
		game.start_match()
		game.ceremony.phase=stop
		key(KEY_SPACE)
		for frame in range(30):
			game._physics_process(1.0/120)
			await physics_frame
		check(game.state=="set_piece" and game.restart_type=="SANTRA" and game.ceremony.phase=="" and game.ball.active,"One Space press skips safely to the opening kickoff from "+stop)
	game.start_match()
	game.ceremony.phase="presentation"
	key(KEY_ENTER)
	for frame in range(30):
		game._physics_process(1.0/120)
		await physics_frame
	check(game.state=="set_piece" and game.restart_type=="SANTRA" and game.ceremony.phase=="" and game.ball.active,"Enter skips the ceremony the same way as Space")
	game.start_match()
	game.return_menu()
	check(game.state=="menu" and game.ceremony.phase=="" and not game.ceremony.officials[0].prematch,"Returning to the menu ends the ceremony and restores exhibition officials")
	game.start_match(true)
	check(game.state=="playing" and game.training,"Practice starts immediately without the match ceremony")
	game.free()
	print("CEREMONY CHECK: %d failures" % failures)
	quit(0 if failures==0 else 1)
