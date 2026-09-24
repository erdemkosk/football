extends "res://tests/keeper_balance_check.gd"
const DT := 1.0/120.0

func setup_keeper(team: int=1,weather: int=0):
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	game.match_menu.config_path="/tmp/sefc-keeper-handling.cfg"
	game.management.difficulty=1; game.weather.select(weather,true)
	game.goalkeeping.variation.seed=827
	for p in game.players:
		p.visible=false; p.collision_layer=0; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	var keeper=game.players[11 if team==1 else 0]
	keeper.visible=true; keeper.collision_layer=2; keeper.energy=1
	for attribute in ["reflexes","handling","positioning"]: keeper.attributes[attribute]=78
	var forward: float=game.attack_sign(team)
	keeper.position=Vector3(0,0,-forward*47.5); keeper.facing=Vector3(0,0,forward)
	keeper.rig.rotation=Vector3(0,PI if forward>0 else 0,0); keeper.animate(1)
	game.ball.freeze=true
	for frame in range(8): keeper.step(DT); await physics_frame
	game.kick_lock=0; game.last_touch=1-team; game.last_kicker=9 if team==1 else 20
	game.dribbler=-1; game.carrier=-1
	return keeper

func launch_header(keeper,distance: float,corner: float=0) -> void:
	var forward: float=game.attack_sign(keeper.team)
	var origin := Vector3(0,2.05,forward*(-50+distance))
	var aim := (Vector3(corner,0,-forward*50)-origin)*Vector3(1,0,1)
	game.ball.freeze=false; game.ball.place(origin,aim.normalized()*17+Vector3.DOWN*4.5)
	await physics_frame; await physics_frame

func prediction(team: int,weather: int) -> void:
	var keeper=await setup_keeper(team,weather)
	keeper.collision_layer=0
	await launch_header(keeper,14)
	var read: Dictionary=game.goalkeeping.shot_read(11 if team==1 else 0,1).duplicate()
	var previous: Vector3=game.ball.position
	var actual := Vector3.INF
	var bounced := false
	for frame in range(160):
		await physics_frame
		var point: Vector3=game.ball.position
		bounced=bounced or game.ball.ground_bounce_age<.05
		if (point.z-keeper.position.z)*(previous.z-keeper.position.z)<=0:
			actual=previous.lerp(point,(keeper.position.z-previous.z)/(point.z-previous.z)); break
		previous=point
	var error: float=absf(read.height-read.height_error-actual.y)
	print("BOUNCE READ team=",team," weather=",weather," error=",error," actual=",actual.y," read=",read.height)
	check(bounced and actual.is_finite() and error<.20,"Keeper predicts the height after a real turf bounce, team=%d weather=%d" % [team,weather])

func header_result(team: int,weather: int,distance: float,corner: float) -> Dictionary:
	var keeper=await setup_keeper(team,weather)
	var index := 11 if team==1 else 0
	await launch_header(keeper,distance,corner)
	var bounced := false
	var goal := false
	var caught := false
	for frame in range(300):
		game.kick_lock=maxf(0,game.kick_lock-DT)
		var target: Vector3=game.goalkeeping.update(index,DT)
		var move: Vector3=(target-keeper.position)*Vector3(1,0,1)
		keeper.desired=move.normalized()*clampf(move.length()/1.4,0,1)
		keeper.step(DT); await physics_frame
		bounced=bounced or game.ball.ground_bounce_age<.05
		if game.ball.held_by==keeper: caught=true; break
		if game.ball.position.z*game.attack_sign(team)<-50.22:
			goal=absf(game.ball.position.x)<3.44 and game.ball.position.y<2.22; break
		if frame>140 and game.ball.linear_velocity.z*game.attack_sign(team)>2: break
	if caught:
		var retained := true
		for frame in range(72):
			game.goalkeeping.update(index,DT); keeper.desired=Vector3.ZERO; keeper.step(DT)
			await physics_frame
			retained=retained and game.ball.held_by==keeper and game.ball.position.distance_to(keeper.hand_center())<.70
			retained=retained and game.ball.position.z*game.attack_sign(team)>-50.145
		check(retained,"A caught bouncing header stays secured during the recovery, team=%d weather=%d distance=%s" % [team,weather,distance])
	return {"goal":goal,"saved":game.saves[team]>0,"caught":caught,"bounced":bounced}

func grip() -> void:
	for speed in [12.0,18.0]:
		var keeper=await setup_keeper(0)
		keeper.collision_layer=0
		keeper.set_piece_pose="carry"; keeper.animate(1)
		game.ball.freeze=false; game.ball.place(keeper.hand_center(),Vector3.BACK*speed)
		await physics_frame; await physics_frame
		check(game.ball.linear_velocity.length()>speed*.85,"Grip fixture reaches the hands with its incoming shot momentum")
		var start: Vector3=game.ball.position
		game.ball.hold(keeper)
		check(game.ball.position==start,"Securing the ball applies grip without teleporting it")
		var worst := 0.0
		for frame in range(100):
			keeper.desired=Vector3.RIGHT*.3 if frame>30 else Vector3.ZERO
			keeper.step(DT); game.ball.hold_target=keeper.hand_center()
			await physics_frame
			worst=maxf(worst,game.ball.position.distance_to(keeper.hand_center()))
		print("GRIP speed=",speed," worst=",worst)
		check(game.ball.held_by==keeper and worst<.48,"A secured %d m/s ball stays at the gloves while the keeper moves" % int(speed))
		game.ball.strike(Vector3.FORWARD*12)
		await physics_frame; await physics_frame
		check(game.ball.held_by==null and game.ball.collision_mask==11 and game.ball.linear_velocity.z<-8,"A deliberate distribution releases the grip and restores collisions")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	for team in [0,1]:
		for weather in [0,2]: await prediction(team,weather)
	var goals := 0; var saves := 0; var catches := 0; var count := 0
	for team in [0,1]:
		for weather in [0,2]:
			for distance in [10.0,14.0]:
				for corner in [-1.2,1.2]:
					var result: Dictionary=await header_result(team,weather,distance,corner)
					goals+=int(result.goal); saves+=int(result.saved); catches+=int(result.caught); count+=1
					print("HEADER team=",team," weather=",weather," distance=",distance," corner=",corner," result=",result)
	print("BOUNCING HEADER MATRIX: shots=",count," goals=",goals," saves=",saves," caught=",catches)
	check(saves>=12 and goals<=3,"Reachable bouncing headers are usually saved on both ends in dry and wet conditions")
	check(catches>=8,"Routine bounced headers can be held instead of every contact becoming a parry")
	await grip()
	print("KEEPER HANDLING CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
