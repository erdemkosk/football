extends "res://tests/ai_attack_check.gd"

func defence(at: Vector3=Vector3.ZERO,velocity: Vector3=Vector3.ZERO) -> void:
	setup()
	for p in game.players: p.visible=false
	player(9,at,velocity); possession(9)
	game.controlled=9; game.foul_cooldown=0
	game.players[9].facing=Vector3.FORWARD
	game.ball.linear_velocity=velocity

func run_duel(side: float,difficulty: int,cover: bool=false,half: int=1,cut: bool=false,tired: bool=false) -> Dictionary:
	defence()
	game.management.difficulty=difficulty; game.half=half
	var forward: float=game.attack_sign(0)
	var direction:=Vector3(side,0,forward).normalized()
	player(9,Vector3.ZERO); game.players[9].facing=direction
	player(14,Vector3(.3,0,forward*6))
	if tired: game.players[14].energy=.08; game.players[14].exhausted=true
	if cover: player(15,Vector3(-2,0,forward*12))
	for p in game.players:
		p.collision_layer=2 if p.visible else 0; p.collision_mask=3
		p.body_language.enabled=false
	game.ball.freeze=false
	game.ball.place(Vector3.UP*.23+direction*.55)
	await physics_frame; await physics_frame
	game.dribbler=9; game.carrier=9; game.kick_lock=0
	var pressure:=0.0
	var sprint_frames:=0
	var attempts:=0
	var last_action:=false
	for tick in range(300):
		var p=game.players[9]
		if cut and tick==24: direction=Vector3(-.9,0,forward*.45).normalized()
		p.desired=direction; p.sprinting=true
		game.kick_lock=maxf(0,game.kick_lock-DT)
		game.ai_attack.update(DT)
		game.update_ai(DT)
		game.physical_contests.update(DT)
		game.kick_contact.prepare(DT)
		for q in game.players:
			if q.visible: q.step(DT)
		game.duels.resolve(DT); game.rules.resolve_tackles()
		game.defending.resolve(); game.kick_contact.resolve()
		if game.players[14].active_sprint: sprint_frames+=1
		var tackling: bool=game.players[14].pose=="poke" and game.players[14].action_timer>0
		if tackling and not last_action: attempts+=1
		last_action=tackling
		if game.state!="playing": return {"won":false,"foul":true,"pressure":pressure,"attempts":attempts}
		game.update_contacts(DT)
		await physics_frame
		if game.flat_distance(p.position,game.players[14].position)<2.2: pressure+=DT
		if "--visual" in OS.get_cmdline_user_args() and difficulty==1 and side==.20 and (tick in [24,42] or game.last_touch==1):
			await capture("contact" if game.last_touch==1 else str(tick))
		if game.last_touch==1:
			return {"won":true,"foul":false,"pressure":pressure,"attempts":attempts,"sprints":sprint_frames}
	return {"won":false,"foul":false,"pressure":pressure,"attempts":attempts,"sprints":sprint_frames}

func capture(label: String) -> void:
	var velocity: Vector3=game.ball.linear_velocity
	var spin: Vector3=game.ball.angular_velocity
	game.ball.freeze=true; game.hud.hide()
	var centre: Vector3=game.players[9].position.lerp(game.players[14].position,.5)
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=42
	game.camera.position=centre+Vector3(7,5,8)
	game.camera.look_at(centre+Vector3.UP*.5)
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-defence-"+label+".png")
	game.ball.freeze=false; game.ball.linear_velocity=velocity; game.ball.angular_velocity=spin

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-defensive-pressure.cfg"
	# Proximity must not turn a defender into an attacker while we own the ball.
	defence(); player(14,Vector3(0,0,-1.2)); game.players[14].tackle_cooldown=1
	game.update_ai(.2)
	check(game.players[14].desired.z<.15,"A nearby defender stays goal-side instead of switching to his own attacking direction")
	check(not game.ai_attack.act(14) and game.kick_contact.pending.is_empty(),"Being in foot reach of an opponent's ball never authorizes a possession skill or shot")
	# Matching a runner requires sprinting even under a balanced pressing plan.
	defence(Vector3.ZERO,Vector3(0,0,-10)); player(14,Vector3(1.7,0,-1.5))
	game.players[14].tackle_cooldown=1; game.opponent_coach.pressing=1
	game.update_ai(.2)
	check(game.players[14].sprinting,"The defender matches a sprinting attacker rather than slowing down within three metres")
	# A beaten marker must hand over to someone ahead of the ball.
	defence(Vector3.ZERO,Vector3(0,0,-9)); player(14,Vector3(0,0,1)); player(15,Vector3(1,0,-4))
	game.team_tactics.update(.2)
	check(game.team_tactics.pressers[1]==15,"A goal-side defender takes over from the closer but beaten marker")
	check(game.team_tactics.targets[14].z<game.team_tactics.targets[15].z-3,"The beaten marker recovers behind the new presser to cover the actual running lane")
	# Do not waste the standing-tackle animation on a ball already running away.
	defence(Vector3.ZERO,Vector3(0,0,-10)); player(14,Vector3(.9,0,-.1))
	check(not game.duels.ai_poke_window(14,9),"A fleeing ball outside the contact window prompts recovery, not a futile poke")
	game.players[14].position=Vector3(0,0,-1.8)
	check(game.duels.ai_poke_window(14,9),"An incoming exposed ball permits a timely shared standing tackle")
	# Possession changes replace cached duties immediately, not on the next scan.
	game.team_tactics.update(.2); possession(14); game.team_tactics.update(DT)
	check(not game.team_tactics.targets.has(14),"Winning possession releases the previous defensive assignment immediately")
	# Different observation intervals and lane prediction, without input reading.
	var prediction: Array=[]
	for level in range(3):
		defence(Vector3.ZERO,Vector3(0,0,-8)); game.management.difficulty=level
		player(14,Vector3(2,0,-6)); game.team_tactics.update(.3)
		prediction.append(-game.team_tactics.targets[14].z)
	check(prediction[0]<prediction[1] and prediction[1]<prediction[2],"Higher difficulty anticipates visible running more accurately")
	var target: Vector3=game.team_tactics.targets[14]
	game.players[9].desired=Vector3.RIGHT; game.team_tactics.update(DT)
	check(game.team_tactics.targets[14]==target,"Changing human input alone does not reveal the next cut to the defence")
	var fouls:=0
	for difficulty in [1,2]:
		var wins:=0
		for side in [0.0,.20,-.24]:
			var result: Dictionary=await run_duel(side,difficulty)
			print("DUEL level=",difficulty," side=",side," ",result)
			wins+=int(result.won); fouls+=int(result.foul)
		check(wins>=2,"Straight and shallow diagonal sprints face clean defensive resistance at level %d" % difficulty)
	check(fouls==0,"Defensive pressure does not substitute fouls for clean challenges")
	var reverse: Dictionary=await run_duel(.2,2,true,2)
	check(reverse.won and not reverse.foul,"Defensive interception also works after the teams change ends")
	var wide: Dictionary=await run_duel(.9,1)
	print("WIDE ",wide)
	check(not wide.won and not wide.foul,"Attacking open space outside the defender's reach remains possible")
	var changed: Dictionary=await run_duel(.20,2,false,1,true)
	print("CUT ",changed)
	check(not changed.won and not changed.foul,"A real change of direction can still beat a committed hard defender")
	var exhausted: Dictionary=await run_duel(.5,2,false,1,false,true)
	print("TIRED ",exhausted)
	check(not exhausted.won and not exhausted.foul and exhausted.sprints==0,"An exhausted defender cannot gain a hidden recovery speed boost")
	print("DEFENSIVE PRESSURE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
