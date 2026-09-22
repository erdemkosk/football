extends SceneTree
var game
var failures := 0
var assertions := 0
var escaped_menu := false
var touched := [false,false]
var max_ball_distance := 0.0
var movement_origins: Array[Vector3]=[]
var max_movement := [0.0,0.0]

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> void:
	assertions+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)

func advance(seconds: float) -> void:
	for frame in range(int(seconds*120)):
		game._physics_process(1.0/120)
		if game.state!="menu": escaped_menu=true
		if game.last_kicker>=0: touched[game.last_touch]=true
		max_ball_distance=maxf(max_ball_distance,game.ball.position.length())
		if movement_origins.size()==2:
			for team in range(2): max_movement[team]=maxf(max_movement[team],game.players[9+team*11].position.distance_to(movement_origins[team]))
		await physics_frame

func wait_for_play(seconds: float=90) -> bool:
	for frame in range(int(seconds*120)):
		await advance(1.0/120)
		if game.menu_match.phase=="playing": return true
	print("STALLED MENU MATCH: %s / %s / %s" % [game.menu_match.phase,game.restart_type,game.set_pieces.recovery.phase])
	return false

func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw()
	for frame in range(3): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/menu-match-"+label+".png")

func check_camera() -> void:
	game.update_camera(0)
	var angle: float=0.86+sin(game.elapsed*0.035)*0.055
	var expected := Vector3(-26,0,22)+Vector3(cos(angle)*190,144,sin(angle)*190)
	check(game.camera.size==230 and game.camera.position.distance_to(expected)<0.001,"Distant stadium angle is preserved while the surrounding district stays in frame")

func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.match_menu.config_path="/tmp/football-menu-match-settings.cfg"
	check(game.state=="menu" and game.ball.active and not game.ball.freeze,"Main menu starts a live physical exhibition match")
	check(game.stadium.architecture.city_blocks>=16,"The menu backdrop continues the district with surrounding city blocks")
	movement_origins=[game.players[9].position,game.players[20].position]
	await advance(12)
	check(max_movement[0]>3 and max_movement[1]>3,"Both teams move, including the normally user-controlled player")
	# A goal/restart can reset last_kicker and return the ball near the centre.
	# Observe actual movement and touches throughout the window, not only its end.
	check(max_ball_distance>3 and (touched[0] or touched[1]),"The real ball is played away from kickoff")
	check_camera()
	await capture("day")
	await advance(48)
	check(touched[0] and touched[1],"Both AI teams touch the ball without user commands")
	# Exercise a definite shooting opportunity rather than requiring a random
	# attack to finish inside 60 seconds of throw-ins and physical recovery.
	game.rules.reset(); game.set_pieces.clear(); game.reset_advanced_play()
	game.menu_match.phase="playing"; game.kick_lock=0
	var shooter=game.players[9]
	for p in game.players:
		p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
		if p.team==1 and not p.keeper: p.position.x=18 if p.number%2==0 else -18
	shooter.position=Vector3(0,0,-37); shooter.facing=Vector3.FORWARD; shooter.rig.rotation=Vector3.ZERO
	shooter.action_timer=0; shooter.kick_timer=0; shooter.touch_cooldown=0; shooter.ai_think=20
	game.dribbler=9; game.last_touch=0; game.last_kicker=9
	game.ball.place(shooter.position+Vector3(0,.23,-.72)); game.previous_ball=game.ball.position
	await physics_frame; await physics_frame
	await advance(1)
	check(game.passes[0]+game.passes[1]>0 and game.shots[0]+game.shots[1]>0,"Background play produces genuine passes and shots")
	check(game.players.all(func(p): return not p.chosen and not p.marker.visible),"No selection marker appears over background players")
	check(game.replay.frames.is_empty() and not game.audio.match_audio and not game.audio.effects.playing,"Menu play avoids replay recording and match sound effects")
	print("MENU PLAY: time=%.1f score=%s passes=%s shots=%s phase=%s" % [game.match_time,game.score,game.passes,game.shots,game.menu_match.phase])
	print("MENU CONTACTS: ",game.kick_contact.contacts," missed approaches=",game.kick_contact.misses)
	game.stadium.light_rig.select(1)
	await advance(1)
	await capture("night")
	game.match_menu.open_menu()
	# Let PhysicsServer commit freeze before comparing the held/moving ball.
	await physics_frame
	var clock_before: float=game.match_time
	var ball_before: Vector3=game.ball.position
	for frame in range(120):
		game._physics_process(1.0/120)
		await physics_frame
	check(game.state=="paused" and game.ball.freeze and game.match_time==clock_before and game.ball.position.distance_to(ball_before)<0.01,"Settings pause the exhibition and physical ball")
	game.match_menu.close_menu()
	await advance(0.1)
	check(game.state=="menu" and not game.ball.freeze,"Closing settings resumes the background match")
	# A real goal-line crossing must celebrate and restart without changing camera.
	game.return_menu()
	game.rules.reset()
	game.ball.place(Vector3(0,0.7,-49),Vector3(0,0,-18))
	game.previous_ball=Vector3(0,0.7,-49)
	game.boundary_grace=0.05
	await advance(0.5)
	check(game.score[0]==1 and game.menu_match.phase=="goal" and game.state=="menu","A physical goal starts celebration behind the menu, without a replay cut")
	check_camera()
	check(await wait_for_play(),"Goal celebration and away kickoff finish automatically")
	for team in [0,1]:
		game.state=game.menu_match.phase
		game.begin_restart("TAÇ",team,Vector3(32,0,10 if team==0 else -10))
		game.menu_match.phase=game.state
		game.state="menu"
		check(await wait_for_play(),"Team %d retrieves and takes its throw-in without menu input" % team)
	game.menu_match.phase="finished"
	await advance(1.0/120)
	check(game.state=="menu" and game.menu_match.phase=="playing" and game.score==[0,0] and game.match_time==0,"A completed exhibition automatically starts another match")
	check(not escaped_menu,"Goals and restarts never expose match state to the menu UI")
	# Enter through the actual controller menu path after the demo has progressed.
	await advance(2)
	game.hud.sync_navigation()
	game.hud.nav_buttons[0].grab_focus()
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index=JOY_BUTTON_A; event.pressed=pressed
		Input.parse_input_event(event); Input.flush_buffered_events()
	check(game.state=="setup" and game.frontend.visible and game.frontend.stage=="teams","Controller A still opens Quick Match while the background plays")
	check(game.match_time==0 and game.score==[0,0] and game.players.all(func(p): return p.energy==1 and p.yellow_cards==0),"Quick Match has fresh score, clock, stamina and discipline")
	game.frontend.open_tactics(true)
	game.frontend.confirm()
	check(game.state=="ceremony" and not game.audio.background and game.audio.match_audio,"A real match keeps its ceremony and restores normal match audio")
	game.ceremony.finish(true)
	check(game.state=="playing" and game.is_user_player(game.controlled),"Real match returns the team to user control")
	game.return_menu()
	await advance(1)
	check(game.state=="menu" and game.menu_match.phase=="playing" and game.ball.active,"Returning from a real match starts the live menu again")
	print("MENU MATCH CHECK: %d checks, %d failures" % [assertions,failures])
	game.free()
	quit(0 if failures==0 else 1)
