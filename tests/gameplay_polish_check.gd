extends "res://tests/pass_skill_check.gd"
var checks := 0
func check(ok: bool,label: String) -> void:
	checks+=1
	super.check(ok,label)

func first_time_angle(degrees: float,rate: int) -> void:
	Engine.physics_ticks_per_second=rate
	incoming()
	var direction := Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(degrees))
	game.players[7].position=direction*8
	game.controller.stick=Vector2(direction.x,direction.z)
	game.ball.freeze=false; game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,-2.8),Vector3.BACK*12)
	await physics_frame; await physics_frame
	var before: int=game.kick_contact.contacts
	var feedback: int=game.feedback.event_count
	button(JOY_BUTTON_A); button(JOY_BUTTON_A,false)
	game.controller.stick=Vector2.ZERO
	var delay := 0.0
	var received := false
	var sent := false
	for frame in range(rate):
		game.simulate_match(1.0/rate); await physics_frame
		if game.players[9].receive_timer>0 or game.kick_contact.pending.get("index",-1)==9: received=true
		if received: delay+=1.0/rate
		if game.kick_contact.contacts>before:
			sent=game.last_kicker==9 and game.ball.kick_velocity.dot(direction)>5
			break
	check(sent and game.kick_contact.contacts==before+1 and delay<=.15,"Early pass at %.0f degrees / %d Hz makes one real contact promptly (%.3fs)" % [degrees,rate,delay])
	check(game.feedback.event_count==feedback+1 and game.kick_contact.last_gap<=.36,"Pass impulse and contact feedback coincide at the visible boot")
	Engine.physics_ticks_per_second=120

func touch(prepared: bool,weak: bool,sprint: bool=false) -> Dictionary:
	incoming()
	var p=game.players[9]
	p.attributes.control=80; p.attributes.balance=80; p.attributes.preferred_foot=1 if weak else 0; p.attributes.weak_foot=1
	p.desired=Vector3.RIGHT; p.active_sprint=sprint
	game.controller.stick=Vector2.RIGHT
	game.ball.position=Vector3(-.18,game.ball.GROUND_HEIGHT,-.8); game.ball.linear_velocity=Vector3.BACK*10
	if prepared:
		for frame in range(24): game.first_touch.prepare(DT)
	var origin: Vector3=game.ball.position
	check(game.first_touch.receive(9,false),"An ordinary directed reception remains controllable")
	check(game.ball.position==origin and game.ball.touch_impulse_limit>0,"The opening touch uses an impulse without moving the ball transform")
	return {"opening":p.ball_actions.receive_distance,"duration":p.receive_duration,"error":p.ball_actions.receive_error,"heading":game.ball.touch_velocity.x}

func turning(control: int) -> Vector3:
	setup()
	var p=game.players[9]
	p.attributes.control=control; p.attributes.balance=control; p.attributes.acceleration=72; p.attributes.pace=72
	p.position=Vector3.ZERO; p.desired=Vector3.RIGHT; p.velocity=Vector3.FORWARD*6
	p.body_language.enabled=false; p.dribble_motion.freshness=.1
	for frame in range(6):
		p.step(DT); await physics_frame
	return p.velocity

func box_scene(team: int,half: int,side: float) -> int:
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	game.half=half; game.controller.stick=Vector2.ZERO; game.controller.held.clear()
	var forward: float=game.attack_sign(team)
	for p in game.players:
		p.visible=false; p.collision_layer=0; p.desired=Vector3.ZERO; p.velocity=Vector3.ZERO
	var owner := 6+team*11
	game.controlled=owner if team==0 else 9
	for i in [owner,7+team*11,9+team*11,10+team*11]:
		game.players[i].visible=true
	game.players[owner].position=Vector3(side*26,0,forward*34)
	game.players[7+team*11].position=Vector3(0,0,forward*26)
	game.players[9+team*11].position=Vector3(side*3,0,forward*29)
	game.players[10+team*11].position=Vector3(-side*6,0,forward*30)
	for i in [(1-team)*11,(1-team)*11+2]:
		game.players[i].visible=true; game.players[i].position=Vector3(24 if i%11==2 else 0,0,forward*(48 if i%11==2 else 49))
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false
	game.ball.position=game.players[owner].position+Vector3(0,game.ball.GROUND_HEIGHT,forward*.6)
	game.dribbler=owner; game.carrier=owner; game.last_touch=team; game.last_kicker=owner
	game.support.reset(); game.support.update(DT)
	return owner

func box_runs() -> void:
	for team in [0,1]:
		for half in [1,2]:
			for side in [-1.0,1.0]:
				var owner := box_scene(team,half,side)
				var forward: float=game.attack_sign(team)
				var jobs: Dictionary=game.support.box.jobs.duplicate()
				check(jobs.size()==3,"Both teams create near/far/cutback options, team=%d half=%d side=%.0f" % [team,half,side])
				if jobs.size()!=3: continue
				var near: Vector3=game.support.targets[jobs.near]
				var far: Vector3=game.support.targets[jobs.far]
				var back: Vector3=game.support.targets[jobs.cutback]
				check(near.x*side>0 and far.x*side<0 and back.z*forward<game.ball.position.z*forward-3 and near.distance_to(far)>5,"Runners offer distinct forward, far-side and backward passing lanes")
				var near_origin: Vector3=game.players[jobs.near].position
				for frame in range(90):
					game.support.update(DT)
					for i in jobs.values():
						var p=game.players[i]
						p.desired=(game.support.targets[i]-p.position).normalized(); p.step(DT)
					await physics_frame
				check(game.players[jobs.near].position.distance_to(near_origin)>2 and game.support.box.jobs==jobs,"Actual runners advance while keeping complementary jobs")
				game.players[owner].position.z+=forward*5; game.players[owner].velocity=Vector3(0,0,forward*3)
				game.ball.position.z+=forward*5; game.support.plan_age=0; game.support.update(DT)
				check(game.support.targets[jobs.near].z*forward>near.z*forward+3 and game.support.targets[jobs.cutback].z*forward<game.ball.position.z*forward-3,"The delivery run advances with the winger while the cutback stays behind")
				var far_target: Vector3=game.support.targets[jobs.far]
				game.dribbler=-1; game.ai_pass_time[team]=2; game.ai_receivers[team]=jobs.near
				game.ball.position=Vector3(0,3,forward*43); game.ball.linear_velocity=Vector3(0,-1,forward*8)
				game.support.plan_age=0; game.support.update(DT)
				check(game.support.targets.get(jobs.far,Vector3.INF).is_equal_approx(far_target) and game.support.roles.get(jobs.cutback,"")=="box_cutback","Supporting runners finish their routes while the cross is in flight")
				game.last_touch=1-team; game.dribbler=-1; game.ai_pass_time=[0.0,0.0]; game.ball.position=Vector3.ZERO
				game.support.update(DT)
				check(game.support.box.jobs.is_empty(),"A turnover clears the box assignments")

func tackle() -> void:
	setup()
	var p=game.players[9]
	var owner=game.players[17]
	p.position=Vector3(0,0,.85); p.rig.rotation.y=0; p.animate(1)
	owner.visible=true; owner.position=Vector3(.15,0,-.62)
	game.ball.position=Vector3(0,game.ball.GROUND_HEIGHT,0); game.dribbler=17; game.last_touch=1; game.last_kicker=17
	game.duels.standing_tackle(9)
	p.step(.13); game.duels.resolve(.13)
	var away: Vector3=(game.ball.position-owner.position)*Vector3(1,0,1)
	check(game.last_kicker==9 and game.ball.pending_kick and game.ball.kick_velocity.dot(away)>0,"A clean visible tackle knocks the loose ball away from the carrier")
	check(game.dribbler==-1 and p.action_timer<=.16 and game.controlled==9,"Clean contact keeps the defender selected and permits a quick physical follow-up")
	var clean: float=p.action_timer
	var knee: Node3D=p.left_knee if p.tackle_foot==0 else p.right_knee
	var boot: Vector3=knee.to_global(p.ball_actions.BOOT)
	p.step(DT)
	check(knee.to_global(p.ball_actions.BOOT).distance_to(boot)<.12,"A successful tackle retracts its boot smoothly instead of skipping recovery poses")
	setup(); p=game.players[9]; game.dribbler=-1; game.ball.position=Vector3(0,game.ball.GROUND_HEIGHT,-4)
	game.duels.standing_tackle(9); p.step(.13); game.duels.resolve(.13)
	check(p.action_timer>clean+.05 and p.tackle_recovery>.4 and not game.ball.pending_kick,"A missed lunge costs recovery and never wins a distant ball")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-gameplay-polish.cfg"
	for rate in [60,120]:
		for angle in [-135.0,-90.0,0.0,90.0,180.0]: await first_time_angle(angle,rate)
	var ordinary := touch(false,false)
	var prepared := touch(true,false)
	var weak := touch(false,true)
	var sprint := touch(false,false,true)
	check(prepared.opening<ordinary.opening*.9 and prepared.duration<ordinary.duration and prepared.heading>0,"Preparing the exit direction creates a shorter, quicker first touch")
	check(weak.opening>ordinary.opening+.08 and weak.error>ordinary.error,"An awkward weak-foot control exposes more ball without changing the chosen direction")
	check(sprint.opening>ordinary.opening+.15,"Receiving at a sprint carries a readable first-touch risk")
	var heavy := await turning(45)
	var agile := await turning(94)
	check(agile.x>heavy.x+.5 and absf(agile.z)<absf(heavy.z)-.5,"Technique and balance change the actual speed of a sharp turn")
	await box_runs()
	tackle()
	print("GAMEPLAY POLISH CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
