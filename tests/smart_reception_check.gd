extends "res://tests/team_control_check.gd"

func delivery() -> void:
	setup()
	game.team_control.reset(); game.dribbler=-1; game.carrier=-1
	game.controlled=6; game.last_touch=0; game.last_kicker=9
	game.ai_receivers[0]=6; game.ai_pass_time[0]=3
	game.players[6].position=Vector3.ZERO; game.players[6].velocity=Vector3.ZERO
	game.players[6].active_sprint=false; game.players[6].energy=1
	game.players[6].exhausted=false
	game.ball.position=Vector3(0,game.ball.GROUND_HEIGHT,-8)
	game.ball.linear_velocity=Vector3.FORWARD*10
	game.team_control.predicted_receiver=6
	game.team_control.predicted_point=Vector3(0,0,-6)
	game.team_control.predicted_time=.65
	game.controller.using_gamepad=true; game.controller.stick=Vector2.ZERO
	game.controller.held.clear(); game.match_camera.select("pitch"); game.update_camera(0)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	delivery()
	var p=game.players[6]
	p.velocity=Vector3.FORWARD*4
	var toward: float=game.team_control.arrival_time(6,Vector3(0,0,-8))
	p.velocity=Vector3.BACK*4
	check(game.team_control.arrival_time(6,Vector3(0,0,-8))>toward+.2,"Selection distinguishes a runner facing the pass from one moving away")
	p.velocity=Vector3.ZERO
	var fresh: float=game.team_control.arrival_time(6,Vector3(0,0,-10))
	p.exhausted=true
	check(game.team_control.arrival_time(6,Vector3(0,0,-10))>fresh,"Arrival prediction respects exhaustion")
	delivery()
	game.team_control.run_receiver=6; game.team_control.run_target=Vector3(15,0,-20)
	game.update_control(1.0/120)
	check(p.desired.z<-.8 and absf(p.desired.x)<.01 and p.sprinting,"Receiver sprints to the live interception instead of the old through-pass destination")
	game.controller.stick=Vector2.RIGHT
	game.update_control(1.0/120)
	check(p.desired.dot(game.movement_input().normalized())>.99 and not p.sprinting,"Manual direction immediately replaces the automatic run and sprint")
	game.controller.stick=Vector2.ZERO
	game.team_control.predicted_point=Vector3(0,0,-.35)
	game.update_control(1.0/120)
	check(not p.sprinting and p.desired.length()<.6,"Receiver brakes near the meeting point")
	game.dribbler=6; game.update_control(1.0/120)
	check(p.desired.length()<.01 and not p.sprinting,"Automatic approach stops when possession is secured")
	# Real rolling pass: no selection, movement or velocity is forced after launch.
	delivery()
	for q in game.players: q.visible=false; q.collision_layer=0
	p.visible=true; p.position=Vector3(3.0,0,-8); p.facing=Vector3.FORWARD
	game.players[9].visible=true; game.players[9].position=Vector3(15,0,8)
	game.controlled=9; game.team_control.reset()
	game.ball.freeze=false; game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,0),Vector3.FORWARD*12)
	await physics_frame; await physics_frame
	var touched := false
	var closest := INF
	for tick in range(360):
		var dt: float=Engine.time_scale/Engine.physics_ticks_per_second
		game.team_control.update(dt); game.update_control(dt)
		p.step(dt); game.update_contacts(dt)
		await physics_frame
		closest=minf(closest,game.flat_distance(p.position,game.ball.position))
		if game.dribbler==6: touched=true; break
	check(game.controlled==6,"Live pass selects its reachable receiver automatically")
	check(touched and closest<1.2,"Neutral input automatically runs into a real rolling pass and controls it")
	print("SMART RECEPTION CHECK: failures=",failures)
	game.free(); quit(1 if failures else 0)
