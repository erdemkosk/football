extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func gap() -> float:
	var nearest := INF
	for official in game.referees.actors:
		if not official.visible: continue
		for person in game.stadium.sidelines.actors:
			if person.role=="ball_boy": nearest=minf(nearest,game.flat_distance(official.position,person.position))
	return nearest
func step(stoppage: String="",at: Vector3=Vector3.ZERO) -> void:
	game.referees.update(1.0/120)
	game.stadium.sidelines.update(1.0/120,game.ball.position,Vector3.ZERO,0,stoppage=="",stoppage,at)
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	game.ball.freeze=true
	var side=game.stadium.sidelines
	var minimum := INF
	for frame in range(960):
		game.ball.position=Vector3(0,.23,45*sin(frame*.008))
		step(); minimum=minf(minimum,gap())
	check(minimum>=1.10,"Assistants running the offside line never overlap the six resting ball boys")
	for scenario in [Vector2(-1,-1),Vector2(-1,0),Vector2(1,1),Vector2(1,0)]:
		var sign_x: int=int(scenario.x)
		side.reset(); game.referees.reset(true)
		game.state="restart"; game.restart_type="TAÇ"
		game.restart_point=Vector3(sign_x*32,0,sign_x*20)
		game.referees.restart("TAÇ",0,game.restart_point)
		for p in game.players: p.position=Vector3(0,0,0)
		var official=game.referees.actors[1 if sign_x<0 else 2]
		official.position=Vector3(sign_x*33.2,0,sign_x*20)
		game.ball.place(official.position+Vector3(0,.23,0))
		for i in range(3): await physics_frame
		game.ball.freeze=true
		game.ball.position=official.position+Vector3(0,.23,0)
		game.ball.pending_reset=false
		var boy=side.nearest_boy(game.ball.position)
		boy.position=Vector3(sign_x*35.1,0,sign_x*20+scenario.y)
		minimum=INF
		var lane_clear := true
		for frame in range(1200):
			step("TAÇ",game.restart_point)
			minimum=minf(minimum,gap())
			lane_clear=lane_clear and absf(boy.position.x)<=35.181 and absf(boy.position.x)>=32.549
		check(lane_clear,"Collection stays between the touchline and advertising boards, scenario="+str(scenario))
		check(minimum>=1.10,"Pickup and carry avoid the assistant on touchline "+str(sign_x))
		check(game.ball.held_by==boy and side.fetch_phase=="wait","The nearest boy can retrieve a ball at the assistant's feet and deliver it, side="+str(sign_x))
		check(absf(official.position.z-game.restart_point.z)<.35,"Sidestepping preserves the assistant's decision line, side="+str(sign_x))
		if "--visual" in OS.get_cmdline_user_args() and scenario==Vector2(1,1):
			game.ball.position=boy.hand_center()
			game.hud.visible=false
			game.camera.position=Vector3(24,5,28)
			game.camera.look_at(Vector3(34,1,20)); game.camera.size=9
			await process_frame; RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://tests/sideline-clearance.png")
		game.ball.release_hold()
	# Exercise the complete physical pickup -> handover -> legal throw-in flow.
	game.start_match(false,false); game.set_physics_process(false)
	for p in game.players: p.position=Vector3(0,0,0)
	game.ball.place(Vector3(33.2,.23,20))
	for i in range(3): await physics_frame
	var boy=side.nearest_boy(game.ball.position)
	boy.position=Vector3(35.1,0,21)
	game.referees.actors[2].position=Vector3(33.2,0,20)
	game.begin_restart("TAÇ",0,Vector3(32,0,20))
	var saw_pickup := false
	var saw_handover := false
	minimum=INF
	for frame in range(3600):
		game.simulate_match(1.0/120)
		side.update(1.0/120,game.ball.position,game.ball.linear_velocity,0,false,"TAÇ",game.restart_point)
		await physics_frame
		minimum=minf(minimum,gap())
		saw_pickup=saw_pickup or game.ball.held_by==boy
		saw_handover=saw_handover or game.ball.held_by==game.players[game.set_pieces.taker]
		if game.state=="set_piece": break
	check(saw_pickup and saw_handover and game.state=="set_piece","A real throw-in finishes pickup, handover and legal preparation without stalling")
	check(minimum>=1.10,"The assistant and boy remain apart during the complete physical restart")
	# A boy may reach the ball after recovery already assigned a nearby player.
	game.start_match(false,false); game.set_physics_process(false)
	game.ball.place(Vector3(34.9,.23,32.1))
	for i in range(3): await physics_frame
	game.begin_restart("TAÇ",0,Vector3(32,0,31.85))
	var recovery=game.set_pieces.recovery
	recovery.enter("retrieve")
	boy=side.nearest_boy(game.ball.position)
	boy.position=Vector3(34.55,0,31.85)
	side.fetch_boy=boy; side.fetch_phase="carry"; side.fetch_age=0
	game.ball.hold(boy)
	recovery.step(1.0/120)
	check(recovery.phase=="sideline","A late ball-boy pickup transfers the recovery job instead of leaving a player chasing a held ball")
	for frame in range(3600):
		game.simulate_match(1.0/120)
		side.update(1.0/120,game.ball.position,game.ball.linear_velocity,0,false,"TAÇ",game.restart_point)
		await physics_frame
		if game.state=="set_piece": break
	check(game.state=="set_piece" and game.ball.held_by==game.players[game.set_pieces.taker],"A late ball-boy handover completes as a legal throw-in without a restart deadlock")
	print("SIDELINE SPACING CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
