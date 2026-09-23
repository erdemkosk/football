extends "res://tests/defensive_pressure_check.gd"

func squad(owner: int=9,at: Vector3=Vector3.ZERO) -> void:
	setup()
	for i in range(22): player(i,game.players[i].home)
	player(owner,at); possession(owner); game.controlled=9
	game.opponent_coach.pressing=1

func close_duties() -> int:
	var count := 0
	for i in game.team_tactics.targets:
		if game.flat_distance(game.team_tactics.targets[i],game.ball.position)<3.3: count+=1
	return count

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
		game.skills.resolve(); game.duels.resolve(DT); game.rules.resolve_tackles(); game.defending.resolve(); game.kick_contact.resolve()
		game.update_contacts(DT); await physics_frame
		if game.last_touch!=team or (game.dribbler>=0 and game.players[game.dribbler].team!=team):
			return {"escaped":false,"tick":tick,"foul":game.state!="playing","load":peak_load,"physical":exception_ok}
		if game.state!="playing": break
	var kept: bool=game.dribbler==owner and game.flat_distance(p.position,game.ball.position)<1.7
	var passed: bool=(p.position-game.players[marker].position).dot(forward)>.3
	var separated: bool=game.flat_distance(p.position,game.players[marker].position)>2.2
	return {"escaped":kept and (passed or separated),"kept":kept,"passed":passed,"gap":game.flat_distance(p.position,game.players[marker].position),"foul":game.state!="playing","load":peak_load,"physical":exception_ok}

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-space-skill-balance.cfg"
	# The coach retains club style, with tactical exceptions for actual match state.
	squad(); game.clubs.selected[1]=0; game.opponent_coach.samples=30
	game.opponent_coach.review()
	check(game.opponent_coach.pressing==1,"Human possession alone does not turn a balanced club into relentless high pressure")
	game.clubs.selected[1]=2; game.opponent_coach.review()
	check(game.opponent_coach.pressing==0,"A deep-block club retains its own defensive identity")
	game.match_time=game.LENGTH*.8; game.score=[1,0]; game.opponent_coach.review()
	check(game.opponent_coach.pressing==2,"A losing opponent still presses aggressively late in the match")
	for team in [0,1]:
		squad(9 if team==0 else 20)
		game.team_tactics.update(.5)
		var spaced := true
		for i in game.team_tactics.targets:
			if game.team_tactics.roles[i] in ["press","press_support","contain"]: continue
			spaced=spaced and game.flat_distance(game.team_tactics.targets[i],game.ball.position)>=4.79
		check(spaced and close_duties()<=1,"Team %d faces one primary challenger while the other defenders cover from depth" % team)
	squad(9,Vector3(game.P.HALF_WIDTH-4,0,-4))
	player(17,game.ball.position+Vector3(-.2,0,-2)); player(18,game.ball.position+Vector3(-3,0,-3)); player(14,game.ball.position+Vector3(0,0,-7))
	game.opponent_coach.pressing=2; game.team_tactics.update(.5)
	check("press_support" in game.team_tactics.roles.values(),"A high-pressure touchline trap still recruits a second challenger")
	var max_burst := 0.0
	var burst := 0.0
	var rest_seen := false
	for tick in range(960):
		game.team_tactics.update(DT)
		if "press_support" in game.team_tactics.roles.values(): burst+=DT; max_burst=maxf(max_burst,burst)
		else: rest_seen=true; burst=0
	check(max_burst<1.75 and rest_seen,"Double pressure comes in bounded bursts with recovery, not a permanent pile-up")
	# No input reading and no speed/tackle buffs are added to make a skill work.
	defence(Vector3.ZERO,Vector3(0,0,-3)); player(14,Vector3(0,0,-2))
	game.opponent_coach.pressing=2; game.update_ai(.25)
	check(game.players[14].jockeying and not game.players[14].sprinting,"A close defender jockeys against a controlled slow dribble even in a high press")
	setup(); player(4,Vector3(1.8,0,0)); game.players[20].attributes.control=88
	var choice: Dictionary=game.ai_attack.skill_choice(20,game.ai_attack.pressure_read(20))
	check(not choice.is_empty() and choice.exit.x<0,"Opponent skills inspect the free exit rather than always turning toward the same pitch side")
	var actual: bool=game.ai_attack.act(20)
	check(actual and game.skills.active.has(20),"An isolated technical opponent can execute the same physical skill as the user")
	check(game.ai_attack.team_skill_in[1]>=.8 and game.ai_attack.skill_in[20]>=2.2,"Shared team and player recovery prevent immediate skill spam")
	check(game.ai_attack.skill_choice(20,game.ai_attack.pressure_read(20)).is_empty(),"A second skill is not requested on the next AI decision")
	setup(); player(4,Vector3(1.8,0,0)); player(5,Vector3(-1.8,0,0)); player(18,Vector3(0,0,-10))
	game.players[20].attributes.control=88
	check(game.ai_attack.skill_choice(20,game.ai_attack.pressure_read(20)).is_empty() and kind() in ["pass","driven_pass"],"Surrounded AI recycles to the free teammate instead of forcing a trick through two players")
	setup(); player(4,Vector3(1.8,0,0)); game.skills.start(20,"roll",1)
	game.dribbler=4; game.carrier=4; game.skills.update(DT)
	check(game.skills.active.is_empty() and game.players[20].skill_move.is_empty() and not game.players[20] in game.ball.get_collision_exceptions(),"Losing possession cancels the skill and restores the old carrier's body collision")
	setup(); game.skills.start(20,"roulette",1); game.skills.reset()
	check(not game.players[20] in game.ball.get_collision_exceptions(),"Restart/reset removes skill collision exemptions")
	game.ai_attack.decisions.game=game
	for move in ["rainbow","heel","flick"]:
		check(is_finite(game.ai_attack.decisions.value(20,{"kind":move})),"AI valuation safely handles "+move)
	var wins := 0
	var losses := 0
	for entry in [["roll",3.4,1.0,false,0],["elastico",3.4,1.0,false,0],["roulette",3.4,1.0,false,0],["roll",2.7,1.0,false,0],["roll",1.05,1.0,false,0],["roll",3.4,1.0,true,0],["roll",3.4,-1.0,false,1]]:
		var result: Dictionary=await skill_duel(entry[0],entry[1],entry[2],entry[3],entry[4])
		print("SKILL DUEL ",entry," ",result)
		wins+=int(result.escaped); losses+=int(not result.escaped)
		check(result.physical,"Only the carrier's coarse capsule is exempt; every opponent remains a physical obstacle")
		if entry[0]=="roll" and entry[1]>3 and not entry[3]:
			check(result.get("kept",false) and not result.foul,"A clean lateral touch preserves control without requiring an automatic beaten defender for team %d" % (1-int(entry[4])))
		elif entry[1]<1.2:
			check(not result.escaped,"An occupied exit or late input cannot guarantee a successful skill")
		elif entry[3]:
			check(not result.escaped or result.load>0,"An occupied exit must be contested through real defensive movement")
		elif entry[0]=="elastico":
			check(result.get("kept",false) and result.load>0,"An outside-inside exit makes the marker plant while retaining normal ball control")
	check(wins>=2 and losses>=2,"Live one-on-ones allow timed skill escapes, while late or crowded attempts remain contestable")
	print("SPACE AND SKILL BALANCE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
