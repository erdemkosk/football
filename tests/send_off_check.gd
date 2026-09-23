extends SceneTree
const P = preload("res://scripts/pitch_dimensions.gd")
var game
var failures := 0
var visual := false
const DT := 1.0/120.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func tick() -> void:
	game.simulate_match(DT)
	if visual: game.update_camera(DT)
	await physics_frame
func capture(label: String) -> void:
	if not visual: return
	game.update_camera(0)
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/sefc-send-off-"+label+".png")
func arrange() -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	for i in range(22):
		game.players[i].position=Vector3(-24+(i%11)*4.5,0,24 if i<11 else -24)
		game.players[i].velocity=Vector3.ZERO
	game.players[9].position=Vector3(0,0,-6)
	game.players[20].position=Vector3(0,0,-7.2)
	game.players[8].position=Vector3(4,0,-4)
	game.players[19].position=Vector3(-4,0,-9)
	game.players[9].energy=0.04
	game.players[9].exhausted=true
	game.players[9].shirt_number=27
	game.players[9].apply_identity({"shirt":27})
	game.controlled=9
	game.players[9].chosen=true
	game.referees.actors[0].position=Vector3(2.2,0,-4.8)
	game.ball.place(Vector3(0,0.23,-8),Vector3(0,1,-3))
	for i in range(3): await physics_frame
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await arrange()
	var origin: Vector3=game.players[9].position
	game.rules.foul(9,20,true,true)
	check(game.players[9].dismissed and not game.players[9].visible and game.controlled!=9,"Direct red immediately removes the selected footballer from play")
	var entry: Dictionary=game.send_off.exits[0]
	var actor=entry.actor
	check(actor.visible and actor.position.distance_to(origin)<0.01 and actor.shirt_number==27 and actor.number==game.players[9].number and actor.body_scale==game.players[9].body_scale,"Dismissed player remains visible at the foul with the same identity, build and shirt")
	check(actor not in game.players and actor.collision_layer==0 and (actor.collision_mask & game.ball.collision_layer)==0 and not actor.marker.visible,"Exit actor cannot receive passes, be selected or collide with the ball")
	check(not game.referees.ready_for_restart(),"Restart waits for the dismissal and departure")
	var ball_start: Vector3=game.ball.position
	var saw_red := false
	var saw_shove := false
	var saw_stumble := false
	var physical_recoil := false
	var dead_ball_moved := false
	var saw_separate := false
	var saw_calm := false
	var crossed := false
	var continuous := true
	var waited := true
	var stamina: float=actor.energy
	var screenshots: Dictionary={}
	for i in range(4000):
		var previous: Vector3=actor.position
		var was_blocking: bool=game.send_off.blocks_restart()
		await tick()
		if game.send_off.exits.is_empty(): break
		continuous=continuous and game.flat_distance(actor.position,previous)<0.20
		saw_red=saw_red or game.referees.actors[0].gesture=="red"
		saw_shove=saw_shove or (entry.phase=="confront" and actor.discipline_pose=="shove")
		saw_stumble=saw_stumble or (game.players[20].pose=="stumble" and game.players[20].action_timer>0)
		physical_recoil=physical_recoil or (game.players[20].pose=="stumble" and game.players[20].velocity.dot(entry.direction)>0.5)
		saw_calm=saw_calm or game.referees.actors[0].gesture=="separate"
		for helper in entry.helpers: saw_separate=saw_separate or game.players[helper].discipline_pose=="separate"
		if was_blocking:
			waited=waited and game.state=="restart"
			dead_ball_moved=dead_ball_moved or game.ball.position.distance_to(ball_start)>0.5
		if entry.phase=="exit" and actor.position.x>=P.HALF_WIDTH+1.3 and not crossed:
			crossed=true
			check(game.referees.ready_for_restart(),"Referee permits play after the player crosses the touchline")
			check(absf(actor.energy-stamina)<0.00001,"Even an exhausted player leaves without losing stamina")
		if entry.phase=="card" and saw_red and not screenshots.has("card"):
			screenshots.card=true
			await capture("card")
		if entry.phase=="confront" and entry.age>0.3 and not screenshots.has("shove"):
			screenshots.shove=true
			await capture("shove")
		if entry.phase=="separate" and entry.age>1.2 and not screenshots.has("separate"):
			screenshots.separate=true
			await capture("separate")
		if entry.phase=="exit" and actor.position.x>25 and not screenshots.has("exit"):
			screenshots.exit=true
			game.update_camera(0)
			check(not game.camera.is_position_behind(actor.position) and root.get_visible_rect().has_point(game.camera.unproject_position(actor.position+Vector3.UP)),"Departure camera keeps the player visible up to the touchline")
			await capture("exit")
	check(saw_red and saw_shove and saw_stumble and physical_recoil,"Visible red card is followed by a short push and physical recoil")
	check(saw_separate and saw_calm,"Both teams separate the players while the referee calms them")
	check(waited and crossed and continuous,"Restart waits for a continuous physical exit without teleporting")
	check(game.send_off.exits.is_empty(),"Dismissed player reaches the stadium tunnel and is cleaned up")
	check(dead_ball_moved,"Dead ball remains physical during the card incident")
	var clean := true
	for p in game.players: clean=clean and p.discipline_pose==""
	check(clean,"Remaining players return to ordinary football animations")
	for i in range(1800):
		if game.state in ["set_piece","playing"]: break
		await tick()
	check(game.state in ["set_piece","playing"],"Free-kick recovery and play resume after the incident")
	game.reset_positions(0)
	check(game.players[9].dismissed and not game.players[9].visible,"Kickoff cannot restore a dismissed player")
	await arrange()
	check(game.players[9].visible and not game.players[9].dismissed,"New match restores the roster and clears send-offs")
	game.players[20].yellow_cards=1
	game.referees.actors[0].position=game.players[20].position+Vector3(2.2,0,1.2)
	game.rules.foul(20,9,true)
	entry=game.send_off.exits[0]
	actor=entry.actor
	var stages: Array[String]=[]
	for i in range(900):
		await tick()
		var gesture: String=game.referees.actors[0].gesture
		if gesture in ["yellow","red"] and gesture not in stages: stages.append(gesture)
		if entry.phase=="exit": break
	check(stages==["yellow","red"] and game.players[20].dismissed and actor.team==1,"Away second yellow presents yellow then red before departure")
	var paused_position: Vector3=actor.position
	var paused_age: float=entry.age
	game.state="paused"
	for i in range(120): await tick()
	check(actor.position==paused_position and entry.age==paused_age,"Pause freezes both the departure and disciplinary choreography")
	game.start_match(false,false)
	await physics_frame
	check(game.send_off.exits.is_empty() and not is_instance_valid(actor),"Starting another match removes unfinished departure actors")
	# Vary approach directions and include an occupied referee target, both
	# touchlines, a corner and a keeper recovering inside the goal mouth.
	for scenario in range(0 if visual else 5):
		await arrange()
		var point: Vector3=[Vector3(-30,0,40),Vector3(30,0,-42),Vector3(-29,0,-48),Vector3(0,0,20),Vector3(0,0,50.4)][scenario]
		var offender: int=0 if scenario==4 else 9
		var direction := Vector3(sin(scenario*1.3),0,cos(scenario*1.3))
		game.players[offender].position=point
		game.players[20].position=point+direction*1.2
		game.players[8].position=point+Vector3(2.2,0,1.2)
		game.players[19].position=point-direction*3
		game.players[7].position=point.lerp(Vector3(P.HALF_WIDTH+1.8,0,clampf(point.z,-46,46)),0.7)
		game.referees.actors[0].position=point+Vector3(-10,0,-5)
		game.ball.place(point+Vector3(2,0.3,0))
		if scenario==4: game.players[0].receive_impact(Vector3.FORWARD,0.4)
		for j in range(3): await physics_frame
		game.rules.foul(offender,20,true,true)
		var recovered := false
		for j in range(4800):
			await tick()
			if game.send_off.exits.is_empty(): recovered=true; break
		check(recovered,"Physical send-off completes from crowded/boundary/keeper scenario %d" % scenario)
		if not recovered: print("STALLED: ",game.send_off.exits," referee=",game.referees.card_stage)
	print("SEND OFF CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
