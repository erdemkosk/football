extends "res://tests/defensive_pressure_check.gd"

class DuelRecorder:
	extends "res://scripts/playtest_recorder.gd"
	var counts: Dictionary={}
	func event(kind: String,_index: int,_data: Dictionary={}) -> void:
		counts[kind]=int(counts.get(kind,0))+1

func make_game():
	return load("res://main.tscn").instantiate()

func spacing(a: int,b: int) -> Vector3:
	var positions := PackedVector3Array()
	var visible := PackedByteArray()
	for i in range(game.players.size()):
		positions.append(game.players[i].position)
		visible.append(1 if i in [a,b] else 0)
	game.players[a].desired=Vector3.ZERO
	game.separate_ai_player(a,positions,visible)
	return game.players[a].desired

func rules_check() -> void:
	defence(); player(14,Vector3(.95,0,0))
	game.team_tactics.pressers[1]=14
	check(spacing(14,9).length()<.001,"The assigned challenger can enter shoulder range without generic avoidance")
	player(15,Vector3.ZERO)
	check(spacing(14,15).length()>.1,"Teammates still make room for one another")
	game.team_tactics.pressers[1]=-1
	check(spacing(14,9).length()>.1,"Unassigned opponents keep normal spacing")
	game.team_tactics.pressers[1]=14; game.dribbler=-1
	check(spacing(14,9).length()>.1,"Losing possession immediately restores ordinary avoidance")
	possession(9); game.players[14].position=Vector3(.60,0,0)
	check(spacing(14,9).x>0,"Close challengers retain a minimum body separation")
	for team in [0,1]:
		for half in [1,2]:
			setup(); game.half=half
			var owner: int=(1-team)*11+9
			var marker: int=team*11+3
			var toward := Vector3(0,0,game.attack_sign(1-team))
			var at := toward*38
			player(owner,at,toward*2.5); possession(owner)
			game.ball.linear_velocity=toward*6
			player(marker,at+Vector3(.96,0,0),toward*2.5)
			game.players[owner].facing=toward
			game.players[marker].yellow_cards=1
			check(game.ai_attack.defend(marker) and game.state=="playing","A controlled lateral shoulder is legal with a booking near either goal, team=%d half=%d" % [team,half])
			check(game.players[owner].action_timer==0,"Legal pressure leaves the carrier's controls available")
			game.players[marker].tackle_cooldown=0
			game.players[marker].position=at-toward*.9
			check(not game.duels.ai_can_shoulder(marker,owner),"Rear pressure cannot trigger a shoulder shove")
			game.players[marker].position=at+Vector3(.96,0,0)
			game.players[marker].velocity=-toward*5
			check(not game.duels.ai_can_shoulder(marker,owner),"Head-on running cannot trigger a side challenge")
	defence(); player(14,Vector3(.95,0,0),Vector3.FORWARD*2.5)
	game.players[9].velocity=Vector3.FORWARD*2.5
	game.players[14].facing=Vector3.LEFT
	game.physical_contests.update(.1)
	check(not game.physical_contests.pairs.is_empty(),"Parallel runners sustain pressure while the jockey looks toward the ball")
	game.players[14].velocity=Vector3.BACK*2.5
	game.physical_contests.update(.1)
	check(game.physical_contests.pairs.is_empty(),"Opposing travel is not treated as sustained shoulder pressure")
	setup(); player(4,Vector3(0,0,-1.0)); game.ai_attack.holds[20]={"age":.2,"kind":"shield"}
	check(game.ai_attack.holding_action(20) and game.players[20].protecting,"A single opponent reaching contact distance does not cancel shielding")
	game.ai_attack.holds[20].age=.7
	check(not game.ai_attack.holding_action(20),"Shielding still releases on its bounded decision timer")

func engagement(shield: bool,side: float,team: int=0,half: int=1) -> Dictionary:
	setup(); game.management.difficulty=1; game.half=half
	game.playtest.counts.clear()
	for p in game.players: p.visible=false; p.collision_layer=0
	var owner: int=team*11+9
	var marker: int=(1-team)*11+3
	var toward := Vector3(0,0,game.attack_sign(team))
	player(owner,Vector3.ZERO,toward*(0 if shield else 2.5))
	player(marker,Vector3(side*1.8,0,0) if not shield else -toward*1.8,toward*(0 if shield else 2.5))
	game.controlled=owner; game.foul_cooldown=0
	for i in [owner,marker]: game.players[i].collision_layer=2; game.players[i].collision_mask=3
	var p=game.players[owner]
	p.facing=toward; p.protecting=shield
	game.ball.freeze=false; game.weather.select(0,true)
	game.ball.place(toward*.55+Vector3.UP*game.ball.GROUND_HEIGHT)
	await physics_frame; await physics_frame
	game.dribbler=owner; game.carrier=owner; game.last_kicker=owner; game.last_touch=team; game.kick_lock=0
	var contact := 0.0
	var pressure := 0.0
	var attempts := 0
	var previous_poke := false
	var won := false
	var captured := false
	for tick in range(480):
		p.desired=Vector3.ZERO if shield else toward*.60
		p.sprinting=false; p.protecting=shield
		game.kick_lock=maxf(0,game.kick_lock-DT)
		game.ai_attack.update(DT); game.update_ai(DT)
		game.physical_contests.update(DT); game.kick_contact.prepare(DT)
		for i in [owner,marker]:
			game.players[i].body_language.observe(game,i)
			game.players[i].step(DT)
		if not game.physical_contests.pairs.is_empty(): contact+=DT
		if game.flat_distance(p.position,game.players[marker].position)<1.2: pressure+=DT
		var poke: bool=game.players[marker].pose=="poke" and game.players[marker].action_timer>0
		if poke and not previous_poke: attempts+=1
		previous_poke=poke
		if not captured and "--visual" in OS.get_cmdline_user_args() and team==0 and half==1 and side==1:
			if (shield and tick==120) or (not shield and game.duels.attempts.get(marker,0)>.08):
				await capture_engagement("pressure" if shield else "tackle",owner,marker)
				captured=true
		game.duels.resolve(DT); game.rules.resolve_tackles(); game.defending.resolve(); game.kick_contact.resolve()
		if game.state!="playing": break
		game.update_contacts(DT); await physics_frame
		if game.last_touch!=team: won=true; break
	var result := {"shield":shield,"side":side,"team":team,"half":half,"contact_seconds":snapped(contact,.001),"pressure_seconds":snapped(pressure,.001),"attempts":attempts,"clean_tackles":game.playtest.counts.get("tackle_clean",0),"shoulders":game.ai_attack.uses.get("shoulder",0),"won":won,"foul":game.state!="playing"}
	print("ENGAGEMENT ",JSON.stringify(result))
	return result

func capture_engagement(label: String,owner: int,marker: int) -> void:
	var velocity: Vector3=game.ball.linear_velocity
	var spin: Vector3=game.ball.angular_velocity
	game.ball.freeze=true; game.hud.hide()
	var centre: Vector3=game.players[owner].position.lerp(game.players[marker].position,.5)
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=38
	game.camera.position=centre+Vector3(5,3,6)
	game.camera.look_at(centre+Vector3.UP*.65)
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-duel-"+label+".png")
	game.ball.freeze=false; game.ball.linear_velocity=velocity; game.ball.angular_velocity=spin

func run() -> void:
	game=make_game(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-duel-engagement.cfg"
	game.playtest=DuelRecorder.new(); game.playtest.game=game
	if not "--samples-only" in OS.get_cmdline_user_args(): rules_check()
	for team in [0,1]:
		for half in [1,2]:
			var shielded := await engagement(true,1,team,half)
			check(shielded.pressure_seconds>.1 and (shielded.attempts>0 or shielded.contact_seconds>.1),"A rear marker works around shielding into a real contest, team=%d half=%d" % [team,half])
			check(not shielded.foul,"Shielding pressure does not become a rear foul")
		for side in [-1.0,1.0]:
			var running := await engagement(false,side,team)
			check(running.shoulders>0 or running.contact_seconds>.1 or (running.attempts>0 and running.won),"A marker joins a controlled runner's duel, team=%d side=%s" % [team,side])
			check(running.clean_tackles>0,"The running duel can end with a real boot contact, team=%d side=%s" % [team,side])
			check(not running.foul,"Parallel running pressure stays legal")
	print("DUEL ENGAGEMENT CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
