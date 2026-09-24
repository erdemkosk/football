extends "res://tests/motion_contact_check.gd"
## Integration checks for continuous visual motion, physical footfalls and framing.
func run_steps(count: int,delta: float=DT) -> void:
	for i in range(count):
		tick(delta)
		await physics_frame

func camera_frame(focus: Vector3,delta: float) -> Dictionary:
	var view: Dictionary=game.match_camera.apply(focus,49,delta)
	game.camera.position=view.eye
	game.camera.look_at(view.look)
	return view

func framed(point: Vector3) -> bool:
	var view: Vector2=root.get_visible_rect().size
	var at: Vector2=game.camera.unproject_position(point)
	return not game.camera.is_position_behind(point) and at.x>24 and at.x<view.x-24 and at.y>24 and at.y<view.y-24

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-action-flow-settings.cfg"; p=game.players[9]
	for rate in [30,60,120]:
		setup(); game.state="playing"; game.audio.muted=false; game.audio.background=false; game.audio.paused=false
		p.sprinting=true; p.desired=Vector3(-.55,0,-.84).normalized()
		await run_steps(rate,1.0/rate)
		var phase: float=p.run_phase
		var direction: Vector3=p.desired
		game.ball.position=p.position+direction*.67+Vector3.UP*.23
		game.dribbler=9
		check(game.strike(9,direction*17+Vector3.UP*.5,0,false,"kick"),"Moving pass accepted at %d Hz" % rate)
		var layered:=false; var grounded:=true
		for i in range(int(rate*.38)):
			await run_steps(1,1.0/rate)
			var floor_y: float=p.position.y+p.boot_ground_height()
			grounded=grounded and minf(p.left_knee.to_global(p.ball_actions.BOOT).y,p.right_knee.to_global(p.ball_actions.BOOT).y)>floor_y-.025
			if p.kick_timer>0 and p.ball_actions.release_age>.205:
				var error:=0.0
				for j in range(4): error=maxf(error,p.kick_joints[j].quaternion.angle_to(p.motion_transition.gait[j]))
				layered=layered or (error<.055 and absf(p.spine.rotation.y)>.025)
		print("FLOW rate=",rate," contact=",game.feedback.event_count," misses=",game.kick_contact.misses," pending=",game.ball.pending_kick," power=",p.kick_power," speed=",p.velocity.length())
		check(layered,"Running legs recover while the passing torso still follows through at %d Hz" % rate)
		check(grounded and p.run_phase>phase and p.velocity.dot(direction)>5,"Diagonal pass retains grounded stride and immediate running speed at %d Hz" % rate)
		var outcome: Dictionary=game.strike_quality.last
		check(game.feedback.event_count==1 and outcome.get("intended",Vector3.INF).distance_to(direction*17+Vector3.UP*.5)<.001 and game.ball.kick_velocity.distance_to(outcome.velocity)<.001 and absf(outcome.yaw)<=outcome.limit+.0001,"Layering preserves one physical kick, its speed and the bounded contact accuracy at %d Hz" % rate)
		p.kick_timer=0; p.ball_actions.reset(p); p.motion_transition.reset()
		p.begin_receive("foot",p.position+direction*.55+Vector3.UP*.23,-direction*9)
		await run_steps(int(rate*.27),1.0/rate)
		var error:=0.0
		for j in range(4): error=maxf(error,p.kick_joints[j].quaternion.angle_to(p.motion_transition.gait[j]))
		check(p.receive_timer>0 and error<.055,"A moving first touch rejoins the live stride before its upper-body recovery ends at %d Hz" % rate)
	# Short turns and two support steps cannot delay the physics response.
	setup(); game.state="playing"; p.desired=Vector3.FORWARD; p.sprinting=true
	await run_steps(100)
	p.desired=Vector3.FORWARD.rotated(Vector3.UP,.35)
	var velocity: Vector3=p.velocity
	await run_steps(1)
	check(p.locomotion.adjustment>.1 and p.velocity!=velocity and p.locomotion.cut==0,"A small turn shortens the visible step while input acts immediately")
	await run_steps(60)
	p.desired=Vector3.ZERO; await run_steps(1)
	var first_leg: int=p.locomotion.plant_leg
	await run_steps(28)
	check(p.locomotion.plant_leg==1-first_leg and p.locomotion.plant_age<.04,"Stopping a sprint places the other foot for the second recovery step")
	p.desired=Vector3.RIGHT; velocity=p.velocity
	await run_steps(1)
	check(p.locomotion.stop_leg==-1 and p.velocity.x>velocity.x,"A new run cancels settling and accelerates on the next tick")
	# Foot sound and turf mark must come from the rendered sole, not a timer.
	game.audio.muted=false; game.audio.background=false; game.audio.paused=false
	game.controlled=9; p.chosen=true; p.footfalls.reset()
	var count: int=game.audio.step_count; var marks: int=game.weather.mark_count
	var valid_contacts:=true
	for i in range(180):
		var before: int=game.audio.step_count
		await run_steps(1)
		if game.audio.step_count>before:
			var floor_y: float=p.position.y+p.boot_ground_height()
			valid_contacts=valid_contacts and minf(p.left_knee.to_global(p.ball_actions.BOOT).y,p.right_knee.to_global(p.ball_actions.BOOT).y)<floor_y+.02
	check(game.audio.step_count>=count+3 and valid_contacts,"Running footfalls sound only when a rendered boot reaches the turf")
	check(game.weather.mark_count-marks==game.audio.step_count-count,"Every nearby visible footfall stamps and sounds in the same frame")
	p.desired=Vector3.ZERO; await run_steps(180); count=game.audio.step_count
	await run_steps(60)
	check(game.audio.step_count==count,"Standing does not repeat footstep audio")
	var variants: Array=game.audio.contact_variants.glove
	check(variants[0].data!=variants[1].data and variants[1].data!=variants[2].data,"Glove contacts have three distinct, locally generated recordings")
	check(game.audio.clips.soft_pass.data!=game.audio.clips.kick.data and game.audio.clips.grass_step.data!=game.audio.clips.wet_step.data,"Soft passes and dry/wet steps have distinct contact sounds")
	seed(2468); var expected:=randi(); seed(2468)
	for i in range(6): game.audio.contact("glove",.6); game.audio.footstep(8,.7,1)
	check(randi()==expected,"Sound variation cannot consume the gameplay random sequence")
	game.audio.update_atmosphere(DT,"paused")
	count=game.audio.step_count; var contacts: int=game.audio.contact_variation
	game.audio.footstep(8,0,1); game.audio.contact("kick")
	check(game.audio.step_count==count and game.audio.contact_variation==contacts and game.audio.contacts.all(func(c): return c.stream_paused) and game.audio.steps.all(func(c): return c.stream_paused),"Pause freezes all contact channels and rejects new steps")
	game.audio.update_atmosphere(DT,"playing"); game.audio.toggle()
	check(game.audio.steps.all(func(c): return not c.playing) and game.audio.contacts.all(func(c): return not c.playing),"Mute stops both turf sounds and ball impacts")
	game.audio.footstep(8,0,1); check(game.audio.step_count==count,"Muted steps stay silent")
	game.audio.toggle(); game.audio.background=true; game.audio.footstep(8,0,1)
	check(game.audio.step_count==count,"Menu background matches do not emit steps")
	game.audio.background=false
	# Read only the physical flight. Keep the ball, current player and forward
	# receiving region framed, with small bounded lens changes in both directions.
	setup(); game.training=false; game.state="playing"; game.dribbler=-1
	game.ball.held_by=null; game.match_camera.defaults()
	for camera_id in ["sideline","broadcast","pitch"]:
		for direction in [-1.0,1.0]:
			game.match_camera.select(camera_id); game.match_camera.reset(); game.match_camera.select(camera_id)
			game.ball.position=Vector3(0,4,0); game.ball.linear_velocity=Vector3(0,6,24*direction); game.ball.spin=.2
			p.position=Vector3(0,0,-3*direction)
			camera_frame(Vector3.ZERO,0)
			var ball_velocity: Vector3=game.ball.linear_velocity
			var starting_fov: float=game.camera.fov; var starting_size: float=game.camera.size
			for i in range(60): camera_frame(Vector3.ZERO,1.0/60)
			check(game.match_camera.attack_lead.z*direction>6 and framed(game.ball.position) and framed(p.position+Vector3.UP) and framed(Vector3(0,0,17*direction)),"A long pass reveals receiving space while keeping ball/player visible: %s %d" % [camera_id,int(direction)])
			check(absf(game.camera.fov-starting_fov)<2.51 and game.camera.size<=starting_size*1.061 and game.ball.linear_velocity==ball_velocity,"Framing stays subtle and cannot steer the ball: %s %d" % [camera_id,int(direction)])
	var eye: Vector3=game.match_camera.current_eye; var lead: Vector3=game.match_camera.attack_lead
	game.state="paused"; camera_frame(Vector3(12,0,22),.8)
	check(game.match_camera.current_eye==eye and game.match_camera.attack_lead==lead,"Pausing holds anticipation and the actual camera steady")
	game.state="playing"; game.match_camera.select("tactical"); game.match_camera.reset(); game.match_camera.select("tactical")
	camera_frame(Vector3.ZERO,1)
	check(game.match_camera.attack_lead==Vector3.ZERO and game.match_camera.attack_width==0,"The tactical view remains a fixed full-pitch overview")
	print("ACTION FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
