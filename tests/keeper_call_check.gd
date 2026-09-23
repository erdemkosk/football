extends SceneTree
const P = preload("res://scripts/pitch_dimensions.gd")
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func button(code: int,pressed: bool=true) -> void:
	var e := InputEventJoypadButton.new(); e.button_index=code; e.device=0; e.pressed=pressed
	game._input(e)
func key(code: int,pressed: bool=true) -> void:
	var e := InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.pressed=pressed
	game._input(e)
func setup() -> void:
	game.frontend.visible=false; game.match_menu.visible=false
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	game.controller.reset_bindings(); game.controller.device=0; game.controller.stick=Vector2.ZERO
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false
	game.ball.position=Vector3(3,0.23,30); game.ball.linear_velocity=Vector3.ZERO
	game.kick_lock=0; game.last_touch=1; game.dribbler=17
	for p in game.players:
		p.visible=false; p.collision_layer=0; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	for i in [0,9,11,17]: game.players[i].visible=true
	game.players[0].position=Vector3(0,0,46)
	game.players[9].position=Vector3(-12,0,35)
	game.players[11].position=Vector3(0,0,-46)
	game.players[17].position=Vector3(3,0,29.3)
func capture(name: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.camera.size=50; game.camera.position=Vector3(0,60,60); game.camera.look_at(Vector3(0,0,31))
	if name=="substitution":
		var focus: Vector3=game.players[9].position
		game.camera.size=10; game.camera.position=focus+Vector3(5,6,7); game.camera.look_at(focus+Vector3.UP)
	game.hud.queue_redraw(); await process_frame; await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/keeper-call-"+name+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	setup()
	button(JOY_BUTTON_Y)
	check(game.goalkeeping.rush_requested and not game.pass_charging and game.requested_receiver==-1,"Defensive Y calls the keeper without preparing or requesting a pass")
	var before: Vector3=game.players[0].position
	game.update_ai(0.01)
	check(game.goalkeeping.modes[0]=="manual_rush" and game.players[0].desired.z< -0.8 and game.players[0].sprinting,"Keeper AI actively runs toward the danger while Y is held")
	check(game.controlled==9 and game.players[0].position==before,"Calling the keeper neither switches the outfielder nor teleports the keeper")
	var energy: float=game.players[0].energy
	for n in range(60):
		game.update_ai(1.0/120); game.players[0].step(1.0/120); await physics_frame
	check(game.players[0].position.z<before.z-2 and game.players[0].energy<energy,"The called keeper physically sprints and uses normal match stamina")
	await capture("rush")
	button(JOY_BUTTON_Y,false)
	var target: Vector3=game.goalkeeping.update(0,0.01)
	check(not game.goalkeeping.rush_requested and target.z>game.players[0].position.z and game.passes[0]==0,"Releasing Y sends the keeper back toward goal without releasing a pass")
	game.ball.position=Vector3(1,0.23,40); game.players[0].position=Vector3(0,0,42)
	target=game.goalkeeping.update(0,0.01)
	check(target.z>45 and game.goalkeeping.modes[0]=="angle","Return command is not immediately overridden by automatic rushing")
	setup(); game.half=2; game.players[0].position.z=-46; game.players[17].position.z=-29.3; game.ball.position.z=-30
	button(JOY_BUTTON_Y); target=game.goalkeeping.update(0,0.01)
	check(target.z> -35,"Keeper call respects reversed second-half ends")
	setup(); key(KEY_Y); game.update_ai(0.01)
	check(game.goalkeeping.rush_requested,"Keyboard Y also calls the keeper in defence")
	key(KEY_Y,false)
	check(not game.goalkeeping.rush_requested,"Keyboard release cancels the keeper call")
	setup(); game.dribbler=9; game.players[9].position=Vector3(3,0,30.8); game.last_touch=0
	button(JOY_BUTTON_Y)
	check(game.pass_charging and game.pass_through and not game.goalkeeping.rush_requested,"Y in possession still charges a through ball")
	button(JOY_BUTTON_Y,false)
	check(game.passes[0]==1,"Releasing an attacking Y gesture still kicks its through ball")
	setup(); game.dribbler=6; game.players[6].visible=true; game.players[6].position=Vector3(3,0,30.8); game.last_touch=0
	button(JOY_BUTTON_Y)
	check(game.requested_receiver==9 and game.request_through and not game.goalkeeping.rush_requested,"Y off-ball during the team's own attack still requests a through ball")
	setup(); button(JOY_BUTTON_Y)
	game.dribbler=9; game.players[9].position=Vector3(3,0,30.8); game.last_touch=0
	game.goalkeeping.update(0,0.01); button(JOY_BUTTON_Y,false)
	check(not game.goalkeeping.rush_requested and game.passes[0]==0,"Winning possession cancels the call without turning its release into an accidental pass")
	setup(); button(JOY_BUTTON_Y); button(JOY_BUTTON_START); button(JOY_BUTTON_START,false)
	button(JOY_BUTTON_Y,false); button(JOY_BUTTON_START); button(JOY_BUTTON_START,false)
	check(game.state=="playing" and not game.goalkeeping.rush_requested,"Pausing and resuming cannot leave the keeper call stuck")
	setup(); game.match_menu.config_path="/tmp/football-keeper-settings.cfg"; button(JOY_BUTTON_Y)
	game.match_menu.open_menu(); button(JOY_BUTTON_Y,false); game.match_menu.close_menu()
	check(not game.goalkeeping.rush_requested,"Opening settings clears a held keeper call")
	setup(); button(JOY_BUTTON_Y); game.frontend.open_tactics()
	check(not game.goalkeeping.rush_requested,"Opening tactics clears a held keeper call")
	setup(); button(JOY_BUTTON_Y); game.controller.connection_changed(0,false)
	check(game.state=="paused" and not game.goalkeeping.rush_requested,"Disconnecting the controller stops the keeper call")
	setup(); button(JOY_BUTTON_Y); game.begin_restart("TAÇ",1,Vector3(P.HALF_WIDTH,0,30))
	check(not game.goalkeeping.rush_requested,"A whistle clears the keeper call before the restart")
	setup(); game.controller.rebind(KEY_Y,JOY_BUTTON_RIGHT_STICK); button(JOY_BUTTON_RIGHT_STICK)
	check(game.goalkeeping.rush_requested,"The keeper call follows the remapped through-ball button")
	button(JOY_BUTTON_RIGHT_STICK,false)
	check(not game.goalkeeping.rush_requested,"Releasing the remapped button stops the call")
	setup(); game.players[0].position=Vector3(3,0,30.8); game.players[0].animate(1)
	button(JOY_BUTTON_Y); game.goalkeeping.update(0,0.01)
	# Feet clearances are committed by the animated boot contact, not on request.
	for frame in range(30):
		game.kick_contact.prepare(1.0/120)
		game.players[0].step(1.0/120)
		game.kick_contact.resolve()
		if game.ball.pending_kick: break
		await physics_frame
	check(game.last_kicker==0 and game.ball.pending_kick and game.ball.held_by==null and game.saves[0]==0,"Outside the penalty area the keeper clears the ball with his feet, never his hands")
	setup(); button(JOY_BUTTON_Y); var keeper=game.players[0]
	keeper.facing=Vector3.FORWARD; keeper.animate(1); game.ball.position=keeper.left_hand.global_position
	game.goalkeeping.update(0,0.01)
	check(game.ball.held_by==keeper and not game.goalkeeping.rush_requested,"Inside the penalty area a real glove contact can catch the ball and end the call")

	# A fatigued substitute must run out, retain fatigue, and still walk through the gate.
	setup(); var p=game.players[9]; p.position=Vector3(-22,0,8); p.energy=0.03; p.exhausted=true
	var old_name: String=p.display_name
	game.management.queue_sub(9,1); game.begin_restart("TAÇ",0,Vector3(P.HALF_WIDTH,0,8))
	var peak := 0.0; var exit_time := 0.0; var exited := false; var completed := false; var exit_point := Vector3.ZERO
	for n in range(3000):
		var active: bool=game.management.update_substitutions(1.0/120)
		await physics_frame
		if not exited:
			peak=maxf(peak,Vector2(p.velocity.x,p.velocity.z).length()); exit_time+=1.0/120
			if p.display_name!=old_name: exited=true; exit_point=p.position
			elif n==120:
				check(is_equal_approx(p.energy,0.03) and p.exhausted,"Running off does not drain or reset the outgoing player's stamina")
				await capture("substitution")
		if not active: completed=true; break
	check(peak>8 and exit_time<8,"Even an exhausted outgoing player covers the long route at a fast run")
	check(exited and exit_point.x>P.HALF_WIDTH and completed and game.management.used[0]==1,"Player identity changes only at the touchline and the substitute physically returns")
	check(p.energy==1 and not p.exhausted and not p.stamina_free_movement and p.movement_speed()<7,"The fresh substitute returns to normal match speed and stamina rules")
	print("KEEPER CALL / SUBSTITUTION CHECK: %d failures" % failures)
	game.free(); await process_frame; quit(0 if failures==0 else 1)
