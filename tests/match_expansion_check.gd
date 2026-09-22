extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if value: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func key(code: int,pressed: bool=true) -> void:
	var e := InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.pressed=pressed; game._input(e)
func button(code: int,pressed: bool=true) -> void:
	var e := InputEventJoypadButton.new(); e.button_index=code; e.device=0; e.pressed=pressed; game._input(e)
func trigger(axis: int,value: float) -> void:
	var e := InputEventJoypadMotion.new(); e.axis=axis; e.axis_value=value; e.device=0; game._input(e)
func capture(name: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/expansion-"+name+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false); game.set_process(false)
	game.match_menu.config_path="/tmp/football-expansion-test.cfg"
	game.start_match(false,false)
	var m=game.management
	var p=game.players[9]
	game.match_menu.open_menu()
	check(game.state=="paused" and game.match_menu.visible and game.ball.freeze,"Match centre pauses the game and ball")
	await process_frame
	await process_frame
	var nav := InputEventJoypadButton.new(); nav.button_index=JOY_BUTTON_DPAD_DOWN; nav.device=0; nav.pressed=true
	Input.parse_input_event(nav); Input.flush_buffered_events()
	await process_frame
	nav.pressed=false; Input.parse_input_event(nav); Input.flush_buffered_events()
	check(game.match_menu.get_viewport().gui_get_focus_owner()==game.match_menu.navigation[1],"Xbox D-pad navigates between settings sections")
	for page in range(4):
		game.match_menu.show_page(page)
		await capture(str(page))
	game.match_menu.close_menu()
	check(game.state=="playing" and not game.ball.freeze,"Closing management restores play")
	m.formation=1; m.apply_formation()
	check(game.players[8].home.x< -20 and game.players[10].home.x>20,"4-3-3 assigns separate wide forwards")
	var home: Vector3=game.players[2].home
	game.half=2; m.apply_formation()
	check(game.players[2].home==-home,"Formation respects second-half ends")
	game.half=1; m.formation=0; m.apply_formation()
	m.difficulty=0; var slow: float=m.reaction(1); var inaccurate: float=m.pass_error(1)
	m.difficulty=2
	check(m.reaction(1)<slow and m.pass_error(1)<inaccurate,"Difficulty changes reaction time and pass error")
	m.difficulty=1
	m.mentality=2; m.line_height=2; game.carrier=-1
	check(m.adjust_target(2,home).z<home.z-10,"Attacking tactics push the defensive line up")
	m.mentality=1; m.line_height=1
	p.position=Vector3(25,0,-2); p.energy=0.2
	game.players[4].position=Vector3(26.2,0,-0.4)
	var old_name: String=p.display_name
	check(m.queue_sub(9,1).contains("duraklamada"),"A valid substitution is queued")
	check(m.queue_sub(9,2).contains("bekleyen"),"The same player cannot be queued twice")
	check(m.queue_sub(0,2).contains("kaleci"),"Keeper requires a goalkeeper reserve")
	game.begin_restart("TAÇ",0,Vector3(32,0,2))
	var completed := false
	var entered := false
	for n in range(5000):
		var active: bool=m.update_substitutions(1.0/120)
		if p.display_name!=old_name: entered=true
		if not entered and n%120==0: check(is_equal_approx(p.energy,0.2),"Running off spends no stamina")
		await physics_frame
		if not active: completed=true; break
	check(completed and entered and m.used[0]==1 and m.bench[0][1].used,"Substitute physically leaves and enters, consuming one slot")
	check(p.energy==1 and p.shirt_number==13 and p.number==10,"Fresh identity and stamina preserve the tactical slot")
	check(m.queue_sub(8,1).contains("kullanıldı"),"Used reserve cannot enter twice")
	m.used[0]=3
	check(m.queue_sub(8,2).contains("doldu"),"Three-substitution limit is enforced")
	game.start_match(false,false)
	check(p.display_name==old_name and p.shirt_number==10 and m.used[0]==0,"New match restores the starting roster")
	game.ball.freeze=true
	for i in range(22): game.players[i].position=Vector3(-25+i*2,0,25)
	p.position=Vector3(0,0,-15)
	game.players[10].position=Vector3(0,0,-20)
	game.ball.position=Vector3(0,0.23,-20)
	game.ball.linear_velocity=Vector3.ZERO
	game.rules.foul(12,9)
	check(game.state=="playing" and not game.rules.advantage.is_empty(),"Advantage keeps a teammate's attack alive")
	game.players[10].position.x=10
	game.players[12].position=Vector3(0,0,-20)
	game.rules.update_advantage(0.5)
	check(game.state=="restart" and game.restart_team==0 and game.restart_point.z== -15,"Lost advantage returns to the original foul location")
	game.state="playing"; game.players[12].position.x=10; game.players[10].position.x=0
	game.rules.foul(13,9,true)
	check(not game.rules.advantage.is_empty() and 13 in game.rules.deferred_cards,"Advantage defers an appropriate caution")
	game.ball.position.z=-26
	game.rules.update_advantage(3.1)
	check(game.rules.advantage.is_empty() and game.state=="playing","Successful advantage expires without a whistle")
	game.begin_restart("TAÇ",0,Vector3(32,0,-26))
	check(game.players[13].yellow_cards==1 and game.rules.deferred_cards.is_empty(),"Deferred yellow is shown at the next stoppage")
	game.rules.foul(14,9,true,true)
	check(game.players[14].dismissed and game.players[14].yellow_cards==0 and game.referees.card_queue==["red"],"Severe foul produces a direct red without a fake yellow")
	game.start_match(false,false)
	game.state="restart"; m.update_clock(100)
	game.state="playing"; game.match_time=111; m.update_clock(0.1)
	check(m.added[0]>0 and m.half_end()>120,"Stoppages produce announced additional time")
	var stop: float=m.lost_time[0]
	game.state="paused"; m.update_clock(60)
	check(m.lost_time[0]==stop,"Pause does not inflate added time")
	game.start_match(false,false)
	game.ball.freeze=true
	for n in range(45):
		p.position=Vector3(n*0.12,0,-20)
		game.ball.position=Vector3(n*0.2,0.23,-30-n*0.3)
		game.replay.capture(0.05)
	game.goal(0)
	check(game.state=="goal" and game.replay.goal_tail>1.0,"A goal leaves time for live ball and net contact before replay")
	for frame in range(24): game.replay.capture_goal(0.05)
	check(game.state=="replay" and game.score==[1,0],"Goal enters buffered replay once")
	var live: Vector3=game.ball.position
	var live_player: Vector3=p.position
	var clock: float=game.match_time
	game.replay.update(0.3)
	check(game.ball.position.distance_to(live)>1 and game.match_time==clock and game.score==[1,0],"Replay animates history without changing score or clock")
	await capture("replay")
	button(JOY_BUTTON_A)
	button(JOY_BUTTON_A,false)
	check(game.state=="goal" and game.ball.position==live and p.position==live_player,"A skips replay and restores the live match exactly")
	for n in range(25): game.replay.capture(0.05)
	game.replay.begin()
	game.replay.update(8)
	check(game.state=="goal" and game.replay.saved.is_empty() and game.score==[1,0],"Replay also finishes automatically without duplicating the goal")
	game.start_match(false,false)
	game.ball.freeze=true
	for n in range(40):
		game.ball.position=Vector3(n*0.25,0.23,10)
		game.replay.capture(0.05)
	game.ball.position=Vector3(0,0.23,-39)
	game.replay.origin()
	for n in range(10):
		game.ball.position=Vector3(0,0.4+n*0.08,-39-n)
		game.replay.capture(0.05)
	check(game.replay.restart_clip and game.replay.frames[0].ball.distance_to(Vector3(0,0.23,-39))<0.05,"A penalty clip drops the earlier open-play buffer")
	game.replay.begin()
	game.replay.update(0)
	check(game.state=="replay" and game.ball.position.distance_to(Vector3(0,0.23,-39))<0.2,"Penalty-goal replay starts from the kick, not the previous play")
	game.replay.finish()
	game.start_match(false,false)
	game.ball.freeze=true; p.position=Vector3.ZERO; game.ball.position=Vector3(0,0.23,-0.7); game.ball.pending_reset=false
	game.dribbler=9; game.controlled=9
	button(JOY_BUTTON_Y)
	check(game.pass_charging and game.pass_through and p.feint_time==0,"Xbox Y prepares a through ball")
	game.cancel_pass()
	button(JOY_BUTTON_Y,false)
	trigger(JOY_AXIS_TRIGGER_LEFT,1)
	game.update_control(0.01)
	check(p.protecting and not p.sprinting,"LT shields possession")
	trigger(JOY_AXIS_TRIGGER_LEFT,0)
	game.update_control(0.01)
	check(not p.protecting,"Releasing LT releases shielding")
	game.dribbler=-1
	trigger(JOY_AXIS_TRIGGER_RIGHT,1)
	check(game.coaching.opened and not game.duels.attempts.has(9),"RT opens live tactics without attempting a tackle")
	trigger(JOY_AXIS_TRIGGER_RIGHT,0)
	button(JOY_BUTTON_START); button(JOY_BUTTON_START,false)
	check(game.state=="paused","Start pauses the match")
	button(JOY_BUTTON_START); button(JOY_BUTTON_START,false)
	check(game.state=="playing","Start resumes the match")
	game.controller.rebind(KEY_D,JOY_BUTTON_Y)
	check(game.controller.bindings[JOY_BUTTON_Y]==KEY_D and game.controller.bindings[JOY_BUTTON_X]==KEY_Y,"Controller remapping swaps conflicts without losing an action")
	game.match_menu.keys={KEY_S:KEY_D,KEY_D:KEY_S}
	game.audio.drum_volume=0.2; game.controller.deadzone=0.22
	game.match_menu.save_settings()
	game.audio.drum_volume=1; game.controller.deadzone=0.18
	game.match_menu.load_settings()
	check(is_equal_approx(game.audio.drum_volume,0.2) and is_equal_approx(game.controller.deadzone,0.22) and game.match_menu.key_for(KEY_D)==KEY_S,"Settings and custom controls persist on disk")
	game.audio.stadium_volume=0; game.audio.cheer_volume=0; game.audio.drum_volume=0
	game.audio.start_match(true); game.audio.react("goal",0,Vector3.ZERO); game.audio.update_atmosphere(0.5,"playing")
	check(game.audio.ambience.volume_db<= -79 and game.audio.cheering.volume_db<= -79,"Independent volume controls can silence stadium and cheers")
	print("EXPANSION CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
