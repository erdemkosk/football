extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func scenario(team: int) -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	var side := 1.0 if team==0 else -1.0
	for i in range(22):
		game.players[i].position=Vector3(-side*(12+(i%4)*3),0,-30+(i%11)*5)
	var original := 8 if team==0 else 19
	var nearby := 17 if team==0 else 6
	game.players[original].position=Vector3(side*30,0,-19)
	game.players[nearby].position=Vector3(side*32,0,7)
	game.players[nearby].energy=0.3
	# A firm roll travels about 27 m with the new turf resistance.
	game.ball.place(Vector3(side*33,0.23,-20),Vector3(0,0,13))
	await physics_frame
	await physics_frame
	game.begin_restart("TAÇ",team,Vector3(side*32,0,-20))
	var recovery=game.set_pieces.recovery
	check(recovery.collector==original,"The whistle initially finds the player near the exit point")
	var selected := false
	var lifted_at := Vector3.ZERO
	var delivered := false
	var caught := false
	var ready := false
	var airborne_distance := 0.0
	var throw_from := Vector3.ZERO
	var collector_travel := 0.0
	var max_step := 0.0
	var initial_player: Vector3=game.players[original].position
	var minimum_energy := 0.3
	var seen_throw := false
	var captured := false
	var near_energy_at_selection := 0.3
	for frame in range(9000):
		var previous_phase: String=recovery.phase
		var ball_before: Vector3=game.ball.position
		game._physics_process(1.0/120)
		await physics_frame
		max_step=maxf(max_step,game.ball.position.distance_to(ball_before))
		if previous_phase=="watch" and recovery.phase=="retrieve":
			selected=true
			var minimum := INF
			for p in game.players:
				if p.visible: minimum=minf(minimum,game.flat_distance(p.position,game.ball.position))
			check(recovery.collector==nearby and recovery.collector!=original,"Collector changes to the player beside the ball's final position")
			check(game.flat_distance(game.players[nearby].position,game.ball.position)<=minimum+0.1,"Selection uses actual final ball proximity")
			check(game.players[original].position.distance_to(initial_player)<0.3,"Original player does not chase the rolling ball across the touchline")
			near_energy_at_selection=game.players[nearby].energy
		if game.ball.held_by==game.players[nearby] and lifted_at==Vector3.ZERO: lifted_at=game.players[nearby].position
		if lifted_at!=Vector3.ZERO and not recovery.relayed:
			collector_travel=maxf(collector_travel,game.players[nearby].position.distance_to(lifted_at))
		if recovery.phase=="receive":
			if not seen_throw: throw_from=game.ball.position; seen_throw=true
			airborne_distance=maxf(airborne_distance,game.ball.position.distance_to(throw_from))
			delivered=delivered or game.ball.held_by==null
		if "--visual" in OS.get_cmdline_user_args() and recovery.phase=="receive" and recovery.age>0.45 and not captured:
			captured=true
			var focus: Vector3=(game.players[nearby].position+game.players[game.set_pieces.taker].position)*0.5
			game.camera.size=42
			game.camera.position=focus+Vector3(-side*27,32,20)
			game.camera.look_at(focus)
			game.hud.queue_redraw()
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://tests/restart-relay-%d.png" % team)
		if seen_throw and game.ball.held_by==game.players[game.set_pieces.taker]: caught=true
		if selected: minimum_energy=minf(minimum_energy,game.players[nearby].energy)
		if game.state=="set_piece": ready=true; break
		if frame%1800==0: print("RELAY team=",team," phase=",recovery.phase," ball=",game.ball.position," collector=",recovery.collector," worker=",recovery.worker)
	check(selected and lifted_at!=Vector3.ZERO,"Nearest player actually bends down and picks up the ball")
	check(seen_throw and delivered and airborne_distance>10,"Ball is physically thrown over distance to the restart taker")
	check(collector_travel<3.5,"Collector does not carry the ball all the way back to the restart")
	check(caught and ready and game.ball.held_by==game.players[game.set_pieces.taker],"Lawful thrower receives the ball and finishes the restart preparation")
	check(minimum_energy>=minf(0.3,near_energy_at_selection)-0.0001,"Collection, throw and return consume no stamina")
	check(max_step<0.6,"No teleport occurs during collection or the throw")
	check(game.restart_team==team and game.state=="set_piece" and game.match_time==0,"Delivery does not start play or change restart ownership")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await scenario(0)
	await scenario(1)
	print("RESTART RELAY CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
