extends "res://tests/space_skill_balance_check.gd"
func skill_duel(move: String,gap: float,side: float=1,blocked: bool=false,team: int=0) -> Dictionary:
	defence()
	for p in game.players: p.visible=false
	var owner := 9 if team==0 else 20
	var marker := 14 if team==0 else 4
	var forward := Vector3(0,0,game.attack_sign(team))
	var exit: Vector3=game.skills.exit_direction(move,forward,side) if move!="" else forward
	player(owner,Vector3.ZERO); player(marker,forward*gap,-forward*4)
	game.controlled=owner; game.players[owner].attributes.control=90
	game.players[owner].facing=forward
	if blocked: player(marker+1,exit*2.0)
	for p in game.players:
		p.collision_layer=2 if p.visible else 0; p.collision_mask=3
		p.body_language.enabled=false
	game.ball.freeze=false; game.ball.place(forward*.55+Vector3.UP*game.ball.GROUND_HEIGHT)
	await physics_frame; await physics_frame
	game.dribbler=owner; game.carrier=owner; game.last_kicker=owner; game.last_touch=team; game.kick_lock=0
	if move!="": check(game.skills.start(owner,move,side),"Shared skill starts for team %d: %s at %.2fm" % [team,move,gap])
	var p=game.players[owner]
	var peak_load := 0.0
	var exception_ok := true
	for tick in range(180):
		p.desired=exit; p.sprinting=not game.skills.active.has(owner)
		game.kick_lock=maxf(0,game.kick_lock-DT)
		game.ai_attack.update(DT); game.update_ai(DT)
		game.skills.update(DT); game.physical_contests.update(DT); game.kick_contact.prepare(DT)
		for q in game.players:
			if q.visible: q.step(DT)
		peak_load=maxf(peak_load,game.players[marker].defensive_turn_load)
		if game.skills.active.has(owner):
			exception_ok=exception_ok and p in game.ball.get_collision_exceptions() and not game.players[marker] in game.ball.get_collision_exceptions()
		game.duels.resolve(DT); game.rules.resolve_tackles(); game.defending.resolve(); game.kick_contact.resolve()
		game.update_contacts(DT); await physics_frame
		if tick%10==0 or game.last_touch!=team: print("TRACE ",tick," p=",p.position," v=",p.velocity," ball=",game.ball.position," marker=",game.players[marker].position," mpose=",game.players[marker].pose," mtimer=",game.players[marker].action_timer," owner=",game.dribbler," bv=",game.ball.linear_velocity)
		if game.last_touch!=team or (game.dribbler>=0 and game.players[game.dribbler].team!=team):
			return {"escaped":false,"tick":tick,"foul":game.state!="playing","load":peak_load,"physical":exception_ok}
		if game.state!="playing": break
	var kept: bool=game.dribbler==owner and game.flat_distance(p.position,game.ball.position)<1.7
	var passed: bool=(p.position-game.players[marker].position).dot(forward)>.3
	var separated: bool=game.flat_distance(p.position,game.players[marker].position)>2.2
	return {"escaped":kept and (passed or separated),"kept":kept,"passed":passed,"gap":game.flat_distance(p.position,game.players[marker].position),"foul":game.state!="playing","load":peak_load,"physical":exception_ok}

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	print(await skill_duel("roll",3.4))
	quit()
