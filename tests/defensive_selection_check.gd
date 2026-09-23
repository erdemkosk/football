extends "res://tests/team_control_check.gd"

func defence() -> void:
	setup()
	game.team_control.reset(); game.controlled=9
	game.match_camera.select("pitch"); game.update_camera(0)
	for p in game.players:
		p.visible=false; p.dismissed=false; p.action_timer=0; p.touch_cooldown=0
		p.energy=1; p.exhausted=false; p.active_sprint=false; p.sprinting=false
	place(9,Vector3(0,0,6))
	place(6,Vector3(0,0,2.2))
	place(17,Vector3(0,0,-.65))
	game.dribbler=17; game.carrier=17; game.last_touch=1; game.last_kicker=17
	game.ball.position=Vector3(0,.23,0)

func place(index: int,point: Vector3) -> void:
	var p=game.players[index]
	p.visible=true; p.position=point; p.facing=Vector3.FORWARD
	p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO

func advance(seconds: float) -> void:
	for frame in range(ceili(seconds*120)): game.team_control.update(1.0/120)

func screenshot() -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.camera.position=Vector3(0,28,18); game.camera.look_at(Vector3.ZERO); game.camera.size=32
	for i in range(game.players.size()):
		game.players[i].chosen=i==game.controlled
		game.players[i].marker.visible=i==game.controlled
	game.hud.queue_redraw()
	await process_frame; await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-defensive-selection.png")

func live_run(half: int) -> void:
	defence(); game.half=half
	var forward: float=game.attack_sign(1)
	place(9,Vector3(0,0,-3*forward)); place(6,Vector3(3,0,4*forward))
	place(7,Vector3(3,0,11*forward)); place(17,Vector3.ZERO)
	var runner=game.players[17]
	runner.facing=Vector3(0,0,forward); runner.velocity=runner.facing*6
	runner.rig.rotation.y=atan2(-runner.facing.x,-runner.facing.z)
	for p in game.players: p.collision_layer=2 if p.visible else 0; p.collision_mask=1
	game.ball.freeze=false; game.ball.place(Vector3(0,.23,.65*forward),runner.velocity)
	await physics_frame; await physics_frame
	var sequence: Array[int]=[]
	var lost := false
	for frame in range(360):
		game.team_control.update(1.0/120)
		if sequence.is_empty() or sequence.back()!=game.controlled: sequence.append(game.controlled)
		game.update_control(1.0/120)
		runner.desired=Vector3(0,0,forward)
		for p in game.players:
			if p.visible: p.step(1.0/120)
		game.update_contacts(1.0/120)
		if game.dribbler!=17: lost=true
		await physics_frame
	print("LIVE DEFENCE half=",half," sequence=",sequence," runner=",runner.position," ball=",game.ball.position)
	check(not lost and sequence.has(6) and game.controlled==7 and sequence.size()<=3,"A live dribbler passes between defensive zones with timely stable selection, half %d" % half)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-defensive-selection.cfg"
	defence(); advance(.15)
	check(game.controlled==6,"Defence selects a nearby challenger while the old selection is still within eight metres")
	place(7,Vector3(5,0,3)); await screenshot()
	defence(); game.players[9].position.z=3.2; game.players[6].position.z=1.65
	advance(.12)
	check(game.controlled==6,"A player within tackling range takes over without needing a five-metre advantage")
	defence(); game.team_control.cooldown=.75; game.team_control.touch_hold=.18
	game.players[6].position.z=1.4; advance(.05)
	check(game.controlled==6,"An opponent takeover overrides stale automatic possession grace when a tackle is available")
	defence(); game.players[9].position=Vector3(-2.5,0,0); game.players[6].position=Vector3(2.5,0,0)
	var changes := 0
	for frame in range(480):
		game.players[6].position.x=2.5+sin(frame*.31)*.12
		var before: int=game.controlled
		game.team_control.update(1.0/120)
		if before!=game.controlled: changes+=1
	check(changes==0,"Small distance oscillations never bounce the cursor between equally useful defenders")
	defence(); game.team_control.cooldown=.65; game.players[6].position.z=1.3
	advance(.05)
	check(game.controlled==6,"A clear nearby emergency is not blocked by an earlier automatic switch cooldown")
	defence(); game.players[9].position.z=-3; game.players[9].velocity=Vector3.FORWARD*5
	game.players[6].position.z=4; game.players[17].velocity=Vector3.BACK*8
	game.ball.linear_velocity=Vector3.BACK*8; advance(.18)
	check(game.controlled==6,"A beaten defender moving away gives way to the nearby defender ahead of the runner")
	defence(); game.players[9].action_timer=1.2; game.players[9].pose="fall"; advance(.02)
	check(game.controlled==6,"A fallen selected player cannot lock automatic switching until the recovery animation ends")
	defence(); game.players[6].action_timer=.8; game.players[6].pose="fall"
	place(7,Vector3(0,0,3)); place(8,Vector3(0,0,.4)); game.players[8].dismissed=true
	place(0,Vector3(0,0,.1)); advance(.15)
	check(game.controlled==7,"Automatic defence excludes a downed player, a dismissed player and the goalkeeper")
	defence(); game.players[9].position.z=1.1; game.players[9].action_timer=.25; game.players[9].pose="poke"
	game.players[6].position=Vector3(.7,0,0); advance(.12)
	check(game.controlled==9,"An active close standing tackle is allowed to finish without a cursor jump")
	defence(); game.defending.pressing=true; game.defending.presser=6; advance(.5)
	check(game.controlled==9,"Calling a second presser preserves the user's deliberate covering player")
	game.defending.pressing=false; game.defending.presser=-1; advance(.15)
	check(game.controlled==6,"Releasing second-man pressure restores automatic proximity selection")
	for family in ["Xbox Controller","DualSense"]:
		defence(); game.players[9].position=Vector3(8,0,0); game.players[6].position=Vector3(1.8,0,0)
		place(7,Vector3(8,0,-18)); game.controller.adopt_device(0,family)
		game.controller.stick=Vector2(0,-1)
		check(game.team_control.next_switch()==6,family+" preview identifies the actual next shoulder selection")
		button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_LEFT_SHOULDER,false)
		check(game.controlled==6,family+" shoulder selects near the ball independently of the left-stick running direction")
		button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_LEFT_SHOULDER,false)
		check(game.controlled==9,family+" repeated shoulder press immediately chooses the next viable nearby defender")
		advance(.5)
		check(game.controlled==9,family+" deliberate shoulder choice is not immediately undone by automation")
		game.team_control.touched(6)
		check(game.controlled==6,family+" a real teammate touch still overrides the manual choice immediately")
	defence(); game.players[9].position=Vector3(8,0,0); game.players[6].position=Vector3(1.8,0,0)
	place(7,Vector3(8,0,-18)); game.defending.switch_direction(Vector3.FORWARD); advance(.5)
	check(game.controlled==7,"Explicit directional switching still reaches a distant chosen teammate and preserves that choice")
	defence(); game.players[9].position=Vector3(8,0,0); game.players[6].position=Vector3(1.8,0,0)
	place(7,Vector3(8,0,-18)); game.controller.stick=Vector2(0,-1)
	var key := InputEventKey.new(); key.keycode=KEY_Q; key.physical_keycode=KEY_Q; key.pressed=true
	game._input(key)
	check(game.controlled==6,"Keyboard Q uses the same nearby choice as the controller shoulder")
	defence(); game.requested_receiver=9; game.charging=true; game.charge=.5; advance(.15)
	check(game.controlled==6 and not game.charging and game.requested_receiver<0,"An opponent takeover clears a stale attacking input that would block defensive selection")
	defence(); game.dribbler=-1; game.carrier=-1; game.players[6].position.z=1.8; advance(.15)
	check(game.controlled==6,"A loose slow ball selects its nearby receiver before physical contact")
	defence(); game.dribbler=-1; game.carrier=-1; game.ball.linear_velocity=Vector3.BACK*18
	game.players[9].position.z=-2; game.players[6].position=Vector3(3,0,9); advance(.15)
	check(game.controlled==6,"An opponent through ball chooses the interception path instead of the player it has already passed")
	game.team_control.select(9,true); game.players[9].action_timer=1; game.players[9].pose="fall"
	game.team_control.update(1.0/120)
	check(game.controlled==6,"A downed manual selection cannot trap the cursor during an opponent pass")
	defence(); game.controller.stick=Vector2(1,0); advance(.15); game.update_control(1.0/120)
	check(game.controlled==6 and game.players[6].desired.x>.9,"The new selection immediately responds to the user's movement")
	defence(); game.dribbler=6; game.last_touch=0; advance(.02)
	check(game.controlled==6,"Real own possession remains authoritative over defensive proximity")
	for mode in ["player_lock","training","restart"]:
		defence()
		if mode=="player_lock": game.player_lock=true
		elif mode=="training": game.training=true; game.training_drills.mode="cross"
		else: game.state="restart"
		advance(.3)
		check(game.controlled==9,"Defensive automation respects "+mode)
	check(game.passes[0]==0 and game.shots[0]==0,"Selection assistance never performs the user's pass or shot")
	await live_run(1); await live_run(2)
	print("DEFENSIVE SELECTION CHECK: %d failures" % failures)
	game.free(); await process_frame; quit(1 if failures else 0)
