extends SceneTree
const DT := 1.0/120
var game
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func setup() -> void:
	game.start_match(true,false,false,"duel")
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.held.clear(); game.controller.stick=Vector2.ZERO
	for p in game.players: p.body_language.enabled=false
	await physics_frame; await physics_frame
	for i in range(5):
		game.players[9].step(DT); game.players[14].step(DT); await physics_frame
func tick(direction: Vector3=Vector3.ZERO) -> void:
	game.players[9].desired=direction
	game.skills.update(DT)
	for p in game.players:
		if p.visible: p.step(DT)
	game.skills.resolve(); game.duels.resolve(DT)
	game.update_contacts(DT)
	await physics_frame
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.update_camera(1); game.hud.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/duel-"+label+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	await setup()
	check(game.players.filter(func(p): return p.visible).size()==2 and game.controlled==9,"Duel training fields only the learner and defender")
	check(not game.team_control.automatic() and game.training_drills.manages(14),"Training keeps control on the learner and starts with a stationary defender")
	for entry in [[KEY_9,"stop_go"],[KEY_0,"knock_around"]]:
		await setup()
		var key := InputEventKey.new(); key.keycode=entry[0]; key.pressed=true
		game.advanced_controls.handle(key)
		check(game.skills.active.get(9,{}).get("kind","")==entry[1],"Keyboard maps the new intent: "+entry[1])
	for entry in [[Vector3.BACK,"stop_go"],[Vector3.RIGHT,"knock_around"]]:
		await setup()
		game.controller.held[JOY_BUTTON_RIGHT_SHOULDER]=KEY_W
		game.advanced_controls.skill_gesture(entry[0])
		check(game.skills.active.get(9,{}).get("kind","")==entry[1],"Sprint and right-stick map the new intent: "+entry[1])
	for kind in ["roll","stop_go","knock_around"]:
		for side in [-1.0,1.0]:
			await setup()
			var p=game.players[9]
			check(game.skills.start(9,kind,side),"Starts %s on side %.0f" % [kind,side])
			var s: Dictionary=game.skills.active[9]
			var before: Vector3=game.ball.position
			for i in range(8): await tick()
			check(s.contacts==0 and game.ball.position.distance_to(before)<.07,"Preparation cannot move the ball before contact: "+kind)
			var peak_lean := 0.0
			var maximum_jump := 0.0
			for i in range(130):
				var old: Vector3=p.position
				await tick()
				maximum_jump=maxf(maximum_jump,p.position.distance_to(old))
				peak_lean=maxf(peak_lean,absf(p.spine.rotation.z))
			check(s.contacts==(2 if kind=="stop_go" else 1),"Uses discrete physical contacts: "+kind+" / "+str(s.contacts))
			check(s.get("hit_gap",INF)<=.34,"Ball impulse requires actual boot proximity: "+kind)
			check(maximum_jump<.15 and peak_lean<.4,"Exit retains bounded physical movement and body pose: "+kind)
			check(not game.skills.active.has(9),"Returns control after the move: "+kind)
	await setup()
	game.skills.start(9,"roll",1)
	game.begin_pass()
	check(game.pass_charging and not game.skills.active.has(9),"Pass cancels preparation before the foot commits")
	await setup()
	game.skills.start(9,"roll",1)
	game.ball.place(game.players[9].position+Vector3(5,.22,0))
	await physics_frame; await tick()
	check(not game.skills.active.has(9) and not game.ball.pending_touch,"A deflected ball cancels the move without a rescue impulse")
	await setup()
	game.skills.start(9,"knock_around",1)
	var released := false
	for i in range(35):
		await tick()
		if game.players[9].touch_cooldown>.1 and game.dribbler!=9: released=true
	check(released,"Knock-around relinquishes possession for a real race")
	game.last_kicker=14; game.last_touch=1; game.dribbler=14; game.carrier=14
	game.skills.update(DT)
	check(not game.skills.active.has(9),"An opponent's possession interrupts the exit")
	await setup()
	game.players[9].energy=.02
	check(not game.skills.start(9,"roll",1) and game.skills.notice.contains("KONDİSYON"),"Rejected input explains low energy")
	game.players[9].energy=1; game.players[9].skill_cooldown=.5
	check(not game.skills.start(9,"roll",1) and game.skills.notice.contains("DENGE"),"Repeated input explains recovery instead of silently failing")
	await setup()
	game.training_drills.duel.next_stage()
	check(game.training_drills.duel.stage==1 and game.training_drills.manages(14),"Stage two uses the stationary tackling partner")
	game.players[9].position=game.players[14].position+Vector3(0,0,1)
	game.ball.place(game.players[14].position+Vector3(0,.22,.65)); await physics_frame
	game.training_drills.duel.age=1; game.training_drills.actor(14)
	check(game.players[14].pose=="poke" and game.duels.attempts.has(14),"Training defender uses the same timed tackle as a match")
	game.training_drills.duel.next_stage()
	check(game.training_drills.duel.stage==2 and not game.training_drills.manages(14),"Final stage releases the defender to normal match AI")
	await setup()
	game.training_drills.duel.used=true
	game.training_drills.duel.finish("ok",true); game.training_drills.duel.update(2.1)
	game.training_drills.duel.finish("ok",true); game.training_drills.duel.update(2.1)
	check(game.training_drills.duel.stage==1,"Two successful attempts advance the lesson")
	await setup()
	game.skills.start(9,"roll",1); game.state="paused"
	var paused_ball: Vector3=game.ball.position
	game.simulate_match(.2)
	check(not game.skills.active.has(9) and game.ball.position==paused_ball,"Pause cancels preparation without striking the ball")
	game.state="playing"
	game.training_menu.open_menu(); game.training_menu.choose(3)
	check(game.training_menu.cards.size()==4,"Training menu exposes the new workshop")
	await capture("workshop-menu")
	game.training_menu.start(); game.set_process(false); game.set_physics_process(false)
	game.hud.sync_navigation(); game.hud.bug_age=2
	await capture("workshop")
	print("GROUND SKILLS CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
