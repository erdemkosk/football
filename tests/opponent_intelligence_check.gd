extends "res://tests/ai_attack_check.gd"

func observe(seconds: float) -> void:
	for tick in range(roundi(seconds*20)): game.opponent_coach.update(.05)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-opponent-intelligence.cfg"
	for difficulty in range(3):
		setup(); game.management.difficulty=difficulty
		player(9,Vector3(-24,0,-5)); possession(9)
		observe(16); game.opponent_coach.review()
		check(game.opponent_coach.wing_bias<0,"Observed left-wing attacks shift defensive cover, difficulty %d" % difficulty)
		var strength: float=absf(game.opponent_coach.wing_bias)
		check(strength==[.28,.62,.9][difficulty],"Adaptation strength follows difficulty %d" % difficulty)
		var memory: float=game.opponent_coach.samples
		game.state="paused"; observe(30)
		check(game.opponent_coach.samples==memory,"Pausing cannot secretly advance opponent analysis")
		game.state="playing"
		for n in range(6): game.opponent_coach.observe_kick(9,Vector3(0,.3,-20),"kick")
		game.opponent_coach.review()
		check(game.opponent_coach.protect_depth and game.opponent_coach.line_height==0,"Repeated direct passes drop the defensive line, difficulty %d" % difficulty)
		game.half=2
		var direct: float=game.opponent_coach.direct_play
		game.opponent_coach.observe_kick(9,Vector3(0,.3,20),"kick")
		check(game.opponent_coach.direct_play>direct,"Opponent observations reverse with second-half attack direction")
	setup(); player(9,Vector3(-24,0,-5)); possession(9)
	observe(16); game.opponent_coach.review()
	game.players[9].position.x=24; possession(9); observe(45); game.opponent_coach.review()
	check(game.opponent_coach.wing_bias>0,"Old tendencies decay so changing wings can beat the previous adjustment")
	game.start_match(false,false)
	check(game.opponent_coach.samples==0 and game.opponent_coach.wing_bias==0,"A new match forgets the previous opponent scouting")
	setup(); game.match_time=game.LENGTH*.82; game.score=[2,0]
	for i in range(12,22): game.players[i].visible=true
	game.opponent_coach.review()
	check(game.opponent_coach.mentality==2 and game.management.opponent_formation==1,"A losing hard opponent changes to 4-3-3 late")
	game.score=[0,1]; game.opponent_coach.review()
	check(game.opponent_coach.mentality==0 and game.opponent_coach.pressing==0 and game.management.opponent_formation==0,"Leading late restores a compact shape")
	game.match_time=30; game.score=[0,0]; game.players[14].dismissed=true; game.opponent_coach.review()
	check(game.opponent_coach.reason=="ten_men" and game.opponent_coach.press_level()==0,"A sent-off defender makes the coach protect the remaining shape")
	setup()
	for i in range(12,22): game.players[i].visible=true
	game.opponent_coach.build_pressure=5; game.opponent_coach.review()
	check(game.opponent_coach.escape_press and game.management.opponent_formation==2,"Sustained pressure on build-up can produce a three-defender outlet shape")
	game.players[20].sprinting=true
	var speed: float=game.players[20].movement_speed()
	game.management.difficulty=0
	check(is_equal_approx(speed,game.players[20].movement_speed()),"Difficulty does not secretly change the same footballer's running speed")
	setup(); player(9,Vector3(24,0,0)); possession(9)
	for i in range(12,22): player(i,Vector3(12+(i%3)*4,0,6+(i%4)*3))
	player(17,Vector3(23,0,2)); player(18,Vector3(20,0,0)); player(16,Vector3(23,0,-4))
	game.opponent_coach.pressing=2; game.team_tactics.update(.2)
	check(game.team_tactics.roles.values().count("press")==1 and game.team_tactics.roles.values().count("press_support")==1 and game.team_tactics.roles.values().count("cover")==1,"Touchline trap keeps a presser, second presser and cover as separate duties")
	game.opponent_coach.press_load=7.4; game.opponent_coach.update(.2)
	check(game.opponent_coach.press_rest>0 and game.opponent_coach.press_level()<2,"High pressing has an enforced recovery interval")
	for i in range(12,22): game.players[i].energy=.2
	game.opponent_coach.review()
	check(game.opponent_coach.press_level()==0,"An exhausted opponent abandons unsustainable high pressing")
	setup(Vector3(24,0,30))
	for i in range(12,22): game.players[i].visible=true
	game.support.update(.1)
	var retained := 0
	for i in game.support.roles:
		if game.support.roles[i]=="cover_attack" and game.support.targets[i].z<game.ball.position.z-9: retained+=1
	check(retained>=2,"Attacks retain central defenders behind the ball against a counterattack")
	setup(); player(9,Vector3(0,0,-39)); player(14,Vector3(0,0,-38.1)); possession(9)
	game.players[9].facing=Vector3.FORWARD
	check(not game.duels.ai_can_challenge(14,9) and not game.duels.ai_can_challenge(14,9,true),"A defender avoids tackling through the attacker from behind in the penalty area")
	game.players[14].position=Vector3(0,0,-40.6); game.ball.position=Vector3(0,.23,-40)
	check(game.duels.ai_can_challenge(14,9),"Penalty-area caution still allows a clean ball-first standing tackle")
	game.players[14].yellow_cards=1
	check(not game.duels.ai_can_challenge(14,9,true),"A booked defender avoids the extra risk of sliding")
	game.team_tactics.update(.2)
	check("contain" in game.team_tactics.roles.values(),"The box defender contains and blocks instead of blindly charging")
	setup(); player(9,Vector3(0,0,-25)); possession(9)
	player(10,Vector3(10,0,-38),Vector3(0,0,-6)); player(14,Vector3(10,0,-34)); player(15,Vector3(0,0,-20))
	player(12,Vector3(1,0,-26))
	game.team_tactics.update(.2)
	check("recover" in game.team_tactics.roles.values(),"A defender recovers goal-side of a visible run behind the line")
	setup(Vector3(13,0,33)); player(18,Vector3(0,0,40))
	check(kind()=="square" and act_and_contact(20) and game.passes[1]==1 and game.shots[1]==0,"An open teammate near goal is preferred over a difficult-angle shot")
	setup(Vector3(0,0,33)); player(4,Vector3(0,0,37)); player(18,Vector3(8,0,31))
	check(not game.ai_attack.decide(20).has("velocity"),"A blocked shooting lane causes the attacker to seek another solution")
	setup(); player(18,Vector3(0,0,13),Vector3(0,0,4)); player(4,Vector3(0,0,8))
	check(kind()=="lob_through","An obstructed ground through-pass can go over the defender")
	setup(Vector3(0,0,25)); game.players[20].attributes.finishing=90
	check(kind()=="power" and game.ai_attack.act(20) and game.ai_attack.finishing.pending.contact>.3,"Space outside the box permits a power shot with its longer preparation")
	setup(Vector3(-13,0,33)); game.players[20].attributes.control=88; game.players[20].attributes.preferred_foot=1
	check(kind()=="outside" and game.ai_attack.act(20),"A technical finisher on the appropriate side can choose the outside of the boot")
	setup(); game.players[20].attributes.control=87; player(4,Vector3(1.8,0,0))
	check(kind()=="roll" and game.ai_attack.act(20) and game.skills.active.has(20),"A technical player can use the same ball-roll action as the user")
	setup(); player(4,Vector3(0,0,3))
	var target: Vector3=game.ai_attack.carry_target(20)
	check(absf(target.x)>1,"The carrier picks space around the defender instead of running straight into him")
	setup(); player(14,Vector3(0,0,0)); game.dribbler=-1; game.last_touch=0
	game.ball.position=Vector3(0,.23,2); game.ball.linear_velocity=Vector3(0,0,-12)
	check(game.ai_attack.defend(14) and game.players[14].pose=="intercept" and not game.ball.pending_kick,"Pass interception starts a real foot movement without remote ball contact")
	setup(); game.match_time=game.LENGTH*.75
	player(14,Vector3.ZERO); game.players[14].energy=.65; game.players[14].yellow_cards=1
	var proposed: Dictionary=game.opponent_coach.substitution()
	check(not proposed.is_empty() and proposed.slot==14,"The coach can replace a booked defender before a second yellow")
	game.management.prepare_substitutions()
	check(game.management.transit.has(14) and game.management.used[1]==0,"Opponent substitution enters the real outgoing-player sequence")
	check(game.opponent_coach.substitution().is_empty(),"The coach spaces substitutions rather than consuming all three at one whistle")
	setup(); game.match_time=game.LENGTH*.8; game.score=[2,0]
	for i in range(12,22): game.players[i].visible=true
	game.opponent_coach.review()
	game.players[20].energy=.64
	proposed=game.opponent_coach.substitution()
	check(not proposed.is_empty() and proposed.slot==20,"Chasing a goal can refresh the striker before complete exhaustion")
	game.management.used[1]=3
	check(game.opponent_coach.substitution().is_empty(),"Opponent respects the same three-substitution limit")
	setup(); game.match_time=100; game.players[20].energy=.12; game.players[20].dismissed=true
	check(game.opponent_coach.substitution().is_empty(),"An expelled player cannot be replaced by the AI")
	setup(); player(11,Vector3(0,0,-45)); player(14,Vector3(-12,0,-34))
	game.players[20].visible=false
	game.ball.hold(game.players[11]); game.goalkeeping.holding=11; game.ball.position=game.players[11].hand_center()
	game.charging=true; game.charge=.4
	check(game.ai_attack.distribute(11) and game.keeper_distribution.active(11),"Opponent keeper uses the shared animated distribution")
	check(game.charging and game.charge==.4,"Opponent keeper distribution never cancels the user's shot input")
	for tick in range(48):
		game.keeper_distribution.update(DT); game.players[11].step(DT); game.keeper_distribution.resolve()
	check(game.ball.pending_kick and game.ball.held_by==null and game.passes[1]==1,"Keeper release really leaves the hand and counts a physical pass")
	setup(); player(11,Vector3(0,0,-45)); game.players[20].visible=false
	game.ball.hold(game.players[11]); game.goalkeeping.holding=11; game.ball.position=game.players[11].hand_center()
	check(game.ai_attack.distribute(11) and game.keeper_distribution.pending.kind=="punt","A keeper with no safe short outlet can select a physical punt")
	# Finishing has separate queues so the AI cannot steal the user's timing window.
	setup(Vector3(0,0,40)); game.ball.freeze=false
	var p=game.players[20]; p.body_language.enabled=false; p.rig.rotation=Vector3.ZERO; p.animate(1)
	for tick in range(4): p.step(DT); await physics_frame
	game.ball.place(p.position+Vector3(0,.23,.65),Vector3.ZERO)
	await physics_frame; await physics_frame
	game.dribbler=20; game.carrier=20; game.kick_lock=0; p.touch_cooldown=0; p.ai_think=3
	check(game.ai_attack.act(20) and game.ai_attack.finishing.active(20) and game.finishing.pending.is_empty(),"Close-range AI low shot uses its own physical finishing queue")
	var contact := false
	for tick in range(85):
		game.ai_attack.finishing.prepare(DT); p.step(DT); game.ai_attack.finishing.resolve()
		if game.last_kicker==20 and game.shots[1]>0: contact=true; break
		await physics_frame
	check(contact and game.ball.kick_velocity.y<1,"AI low finishing releases only after actual boot contact")
	game.state="paused"; game.ai_attack.update(.1)
	check(game.ai_attack.finishing.pending.is_empty(),"A pause cancels unfinished AI wind-ups")
	print("OPPONENT INTELLIGENCE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
