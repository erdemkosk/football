extends "res://tests/dribble_control_check.gd"

func press_sprint(pad: bool,down: bool,code: int=JOY_BUTTON_RIGHT_SHOULDER) -> void:
	if pad:
		var event:=InputEventJoypadButton.new()
		event.device=0; event.button_index=code; event.pressed=down
		game._input(event)
	else:
		var event:=InputEventKey.new()
		event.keycode=KEY_W; event.physical_keycode=KEY_W; event.pressed=down
		game._input(event)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-sticky-control.cfg"
	p=game.players[9]
	await setup(); await drive(Vector3.FORWARD,240)
	var settled:=samples.slice(100)
	check(settled.max()<.67 and settled.min()>.40,"Normal possession stays by the front boot instead of travelling loosely ahead")
	check(settled.max()-settled.min()<.13,"Close control has a small stride pulse without oscillation")
	await drive(Vector3.ZERO,100)
	check(game.flat_distance(p.position,game.ball.position)>.40 and game.flat_distance(p.position,game.ball.position)<.65,"Stopping keeps the ball in front, not buried between the player's feet")
	await drive(Vector3.FORWARD,180,true)
	check(game.flat_distance(p.position,game.ball.position)>.72 and game.flat_distance(p.position,game.ball.position)<1.05,"Holding sprint gives a distinctly more exposed touch")
	for pad in [false,true]:
		await setup(); await drive(Vector3.FORWARD,150)
		game.controller.device=0; game.controller.held.clear()
		press_sprint(pad,true); press_sprint(pad,false)
		check(game.kick_contact.pending.is_empty(),"One sprint press keeps ordinary possession")
		game.advanced_controls.update(.12)
		press_sprint(pad,true); press_sprint(pad,false)
		check(not game.kick_contact.pending.is_empty() and game.dribbler<0 and not game.ball.pending_control,"A double sprint tap requests a real knock-on and releases the guide: "+str(pad))
		await drive(Vector3.FORWARD,35)
		check(game.flat_distance(p.position,game.ball.position)>1.3 and game.kick_contact.pending.is_empty(),"A double-tap knock-on really escapes the boot: "+str(pad))
	await setup(); await drive(Vector3.FORWARD,150)
	press_sprint(false,true); press_sprint(false,false)
	game.advanced_controls.update(.5)
	press_sprint(false,true); press_sprint(false,false)
	check(game.kick_contact.pending.is_empty(),"Separate sprint presses outside the gesture window do not knock the ball away")
	await setup(); await drive(Vector3.FORWARD,100)
	p.shot_preparation=.8; p.wrapping=.7; p.begin_kick(.7,.5,"laces",game.ball.position,Vector3.FORWARD*20)
	game.ball.place(Vector3(33,.25,-20),Vector3.RIGHT*4)
	await physics_frame; await physics_frame
	game.begin_restart("TAÇ",1,Vector3(32,0,-20))
	var clock_before: float=p.motion_clock
	check(not game.ball.pending_control and p.shot_preparation==0 and p.wrapping==0,"The whistle clears dribble forces and the held shooting pose immediately")
	for i in range(90):
		game.simulate_match(DT); await physics_frame
	check(game.state=="restart" and p.motion_clock>clock_before+.7 and p.kick_timer<=0 and p.velocity.length()<.2,"Players keep animating and settle during the practice out-of-play wait")
	check(game.ball.position.x>33,"The out-of-play ball keeps moving and is never pulled back to a player")
	print("STICKY CONTROL CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
