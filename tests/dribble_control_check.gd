extends SceneTree
const DT := 1.0/120.0
var game
var p
var checks := 0
var failures := 0
var visual := false
var trace := false
var samples: Array = []
var touch_gaps: Array[float] = []
var free_frames := 0
var last_sample_contacts := 0
var styles: Dictionary = {}
var sim_delta := DT
var captured: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func setup(direction: Vector3=Vector3.FORWARD,weather: int=0) -> void:
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false); game.hud.hide()
	game.weather.select(weather,true)
	for player in game.players:
		player.visible=player==p; player.collision_layer=2 if player==p else 0
		player.desired=Vector3.ZERO; player.velocity=Vector3.ZERO
	p.position=Vector3(0,0,-10); p.facing=direction
	p.rig.rotation=Vector3(0,atan2(-direction.x,-direction.z),0)
	p.body_language.enabled=false; p.animate(1)
	game.dribbler=-1; game.carrier=-1; game.kick_lock=0
	game.ball.place(p.position+direction*.78+Vector3.UP*.23)
	await physics_frame; await physics_frame
	samples.clear(); touch_gaps.clear(); styles.clear(); free_frames=0; last_sample_contacts=0

func drive(direction: Vector3,frames: int,sprint: bool=false) -> void:
	for frame in range(frames):
		p.desired=direction; p.sprinting=sprint
		game.kick_contact.prepare(sim_delta)
		p.step(sim_delta)
		game.kick_contact.resolve()
		var point: Vector3=game.ball.position
		game.update_contacts(sim_delta)
		if game.ball.position!=point: check(false,"Dribbling must never teleport the ball")
		if game.ball.pending_touch:
			if p.dribble_motion.contacts!=last_sample_contacts:
				touch_gaps.append(p.dribble_motion.last_gap)
				styles[p.dribble_motion.style]=true
				if visual and not samples.is_empty() and not captured.has(p.dribble_motion.style):
					captured[p.dribble_motion.style]=true
					await capture(p.dribble_motion.style)
		else: free_frames+=1
		last_sample_contacts=p.dribble_motion.contacts
		await physics_frame
		var gap: float=game.flat_distance(p.position,game.ball.position)
		samples.append(gap)
		if trace and frame%8==0:
			print("TRACE ",frame," gap=",gap," vel=",p.velocity," ballv=",game.ball.linear_velocity," offset=",game.ball.position-p.position," age=",p.dribble_motion.age," boot=",p.dribble_motion.boot(p).distance_to(game.ball.position)," style=",p.dribble_motion.style," touches=",p.dribble_motion.contacts," owner=",game.dribbler)

func capture(label: String) -> void:
	var velocity: Vector3=game.ball.linear_velocity
	var angular: Vector3=game.ball.angular_velocity
	game.ball.freeze=true
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=42
	game.camera.position=p.position+Vector3(3.5,2.2,-4.5)
	game.camera.look_at(p.position+Vector3(0,.9,0))
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/dribble-"+label+".png")
	game.ball.freeze=false; game.ball.linear_velocity=velocity; game.ball.angular_velocity=angular

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	trace="--trace" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-dribble-control-test.cfg"
	p=game.players[9]
	await setup()
	await drive(Vector3.FORWARD,240)
	print("RUN gap range=",samples.min(),"..",samples.max()," contacts=",touch_gaps.size()," free=",free_frames)
	# Compare established carries: the shared 0.78m setup/acquisition gap is
	# not the distance a jogging player keeps once the first touch settles.
	var running_gap: float=samples.slice(120).max()
	check(touch_gaps.size()>3 and touch_gaps.size()<30 and free_frames>190,"Running uses separate boot impulses with smooth close-control guidance between them")
	check(samples.max()<1.35 and samples.max()-samples.min()>.12 and game.dribbler==9,"The ball rolls ahead and is recovered without a fixed foot offset")
	if not touch_gaps.is_empty(): check(touch_gaps.max()<.40,"Every dribble impulse has an actual animated boot contact")
	if visual: await capture("running")
	samples.clear()
	await drive(Vector3.RIGHT,80)
	await drive(Vector3.LEFT,100)
	print("TURN max=",samples.max()," styles=",styles," owner=",game.dribbler)
	check(samples.max()<1.5 and game.dribbler==9,"Right-angle cuts and full reversals keep the ball recoverable")
	check(styles.has("sole") and (styles.has("inside") or styles.has("outside")),"Sharp turns use contextual sole and side-of-foot animations")
	await setup()
	await drive(Vector3.FORWARD,260,true)
	print("SPRINT max=",samples.max()," contacts=",touch_gaps.size())
	var sprint_gap: float=samples.slice(120).max()
	check(sprint_gap>running_gap+.08 and samples.max()<1.12 and game.dribbler==9,"Sprinting exposes the ball a little farther without losing it")
	samples.clear(); await drive(Vector3.FORWARD,140)
	print("RECOVER max=",samples.max()," last=",samples.back()," owner=",game.dribbler)
	check(game.dribbler==9 and samples.back()<1.2,"Releasing sprint returns to controlled touches")
	await drive(Vector3.ZERO,140)
	check(game.ball.linear_velocity.length()<.25 and game.flat_distance(p.position,game.ball.position)<1.15,"A sole contact settles the ball when the runner stops")
	for phase in [80,130,190,260]:
		await setup(); await drive(Vector3.FORWARD,phase,true)
		samples.clear(); await drive(Vector3.BACK,120,true)
		check(game.dribbler==9 and samples.max()<1.55,"A sprint reversal keeps the ball controlled at stride phase %d" % phase)
	for weather in [1,2]:
		await setup(Vector3.BACK,weather)
		trace=weather==1 and "--trace" in OS.get_cmdline_user_args()
		await drive(Vector3.BACK,180)
		await drive(Vector3.LEFT,65)
		await drive(Vector3.RIGHT,80)
		trace=false
		print("WET ",weather," max=",samples.max()," owner=",game.dribbler)
		check(game.dribbler==9 and samples.max()<1.5,"Wet-ground dribbling and mirrored turns remain controllable: %d" % weather)
	for rate in [60,30]:
		Engine.physics_ticks_per_second=rate; sim_delta=1.0/rate
		await setup()
		await drive(Vector3.FORWARD,rate*2)
		await drive(Vector3.RIGHT,rate)
		await drive(Vector3.LEFT,rate)
		check(game.dribbler==9 and samples.max()<1.5,"Discrete foot contacts work at %d physics ticks" % rate)
	Engine.physics_ticks_per_second=120; sim_delta=DT
	await setup()
	await drive(Vector3.FORWARD,120)
	check(game.ball.get_collision_exceptions().has(p),"Animated feet replace the carrier capsule only during grounded control")
	game.strike(9,Vector3(0,2,-24),0,false,"shot")
	check(p.dribble_motion.preparing and game.ball.get_collision_exceptions().has(p) and game.dribbler==-1,"A controlled shot keeps its close-control contact until the boot releases it")
	await drive(Vector3.ZERO,40)
	check(game.flat_distance(p.position,game.ball.position)>4 and game.dribbler==-1 and not p.dribble_motion.preparing and not game.ball.get_collision_exceptions().has(p),"A released shot restores ordinary collisions and is never pulled back by dribble assistance")
	await setup(); await drive(Vector3.FORWARD,90)
	game.ball.place(p.position+Vector3(4,.23,0),Vector3(7,0,0))
	await physics_frame; await physics_frame
	await drive(Vector3.FORWARD,30)
	check(game.dribbler==-1 and not game.ball.get_collision_exceptions().has(p),"A lost ball removes the carrier exception and stays free")
	await setup(); await drive(Vector3.FORWARD,90)
	game.state="paused"; game.simulate_match(DT)
	check(not game.ball.get_collision_exceptions().has(p) and p.dribble_motion.age>=p.dribble_motion.DURATION,"Pause clears pending touches and the carrier collision exception")
	await setup(); await drive(Vector3.FORWARD,90)
	p.receive_impact(Vector3.RIGHT,.85)
	await drive(Vector3.ZERO,1)
	check(game.dribbler==-1 and not game.ball.get_collision_exceptions().has(p),"A physical knockdown interrupts control and restores collision")
	p=game.players[20]
	await setup(Vector3.BACK)
	await drive(Vector3.BACK,180)
	await drive(Vector3.LEFT,75)
	check(game.dribbler==20 and p.dribble_motion.contacts>3 and samples.max()<1.5,"An opponent uses the same physical footwork and control limits")
	print("DRIBBLE CONTROL CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
