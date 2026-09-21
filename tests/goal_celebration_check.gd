extends SceneTree
var game
var failures := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func tick() -> void:
	game._physics_process(1.0/120)
	game._process(1.0/120)
	await physics_frame
func capture(label: String) -> void:
	if not visual: return
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/goal-"+label+".png")
func key(code: int,pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	return event
func scenario(team: int) -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	var forward := -1.0 if team==0 else 1.0
	var scorer := 9+team*11
	for i in range(1,11):
		game.players[team*11+i].position=Vector3(-15+i*3,0,forward*(28+i))
	game.players[scorer].position=Vector3(13,0,forward*42)
	game.ball.place(Vector3(0,0.8,forward*51),Vector3(0,0.5,forward*4))
	await physics_frame
	await physics_frame
	game.last_kicker=scorer
	var original: Vector3=game.ball.position
	var momentum: Vector3=game.ball.linear_velocity
	game.goal(team)
	check(game.ball.position==original and game.ball.linear_velocity==momentum and not game.ball.freeze,"Goal preserves the moving physical ball")
	check(game.celebration.scorer==scorer and game.celebration.group.size()==10,"Every outfield teammate joins the scorer")
	check(game.stadium.crowd.event_duration>=10 and game.stadium.crowd.material.get_shader_parameter("event_team")==float(team),"Scoring supporters receive a sustained goal celebration")
	var max_step := 0.0
	var max_ball_step := 0.0
	var max_height := 0.0
	var grouped := 0
	var phases: Array[String]=[]
	var goal_frames := 0
	var paused_checked := false
	var start_clock: float=game.match_time
	var ready := false
	for frame in range(9000):
		var before: Array[Vector3]=[]
		for p in game.players: before.append(p.position)
		var ball_before: Vector3=game.ball.position
		if game.state=="goal":
			goal_frames+=1
			max_height=maxf(max_height,game.players[scorer].position.y)
			var near := 0
			for i in game.celebration.group:
				if game.flat_distance(game.players[i].position,game.celebration.gathering)<4.0: near+=1
			grouped=maxi(grouped,near)
			if goal_frames==600: await capture("celebration-%d" % team)
			if goal_frames==720 and visual:
				var saved_position: Vector3=game.camera.position
				var saved_size: float=game.camera.size
				game.camera.size=12
				game.camera.position=game.celebration.gathering+Vector3(-10,7,-8)
				game.camera.look_at(game.celebration.gathering+Vector3.UP)
				await capture("group-%d" % team)
				game.camera.position=saved_position
				game.camera.size=saved_size
			if goal_frames==360 and not paused_checked:
				game._input(key(KEY_ESCAPE,true))
				var age: float=game.celebration.age
				var crowd_age: float=game.stadium.crowd.event_age
				for n in range(30): await tick()
				check(game.celebration.age==age and game.stadium.crowd.event_age==crowd_age,"Pause freezes player and supporter celebrations")
				game.resume()
				paused_checked=true
		await tick()
		for i in range(22): max_step=maxf(max_step,before[i].distance_to(game.players[i].position))
		max_ball_step=maxf(max_ball_step,ball_before.distance_to(game.ball.position))
		if game.state=="restart":
			if not game.set_pieces.recovery.phase in phases: phases.append(game.set_pieces.recovery.phase)
			if game.restart_type!="SANTRA": break
		if game.state=="set_piece": ready=true; break
		if frame%1800==0: print("GOAL %d %.1fs state=%s phase=%s" % [team,frame/120.0,game.state,game.set_pieces.recovery.phase])
	check(grouped>=8 and max_height>0.3,"Teammates physically gather and the scorer jumps off the ground")
	check(goal_frames>=1440 and goal_frames<=2282,"Celebration remains visible before the walk back to kickoff")
	check(max_step<0.35 and max_ball_step<0.6,"Players and ball remain continuous through celebration and return")
	check(ready and game.restart_type=="SANTRA" and game.restart_team==1-team,"The conceding team receives a protected centre kickoff")
	check("carry" in phases and "place" in phases and game.ball.held_by==null and game.flat_distance(game.ball.position,Vector3.ZERO)<0.3,"A player retrieves the same ball and places it at centre")
	check(game.match_time==start_clock and game.score[team]==1,"Celebration and preparation do not advance the match clock or recount the goal")
	var legal := ready
	for i in range(22):
		if i==game.set_pieces.taker: continue
		var p=game.players[i]
		legal=legal and p.position.z*(1 if p.team==0 else -1)>=0
		if p.team==team: legal=legal and game.flat_distance(p.position,Vector3.ZERO)>=9.15
	check(legal,"Both teams return to their halves and opponents stay outside the centre circle")
	await capture("kickoff-%d" % team)
	if ready:
		if game.restart_team==0:
			for i in range(180): await tick()
			check(game.state=="set_piece","Home kickoff waits for player input")
			game._input(key(KEY_S,true))
			for i in range(18): await tick()
			game._input(key(KEY_S,false))
		for i in range(240):
			await tick()
			if game.state=="playing": break
		check(game.state=="playing" and game.last_touch==1-team and game.ball.linear_velocity.length()>2,"A real kickoff pass releases play for the conceding team")
	if not ready:
		print("BLOCKED ball=%s taker=%s" % [game.ball.position,game.set_pieces.taker])
		for i in game.set_pieces.targets: print("PLAYER %d %s -> %s" % [i,game.players[i].position,game.set_pieces.targets[i]])
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await scenario(0)
	await scenario(1)
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	game.goal(0)
	check(game.state=="goal" and game.score==[1,0],"A fresh goal is waiting on the celebration")
	game._input(key(KEY_SPACE,true))
	check(game.state=="set_piece" and game.restart_type=="SANTRA" and game.restart_team==1,"Space skips the celebration and opens the conceding kickoff")
	check(game.celebration.group.is_empty() and game.flat_distance(game.ball.position,Vector3.ZERO)<0.4,"Skip places the same ball at centre without a walk-back")
	var lined := true
	for i in range(22):
		if i==game.set_pieces.taker: continue
		var p=game.players[i]
		lined=lined and p.position.z*(1 if p.team==0 else -1)>=0
		if p.team==0: lined=lined and game.flat_distance(p.position,Vector3.ZERO)>=9.15
	check(lined,"Skip puts both teams into a legal kickoff shape")
	game.start_match(true)
	game.goal(0)
	game._input(key(KEY_SPACE,true))
	check(game.training and game.state=="playing" and game.celebration.group.is_empty(),"Practice skip returns directly to shooting")
	game.goal(0)
	for i in range(480): await tick()
	check(game.training and game.state=="playing" and game.celebration.group.is_empty(),"Practice returns directly to shooting without a kickoff sequence")
	game.start_match(false,false)
	var cleared := true
	for p in game.players: cleared=cleared and p.celebration==""
	check(cleared,"A new match clears every celebration pose")
	print("GOAL CELEBRATION CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
