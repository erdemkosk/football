extends "res://tests/training_modes_check.gd"
func steer(world_direction: Vector3) -> void:
	var direction:=world_direction.normalized()
	game.controller.stick=Vector2(direction.dot(game.match_camera.ground_right()),-direction.dot(game.match_camera.ground_forward()))
	game.controller.using_gamepad=true
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_physics_process(false); game.set_process(false)
	game.match_menu.config_path="/tmp/sefc-training-playability.cfg"; game.controller.device=0
	game.start_match(true,false,false,"slalom")
	var ch=game.training_drills.challenges
	for frame in range(7200):
		var goal: Vector3=ch.target+Vector3.FORWARD*1.4
		steer(goal-game.players[9].position)
		await tick()
		if ch.finished: break
	game.controller.stick=Vector2.ZERO
	print("SLALOM actual controller movement points=",ch.points," completed=",ch.completed)
	check(ch.finished and ch.points>=400,"The full cone course can be completed with controller movement and physical dribbling")
	game.training_menu.hide(); game.training_menu.result={}
	game.start_match(true,false,false,"defending")
	var tackled:=false
	for frame in range(2800):
		if game.has_ball_control(9) and game.last_touch==0:
			steer(Vector3(1,0,-1))
		else:
			steer(game.ball.position-game.players[9].position)
			if game.flat_distance(game.players[9].position,game.ball.position)<1.6 and game.players[9].tackle_cooldown<=0:
				key(KEY_D); key(KEY_D,false); tackled=true
		await tick()
		if ch.completed>0: break
	game.controller.stick=Vector2.ZERO
	print("DEFENDING actual tackle points=",ch.points," completed=",ch.completed," tackled=",tackled)
	check(ch.completed==1 and ch.points>0,"A real tackle and controlled dribble can complete the defensive exercise")
	game.training_menu.hide(); game.training_menu.result={}
	game.start_match(true,false,false,"penalty"); await tick(20)
	check(ch.completed==0,"Settling the penalty ball does not consume an attempt")
	for attempt in range(6):
		pad(JOY_BUTTON_X,true); await tick(35); pad(JOY_BUTTON_X,false)
		for frame in range(2400):
			await tick()
			if ch.completed>attempt: break
		check(game.shots[0]==attempt+1 and ch.completed==attempt+1,"A controller penalty produces exactly one shot and one completed attempt: "+str(attempt+1))
		if attempt<5: await tick(145)
	check(ch.finished and game.training_menu.visible,"Six actual controller penalties reach the scored result")
	print("TRAINING PLAYABILITY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
