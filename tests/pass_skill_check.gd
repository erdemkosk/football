extends SceneTree
var game
var failures:=0
var visual:=false
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func key(code:int,pressed:bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func setup() -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	game.match_camera.select("pitch")
	game.update_camera(0)
	game.ball.freeze=true
	game.ball.pending_reset=false
	game.ball.pending_kick=false
	game.ball.position=Vector3(0,0.23,0)
	game.kick_lock=0
	game.last_direction=Vector3.FORWARD
	for p in game.players:
		p.visible=false; p.collision_layer=0; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	game.players[9].visible=true
	game.players[9].position=Vector3(0,0,0.8)
	game.players[6].visible=true
	game.players[6].position=Vector3(1.0,0,-8)
	game.players[7].visible=true
	game.players[7].position=Vector3(2,0,-29)
	game.player_lock=true
func hold(seconds:float,rate:float=120) -> void:
	for i in range(int(seconds*rate)): game.update_control(1.0/rate)
func capture() -> void:
	if not visual: return
	game.camera.position=Vector3(0,39,13)
	game.camera.look_at(Vector3(0,0,-13))
	game.camera.size=39
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/pass-skill.png")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	setup()
	key(KEY_S,true)
	check(game.pass_charging and game.passes[0]==0 and not game.ball.pending_kick,"S starts a pass preview without kicking before release")
	check(game.pass_preview.receiver==-1 and game.pass_preview.velocity.z<0,"A quick tap sends the pass along the aimed heading instead of locking a teammate")
	hold(0.1)
	var short_velocity:Vector3=game.pass_preview.velocity
	key(KEY_S,false)
	check(game.passes[0]==1 and game.ball.kick_velocity.is_equal_approx(short_velocity),"A short tap releases exactly the previewed pass")
	setup()
	key(KEY_S,true)
	hold(0.65)
	check(game.pass_power>0.99 and game.pass_preview.receiver==-1,"A short hold reaches full range without locking the farther teammate")
	check(game.pass_preview.velocity.length()>short_velocity.length()*1.6,"Hold duration physically changes pass speed")
	await capture()
	var long_velocity:Vector3=game.pass_preview.velocity
	key(KEY_S,false)
	check(game.ball.kick_velocity.is_equal_approx(long_velocity) and not game.pass_charging,"Release commits the shown long pass and closes the preview")
	setup()
	game.players[6].position=Vector3(-1,0,8)
	game.players[7].visible=false
	key(KEY_S,true)
	check(game.pass_preview.receiver==-1 and game.pass_preview.velocity.z<0,"Aim assistance never turns a forward pass toward a teammate behind you")
	key(KEY_S,false)
	setup()
	key(KEY_S,true)
	key(KEY_RIGHT,true)
	hold(0.85)
	check(game.pass_direction.x>0.9,"Arrow input steers the pass toward the chosen direction")
	key(KEY_RIGHT,false)
	var aimed:Vector3=game.pass_preview.velocity
	key(KEY_LEFT,true)
	key(KEY_S,false)
	check(game.ball.kick_velocity.is_equal_approx(aimed),"A last-moment key event cannot replace the displayed pass direction")
	key(KEY_LEFT,false)
	setup()
	game.players[17].visible=true
	game.players[17].position=Vector3(0.5,0,-4)
	key(KEY_S,true)
	check(game.pass_risk>0.48 and game.pass_preview.receiver==-1,"A defender marks the aimed passing lane as risky instead of choosing another teammate")
	key(KEY_S,false)
	setup()
	key(KEY_S,true)
	game.ball.position=Vector3(8,0.23,0)
	hold(0.05)
	key(KEY_S,false)
	check(game.passes[0]==0 and not game.pass_charging and game.requested_receiver==-1,"Losing the ball cancels a held pass without a remote kick or unintended request")
	setup()
	key(KEY_S,true)
	key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
	key(KEY_S,false)
	check(game.state=="paused" and game.passes[0]==0 and not game.pass_charging,"Pause cancels the pass and release does not kick")
	setup()
	game.players[9].position=Vector3(0,0,-14)
	game.players[6].position=Vector3(0,0,0.8)
	key(KEY_S,true)
	check(game.requested_receiver==9 and not game.pass_charging,"S without possession still requests immediately")
	key(KEY_S,false)
	setup()
	key(KEY_S,true)
	key(KEY_D,true)
	check(game.charging and not game.pass_charging,"Starting a shot cancels the pass gesture")
	key(KEY_S,false)
	check(game.passes[0]==0,"Releasing a cancelled pass cannot produce a second kick")
	key(KEY_D,false)
	setup()
	key(KEY_S,true)
	hold(0.4,30)
	var power30:float=game.pass_power
	game.cancel_pass()
	key(KEY_S,false)
	key(KEY_S,true)
	hold(0.4,120)
	check(absf(game.pass_power-power30)<0.001,"Pass charging uses elapsed time consistently at different update rates")
	hold(2)
	check(game.pass_power==1,"Holding longer stays at maximum without a timing penalty")
	key(KEY_S,false)
	setup()
	game.players[6].visible=false
	game.players[7].visible=false
	game.ball.freeze=false
	game.ball.place(Vector3(0,0.23,0))
	await physics_frame
	await physics_frame
	key(KEY_UP,true)
	key(KEY_S,true)
	game.set_physics_process(true)
	for i in range(45): await physics_frame
	var held_while_moving:bool=game.pass_charging
	key(KEY_S,false)
	key(KEY_UP,false)
	game.set_physics_process(false)
	check(held_while_moving and game.passes[0]==1,"The player can carry the ball while preparing and releasing a pass")
	print("PASS SKILL CHECK: %d failures" % failures)
	game.free()
	await process_frame
	quit(0 if failures==0 else 1)
