extends "res://tests/volley_check.gd"
var start_position := Vector3.ZERO
var moved := 0.0
var peak := 0.0
var max_step := 0.0
var count_kind := ""
var sim_delta := DT

func tick(count: int=1,boundaries: bool=false) -> void:
	for frame in range(count):
		game.kick_lock=maxf(0,game.kick_lock-sim_delta)
		game.update_control(sim_delta)
		game.heading.prepare(sim_delta); game.volleys.prepare(sim_delta)
		var old_position: Vector3=p.position
		p.step(sim_delta)
		max_step=maxf(max_step,game.flat_distance(old_position,p.position))
		moved=maxf(moved,game.flat_distance(start_position,p.position))
		peak=maxf(peak,p.position.y)
		var before: Vector3=game.ball.position
		var old_shots: int=game.shots[p.team]
		game.heading.resolve(); game.volleys.resolve()
		if game.shots[p.team]>old_shots:
			contacts+=1
			count_kind="header" if p.pose=="header" else p.volley_motion.kind
			contact_gap=(game.heading.head_point(p) if count_kind=="header" else p.volley_motion.boot(p)).distance_to(game.ball.position)
			check(game.ball.position==before,"Assisted finish changes ball velocity only at physical contact")
			check(contact_gap<.58,"Assistance still requires a real animated body/ball contact")
			await capture("assisted-"+count_kind)
		if game.state=="playing": game.update_contacts(sim_delta)
		await physics_frame
		if boundaries and game.state=="playing": game.check_boundaries()
		game.previous_ball=game.ball.position

func scenario(offset: Vector3,velocity: Vector3) -> void:
	await reset(offset,velocity)
	start_position=p.position; moved=0; peak=0; max_step=0; count_kind=""

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-aerial-assist-test.cfg"
	p=game.players[9]
	for entry in [
		[Vector3(-6,4.2,-1.4),Vector3(11,.3,0)],
		[Vector3(-6,3.4,-1.6),Vector3(11,.5,0)],
		[Vector3(-6,2.3,-1.7),Vector3(11,0,0)],
		[Vector3(-6,1.5,-1.6),Vector3(11,0,0)]]:
		await scenario(entry[0],entry[1])
		print("SCENARIO ",entry," PLAN ",game.aerial_assist.plan(9,Vector3.FORWARD))
		check(not game.heading.can_request(9) and not game.volleys.can_request(9),"Offset cross starts outside the old precise contact window")
		key(true)
		check(game.aerial_assist.active(9),"Early shot input buffers a reachable offset cross")
		await tick(5); key(false)
		await tick(140)
		print("RESULT contacts=",contacts," kind=",count_kind," move=",moved," peak=",peak," p=",p.position," ball=",game.ball.position)
		check(contacts==1,"Early release produces one contextual finish after the approach")
		check(moved>.45 and moved<3.35 and max_step<.09,"Approach uses a short physical run without player teleportation")
		check(not game.aerial_shot_active(9) and not game.charging,"The assisted shot ends cleanly")
	for family in ["Xbox Controller","DualSense"]:
		await scenario(Vector3(-6,2.3,-1.7),Vector3(11,0,0))
		game.controller.adopt_device(0,family)
		button(true); button(false)
		check(game.aerial_assist.active(9) and p.pose!="poke",family+" treats an early aerial shot as a finish, not a tackle")
		await tick(140)
		check(contacts==1,family+" completes the approach and real contact")
	await scenario(Vector3(-6,2.3,-1.7),Vector3(11,0,0))
	key(true); key(false); key(true,KEY_S); key(false,KEY_S)
	await tick(140)
	check(contacts==0 and not game.aerial_shot_active(9),"A pass command cancels the assisted shot")
	await scenario(Vector3(-6,2.3,-1.7),Vector3(11,0,0))
	key(true); key(false); game.players[6].visible=true
	game.players[6].position=game.ball.position*Vector3(1,0,1)
	game.training=false; game.team_control.manual_hold=0; game.team_control.update(DT)
	check(game.controlled==9,"Automatic selection preserves a requested aerial finish")
	game.team_control.select(6,true)
	check(not game.aerial_assist.active(9),"Explicit player selection cancels the previous intent")
	await scenario(Vector3(-6,2.3,-1.7),Vector3(11,0,0))
	key(true); key(false); game.state="paused"; game.simulate_match(DT)
	check(game.aerial_assist.pending.is_empty(),"Pause clears pending approach assistance")
	await scenario(Vector3(-6,2.3,-1.7),Vector3(11,0,0))
	key(true); key(false)
	game.ball.place(p.position+Vector3(8,3,0),Vector3(10,0,0))
	await physics_frame; await physics_frame; await tick(140)
	check(contacts==0 and moved<.5 and not game.aerial_shot_active(9),"A deflected cross cancels without chasing or striking from a distance")
	await scenario(Vector3(-6,2.3,-6),Vector3(11,0,0))
	key(true); key(false); await tick(130)
	check(contacts==0 and moved<.1,"A distant unreachable cross does not pull the player away")
	await scenario(Vector3(0,10,-.5),Vector3(0,-1,0))
	check(not game.can_request_aerial(9),"An unreachable high ball cannot cause an impossible jump")
	await scenario(Vector3(0,.23,-.6),Vector3.ZERO)
	key(true); await tick(10); key(false)
	check(game.shots[0]==1 and not game.aerial_assist.active(9),"Ordinary ground shots retain immediate release behavior")
	await scenario(Vector3(-6,2.3,-1.7),Vector3(11,0,0))
	key(true)
	for frame in range(80):
		await tick()
		if game.volleys.active(9): break
	check(game.aerial_assist.active(9) and game.volleys.active(9),"Held shot transfers from approach to the contact animation")
	key(false); await tick(100)
	check(contacts==1,"Release during the approach-to-volley transition preserves the shot")
	# The human-sized rig meets this below head height, with a small boot hop.
	await scenario(Vector3(-2,1.65,-.45),Vector3(11,0,0))
	key(true); key(false); await tick(100)
	print("HOP contacts=",contacts," kind=",count_kind," peak=",peak)
	check(contacts==1 and count_kind=="volley" and peak>.04 and peak<.4,"A slightly high foot-level ball gets a small physical jumping volley")
	for rate in [60,30]:
		Engine.physics_ticks_per_second=rate; sim_delta=1.0/rate
		await scenario(Vector3(-6,2.3,-1.7),Vector3(11,0,0))
		key(true); key(false); await tick(rate*2)
		check(contacts==1,"Approach and swept contact work at %d physics ticks" % rate)
	Engine.physics_ticks_per_second=120; sim_delta=DT
	for weather in [1,2]:
		await scenario(Vector3(-6,2.3,-1.7),Vector3(11,0,0))
		game.weather.select(weather,true)
		key(true); key(false); await tick(140)
		check(contacts==1,"Weather-aware approach reaches the ball on wet ground %d" % weather)
	game.weather.select(0,true)
	await scenario(Vector3(-6,2.3,-1.7),Vector3(11,0,0))
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size=Vector3(12,4,.2)
	collision.shape=shape; blocker.add_child(collision)
	blocker.collision_layer=2; game.add_child(blocker)
	blocker.position=p.position+Vector3(0,2,-.7); p.collision_mask=3
	await physics_frame
	key(true); key(false); await tick(140)
	check(contacts==0 and game.flat_distance(start_position,p.position)<.5,"Assistance cannot move through a blocking body or hit a distant ball")
	blocker.free()
	if visual:
		game.hud.show(); game.controls_help.open_panel(); game.controls_help.select_page(0)
		await process_frame; RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://tests/aerial-assist-guide.png")
	print("AERIAL ASSIST CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
