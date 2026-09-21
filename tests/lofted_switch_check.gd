extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func button(code: int,pressed: bool=true) -> void:
	var event := InputEventJoypadButton.new(); event.device=0; event.button_index=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func setup() -> void:
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.controller.device=0; game.controller.stick=Vector2(-1,0); game.controller.held.clear(); game.controller.reset_bindings()
	game.controller.menus.reset(); game.controller.combos.cancel()
	game.pass_assistance=1; game.kick_lock=0; game.last_direction=Vector3.LEFT
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false; game.ball.pending_touch=false
	game.ball.position=Vector3(23.3,0.23,-8); game.ball.linear_velocity=Vector3.ZERO
	for p in game.players: p.visible=false; p.collision_layer=0; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	for i in [9,6,7,11,14]: game.players[i].visible=true
	game.players[9].position=Vector3(24,0,-8); game.players[6].position=Vector3(6,0,-10); game.players[7].position=Vector3(-26,0,-12)
	game.players[11].position=Vector3(0,0,-48); game.players[14].position=Vector3(10,0,-43)
	game.controlled=9; game.dribbler=9; game.rules.reset()
func charge(seconds: float) -> void:
	for i in range(roundi(seconds*120)): game.update_control(1.0/120)
func capture() -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.camera.size=76; game.camera.position=Vector3(0,70,24); game.camera.look_at(Vector3(0,0,-10)); game.hud.queue_redraw()
	await process_frame; await process_frame
	RenderingServer.force_draw(false); root.get_texture().get_image().save_png("res://tests/lofted-switch.png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	setup(); button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_Y)
	check(game.pass_charging and game.pass_lob and not game.pass_through and not game.goalkeeping.rush_requested,"LB + Y prepares an aerial pass without a ground through-ball or keeper call")
	check(game.controlled==9 and game.passes[0]==0,"The original passer stays selected until the kick")
	check(game.pass_preview.receiver==6 and game.pass_preview.lob,"Short press previews the nearer aerial option")
	charge(0.52)
	check(game.pass_preview.receiver==7 and game.pass_preview.velocity.y>9,"Holding Y reaches the opposite wing with a lofted trajectory")
	await capture()
	var route: Dictionary=game.pass_preview.duplicate()
	button(JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.pass_lob and game.controlled==9,"Releasing LB first keeps the prepared aerial pass intact")
	button(JOY_BUTTON_Y,false)
	check(game.passes[0]==1 and game.controlled==7 and game.ball.kick_velocity.is_equal_approx(route.velocity),"Releasing Y kicks the previewed physical pass and transfers control to the far winger")
	check(not game.pass_charging and not game.pass_lob,"The lofted gesture resets after release")
	setup(); button(JOY_BUTTON_Y); charge(0.2); button(JOY_BUTTON_LEFT_SHOULDER)
	check(game.pass_lob and game.pass_power>0.25,"Y then LB also selects the aerial pass without losing held power")
	button(JOY_BUTTON_Y,false); button(JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.passes[0]==1 and game.ball.kick_velocity.y>5,"Either release order produces a single aerial pass")
	setup(); button(JOY_BUTTON_A); button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_Y); charge(0.3); button(JOY_BUTTON_A,false)
	check(game.pass_lob and game.pass_charging and game.passes[0]==0,"Releasing an earlier A press cannot fire a lofted pass that is waiting for Y")
	button(JOY_BUTTON_Y,false); button(JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.passes[0]==1,"The overlapping gesture still releases exactly once with Y")
	setup(); button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_Y); game.ball.position+=Vector3(8,0,0); charge(0.1); button(JOY_BUTTON_Y,false)
	check(game.passes[0]==0 and not game.pass_lob,"Losing possession cancels the lofted pass")
	setup(); button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_Y); button(JOY_BUTTON_START); button(JOY_BUTTON_START,false); button(JOY_BUTTON_Y,false); button(JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.state=="paused" and game.passes[0]==0 and not game.pass_lob,"Pause safely cancels the lofted gesture")
	setup(); game.pass_assistance=0; button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_Y); charge(0.5)
	check(game.pass_preview.receiver==-1 and absf(game.pass_preview.velocity.z)<0.01,"Manual assistance setting preserves the exact lofted heading")
	setup(); game.players[7].position.z=-46; button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_Y); charge(0.65)
	check(game.pass_preview.receiver!=7,"An offside winger is excluded from long-pass assistance")
	setup(); button(JOY_BUTTON_Y)
	check(game.pass_through and not game.pass_lob,"Y alone remains the usual through ball")
	button(JOY_BUTTON_Y,false)
	for rain in [false,true]:
		setup(); game.weather.select(2 if rain else 0,true)
		game.ball.freeze=false; game.ball.place(Vector3(23.3,0.23,-8))
		await physics_frame; await physics_frame
		button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_Y); charge(0.52)
		route=game.pass_preview.duplicate(); var target: Vector3=route.target
		button(JOY_BUTTON_Y,false); button(JOY_BUTTON_LEFT_SHOULDER,false)
		game.players[7].position.x=20
		var peak := 0.0
		for tick in range(roundi(route.flight*120)):
			await physics_frame
			peak=maxf(peak,game.ball.position.y)
		check(peak>5 and game.flat_distance(game.ball.position,target)<1.6 and game.ball.position.y<0.7,"Real aerial switch lands on the far wing despite receiver movement, weather="+str(rain))
	print("LOFTED SWITCH CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
