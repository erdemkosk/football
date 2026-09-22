extends SceneTree
var game
var failures := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func key(code: int,echo: bool=false) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	event.echo=echo
	game._input(event)
func tick() -> void:
	game._physics_process(1.0/120)
	game._process(1.0/120)
	await physics_frame
func capture(label: String) -> void:
	if not visual: return
	game.hud.queue_redraw()
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/match-day-"+label+".png")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	check(not game.performance_hud.visible,"FPS panel starts hidden")
	key(KEY_F)
	check(game.performance_hud.visible and game.duels.attempts.is_empty(),"F shows FPS without tackling")
	key(KEY_F,true)
	check(game.performance_hud.visible,"Held F does not flicker the panel")
	key(KEY_F)
	check(not game.performance_hud.visible,"F hides FPS again")
	game.performance_hud.set_process(false)
	for n in range(60): game.performance_hud._process(1.0/60)
	check(absf(game.performance_hud.fps-60)<0.01 and absf(game.performance_hud.frame_ms-16.6667)<0.01 and game.performance_hud.samples.size()>0,"FPS and milliseconds reflect render-frame timing")
	key(KEY_G)
	check(game.duels.attempts.has(game.controlled),"G preserves standing tackle control")
	game.duels.reset()
	game.score=[2,1]
	game.shots=[8,5]
	game.passes=[20,18]
	game.players[4].yellow_cards=1
	game.players[5].dismissed=true
	game.players[5].visible=false
	game.players[5].collision_layer=0
	game.players[9].energy=0.3
	var home: Vector3=game.players[0].home
	game.match_time=game.LENGTH*0.5-0.004
	await tick()
	check(game.state=="halftime" and game.half==1 and game.match_time==120,"The first half stops at exactly 45:00")
	var position: Vector3=game.players[9].position
	for n in range(120): await tick()
	check(game.match_time==120 and game.players[9].position.distance_to(position)>0.5,"Players walk toward the bench while the match clock is stopped")
	check(is_equal_approx(game.players[9].energy,0.3),"Walking off for halftime costs no stamina")
	key(KEY_ESCAPE)
	var age: float=game.interval.age
	for n in range(30): await tick()
	check(game.state=="paused" and game.interval.age==age,"Pause also suspends the interval countdown")
	game.resume()
	key(KEY_F)
	await capture("halftime-fps")
	key(KEY_ENTER)
	check(game.half==2 and game.state=="restart" and game.restart_team==1 and game.restart_type=="SANTRA","Enter starts the second half with the other team's kickoff")
	check(game.players[0].home==-home and game.attack_sign(0)==1 and game.attack_sign(1)==-1,"Both teams switch ends")
	check(game.score==[2,1] and game.shots==[8,5] and game.passes==[20,18] and game.players[4].yellow_cards==1 and game.players[5].dismissed and not game.players[5].visible,"Score, statistics, bookings and dismissals survive halftime")
	check(is_equal_approx(game.players[9].energy,0.5),"Skipping halftime still grants the same bounded recovery")
	var completed := false
	for n in range(9000):
		await tick()
		if game.state=="playing": completed=true; break
		if n%2400==0: print("SECOND HALF PREPARATION ",n," ",game.set_pieces.recovery.phase)
	check(completed and game.half==2 and game.last_touch==1,"Teams physically return and the away kickoff releases play")
	check(game.match_time<120.02,"Second-half clock waits for the kickoff")
	game.rules.reset()
	game.kick_lock=0
	game.ball.place(Vector3(0,0.23,30))
	await physics_frame
	await physics_frame
	check(game.assisted_shot_direction(Vector3.BACK).z>0.9,"Second-half shot assistance aims at the new goal")
	var keeper_target: Vector3=game.goalkeeping.update(0,0.01)
	check(keeper_target.z< -40,"Home goalkeeper now defends the north goal")
	game.begin_restart("KALE VURUŞU",0,Vector3.ZERO)
	check(game.restart_point.z== -45 and game.set_pieces.direction.z>0,"Second-half goal kick uses the new defensive end")
	game.begin_restart("PENALTI",0,Vector3.ZERO)
	check(game.restart_point.z==39 and game.set_pieces.targets[11].z==50,"Second-half penalty and opposing keeper use the correct end")
	game.set_pieces.clear()
	game.rules.reset()
	for p in game.players:
		if p.team==1: p.position.z=30
	game.players[11].position.z=49
	game.players[12].position.z=40
	game.players[9].position.z=44
	game.ball.position=Vector3(0,0.23,35)
	game.rules.kicked(8)
	check(9 in game.rules.candidates,"Offside follows the reversed attacking direction")
	game.rules.reset()
	game.state="playing"
	game.boundary_grace=0
	game.ball.pending_reset=false
	game.ball.position=Vector3(0,0.5,50.4)
	game.previous_ball=Vector3(0,0.5,49.9)
	game.last_kicker=9
	game.check_boundaries()
	check(game.state=="goal" and game.score==[3,1] and game.celebration.gathering.z>0,"Crossing the south goal credits the home team and celebrates at that end")
	game.start_match(false,false)
	check(game.half==1 and game.players[0].home==home,"A new match restores first-half orientation")
	game.match_time=119.999
	await tick()
	game.interval.age=game.interval.DURATION-0.004
	await tick()
	check(game.half==2 and game.state=="restart","The interval also ends automatically")
	game.state="playing"
	game.match_time=239.999
	await tick()
	check(game.state=="finished" and game.match_time==240,"Full time occurs once at 90:00")
	game.start_match(true)
	game.match_time=119.999
	await tick()
	check(game.state=="playing" and game.half==1,"Training has no halftime interruption")
	var crowd=game.stadium.crowd
	crowd.reset()
	game.ball.position=Vector3(0,0.3,-25)
	# Crowd unit fixture starts at committed contact; approach is tested in motion_contact_check.
	game.commit_strike(9,Vector3(1,4,-28),0,false,"shot")
	check(crowd.event_kind=="shot" and crowd.event_duration>3 and crowd.material.get_shader_parameter("event_strength")>=0.9,"Shots trigger a strong sustained crowd reaction")
	game.camera.size=21
	game.camera.position=Vector3(23,14,-24)
	game.camera.look_at(Vector3(44,3.8,-24))
	game.hud.visible=false
	game.performance_hud.visible=false
	for n in range(100): crowd.update(1.0/120,Vector3.ZERO,Vector3.ZERO,0,false,false)
	await capture("shot-crowd")
	crowd.react("miss",0,Vector3.ZERO)
	check(crowd.event_kind=="miss" and crowd.material.get_shader_parameter("event_style")==3,"Near misses select a distinct disappointment reaction")
	crowd.react("save",1,Vector3.ZERO)
	check(crowd.event_kind=="save" and crowd.material.get_shader_parameter("event_team")==1.0,"Saves excite the goalkeeper's supporters")
	print("MATCH DAY CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
