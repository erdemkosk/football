extends "res://tests/defensive_pressure_check.gd"

func close_duel(in_box: bool,turning: bool,side: float=1) -> Dictionary:
	var origin := Vector3(0,0,-38 if in_box else 0)
	defence(origin); game.management.difficulty=1
	player(14,origin+Vector3(0,0,-2.5))
	for p in game.players:
		p.collision_layer=2 if p.visible else 0; p.collision_mask=3
		p.body_language.enabled=false
	game.ball.freeze=false; game.ball.place(origin+Vector3(0,game.ball.GROUND_HEIGHT,-.55))
	await physics_frame; await physics_frame
	game.dribbler=9; game.carrier=9; game.kick_lock=0
	var attempts := 0
	var previous_poke := false
	for tick in range(600):
		var p=game.players[9]
		var angle: float=tick*DT*5.0*side
		p.desired=Vector3(sin(angle),0,-cos(angle))*.45 if turning else Vector3.ZERO
		p.sprinting=false
		game.kick_lock=maxf(0,game.kick_lock-DT)
		game.ai_attack.update(DT); game.update_ai(DT)
		game.physical_contests.update(DT); game.kick_contact.prepare(DT)
		for q in game.players:
			if q.visible: q.step(DT)
		if "--trace" in OS.get_cmdline_user_args() and not turning and game.duels.attempts.get(14,-1.0)>.11:
			var defender=game.players[14]
			var boot: Vector3=(defender.left_knee if defender.tackle_foot==0 else defender.right_knee).to_global(defender.ball_actions.BOOT)
			print("POKE CONTACT gap=",defender.position.distance_to(game.ball.position)," boot=",boot.distance_to(game.ball.position)," defender=",defender.position," ball=",game.ball.position," boot_position=",boot)
		game.duels.resolve(DT); game.rules.resolve_tackles()
		game.defending.resolve(); game.kick_contact.resolve()
		var poke: bool=game.players[14].pose=="poke" and game.players[14].action_timer>0
		if poke and not previous_poke: attempts+=1
		previous_poke=poke
		if game.state!="playing": return {"won":false,"foul":true,"attempts":attempts}
		game.update_contacts(DT); await physics_frame
		if game.last_touch==1: return {"won":true,"foul":false,"attempts":attempts}
	return {"won":false,"foul":false,"attempts":attempts}

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/close-turn-settings.tmp"
	for box in [false,true]:
		var stationary := await close_duel(box,false)
		print("STATIONARY box=",box," ",stationary)
		check(stationary.won and not stationary.foul,"A defender can reach an unprotected stationary ball without fouling, box=%s" % box)
		var wins := 0
		var fouls := 0
		for side in [-1.0,1.0]:
			var result := await close_duel(box,true,side)
			print("CIRCLE box=",box," side=",side," ",result)
			wins+=int(result.won); fouls+=int(result.foul)
		check(wins>=1 and fouls==0,"Repeated tight circles expose a clean challenge without guaranteed wins on every turn, box=%s" % box)
	print("CLOSE TURN DEFENCE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
