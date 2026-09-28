extends "res://tests/motion_contact_check.gd"
## Exercise real movement and boot contacts; visual overlays may not lock input,
## invent a kick or detach recovery from the current stride.

func grounded() -> bool:
	var floor_y: float=p.global_position.y+p.boot_ground_height()
	return minf(p.left_knee.to_global(p.ball_actions.BOOT).y,p.right_knee.to_global(p.ball_actions.BOOT).y)>=floor_y-.025

func snapshot(label: String) -> void:
	if not visual: return
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=38
	game.camera.position=p.position+Vector3(3.6,2.4,-4.4)
	game.camera.look_at(p.position+Vector3(0,1,0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/sefc-natural-motion-"+label+".png")

func run_steps(count: int,delta: float=DT) -> void:
	for frame in range(count):
		tick(delta)
		await physics_frame

func curved_run(rate: int,side: float) -> void:
	setup(); p.sprinting=true; p.desired=Vector3.FORWARD
	var delta := 1.0/rate
	await run_steps(rate,delta)
	var phase: float=p.run_phase
	var peak := 0.0
	var feet_clear := true
	for frame in range(rate/2):
		p.desired=Vector3.FORWARD.rotated(Vector3.UP,side*(frame+1)*delta*1.5)
		await run_steps(1,delta)
		peak=maxf(peak,absf(p.locomotion.arc_load))
		feet_clear=feet_clear and grounded()
	check(peak>.06 and peak<.81 and p.locomotion.arc_load*side<0,"Continuous %s curve loads the outside leg at %d Hz" % ["left" if side>0 else "right",rate])
	check(feet_clear and p.run_phase>phase and p.velocity.dot(p.desired)>5,"A curved sprint retains grounded, advancing strides at %d Hz" % rate)
	if rate==120 and side>0: await snapshot("curved-run")
	await run_steps(rate,delta)
	check(absf(p.locomotion.arc_load)<.01,"Straightening the run releases the curved stance at %d Hz" % rate)

func reaching_pass(rate: int,side: float,team: int) -> void:
	p=game.players[9+11*team]; setup()
	var yaw := PI if team==1 else 0.0
	var direction := Vector3.FORWARD.rotated(Vector3.UP,yaw)
	p.facing=direction; p.rig.rotation.y=yaw; p.animate(1)
	game.ball.position=p.position+Vector3(side*.65,.23,-.75).rotated(Vector3.UP,yaw)
	check(game.strike(9+11*team,direction*14),"A wide pass starts on either foot/team at %d Hz" % rate)
	var elapsed := 0.0
	while not game.kick_contact.pending.is_empty() and elapsed<.2:
		await run_steps(1,1.0/rate); elapsed+=1.0/rate
	check(game.ball.pending_kick and game.feedback.event_count==1 and game.kick_contact.last_gap<=game.kick_contact.RADIUS and elapsed<=.1,"Reaching still produces one measured boot contact within 100 ms at %d Hz" % rate)
	check(p.ball_actions.foot==(0 if side<0 else 1) and p.spine.rotation.z*side<-.02,"A wide pass leans toward its actual striking side at %d Hz" % rate)
	check(grounded() and game.strike_quality.last.get("intended",Vector3.ZERO).distance_to(direction*14)<.001,"The support boot stays above turf and intended pass direction is preserved")
	if rate==120 and team==0 and side>0: await snapshot("reaching-pass")
	p.desired=direction
	await run_steps(rate/2,1.0/rate)
	check(p.kick_timer==0 and p.velocity.dot(direction)>p.movement_speed()*.95 and p.run_phase>1,"The reaching pass releases straight into the next run")
	p=game.players[9]

func recovery_path(rate: int,direction: Vector3,with_contact: bool) -> Dictionary:
	setup(); p.body_language.enabled=true; p.body_language.ball_target=p.position+Vector3(0,.23,-4)
	p.desired=Vector3.FORWARD; p.sprinting=true
	await run_steps(rate/2,1.0/rate)
	var origin: Vector3=p.position
	var phase: float=p.run_phase
	if with_contact: p.body_language.contact(p,direction,.8)
	var travel: Array[Vector3]=[]
	var boots: Array[Vector3]=[]
	var feet_clear := true
	var widest := 0.0
	for frame in range(rate):
		# Reverse input in mid-recovery: the animation cannot defer the turn.
		if frame==rate/3: p.desired=Vector3.LEFT
		await run_steps(1,1.0/rate)
		travel.append(p.position-origin)
		boots.append(p.left_knee.to_global(p.ball_actions.BOOT)-p.position)
		boots.append(p.right_knee.to_global(p.ball_actions.BOOT)-p.position)
		feet_clear=feet_clear and grounded()
		widest=maxf(widest,absf(p.right_arm.rotation.z))
		if with_contact and rate==120 and frame==19 and direction==Vector3.RIGHT: await snapshot("catch-step")
	return {"travel":travel,"boots":boots,"ground":feet_clear,"arm":widest,"phase":p.run_phase-phase,"timer":p.action_timer}

func shoulder_contact() -> void:
	setup(); p.body_language.enabled=true; p.protecting=true
	var other=game.players[20]
	other.visible=true; other.position=p.position+Vector3(.75,0,0)
	other.rig.rotation=Vector3.ZERO; other.facing=Vector3.FORWARD; other.velocity=Vector3.ZERO; other.desired=Vector3.ZERO
	game.ball.position=p.position+Vector3(0,.23,-.6); game.dribbler=9
	for frame in range(25):
		p.body_language.observe(game,9); other.body_language.observe(game,20)
		p.step(DT); other.step(DT); await physics_frame
	var before: float=p.spine.rotation.z
	p.body_language.contact(p,Vector3.LEFT,.8)
	other.body_language.contact(other,Vector3.RIGHT,.8)
	for frame in range(18):
		p.body_language.observe(game,9); other.body_language.observe(game,20)
		p.step(DT); other.step(DT); await physics_frame
	check(p.body_language.contest_weight>.5 and absf(p.spine.rotation.z-before)>.035,"A live shoulder brace still yields to the impact instead of masking recovery")
	check(p.right_elbow.rotation.x>.8 and other.left_elbow.rotation.x>.8,"Both inside forearms keep their brace during recoil")
	check(p.action_timer==0 and other.action_timer==0 and p.protecting and grounded(),"Shielding recovery keeps control and grounded footwork")
	await snapshot("shoulder-recovery")
	var age: float=p.body_language.balance_age
	var pose: Transform3D=p.left_leg.transform
	game.state="paused"; game.simulate_match(.25)
	check(p.body_language.balance_age==age and p.left_leg.transform==pose,"Pause freezes the added recovery motion")
	game.state="playing"; other.position+=Vector3.RIGHT*4
	await run_steps(120)
	check(p.body_language.balance_age>=p.body_language.BALANCE_TIME,"The contact response settles completely")
	p.receive_impact(Vector3.RIGHT,.95); await run_steps(12)
	check(p.pose=="fall" and p.body_language.balance_age>=p.body_language.BALANCE_TIME,"A heavy tackle still overrides subtle recovery")
	game.reset_practice()
	check(p.body_language.balance_speed==0 and p.locomotion.arc_load==0 and p.ball_actions.kick_reach==0,"Restart clears the added motion state")

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-natural-motion.cfg"; p=game.players[9]
	for rate in [30,60,120]:
		for side in [-1.0,1.0]:
			await curved_run(rate,side)
			for team in [0,1]: await reaching_pass(rate,side,team)
		for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			var plain: Dictionary=await recovery_path(rate,direction,false)
			var hit: Dictionary=await recovery_path(rate,direction,true)
			var error := 0.0
			for i in range(plain.travel.size()): error=maxf(error,plain.travel[i].distance_to(hit.travel[i]))
			check(error<.0001 and hit.timer==0 and hit.phase>1,"Recovery preserves the full physical path and immediate input at %d Hz / %s" % [rate,direction])
			check(hit.ground and hit.arm>plain.arm+.08,"Contact visibly opens the balance arm while feet stay above turf")
			var catch_distance := 0.0
			for frame in range(int(rate*.08),int(rate*.28)):
				for foot in range(2):
					var offset: Vector3=hit.boots[frame*2+foot]-plain.boots[frame*2+foot]
					catch_distance=maxf(catch_distance,offset.dot(direction))
			check(catch_distance>.035,"A visible catch step travels in the shove direction instead of only moving the arms")
	await shoulder_contact()
	print("NATURAL MOTION CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
