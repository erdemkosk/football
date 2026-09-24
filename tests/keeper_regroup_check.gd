extends "res://tests/ai_attack_check.gd"

func regroup(team: int,half: int,formation: int) -> void:
	setup()
	game.half=half
	game.management.formation=formation; game.management.opponent_formation=formation
	game.management.apply_formation()
	game.controlled=0
	game.controller.stick=Vector2.ZERO
	game.work_budget.enabled=true
	game.management.pressing=2; game.opponent_coach.pressing=2
	var keeper=game.players[team*11]
	var forward: float=game.attack_sign(team)
	for i in range(game.players.size()):
		var p=game.players[i]
		player(i,p.home)
		p.collision_layer=2; p.collision_mask=3
	keeper.position=Vector3(0,0,-forward*46)
	keeper.set_piece_pose="carry"; keeper.animate(1)
	var crowded := [2,6,9,13,17,20]
	for slot in range(crowded.size()):
		player(crowded[slot],keeper.position+Vector3(-5+slot*2,0,forward*(3+slot%2*2)))
	var manual: Vector3=Vector3.RIGHT*.3
	game.players[0].desired=manual
	# Preserve a stale attacker, receiver, run and rebound to reproduce the pile-up.
	var old_owner: int=(1-team)*11+9
	game.carrier=old_owner; game.dribbler=old_owner
	game.team_tactics.observed_owner=old_owner; game.team_tactics.age=2
	game.team_tactics.counter_time=[4.0,4.0]
	game.support.assign_run(team*11+6,keeper.position,"one_two",3)
	game.ai_receivers=[6,17]; game.ai_pass_time=[3.0,3.0]
	game.second_balls.alert("save",1-team)
	game.ball.pending_reset=false; game.ball.pending_kick=false
	game.ball.position=keeper.hand_center(); game.ball.linear_velocity=Vector3.ZERO
	game.ball.hold(keeper)
	game.goalkeeping.holding=team*11; game.goalkeeping.hold_age=-10
	game.last_touch=team; game.last_kicker=team*11
	game.second_balls.update(DT); game.update_ai(DT)
	var label := "team=%d half=%d formation=%d" % [team,half,formation]
	check(game.team_tactics.pressers==[-1,-1] and game.second_balls.targets.is_empty(),"A secure catch cancels pressing and rebound races immediately: "+label)
	check(game.support.runs.is_empty() and game.support.targets.is_empty() and game.ai_receivers==[-1,-1] and game.team_tactics.counter_time==[0.0,0.0],"Previous runs and receiving assignments cannot pull players back to the gloves: "+label)
	check(game.carrier==team*11 and game.players[0].desired==manual,"Keeper possession supersedes stale ownership without steering the human: "+label)
	var moving_away := true
	var before := 0.0
	for i in crowded:
		var p=game.players[i]
		var away: Vector3=(p.position-keeper.position)*Vector3(1,0,1)
		moving_away=moving_away and p.desired.dot(away)>0 and not p.jockeying
		before+=game.flat_distance(p.position,game.team_tactics.targets[i])
	check(moving_away,"Both sides turn away from the keeper, including their nearest players: "+label)
	var spread := true
	for i in game.team_tactics.targets:
		spread=spread and game.flat_distance(game.team_tactics.targets[i],keeper.position)>=9.9
		if game.players[i].team==team:
			spread=spread and (game.team_tactics.targets[i]-keeper.position).z*forward>=9.9
	check(spread,"Formation slots provide forward passing outlets and space for distribution: "+label)
	for frame in range(480):
		game.goalkeeping.hold_age=-10
		game.update_ai(DT)
		for i in range(game.players.size()):
			if not game.is_user_player(i): game.players[i].step(DT)
		await physics_frame
	var after := 0.0
	var clear := true
	var gaps: Array=[]
	for i in crowded:
		after+=game.flat_distance(game.players[i].position,game.team_tactics.targets[i])
		var gap: float=game.flat_distance(game.players[i].position,keeper.position)
		gaps.append(snappedf(gap,.1)); clear=clear and gap>9
	print("REGROUP ",label," distance_to_slots=",before," -> ",after," keeper_gaps=",gaps)
	check(clear and before-after>crowded.size()*10,"Real movement clears the keeper's area and recovers formation: "+label)
	check(game.ball.held_by==keeper and game.state=="playing","Regrouping does not tackle or release the protected ball: "+label)
	# A deliberate distribution must wake up the ordinary receiving AI immediately.
	game.ball.release_hold(); game.goalkeeping.reset()
	game.carrier=-1; game.dribbler=-1
	var receiver: int=team*11+6
	game.ai_receivers[team]=receiver; game.ai_pass_time[team]=2
	game.ball.position=game.players[receiver].position+Vector3(3,1,forward*3)
	game.ball.linear_velocity=Vector3(0,1,forward*12)
	game.team_tactics.update(DT); game.support.update(DT)
	check(game.team_tactics.held_keeper==-1 and not game.team_tactics.roles.values().has("regroup") and game.ai_receivers[team]==receiver,"Release immediately restores open-play duties and the new receiver: "+label)

func run() -> void:
	for team in [0,1]:
		for half in [1,2]:
			# Fresh bodies avoid carrying platform-contact history across the
			# fixture's artificial end-to-end teleports between independent cases.
			game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
			game.match_menu.config_path="/tmp/sefc-keeper-regroup.cfg"
			await regroup(team,half,0 if half==1 else 2)
			game.free(); await physics_frame
	print("KEEPER REGROUP CHECK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
