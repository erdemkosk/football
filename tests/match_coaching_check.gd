extends SceneTree
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func button(code: int,down: bool=true,device: int=0) -> void:
	var e := InputEventJoypadButton.new()
	e.device=device; e.button_index=code; e.pressed=down
	Input.parse_input_event(e); Input.flush_buffered_events()
func tap(code: int) -> void:
	button(code); button(code,false)
func trigger(value: float,device: int=0) -> void:
	var e := InputEventJoypadMotion.new()
	e.device=device; e.axis=JOY_AXIS_TRIGGER_RIGHT; e.axis_value=value
	Input.parse_input_event(e); Input.flush_buffered_events()
func setup() -> void:
	game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	game.controller.reset_bindings(); game.controller.adopt_device(0,"Xbox Controller")
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false
	game.ball.position=Vector3(0,.23,-.7); game.ball.linear_velocity=Vector3.ZERO
	game.players[9].position=Vector3.ZERO; game.controlled=9; game.dribbler=9; game.carrier=9
	game.management.live_plan(1)
	game.match_time=150
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw()
	await process_frame; await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/coaching-"+label+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-coaching-test.cfg"
	setup()
	trigger(.4)
	check(not game.coaching.opened,"Trigger deadzone does not open the tactical drawer")
	trigger(1)
	check(game.coaching.opened and game.state=="playing" and game.duels.attempts.is_empty(),"RT opens live tactics without pausing or tackling")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(game.management.mentality==2 and game.management.pressing==2 and game.management.line_height==2,"RT + right selects the attacking plan including press and line")
	var coach
	# The match camera does not frame the home bench; read its pose regardless.
	game.stadium.sidelines.cull_offscreen=false
	for actor in game.stadium.sidelines.actors:
		if actor.role=="coach" and actor.team==0: coach=actor
	game.stadium.sidelines.update(.2,game.ball.position,Vector3.ZERO,0,true)
	var attack_pose: Vector3=coach.arms[0].rotation
	check(game.stadium.sidelines.coach_orders[0].kind=="attack" and absf(attack_pose.x)>.5,"The touchline coach visibly gestures after an attacking instruction")
	tap(JOY_BUTTON_DPAD_LEFT)
	game.stadium.sidelines.update(.2,game.ball.position,Vector3.ZERO,0,true)
	check(game.management.mentality==0 and coach.arms[0].rotation.distance_to(attack_pose)>.2,"The defensive instruction produces a distinct holding-back gesture")
	tap(JOY_BUTTON_DPAD_UP)
	check(game.management.mentality==1 and game.controller.aim_buttons.is_empty(),"RT + up restores balance without leaving shot aim held")
	tap(JOY_BUTTON_X); tap(JOY_BUTTON_Y)
	check(game.shots[0]==0 and game.passes[0]==0 and not game.charging and not game.pass_charging,"Face buttons in the drawer cannot leak into a shot or pass")
	button(JOY_BUTTON_DPAD_RIGHT); trigger(0); button(JOY_BUTTON_DPAD_RIGHT,false)
	check(not game.coaching.opened and game.coaching.consumed.is_empty() and game.controller.aim_buttons.is_empty(),"Releasing RT before the D-pad still consumes the matching button release")
	trigger(1,1)
	check(not game.coaching.opened,"A second controller cannot issue touchline commands")
	game.players[9].energy=.19; game.players[2].energy=.31
	game.coaching.update(.1)
	var offer: Dictionary=game.coaching.proposal.duplicate()
	check(offer.slot==9 and game.management.natural_role(offer.incoming,false)==3,"The most tired player receives a forward-for-forward recommendation")
	trigger(1)
	await capture("xbox")
	var identity: String=game.players[9].display_name
	tap(JOY_BUTTON_A)
	var owner: Control=game.get_viewport().gui_get_focus_owner()
	check(owner==null or not game.hud.nav_buttons.has(owner),"Accepting a change returns control to the match instead of the HUD")
	check(game.management.pending.size()==1 and game.management.transit.is_empty() and game.players[9].display_name==identity and game.players[9].energy==.19,"Accepting while playing queues a change without swapping identity or stamina")
	check(game.shots[0]==0 and game.passes[0]==0 and not game.ball.pending_kick,"RT + A acceptance never plays a pass")
	game.coaching.refresh(); tap(JOY_BUTTON_B)
	check(game.coaching.proposal.is_empty() and game.coaching.dismissed.has(game.players[2].shirt_number),"RT + B dismisses the next suggestion without sliding")
	game.coaching.refresh()
	check(game.coaching.proposal.is_empty(),"Dismissed recommendations do not immediately reappear")
	trigger(0)
	game.players[20].energy=.2
	game.begin_restart("TAÇ",0,Vector3(32,0,4))
	check(game.management.transit.has(9) and game.management.transit.has(20),"The next stoppage begins both teams' changes even when the user already queued one")
	var before: Vector3=game.players[9].position
	game.management.update_substitutions(.1)
	check(game.players[9].position.distance_to(before)>0 and game.players[9].display_name==identity and game.players[9].energy==.19,"The outgoing player runs toward the touchline without losing stamina")
	setup()
	for team in range(2):
		for j in range(3): game.management.queue_sub(team*11+j+1,j+1)
		check(game.management.committed(team)==3 and game.management.queue_sub(team*11+4,4).contains("doldu"),"Pending changes reserve all three places for team "+str(team))
	game.management.prepare_substitutions()
	check(game.management.transit.size()==6 and game.management.pending.is_empty(),"Both teams can start their three valid changes at the same stoppage")
	for team in range(2):
		check(game.management.committed(team)==3 and game.management.queue_sub(team*11+5,5).contains("doldu"),"Changes running toward the bench also count toward team "+str(team)+" limit")
		var index: int=team*11+1
		game.players[index].position=Vector3(32.8,0,(-3 if team==0 else 3)+(index%11)*1.2)
	game.management.update_substitutions(.01)
	check(game.management.used==[0,0],"Arriving at the touchline waits for the incoming player's handshake")
	for n in range(600):
		game.management.update_substitutions(1.0/120)
		await physics_frame
		if game.management.used[0]>=1 and game.management.used[1]>=1: break
	check(game.management.used==[1,1] and game.management.committed(0)==3 and game.management.committed(1)==3,"A completed handoff counts once while the incoming player returns to position")
	setup()
	check(game.management.used==[0,0] and game.management.pending.is_empty() and game.management.transit.is_empty(),"A new match resets both teams' substitution allowances")
	game.players[9].energy=.2; game.players[9].dismissed=true
	game.players[2].energy=.25
	game.coaching.refresh()
	check(game.coaching.proposal.slot==2 and game.management.natural_role(game.coaching.proposal.incoming,false)==1,"Dismissed players are excluded and the replacement matches the defender's position")
	game.controller.adopt_device(0,"DualSense Wireless Controller")
	trigger(1); await capture("playstation")
	check(game.controller.family=="playstation" and game.coaching.opened,"The same normalized R2 command supports PlayStation prompts")
	game.controller.connection_changed(0,false)
	check(game.state=="paused" and not game.coaching.opened and not game.coaching.trigger_down,"Disconnect clears the tactical input and safely pauses")
	setup(); game.players[9].energy=.2; game.coaching.refresh()
	game.begin_restart("TAÇ",0,Vector3(32,0,4)); game.state="set_piece"
	trigger(1); tap(JOY_BUTTON_A)
	check(game.state=="restart" and game.management.transit.has(9),"Accepting at an existing stoppage lets the substitution enter before the restart kick")
	setup(); game.frontend.open_tactics(false); trigger(1)
	check(not game.coaching.opened and game.frontend.visible,"RT cannot overlay the paused squad screen")
	var legacy := ConfigFile.new()
	var bindings: Dictionary=game.controller.bindings.duplicate()
	bindings[JOY_BUTTON_X]=KEY_G; bindings[100+JOY_AXIS_TRIGGER_RIGHT]=KEY_D
	legacy.set_value("pad","bindings",bindings); legacy.set_value("pad","bindings_version",2)
	legacy.save(game.match_menu.config_path); game.match_menu.load_settings()
	check(game.controller.bindings[JOY_BUTTON_X]==KEY_D and not game.controller.bindings.has(100+JOY_AXIS_TRIGGER_RIGHT),"An old custom shot-on-RT layout keeps shooting available after reserving RT for tactics")
	print("MATCH COACHING CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
