extends "res://tests/ai_attack_check.gd"

func live_setup(at: Vector3=Vector3(0,0,-10),rain: bool=false) -> void:
	setup(at)
	game.match_menu.config_path="/tmp/sefc-ai-match-flow.cfg"
	game.ball.freeze=false
	game.team_control.select(0); game.player_lock=true
	game.weather.select(2 if rain else 0,true)
	for p in game.players:
		p.collision_layer=2 if p.visible else 0; p.collision_mask=3
	game.ball.place(game.players[20].position+Vector3(0,.23,.6))
	await physics_frame; await physics_frame
	game.last_kicker=20; game.last_touch=1; game.previous_ball=game.ball.position
	game.dribbler=20; game.carrier=20; game.possession_player=20

func ticks(count: int) -> void:
	for frame in range(count):
		game.simulate_match(DT)
		# Ball boys and restart handovers run on the render tick in the game.
		game._process(DT)
		await physics_frame

func passing_flow(rain: bool,half: int) -> void:
	await live_setup(Vector3(0,0,-10 if half==1 else 10),rain)
	game.half=half
	var forward: float=game.attack_sign(1)
	player(0,Vector3(0,0,forward*49)); player(2,Vector3(-27,0,forward*48))
	player(18,Vector3(16,0,0)); player(4,Vector3(-3,0,-forward*11))
	for i in [18,4]: game.players[i].collision_layer=2
	game.players[20].facing=Vector3(0,0,forward)
	game.ball.place(game.players[20].position+Vector3(0,.23,forward*.6))
	await physics_frame; await physics_frame
	game.previous_ball=game.ball.position
	# Use an actual give-and-go inside its passing cone. An ordinary pass into
	# an empty wing should not require an unsolicited backwards return.
	game.ai_attack.skill_in[20]=0; game.ai_attack.skill_in[18]=20; game.ai_attack.team_skill_in[1]=20
	var received := false
	var return_received := false
	var contacts: int=game.kick_contact.contacts
	var misses: int=game.kick_contact.misses
	for tick in range(720):
		await ticks(1)
		if game.dribbler==18 and game.last_kicker==18: received=true
		if received and game.dribbler==20 and game.last_kicker==20: return_received=true
	print("PASS FLOW rain=",rain," half=",half," passes=",game.passes[1]," contacts=",game.kick_contact.contacts-contacts," misses=",game.kick_contact.misses-misses," received=",received," returned=",return_received)
	check(received,"Moving AI receiver controls the real pass, rain=%s half=%d" % [rain,half])
	check(return_received and game.passes[1]>=2 and game.ai_attack.uses.get("one_two",0)>0,"A planned give-and-go continues into a controlled physical return, rain=%s half=%d" % [rain,half])
	check(game.kick_contact.misses==misses,"AI follows through without an uncontested missed swing, rain=%s half=%d" % [rain,half])

func exhibition(difficulty: int,seed_value: int) -> void:
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	game.management.difficulty=difficulty; game.rng.seed=seed_value; game.menu_match.running=true
	game.weather.select(0,true)
	var contacts_before: int=game.kick_contact.contacts
	var misses_before: int=game.kick_contact.misses
	var delivered := [0,0]
	var controlled_receives := [0,0]
	var waiting := [-1,-1]
	var last_contacts: int=game.kick_contact.contacts
	var active_time := 0.0
	# Compare active football time; real celebrations and ball retrieval remain
	# enabled and must complete without a forced teleport or restart bypass.
	for tick in range(120*180):
		await ticks(1)
		if game.state=="playing": active_time+=DT
		if game.kick_contact.contacts>last_contacts:
			var team: int=game.last_touch
			waiting[team]=game.ai_receivers[team]
			if waiting[team]>=0 and waiting[team]!=game.last_kicker: delivered[team]+=1
			last_contacts=game.kick_contact.contacts
		for team in range(2):
			if waiting[team]>=0 and game.dribbler==waiting[team] and game.last_touch==team:
				controlled_receives[team]+=1; waiting[team]=-1
			elif game.last_touch!=team: waiting[team]=-1
		if active_time>=60: break
	var contacts: int=game.kick_contact.contacts-contacts_before
	var misses: int=game.kick_contact.misses-misses_before
	print("LIVE MATCH difficulty=",difficulty," active=",snapped(active_time,.1)," passes=",delivered," controlled=",controlled_receives," contacts=",contacts," misses=",misses," shots=",game.shots," score=",game.score)
	check(active_time>=60,"Real restarts complete and allow a minute of active football, difficulty %d" % difficulty)
	check(delivered[0]>=3 and delivered[1]>=3,"Both full teams release real passes at difficulty %d" % difficulty)
	check(controlled_receives[0]>=1 and controlled_receives[1]>=2,"Both teams control passes and the opponent completes multiple receptions, difficulty %d" % difficulty)
	check(contacts>5 and misses<=maxi(2,contacts/5),"Physical pass/shot contacts remain reliable in a contested match, difficulty %d" % difficulty)
	game.menu_match.running=false

func attack_flow() -> void:
	await live_setup(Vector3(13,0,21))
	player(18,Vector3(0,0,34)); game.players[18].collision_layer=2
	game.players[20].ai_think=3
	var received := false
	for tick in range(120*8):
		await ticks(1)
		if game.last_kicker==18: received=true
		if game.shots[1]>0: break
	check(received and game.passes[1]>0 and game.shots[1]>0,"A live attacking move links a physical pass, reception and shot")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	# A request is not a completed pass, and a challenge can cancel the windup.
	setup(); player(18,Vector3(10,0,-10)); player(4,Vector3(-1.8,0,0)); game.ai_attack.skill_in[20]=10
	check(game.ai_attack.act(20) and game.passes[1]==0 and not game.support.runs.has(20),"Pass preparation does not count a pass or start the give-and-go run")
	game.last_kicker=4; game.kick_contact.prepare(DT)
	check(game.kick_contact.pending.is_empty() and game.passes[1]==0 and game.ai_receivers[1]==-1,"A dispossessed windup cannot create a phantom receiver or pass statistic")
	# The pass lane ahead remains blocked; a marker behind is not omnipresent.
	setup(); player(4,game.ball.position+Vector3(0,-.23,-1))
	var route: Dictionary=game.Passing.plan(game.ball.position,Vector3(0,.23,12),Vector3.ZERO,false)
	check(game.Passing.risk(game.ball.position,route,1,game.players)<.2,"A defender behind the ball does not veto a forward escape pass")
	game.players[4].position.z=5
	check(game.Passing.risk(game.ball.position,route,1,game.players)>.8,"A defender in the actual passing lane still blocks that option")
	# Preparation and recovery are one continuous decision, even under pressure.
	setup(); player(4,Vector3(0,0,.9)); game.possession_player=20; game.players[20].ai_think=1
	game.update_pass_request(DT)
	check(game.players[20].ai_think==1,"A closer opponent does not repeatedly reset the actual carrier's decision time")
	game.players[20].receive_timer=.3; game.dribbler=-1
	check(not game.ai_attack.act(20),"An uncontrolled first touch is settled before attempting another pass")
	# Use a quick crossing pass with distinct 80 ms arrival samples. At the
	# slower speed both runners can legitimately choose the same meeting point.
	setup(); game.weather.select(0,true); player(18,Vector3(10,0,2)); game.ball.linear_velocity=Vector3(20,0,0)
	var fresh_target: Vector3=game.ai_attack.receiving_target(18)
	game.players[18].energy=.05; game.players[18].exhausted=true
	var tired_target: Vector3=game.ai_attack.receiving_target(18)
	check(tired_target.x>fresh_target.x+.5,"A fatigued receiver allows more time to reach the ball instead of assuming full running speed")
	# A player who has passed the wall must not be sent back through it.
	game.set_pieces.wall.assign([18,19,15])
	game.set_pieces.targets={18:Vector3(-11.00365,0,-29.2783),19:Vector3(-10.23776,0,-28.98536),15:Vector3(-9.471868,0,-28.69242)}
	var destination := Vector3(-12,0,-34)
	check(game.set_pieces.around_wall(Vector3(-10.36497,0,-29.43793),destination)==destination,"Free-kick positioning continues away from the wall after passing it")
	# AI must chase its own physical knock-on, not resume a support run.
	await live_setup()
	game.players[20].ai_think=3; game.players[20].skill_cooldown=0
	check(game.ai_attack.decide(20).kind=="push" and game.ai_attack.act(20),"Open grass permits the shared knock-on")
	var recovered := false
	var released := false
	for tick in range(300):
		await ticks(1)
		if game.ai_receivers[1]==20: released=true
		if released and game.dribbler==20: recovered=true; break
	check(recovered,"The AI runs after and recovers its own knocked-on ball")
	await passing_flow(false,1)
	await passing_flow(true,1)
	await passing_flow(false,2)
	await attack_flow()
	await exhibition(1,541)
	await exhibition(2,983)
	print("AI MATCH FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
