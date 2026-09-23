extends SceneTree
const P = preload("res://scripts/pitch_dimensions.gd")
const Guide = preload("res://scripts/ball_landing_guide.gd")
var game
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func advance(p,seconds: float) -> void:
	for frame in range(roundi(seconds*120)): p.update_stamina(1.0/120)
func probe(point: Vector3,last: int=0) -> void:
	game.state="playing"; game.restart_type=""
	game.ball.pending_reset=false; game.ball.position=point
	game.previous_ball=Vector3(point.x,.23,clampf(point.z,-49,49))
	game.boundary_grace=0; game.last_touch=last
	game.check_boundaries()
func capture(label: String) -> void:
	game.hud.queue_redraw()
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/sefc-pitch-"+label+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	game.ball.freeze=true
	check(P.WIDTH==72 and P.LENGTH==100,"Pitch gains eight metres of real playable width")
	check(game.players.size()==22,"The larger pitch remains eleven versus eleven")
	for side in [-1,1]:
		probe(Vector3(side*34,.23,0))
		check(game.state=="playing","Old touchline no longer ends play, side="+str(side))
		probe(Vector3(side*36.2,.23,0))
		check(game.state=="playing","The whole ball must cross the new touchline, side="+str(side))
		probe(Vector3(side*36.24,.23,8))
		check(game.state=="restart" and game.restart_type=="TAÇ" and is_equal_approx(game.restart_point.x,side*36),"Throw-in is placed on the new line, side="+str(side))
		check(is_equal_approx(game.set_pieces.targets[game.set_pieces.taker].x,side*36.32),"Thrower stands outside the new touchline, side="+str(side))
		probe(Vector3(side*34,.23,-50.3),1)
		check(game.restart_type=="KORNER" and is_equal_approx(game.restart_point.x,side*35.6),"Corner moves to the new flag, side="+str(side))
		check(Guide.on_pitch(Vector3(side*35,1,0)) and not Guide.on_pitch(Vector3(side*36.1,1,0)),"Landing guide recognises the added wing space, side="+str(side))
		var route: Dictionary=game.Passing.plan(Vector3(side*24,.23,0),Vector3(side*34,0,-12),Vector3.ZERO,false,game.weather)
		check(absf(route.target.x)>33.5,"Assisted pass can target the expanded wing, side="+str(side))
	game.management.apply_formation()
	check(absf(game.players[1].home.x)>25 and absf(game.players[12].home.x)>25,"Both teams spread their fullbacks into the new width")
	check(game.players.all(func(p): return absf(p.home.x)<36),"All formation positions remain on the pitch")
	check(game.stadium.sidelines.actors.all(func(a): return absf(a.position.x)>36),"Benches and sideline personnel stay outside the playing area")
	check(absf(game.referees.kickoff_target(1).x)>36,"Assistant referee follows the new touchline")
	check(game.stadium.grass.get_shader_parameter("half_pitch")==Vector2(36,50),"Grass and weather shader use the actual pitch edge")
	check(game.stadium.light_rig.floodlights.size()==4,"Wider stadium keeps the same four floodlights")
	# The added metres must also exist in the collision world, not only in rules.
	game.ball.release_hold(); game.ball.freeze=false
	game.ball.place(Vector3(31,.23,0),Vector3(10,0,0))
	for frame in range(95): await physics_frame
	check(game.ball.position.x>36 and game.ball.linear_velocity.x>0,"A real rolling ball crosses the old board position without rebounding")
	game.ball.freeze=true
	for team in [0,1]:
		var p=game.players[9+team*11]
		p.attributes["stamina"]=72
		p.stamina_free_movement=false; p.action_timer=0
		p.reset_stamina(); p.desired=Vector3.FORWARD; p.sprinting=true
		advance(p,15)
		check(p.energy>.59 and not p.exhausted and p.active_sprint,"Fifteen-second sprint still leaves useful reserves, team="+str(team))
		advance(p,22)
		check(p.exhausted and not p.active_sprint,"Continuous sprint still eventually exhausts the player, team="+str(team))
		p.reset_stamina(); p.desired=Vector3.FORWARD; p.sprinting=false
		advance(p,120)
		check(p.energy>.65 and p.energy<.70 and not p.exhausted,"A full half of normal running leaves about two-thirds energy, team="+str(team))
		p.reset_stamina(); p.desired=Vector3.FORWARD; p.sprinting=true; p.stamina_free_movement=true
		advance(p,20)
		check(p.energy==1,"Dead-ball retrieval remains free of stamina cost, team="+str(team))
		p.stamina_free_movement=false
	if "--visual" in OS.get_cmdline_user_args():
		game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
		game.state="playing"; game.toast_timer=0; game.ball.place(Vector3(0,.23,0))
		for frame in range(3): await physics_frame
		game.match_camera.select("tactical"); game.update_camera(0)
		await capture("overview")
		game.match_camera.select("sideline"); game.update_camera(0)
		await capture("play")
		game.ball.place(Vector3(35.4,.23,8))
		game.players[game.controlled].position=Vector3(34.7,0,8)
		for frame in range(3): await physics_frame
		game.update_camera(0)
		await capture("wing")
		game.stadium.light_rig.select(1); game.update_camera(0)
		await capture("night")
	print("PITCH SPACE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
