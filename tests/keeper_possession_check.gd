extends "res://tests/ai_attack_check.gd"

func fixture(team: int,half: int,depth: float) -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-keeper-possession.cfg"
	setup(); game.half=half; game.menu_match.running=true
	for p in game.players: p.visible=false
	var forward: float=game.attack_sign(team)
	var index := team*11
	player(index,Vector3(0,0,forward*(-50+depth)))
	player(index+4,Vector3(12,0,forward*(-30+depth)))
	var keeper=game.players[index]
	keeper.rig.rotation.y=PI if forward>0 else 0
	keeper.animate(1)
	for tick in range(8): keeper.step(DT); await physics_frame
	game.last_touch=team; game.last_kicker=index+4
	game.dribbler=-1; game.carrier=-1
	game.ball.release_hold(); game.ball.pending_reset=false; game.ball.pending_kick=false
	game.ball.pending_touch=false; game.ball.linear_velocity=Vector3.ZERO
	game.kick_lock=0

func hands(team: int,half: int) -> void:
	await fixture(team,half,4)
	var index := team*11
	var keeper=game.players[index]
	var forward: float=game.attack_sign(team)
	var label := "team=%d half=%d" % [team,half]
	keeper.set_piece_pose="carry"; keeper.animate(1)
	game.ball.position=keeper.hand_center()
	game.last_touch=1-team; game.last_kicker=(1-team)*11+9
	game.update_ai(DT)
	check(game.ball.held_by==keeper and keeper.desired.is_zero_approx(),"The catch frame already cancels the previous positioning movement: "+label)
	# Possession is authoritative even if the keeper's cached mode is stale.
	game.goalkeeping.holding=-1
	game.update_ai(DT)
	check(keeper.desired.is_zero_approx() and game.goalkeeping.holding==index,"A held ball immediately overrides the return-to-goal target: "+label)
	# A nearby player used to make generic spacing walk the keeper backwards.
	player(index+4,keeper.position+Vector3(0,0,forward*.8))
	game.goalkeeping.holding=index; game.goalkeeping.hold_age=0
	game.update_ai(DT)
	check(keeper.desired.is_zero_approx() and not keeper.sprinting,"A crowded keeper stays set while teammates clear the gloves: "+label)
	var start: Vector3=keeper.position
	for tick in range(72):
		game.update_ai(DT)
		for p in game.players:
			if p.visible: p.step(DT)
		await physics_frame
	check(game.flat_distance(keeper.position,start)<.05 and game.ball.held_by==keeper,"Holding the ball does not produce an unrequested retreat over time: "+label)
	# Manual movement must still belong to the user.
	game.menu_match.running=false; game.controlled=index
	keeper.desired=Vector3.RIGHT*.3; keeper.sprinting=true
	game.goalkeeping.update(index,DT)
	check(keeper.desired==Vector3.RIGHT*.3 and keeper.sprinting,"Human keeper movement remains under player control: "+label)
	# Player-lock users still need to be able to call for the held ball.
	game.controlled=index+4; game.player_lock=true
	player(index+4,keeper.position+Vector3(10,0,forward*14))
	keeper.touch_cooldown=0; keeper.action_timer=0
	game.requested_receiver=index+4; game.request_age=1; game.request_time=2
	game.request_lob=false; game.request_through=false
	game.update_ai(DT)
	check(game.ball.held_by==null and game.ball.pending_kick and game.passes[team]==1,"Staying set still allows an outfielder's explicit pass request: "+label)
	game.free(); await physics_frame

func feet(team: int,half: int,depth: float) -> void:
	await fixture(team,half,depth)
	var index := team*11
	var keeper=game.players[index]
	var forward: float=game.attack_sign(team)
	var label := "team=%d half=%d depth=%s" % [team,half,depth]
	var start: Vector3=keeper.position
	game.ball.position=keeper.position+Vector3(0,game.ball.GROUND_HEIGHT,forward*.65)
	keeper.touch_cooldown=.18
	game.update_ai(DT)
	check(keeper.desired.is_zero_approx(),"A reachable back pass holds the keeper at the ball during touch recovery: "+label)
	game.ball.freeze=false
	var kicked := false
	var furthest_back := 0.0
	for tick in range(96):
		game.kick_lock=maxf(0,game.kick_lock-DT)
		game.update_ai(DT); game.kick_contact.prepare(DT)
		for p in game.players:
			if p.visible: p.step(DT)
		game.kick_contact.resolve()
		furthest_back=maxf(furthest_back,-(keeper.position-start).z*forward)
		if game.ball.pending_kick and game.last_kicker==index: kicked=true; break
		await physics_frame
	check(kicked and game.ball.held_by==null and game.passes[team]==1,"Keeper plays a real foot pass inside or outside the penalty area: "+label)
	check(furthest_back<.25,"Keeper stays with the ball until actual boot contact: "+label)
	await physics_frame; await physics_frame
	game.ball.position=Vector3(10,.23,0); game.ball.linear_velocity=Vector3.ZERO
	game.kick_contact.reset(); game.ball.pending_kick=false
	keeper.touch_cooldown=0; keeper.action_timer=0
	var target: Vector3=game.goalkeeping.update(index,DT)
	check((target-keeper.position).z*forward<0,"After releasing possession the keeper recovers toward goal: "+label)
	game.free(); await physics_frame

func run() -> void:
	for team in [0,1]:
		for half in [1,2]:
			await hands(team,half)
			for depth in [10.0,20.0]: await feet(team,half,depth)
	print("KEEPER POSSESSION CHECK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
