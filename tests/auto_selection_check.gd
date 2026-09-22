extends "res://tests/team_control_check.gd"
const Motion=preload("res://scripts/ball_motion.gd")

func receiver_at(point: Vector3) -> void:
	game.players[9].position=Vector3(18,0,15)
	game.players[6].position=point
	game.players[7].visible=false
	game.dribbler=-1; game.rules.reset()

func snapshot() -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.camera.position=Vector3(0,33,9); game.camera.look_at(Vector3(0,0,-10)); game.camera.size=36
	game.hud.queue_redraw()
	await process_frame; await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-auto-selection.png")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	setup(); receiver_at(Vector3(0,0,.7))
	game.team_control.select(9,true); game.team_control.cooldown=2
	game.players[6].action_timer=.3; game.players[6].touch_cooldown=.5
	game.players[6].ball_actions.control_grace=.25; game.dribbler=6
	game.requested_receiver=9
	game.team_control.update(.01)
	check(game.controlled==6 and game.requested_receiver==-1,"Real possession overrides manual grace, recovery and a stale pass request")
	check(game.players[6].chosen and not game.players[9].chosen,"Selection marker moves with control")

	for height in [.23,1.35]:
		setup(); receiver_at(Vector3(0,0,.6))
		game.ball.position.y=height; game.ball.linear_velocity=Vector3.BACK*8
		game.controller.stick=Vector2(1,0); game.match_camera.select("pitch"); game.update_camera(0)
		game.team_control.select(9,true)
		game.first_touch.receive(6,false)
		check(game.controlled==6 and game.players[6].receive_timer>0,"Ground/chest first touch transfers control before the receive animation ends")
		check(game.players[6].ball_actions.receive_direction.x>.9,"The new receiver uses the user's direction on that same first touch")
		game.team_control.update(.01)
		check(game.controlled==6,"A first-touch cooldown cannot switch back to the old player")
	setup(); receiver_at(Vector3(0,0,1.25))
	game.ball.linear_velocity=Vector3.BACK*13
	var controlled_touch: bool=game.first_touch.receive(6,true)
	check(not controlled_touch and game.dribbler<0 and game.controlled==6,"A stretched deflection selects its player even without secured possession")
	setup(); receiver_at(Vector3(0,0,.5))
	game.ball.linear_velocity=Vector3.BACK*30; game.last_touch=1
	game.team_control.select(9,true); game.update_contacts(.01)
	check(game.controlled==6,"A fast ball brushing a teammate transfers control without a dribble")

	setup(); receiver_at(Vector3(0,0,-12))
	game.ball.position=Vector3(0,.23,0)
	game.ball.linear_velocity=Motion.lob_velocity(game.ball.position,Vector3(0,.23,-12),1.5,game.weather)
	game.last_kicker=9; game.last_touch=0; game.ai_receivers[0]=6; game.ai_pass_time[0]=3
	game.team_control.update(.01)
	check(game.controlled==6 and game.ball.position.distance_to(game.players[6].position)>10,"A lofted ball selects its reachable receiver before landing")
	await snapshot()
	var launch: Vector3=game.ball.linear_velocity
	for frame in range(60): game.team_control.update(1.0/120)
	check(game.controlled==6 and game.ball.linear_velocity==launch,"Prediction neither flickers nor changes the real ball velocity")
	game.players[7].visible=true; game.players[7].position=Vector3(10,0,-2)
	game.team_control.cooldown=0; game.ai_pass_time[0]=0
	game.ball.position=Vector3(5,.23,-2); game.ball.linear_velocity=Vector3.RIGHT*12
	game.team_control.update(.01)
	check(game.controlled==7,"A changed physical flight replaces the old intended receiver")

	setup(); receiver_at(Vector3(0,0,-10))
	game.ball.linear_velocity=Vector3.FORWARD*13
	game.last_kicker=9; game.last_touch=0; game.ai_pass_time[0]=2; game.ai_receivers[0]=6
	game.players[7].visible=true; game.players[7].position=Vector3(10,0,-10)
	game.team_control.select(7,true); game.team_control.update(.1)
	check(game.controlled==7,"Manual off-ball selection is respected before another player actually touches")
	game.ball.position=game.players[6].position+Vector3(0,.23,-.6)
	game.first_touch.receive(6,true)
	check(game.controlled==6,"A later real touch overrides manual off-ball selection")
	for mode in ["training","player_lock","menu","stoppage"]:
		setup(); receiver_at(Vector3(0,0,.6))
		if mode=="training": game.training=true
		if mode=="player_lock": game.player_lock=true
		if mode=="menu": game.menu_match.running=true
		if mode=="stoppage": game.state="restart"
		game.first_touch.receive(6,false); game.team_control.update(.01)
		check(game.controlled==9,"Automatic switching respects "+mode)
		game.menu_match.running=false

	# Real RigidBody capsule collision, not just a scripted reception callback.
	setup(); receiver_at(Vector3(0,0,0))
	game.players[6].collision_layer=2; game.players[6].touch_cooldown=2
	game.ball.freeze=false; game.ball.place(Vector3(-2,.65,0))
	await physics_frame; await physics_frame
	game.ball.strike(Vector3.RIGHT*10)
	game.last_kicker=17; game.last_touch=1; game.team_control.select(9,true)
	var collision_seen := false
	for frame in range(90):
		await physics_frame
		game.rules.update(1.0/120); game.team_control.update(1.0/120)
		if game.ball.get_colliding_bodies().has(game.players[6]):
			collision_seen=true
			check(game.controlled==6,"A real physics body deflection transfers control on its contact frame")
			break
	check(collision_seen,"The deflection scenario physically collides with the teammate")
	check(game.shots[0]==0 and game.passes[0]==0,"Selection does not authorize automatic passes or shots")
	print("AUTO SELECTION CHECK: %d failures" % failures)
	game.free(); await process_frame; quit(0 if failures==0 else 1)
