extends SceneTree
const Passing=preload("res://scripts/passing.gd")
var game
var failures:=0
var visual:=false
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func frames(count:int) -> void:
	for i in range(count): await physics_frame
func key(code:int,pressed:bool) -> void:
	var e:=InputEventKey.new()
	e.keycode=code
	e.physical_keycode=code
	e.pressed=pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func setup() -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	for p in game.players:
		p.visible=false
		p.collision_layer=0
		p.velocity=Vector3.ZERO
		p.desired=Vector3.ZERO
	game.players[9].visible=true
	game.players[6].visible=true
	game.players[9].position=Vector3(0,0,-15)
	game.players[6].position=Vector3(0,0,-1)
	game.ball.place(Vector3(0,0.23,-2))
	game.kick_lock=0
	await frames(3)
func capture() -> void:
	if not visual: return
	game.hud.visible=true
	game.hud.queue_redraw()
	game.camera.position=Vector3(16,23,12)
	game.camera.look_at(Vector3(0,0,-8))
	game.camera.size=27
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/pass-request.png")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	await setup()
	var before:Vector3=game.ball.position
	key(KEY_S,true); key(KEY_S,false)
	check(game.controlled==9 and game.requested_receiver==9,"S without the ball requests a pass without switching players")
	check(game.passes[0]==0 and not game.ball.pending_kick and game.ball.position.distance_to(before)<0.01,"Requesting a pass never teleports or remotely kicks the ball")
	game.players[9].step(1.0/120.0)
	check(not game.players[9].call_label.visible and game.players[9].right_arm.rotation.z>2,"The requester raises an arm without a shout label")
	await capture()
	game.update_pass_request(0.3)
	game.update_ai(1.0/120.0)
	check(game.passes[0]==1 and game.last_kicker==6 and game.controlled==9,"A nearby teammate answers the request through real AI while control stays with the requester")
	check(game.incoming_receiver==9 and game.requested_receiver==-1,"A dispatched pass becomes an incoming pass, not a repeated request")
	await frames(10)
	check(game.ball.position.z<before.z-0.5 and game.ball.position.z> -10,"The pass travels through the world over time")
	var closest:=100.0
	for i in range(200):
		await physics_frame
		game.kick_lock=maxf(0,game.kick_lock-1.0/120.0)
		for p in game.players:
			p.touch_cooldown=maxf(0,p.touch_cooldown-1.0/120.0)
		closest=minf(closest,game.flat_distance(game.ball.position,game.players[9].position))
		game.update_contacts(1.0/120.0)
	check(closest<1.0,"The physical pass reaches the requesting player's feet")
	check(game.ball.linear_velocity.length()<5,"First touch absorbs some momentum when the ball reaches the feet")
	await setup()
	game.players[9].velocity=Vector3(6,0,0)
	var moving=Passing.plan(game.ball.position,game.players[9].position,game.players[9].velocity,false)
	check(moving.target.x>3 and moving.velocity.x>2,"Passes lead a teammate running into space")
	game.players[17].visible=true
	game.players[17].position=Vector3(0,0,-8)
	game.players[9].velocity=Vector3.ZERO
	game.call_for_pass()
	game.update_pass_request(0.3)
	game.update_ai(1.0/120.0)
	check(game.last_kicker==6 and game.ball.kick_velocity.y>4,"AI chooses a lofted pass over a blocked ground lane")
	await setup()
	game.players[17].visible=true
	game.players[17].position=Vector3(0.5,0,-15)
	game.call_for_pass()
	game.update_pass_request(0.3)
	game.update_ai(1.0/120.0)
	check(game.passes[0]==0 and game.requested_receiver==9,"A marked receiver must find space instead of receiving a forced pass")
	game.update_pass_request(3.3)
	check(game.requested_receiver==-1 and game.controlled==9,"An unanswered request expires without switching the player")
	await setup()
	game.players[17].visible=true
	game.players[17].position=Vector3(0,0,-2)
	game.call_for_pass()
	game.update_pass_request(0.3)
	check(game.requested_receiver==-1 and game.passes[0]==0,"An opponent holding the ball cannot be commanded to pass")
	await setup()
	game.controlled=6
	key(KEY_S,true); key(KEY_S,false)
	check(game.passes[0]==1 and game.last_kicker==6,"S with the ball still passes normally")
	await setup()
	game.players[9].position=Vector3(1.6,0,-2)
	key(KEY_S,true); key(KEY_S,false)
	check(game.requested_receiver==9 and game.passes[0]==0,"S beside a teammate in possession still requests instead of remotely taking their ball")
	await setup()
	game.players[6].ai_think=8
	game.update_pass_request(0.01)
	game.update_ai(0.01)
	check(game.players[6].ai_think<0.1 and game.passes[0]==0,"A newly receiving AI player gets time to control and carry the ball")
	await setup()
	game.call_for_pass()
	game.update_pass_request(0.3)
	game.update_ai(0.01)
	game.players[17].visible=true
	game.players[17].position=Vector3(0,0,-8)
	game.players[17].collision_layer=2
	for i in range(100):
		await physics_frame
		game.kick_lock=maxf(0,game.kick_lock-1.0/120.0)
		for p in game.players: p.touch_cooldown=maxf(0,p.touch_cooldown-1.0/120.0)
		game.update_contacts(1.0/120.0)
		game.update_pass_request(1.0/120.0)
	check(game.last_touch==1 and game.incoming_receiver==-1,"An opponent moving into a dispatched pass can physically intercept it")
	await setup()
	key(KEY_A,true); key(KEY_A,false)
	game.update_pass_request(0.3)
	game.update_ai(1.0/120.0)
	check(game.last_kicker==6 and game.ball.kick_velocity.y>4,"A without the ball asks for a lofted delivery")
	await setup()
	game.call_for_pass()
	game.switch_player()
	check(game.requested_receiver==-1,"Explicit player switching cancels the old request")
	await setup()
	game.call_for_pass()
	game.goal(0)
	check(game.requested_receiver==-1 and not game.players[9].call_label.visible,"Goals clear stale requests and their markers")
	await setup()
	game.ball.place(Vector3(0,0.23,0),Vector3(18,0,0))
	await frames(2)
	game.ball.touch(Vector3.ZERO,0.43)
	await frames(2)
	check(game.ball.linear_velocity.x>16,"A limited foot impulse preserves momentum rather than instantly stopping the ball")
	print("PASS REQUEST CHECK: %d failures" % failures)
	game.free()
	await process_frame
	quit(0 if failures==0 else 1)
