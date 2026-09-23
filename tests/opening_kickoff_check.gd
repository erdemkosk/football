extends SceneTree
var game
var failures := 0
const DT := 1.0/120.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func key(code: int,pressed: bool=true) -> void:
	var event := InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=pressed
	game._input(event)
func pad(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device=0; event.button_index=JOY_BUTTON_A; event.pressed=pressed
	game._input(event)
func tick(frames: int) -> void:
	for frame in range(frames):
		game._physics_process(DT)
		await physics_frame
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.set_physics_process(false); game.set_process(false)
	for mode in ["space","enter","xbox","playstation"]:
		game.start_match()
		game.controller.device=0; game.controller.reset_bindings(); game.controller.family="xbox" if mode in ["space","enter"] else mode
		await physics_frame; await physics_frame
		if mode=="space": key(KEY_SPACE); key(KEY_SPACE,false)
		elif mode=="enter": key(KEY_ENTER); key(KEY_ENTER,false)
		else: pad(true); pad(false)
		await tick(30)
		check(game.state=="set_piece" and game.restart_type=="SANTRA" and game.restart_team==0 and game.half==1,mode+": skipping the ceremony waits at the first-half kickoff")
		check(game.ball.position.distance_to(Vector3(0,.23,0))<.06 and game.passes[0]==0,mode+": the skip button does not also kick the ball")
		var legal := true
		for i in range(game.players.size()):
			if i==game.set_pieces.taker: continue
			var p=game.players[i]
			legal=legal and p.position.z*game.attack_sign(p.team)<=0
			if p.team==1: legal=legal and game.flat_distance(p.position,Vector3.ZERO)>=9.15
		check(legal,mode+": teammates stay in their own half and opponents outside the centre circle")
		await tick(240)
		check(game.state=="set_piece" and game.match_time==0 and game.score==[0,0],mode+": the clock and play wait for the user's kickoff")
		check(game.management.lost_time[0]==0,mode+": waiting before the opening pass does not add injury time")
		if mode in ["space","enter"]: key(KEY_S); key(KEY_S,false)
		else: pad(true); pad(false)
		await tick(85)
		check(game.state=="playing" and game.passes[0]==1 and game.match_time>0,mode+": the pass command starts the match once")
		check(game.ball.position.length()>1 and game.last_touch==0 and game.last_kicker>=0,mode+": kickoff releases the real physical ball")
		if "--visual" in OS.get_cmdline_user_args() and mode=="space":
			game.hud.queue_redraw(); game.update_camera(0)
			await process_frame; await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("/tmp/sefc-opening-kickoff.png")
	game.state="restart"; game.restart_type="TAÇ"
	game.management.update_clock(1)
	check(game.management.lost_time[0]>0,"Stoppages after kickoff still count toward injury time")
	game.start_match(true)
	check(game.training and game.state=="playing","Free practice still starts immediately")
	game.start_match(false,false,true)
	check(game.state=="menu" and game.menu_match.phase=="playing","The background exhibition keeps running independently")
	print("OPENING KICKOFF CHECK: %d failures" % failures)
	game.free(); await process_frame; quit(0 if failures==0 else 1)
