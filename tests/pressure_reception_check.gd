extends "res://tests/ai_attack_check.gd"

func received_ball(team: int,speed: float) -> void:
	setup()
	for p in game.players: p.visible=false; p.collision_layer=0
	var index := 6 if team==0 else 18
	player(index,Vector3.ZERO)
	var p=game.players[index]
	p.collision_layer=2; p.facing=Vector3.LEFT; p.rig.rotation.y=PI*.5; p.animate(1)
	game.dribbler=-1; game.carrier=-1; game.last_touch=team; game.last_kicker=8 if team==0 else 20
	game.ai_receivers[team]=-1; game.ai_pass_time[team]=0
	game.ball.freeze=false; game.ball.place(Vector3(-3,.23,0),Vector3.RIGHT*speed)
	await physics_frame; await physics_frame
	game.kick_lock=.16
	var received := false
	var peak := 0.0
	for frame in range(90):
		game.kick_lock=maxf(0,game.kick_lock-DT)
		p.desired=Vector3.ZERO; p.step(DT)
		game.update_contacts(DT)
		if game.dribbler==index: received=true
		await physics_frame
		if received: peak=maxf(peak,game.flat_distance(p.position,game.ball.position))
	check(received and game.dribbler==index and peak<1.35,"Team %d cushions a real %.0f m/s pass without requiring a named receiver" % [team,speed])
	if team==0: check(game.controlled==index,"A received real pass immediately belongs to the user")

func pursuit() -> void:
	setup()
	game.players[0].visible=false; game.players[2].visible=false
	player(9,Vector3(0,0,-7),Vector3.BACK*10)
	game.controlled=9; game.player_lock=true
	game.players[20].velocity=Vector3.BACK*4
	game.ball.freeze=false; game.ball.place(Vector3(0,.23,.65),Vector3.BACK*4)
	await physics_frame; await physics_frame
	game.dribbler=20; game.carrier=20; game.last_kicker=20
	var sprints := 0
	var lost_at := -1
	for frame in range(240):
		game.kick_lock=maxf(0,game.kick_lock-DT)
		game.ai_attack.update(DT); game.update_ai(DT)
		game.players[9].desired=((game.ball.position-game.players[9].position)*Vector3(1,0,1)).normalized()
		game.players[9].sprinting=true
		for i in [9,20]: game.players[i].step(DT)
		if game.players[20].active_sprint: sprints+=1
		game.kick_contact.prepare(DT); game.kick_contact.resolve(); game.update_contacts(DT)
		if game.dribbler==9 and lost_at<0: lost_at=frame
		await physics_frame
		if frame==150 and "--visual" in OS.get_cmdline_user_args():
			var centre: Vector3=game.players[20].position
			game.camera.position=centre+Vector3(12,13,20); game.camera.look_at(centre); game.camera.size=24
			game.hud.queue_redraw()
			await process_frame; await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("/tmp/sefc-pressure-pursuit.png")
	print("PURSUIT sprint_frames=",sprints," lost_at=",lost_at," owner=",game.dribbler," energy=",game.players[20].energy)
	check(sprints>60 and game.players[20].energy<.98,"A pursued carrier really sprints and pays the usual stamina cost")
	check(lost_at<0 or lost_at>180,"Running straight from midfield no longer catches a passive jogging carrier immediately")

func received_air(team: int) -> void:
	setup()
	for p in game.players: p.visible=false; p.collision_layer=0
	var index := 6 if team==0 else 18
	player(index,Vector3.ZERO)
	var p=game.players[index]
	p.collision_layer=2; p.facing=Vector3.LEFT; p.rig.rotation.y=PI*.5; p.animate(1)
	game.dribbler=-1; game.carrier=-1; game.last_touch=team; game.last_kicker=8 if team==0 else 20
	game.ball.freeze=false; game.ball.place(Vector3(-1.4,1.5,0),Vector3(18,-1,0))
	await physics_frame; await physics_frame
	game.kick_lock=.16
	var trapped := false
	for frame in range(180):
		game.kick_lock=maxf(0,game.kick_lock-DT)
		p.desired=Vector3.ZERO; p.step(DT); game.update_contacts(DT)
		if game.last_kicker==index and p.receive_style in ["chest","thigh"]: trapped=true
		await physics_frame
	check(trapped and game.dribbler==index and game.flat_distance(p.position,game.ball.position)<1.35,"Team %d cushions a descending cross with the body and gathers it at the feet" % team)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	setup(); player(6,Vector3(0,0,.5)); player(9,Vector3(0,0,1.4))
	game.controlled=9; game.dribbler=9; game.carrier=9
	game.team_control.select(9,true); game.team_control.cooldown=2
	game.players[6].touch_cooldown=.35; game.players[6].action_timer=.2
	game.team_control.touched(6); game.team_control.update(DT)
	check(game.controlled==6 and game.dribbler!=9 and game.carrier!=9,"A new touch clears stale possession instead of selecting the previous owner again")
	setup(); player(9,Vector3(0,0,1)); game.controlled=9; game.dribbler=9; game.carrier=9
	game.team_control.touched(20)
	check(game.dribbler==-1 and game.carrier==-1,"An opposing real touch also breaks the old carry constraint")

	setup(); player(9,Vector3(0,0,-7),Vector3.BACK*10)
	var fast: Dictionary=game.ai_attack.pressure_read(20)
	game.players[9].velocity=Vector3.ZERO
	var still: Dictionary=game.ai_attack.pressure_read(20)
	check(fast.urgency>still.urgency+.3 and fast.time<1,"A fast approaching presser is read before arriving at tackling distance")
	game.players[9].velocity=Vector3.BACK*10
	game.controlled=9; game.update_ai(DT)
	check(game.players[20].sprinting and game.players[20].desired.z>0,"An open escape lane makes the carrier accelerate away from the chase")
	game.players[20].energy=.1; game.players[20].exhausted=true
	game.update_ai(DT)
	check(not game.players[20].sprinting,"Pressure cannot give an exhausted carrier unlimited sprint")
	setup(); player(9,Vector3(0,0,7),Vector3.FORWARD*10)
	var escape: Vector3=game.ai_attack.carry_target(20)
	check(absf(escape.x)>2,"A head-on sprint makes the carrier choose a lateral escape instead of dribbling into it")
	setup(Vector3(0,0,-30)); player(9,Vector3(0,0,-23),Vector3.FORWARD*10)
	player(18,Vector3(11,0,-28))
	game.ai_attack.think_in[20]=.4
	var released := false
	for frame in range(36):
		game.ai_attack.update(DT)
		if game.ai_attack.act(20): released=true; break
	check(released and not game.kick_contact.pending.is_empty(),"A defender under an approaching press prepares a safe outlet before the challenge")
	if released:
		for frame in range(24):
			game.kick_contact.prepare(DT); game.players[20].step(DT); game.kick_contact.resolve()
		check(game.passes[1]==1 and game.last_kicker==20,"The escape pass still needs the normal physical boot contact")
	for team in [0,1]:
		for speed in [8.0,22.0]: await received_ball(team,speed)
		await received_air(team)
		setup()
		for p in game.players: p.visible=false
		var index := 6 if team==0 else 18
		player(index,Vector3(1.24,0,0))
		game.ball.position=Vector3(0,.23,0); game.ball.linear_velocity=Vector3.RIGHT*6
		var position: Vector3=game.ball.position
		check(game.first_touch.receive(index,true) and game.ball.position==position,"Team %d can cushion a routine near-foot stretch without teleporting the ball" % team)
		game.dribbler=-1; game.carrier=-1
		game.players[index].ball_actions.reset(game.players[index]); game.players[index].touch_cooldown=0
		game.ball.pending_touch=false; game.ball.position=Vector3(.8,.23,0); game.ball.linear_velocity=Vector3.RIGHT*33
		game.last_touch=1-team; game.ai_receivers[team]=-1
		game.update_contacts(DT)
		check(game.dribbler<0 and not game.ball.pending_touch,"Team %d cannot magnetically catch a point-blank full-power shot" % team)
	await pursuit()
	print("PRESSURE RECEPTION CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); await process_frame; quit(0 if failures==0 else 1)
