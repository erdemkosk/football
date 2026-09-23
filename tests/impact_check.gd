extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func arrange() -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	for i in range(22): game.players[i].position=Vector3(-28+i*2.4,0,25)
	game.players[9].position=Vector3(0,0,-0.8)
	game.players[12].position=Vector3.ZERO
	game.players[9].facing=Vector3.BACK
	game.ball.place(Vector3(0,0.23,-3))
	await frames(3)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_match(true)
	game.set_physics_process(false)
	await frames(3)
	game.begin_shot()
	game.update_control(0.8)
	var p=game.players[9]
	p.animate(1.0/120)
	check(absf(p.right_leg.rotation.x-p.left_leg.rotation.x)<0.01 and p.shot_preparation>0.5,"Standing charge keeps both feet in a grounded stance")
	var heading: Vector3=game.shot_direction
	var prepared_leg: Vector3=p.right_leg.rotation
	game.shoot()
	p.animate(1.0/120)
	check(p.kick_timer>0.4 and p.right_leg.rotation.distance_to(prepared_leg)<0.001,"Ball release starts the kick without snapping the leg to full extension")
	check(game.feedback.last_kind=="shot" and game.feedback.event_count==1 and game.ball.pending_kick,"The shot sound and camera cue are triggered by the actual strike")
	await frames(3)
	check(Vector3(game.ball.linear_velocity.x,0,game.ball.linear_velocity.z).normalized().dot(heading)>0.999,"Impact feedback preserves the player's chosen shot heading")
	var strong: float=game.feedback.amplitude
	game.feedback.update(0.07)
	check(game.feedback.offset().length()>0 and game.feedback.offset().length()<0.25,"The shot camera response is short and bounded")
	game.feedback.update(0.5)
	check(game.feedback.offset()==Vector3.ZERO,"The camera settles fully after the impact")
	game.reset_practice()
	await frames(3)
	game.charge=0
	game.shoot()
	check(game.feedback.amplitude<strong,"A soft shot has less camera impulse than a charged shot")
	game.feedback.reset()
	game.strike(9,Vector3(0,1,-18))
	check(game.feedback.event_count==0,"An ordinary pass does not trigger the heavy shot cue")
	await arrange()
	game.players[9].position=Vector3(0,0,-0.8)
	game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,-1.15))
	await frames(3)
	game.dribbler=9
	game.last_kicker=9
	game.finishing.style="power"
	game.charge=1
	game.charging=true
	check(game.power_windup()>0.7,"Holding a power shot tightens the camera and crowd")
	game.shoot()
	check(game.feedback.duration>0.33 and game.feedback.amplitude>strong,"A power strike hits harder and longer than a normal shot cue")
	check(game.ball.streak>0.5,"A power strike leaves a short trail on the ball")
	check(p.volley_motion.kind=="power" and p.volley_motion.duration>0.75,"Power follow-through lasts longer than a normal finish")
	await arrange()
	game.charging=true
	game.rules.start_tackle(12,Vector3.FORWARD)
	game.rules.resolve_tackles()
	check(game.players[9].pose=="fall" and game.players[9].action_timer>0,"A hard opponent tackle makes the controlled player fall")
	check(game.feedback.hurt>0 and game.feedback.last_kind=="body_hit" and not game.charging,"Being tackled gives personal contact feedback and cancels charging")
	check(game.state=="restart" and game.restart_team==0,"The body-first tackle still awards the correct free kick")
	check(not game.can_touch(9,100),"A falling player cannot shoot or control the ball during recovery")
	var before: Vector3=game.players[9].position
	var contacts: int=game.feedback.event_count
	game.rules.resolve_tackles()
	check(game.feedback.event_count==contacts,"One tackle cannot emit repeated impact events")
	for i in range(155):
		game.players[9].step(1.0/120)
		await physics_frame
	check(game.players[9].position.z<before.z-0.4,"The victim is displaced by the contact impulse")
	check(game.players[9].action_timer==0 and game.players[9].pose=="run" and game.players[9].body_collision.rotation.length()<0.01,"The fallen player naturally recovers a normal body and stance")
	await arrange()
	game.players[9].position=Vector3.ZERO
	game.players[12].position=Vector3(0,0,-0.8)
	game.rules.start_tackle(9,Vector3.FORWARD)
	game.rules.resolve_tackles()
	check(game.players[12].pose=="fall" and game.feedback.last_kind=="body_hit","The user's tackle gives the opponent the same physical reaction")
	await arrange()
	game.players[12].position=Vector3(10,0,0)
	game.players[9].position=Vector3.ZERO
	game.ball.place(Vector3(0,0.23,-0.6))
	await frames(3)
	game.rules.start_tackle(9,Vector3.FORWARD)
	game.rules.resolve_tackles()
	check(game.state=="playing" and game.feedback.last_kind=="ball_tackle" and game.ball.pending_kick,"A clean tackle has a separate ball contact cue and keeps play live")
	check(game.players[9].kick_timer==0,"A slide does not accidentally play a standing kick animation")
	var old_age: float=game.feedback.age
	game.state="paused"
	game._physics_process(0.5)
	check(game.feedback.age==old_age,"Pause freezes contact feedback timing")
	game.audio.toggle()
	var silent := true
	for channel in game.audio.contacts: silent=silent and not channel.playing
	check(silent,"Mute stops every contact sound channel")
	game.free()
	print("IMPACT CHECK: %d failures" % failures)
	quit(0 if failures==0 else 1)
