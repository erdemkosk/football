extends "res://tests/advanced_play_check.gd"
const Size = preload("res://scripts/ball_dimensions.gd")

func shot_case(kind: String,pad: bool,sprint: bool) -> void:
	await reset()
	game.controller.device=0
	key(KEY_UP)
	if sprint: key(KEY_W)
	await tick(60)
	if pad: button(JOY_BUTTON_X)
	else: key(KEY_D,true,kind=="low",kind=="power",kind=="outside")
	if kind in ["low","power","outside"]: game.finishing.style=kind
	if kind=="chip": game.shot_chip=true
	if kind=="finesse": game.shot_finesse=true
	await tick(24)
	var aim: Vector3=game.shot_direction
	var before: Vector3=game.ball.position
	check(game.charging and game.has_ball_control(9),"Controlled charge: %s pad=%s sprint=%s" % [kind,pad,sprint])
	if pad: button(JOY_BUTTON_X,false)
	else: key(KEY_D,false)
	check(game.shots[0]==1 and game.ball.pending_kick and game.kick_contact.pending.is_empty() and game.finishing.pending.is_empty(),"Release strikes in the input frame: %s pad=%s sprint=%s" % [kind,pad,sprint])
	check(not game.charging and p.shot_preparation==0 and (p.kick_timer>0 or p.action_timer>0),"Charge ends with an active follow-through: "+kind)
	check((game.ball.kick_velocity*Vector3(1,0,1)).normalized().dot(aim)>.9999,"Immediate shot preserves preview direction: "+kind)
	check(game.ball.position.is_equal_approx(before),"Release changes velocity without teleporting the ball")
	await tick(8)
	check(game.ball.linear_velocity.length()>10 and game.flat_distance(before,game.ball.position)>.6,"Physical ball leaves the boot after release: "+kind)
	if pad: button(JOY_BUTTON_X,false)
	else: key(KEY_D,false)
	check(game.shots[0]==1,"Duplicate release cannot create another shot")
	key(KEY_UP,false); key(KEY_W,false)

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/pace-release-settings.cfg"
	await reset()
	var collision: SphereShape3D
	var shell: SphereMesh
	for child in game.ball.get_children():
		if child is CollisionShape3D: collision=child.shape
	if game.ball.shell!=null: shell=game.ball.shell.mesh
	check(is_equal_approx(collision.radius,Size.RADIUS) and is_equal_approx(shell.radius,Size.RADIUS),"Visual and physical ball share the same diameter")
	game.dribbler=-1; p.position=Vector3(4,0,-30)
	game.ball.place(Vector3(0,Size.GROUND_HEIGHT,-30))
	for n in range(120): await physics_frame
	check(absf(game.ball.position.y-Size.RADIUS)<.025 and absf(game.ball.linear_velocity.y)<.1,"Smaller ball rests on the turf without sinking or hovering")
	game.ball.place(Vector3(0,-.06,-30),Vector3(3,-6,0))
	for n in range(5): await physics_frame
	check(game.ball.position.y>=Size.RADIUS-.005 and game.ball.position.x>0,"A ground penetration recovers through turf contact without losing horizontal travel")
	var recovery=game.set_pieces.recovery
	game.training=false; game.begin_restart("SERBEST VURUŞ",0,Vector3(0,0,-30))
	game.ball.place(Vector3(0,Size.RADIUS+.02,-30)); game.ball.freeze=false
	for n in range(45): await physics_frame
	recovery.worker=game.set_pieces.taker; recovery.enter("arrange")
	for n in range(40): recovery.step(DT)
	check(recovery.rest_age>.25,"A settled small ball counts as placed despite the physics contact margin")
	check(is_equal_approx(game.hud.shot_guide.RADIUS,Size.RADIUS) and is_equal_approx(game.hud.landing_guide.RADIUS,Size.RADIUS),"Shot and landing previews share physical ball dimensions")
	for owner in [9,20,0,11]:
		await reset(owner)
		p.attributes.pace=72
		p.reset_stamina(); p.desired=Vector3.FORWARD
		var run_speed: float=p.movement_speed()
		check(run_speed<6.6*p.MOVEMENT_PACE and run_speed>6.0*p.MOVEMENT_PACE,"Normal pace reduced for player "+str(owner))
		p.sprinting=true
		for n in range(200): p.step(DT); await physics_frame
		var speed: float=Vector2(p.velocity.x,p.velocity.z).length()
		check(speed>9.6*p.MOVEMENT_PACE and speed<11.0*p.MOVEMENT_PACE,"Physical sprint is controlled for player %d: %.2f m/s" % [owner,speed])
		p.exhausted=true
		check(is_equal_approx(p.movement_speed(),3.4*p.MOVEMENT_PACE),"Fatigued movement uses the same pace scale")
	for kind in ["normal","chip","finesse","low","power","outside"]:
		for pad in [false,true]:
			await shot_case(kind,pad,pad)
	for reason in ["opponent","impact","distant","paused"]:
		await reset(); key(KEY_D); await tick(12)
		match reason:
			"opponent":
				var opponent=game.players[20]
				opponent.visible=true; opponent.position=game.ball.position-Vector3(0,Size.GROUND_HEIGHT,.2)
				game.dribbler=20; game.last_kicker=20
			"impact": p.receive_impact(Vector3.RIGHT,.85)
			"distant": p.position.x+=6
			"paused": game.state="paused"
		key(KEY_D,false)
		check(game.shots[0]==0 and not game.ball.pending_kick,"Cannot release an invalid shot: "+reason)
	await reset(); key(KEY_5); key(KEY_5,false); key(KEY_D); await tick(18); key(KEY_D,false)
	check(game.finishing.active(9) and game.shots[0]==0,"Explicit timed finishing still allows the second input")
	await tick(20); key(KEY_D); key(KEY_D,false); await tick(35)
	check(game.shots[0]==1 and game.finishing.result=="MÜKEMMEL ZAMANLAMA","Deliberate timed shot still finishes successfully")
	# The whole, smaller ball must cross the line, including near-post shots
	# that fit inside the goal with the new radius.
	for side in [-1,1]:
		await reset()
		game.ball.freeze=true; game.boundary_grace=0
		var near_post := 3.66-Size.RADIUS-.05
		game.previous_ball=Vector3(near_post,.7,side*49.9)
		game.ball.position=Vector3(near_post,.7,side*(50+Size.RADIUS*.5))
		game.check_boundaries()
		check(game.score==[0,0],"A partially crossing ball is not a goal, side "+str(side))
		game.previous_ball=game.ball.position
		game.ball.position.z=side*(50+Size.RADIUS+.02)
		game.check_boundaries()
		check(game.score[0]+game.score[1]==1,"A whole-ball near-post crossing scores with the new radius, side "+str(side))
		game.ball.freeze=false
	if visual:
		await reset()
		game.dribbler=-1; game.ball.freeze=true
		game.ball.position=p.position+Vector3(.4,Size.GROUND_HEIGHT,-.45)
		game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=40
		game.camera.position=p.position+Vector3(2.7,1.6,-3.7)
		game.camera.look_at(p.position+Vector3(0,.75,0))
		await process_frame; RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://tests/ball-pace-scale.png")
	print("BALL PACE RELEASE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
