extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(false,false)
	game.set_physics_process(false)
	# Reproduce a real-match corner-of-net recovery and a returning midfielder
	# walking directly into an already settled opponent.
	game.players[3].position=Vector3(4.461738,0,53.18525)
	game.players[18].position=Vector3(9.411258,0,10.51764)
	game.ball.place(Vector3(3.445474,0.23,52.18265))
	await physics_frame
	await physics_frame
	game.begin_restart("SANTRA",0,Vector3.ZERO)
	print("TAKER ",game.set_pieces.taker)
	var ready := false
	for frame in range(7200):
		game._physics_process(1.0/120)
		await physics_frame
		if frame%1200==0: print("CORNER %.1f phase=%s taker=%s ball=%s midfielder=%s" % [frame/120.0,game.set_pieces.recovery.phase,game.players[game.set_pieces.taker].position,game.ball.position,game.players[18].position])
		if game.state=="set_piece": ready=true; break
	print("PASS: Inside back-corner recovery and obstructed return reach a legal kickoff" if ready else "FAIL: Kickoff corner recovery stalled")
	game.free()
	quit(0 if ready else 1)
