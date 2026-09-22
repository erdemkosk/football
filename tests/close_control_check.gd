extends "res://tests/dribble_control_check.gd"

func receive_pass(speed: float,intent: Vector3,sprint: bool=false) -> Dictionary:
	await setup()
	game.ai_receivers[0]=9; game.incoming_receiver=9; game.incoming_time=2
	game.last_touch=0; game.last_kicker=8
	game.ball.place(p.position+Vector3(0,.23,-1.04),Vector3.BACK*speed)
	await physics_frame; await physics_frame
	var got_ball:=false
	var peak:=0.0
	var height:=0.0
	var touched_at:=-1
	var loss_frames:=0
	for i in range(180):
		p.desired=intent; p.sprinting=sprint
		p.step(DT)
		var point: Vector3=game.ball.position
		game.update_contacts(DT)
		if game.ball.position!=point: check(false,"Receiving never teleports the ball")
		if game.dribbler==9:
			got_ball=true
			if touched_at<0: touched_at=i
		await physics_frame
		if got_ball:
			peak=maxf(peak,game.flat_distance(p.position,game.ball.position))
			height=maxf(height,game.ball.position.y)
			if game.dribbler!=9: loss_frames+=1
	return {"got":got_ball,"peak":peak,"height":height,"loss":loss_frames,"owner":game.dribbler,"gap":game.flat_distance(p.position,game.ball.position),"speed":game.ball.linear_velocity.length(),"touch_frame":touched_at}

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-close-control.cfg"
	p=game.players[9]
	for scenario in [{"speed":8.0,"intent":Vector3.ZERO,"sprint":false},{"speed":8.0,"intent":Vector3.RIGHT,"sprint":false},{"speed":18.0,"intent":Vector3.LEFT,"sprint":false},{"speed":24.0,"intent":Vector3.FORWARD,"sprint":false},{"speed":18.0,"intent":Vector3.BACK,"sprint":true}]:
		var received: Dictionary=await receive_pass(scenario.speed,scenario.intent,scenario.sprint)
		print("RECEIVE ",scenario," => ",received)
		check(received.got and received.owner==9 and received.peak<1.3 and received.loss==0,"A reachable pass at %.0f m/s stays close through its first control and next run" % scenario.speed)
		check(received.height<.5,"Ground-pass cushioning does not launch the ball upwards")
	await setup(); await drive(Vector3.FORWARD,240)
	print("CLOSE RUN max=",samples.max()," last=",samples.back())
	check(samples.max()<.9 and game.dribbler==9,"Ordinary running keeps the ball within a compact carrying distance")
	await setup(); await drive(Vector3.FORWARD,240,true)
	print("CLOSE SPRINT max=",samples.max()," last=",samples.back())
	check(samples.max()<1.12 and game.dribbler==9,"Sprinting gives a small controlled lead instead of a loose knock-on")
	for direction in [Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3.FORWARD]:
		trace=direction==Vector3.LEFT and "--trace" in OS.get_cmdline_user_args()
		samples.clear(); await drive(direction,90,true)
		print("CUT ",direction," max=",samples.max()," owner=",game.dribbler," gap=",samples.back())
		check(samples.max()<1.3 and game.dribbler==9,"Successive sprint cuts retain close possession")
	trace=false
	await drive(Vector3.ZERO,120)
	print("STOP gap=",game.flat_distance(p.position,game.ball.position)," speed=",game.ball.linear_velocity.length())
	check(game.flat_distance(p.position,game.ball.position)<.95 and game.ball.linear_velocity.length()<.3,"Letting go of movement settles the ball near the boot")
	await setup()
	var point: Vector3=p.position+Vector3(-.18,.24,-.26)
	p.left_knee.quaternion=Quaternion.from_euler(Vector3(-2.1,.32,0))
	p.locomotion.solve_leg(p.left_leg,p.left_knee,p.rig.to_local(point)-p.left_leg.position,1)
	check(p.left_knee.to_global(p.dribble_motion.BOOT).distance_to(point)<.025,"A twisted knee still places the boot at the ball instead of flipping the lower leg upwards")
	for build in [{"height":166.0,"weight":60.0,"control":94,"pace":92},{"height":195.0,"weight":92.0,"control":58,"pace":64}]:
		await setup()
		p.height_cm=build.height; p.weight_kg=build.weight
		p.attributes.control=build.control; p.attributes.pace=build.pace
		p.apply_build()
		await drive(Vector3.FORWARD,140,true)
		await drive(Vector3.RIGHT,70,true); await drive(Vector3.BACK,70,true)
		await drive(Vector3.LEFT,70,true)
		print("BUILD ",build.height," max=",samples.max()," owner=",game.dribbler)
		check(game.dribbler==9 and samples.max()<1.35,"Different player builds and abilities retain controllable consecutive sprint turns")
	await setup()
	await drive(Vector3.FORWARD*.3,180)
	await drive(Vector3.RIGHT*.4,120)
	check(game.dribbler==9 and samples.max()<1.0,"Partial analog movement keeps a short, controllable touch")
	print("CLOSE CONTROL CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
