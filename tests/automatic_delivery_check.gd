extends "res://tests/pass_skill_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	for through in [false,true]:
		for lob in [false,true]:
			setup()
			game.begin_pass(through,lob)
			check(not game.pass_charging and not game.kick_contact.pending.is_empty(),"All pass types commit without charging: %s/%s" % [through,lob])
			check(game.ai_receivers[0]==6,"Assistance selects the forward teammate")
			var velocity: Vector3=game.kick_contact.pending.velocity
			check(velocity.z<0 and (not lob or velocity.y>2),"Delivery follows direction and requested height")
	setup()
	game.players[6].velocity=Vector3.FORWARD*3
	var run_pass := Passing.quick_plan(game.ball.position,Vector3.FORWARD,0,9,game.players,1,-1,100,null,false,true)
	check(run_pass.target.z<game.players[6].position.z-2,"Through pass leads the teammate into running space")
	game.players[6].velocity=Vector3.ZERO; game.players[7].visible=false
	var near_pass := Passing.quick_plan(game.ball.position,Vector3.FORWARD,0,9,game.players,1,-1,100)
	game.players[6].position.z=-25
	var far_pass := Passing.quick_plan(game.ball.position,Vector3.FORWARD,0,9,game.players,1,-1,100)
	check(far_pass.velocity.length()>near_pass.velocity.length()+3,"Automatic power grows with the chosen receiver's distance")
	setup()
	game.players[6].position=Vector3(15,0,0); game.players[7].visible=false
	var missed := Passing.quick_plan(game.ball.position,Vector3.FORWARD,0,9,game.players,1,-1,100,null,false,true,true)
	check(missed.receiver<0 and absf(missed.velocity.x)<.001 and missed.velocity.z<0,"Wrong aim stays wrong even for assisted lofted through balls")
	setup()
	game.controller.combos.begin_cross()
	check(game.controller.combos.cross_player==9 and game.kick_contact.pending.is_empty(),"Cross waits for the requested charge before release")
	game.controller.combos.release_cross()
	check(not game.kick_contact.pending.is_empty(),"Releasing commits one charged cross")
	incoming()
	game.begin_pass(true,true)
	check(not game.pass_buffer.pending.is_empty(),"Early lofted through-pass command is buffered")
	game.ball.position=game.players[9].position+Vector3(0,game.ball.GROUND_HEIGHT,-.5)
	game.dribbler=9; game.carrier=9
	game.pass_buffer.try_execute()
	check(game.pass_buffer.pending.is_empty() and not game.kick_contact.pending.is_empty(),"Buffered delivery executes on reception without another press")
	setup()
	game.charging=true
	check(game.hud.shot_guide_visible(),"Shot arrow remains available with the ball")
	game.ball.position=Vector3(0,game.ball.GROUND_HEIGHT,-12)
	check(not game.hud.shot_guide_visible() and game.charging,"Distant-ball shot command remains active without showing a guide")
	check(is_equal_approx(game.ball.RADIUS,.11) and is_equal_approx(game.ball.shell.mesh.radius,.11),"Physics and visible ball share the smaller radius")
	print("AUTOMATIC DELIVERY CHECK: failures=",failures)
	game.free(); quit(1 if failures else 0)
