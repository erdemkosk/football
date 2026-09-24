extends "res://tests/pass_skill_check.gd"
var assertions := 0

func verify(ok: bool,label: String) -> void:
	assertions+=1; check(ok,label)

func snapshot(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.show(); game.hud.bug_age=1; game.hud.queue_redraw()
	for frame in range(4): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/football-experience-"+label+".png")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/football-experience-settings.cfg"
	game.playtest.output_dir="/tmp/football-experience-reports"
	game.playtest.enabled=false
	setup()
	game.experience.text_size=2; game.experience.team_symbols=true; game.match_menu.save_settings()
	game.experience.text_size=0; game.experience.team_symbols=false
	game.match_menu.load_settings()
	verify(game.experience.text_size==2 and game.experience.team_symbols,"Readability and shapes survive a settings reload")
	for rain in [0,2]:
		for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.BACK]:
			setup(); game.weather.select(rain,true)
			var p=game.players[9]
			p.energy=.4; p.match_fatigue=.3; p.desired=direction
			game.players[17].visible=true; game.players[17].position=p.position+Vector3(.95,0,0)
			game.ball.linear_velocity=Vector3.BACK*8
			verify(game.first_touch.receive(9,false),"A routine pressured pass remains controllable, rain=%d direction=%s" % [rain,direction])
			verify(game.ball.touch_velocity.dot(direction)>.5,"Tired first touch still follows the requested change of direction")
	setup(); game.dribbler=-1
	game.duels.standing_tackle(9)
	var timer: float=game.players[9].action_timer
	game.duels.standing_tackle(9)
	verify(game.players[9].action_timer==timer and game.skills.notice.contains("TOPARLANIYOR"),"Repeated tackle input explains recovery without restarting or queuing the challenge")
	var p=game.players[9]
	p.action_timer=0; p.pose="run"; p.tackle_cooldown=0
	p.begin_receive("foot",game.ball.position,Vector3.BACK*8)
	for frame in range(8): p.step(DT)
	var exact := true
	for i in range(p.kick_joints.size()): exact=exact and p.motion_transition.previous[i].angle_to(p.kick_joints[i].quaternion)<.001
	verify(exact,"Animation boundaries capture the final visible pose after contact and ground placement")
	setup(); p=game.players[9]
	var q=game.players[17]; q.visible=true; q.position=p.position+Vector3(.8,0,0)
	p.protecting=true; game.dribbler=9
	for frame in range(24): game.physical_contests.update(DT)
	var before: Vector3=p.contest_direction
	q.position=p.position-Vector3(.8,0,0); game.physical_contests.update(DT)
	verify(p.contest_direction.dot(before)>.85 and p.contest_direction.dot(q.contest_direction)<-.99,"A shoulder-side change blends the brace while preserving an opposing paired reaction")
	q.position.x+=8
	for frame in range(30): game.physical_contests.update(DT)
	verify(p.contest_weight==0 and q.contest_weight==0,"Separating releases the contact pose promptly")
	setup(); game.playtest.enabled=true; game.playtest.begin(false,false,true)
	game.playtest.update(DT)
	game.playtest.strike(9,Vector3(2,1,-22),"shot",false)
	game.playtest.strike(11,Vector3.ZERO,"catch",true)
	game.playtest.strike(9,Vector3(-2,1,-22),"shot",false)
	game.playtest.goal(0); game.score=[1,0]
	verify(game.playtest.report.shots[0].outcome=="saved" and game.playtest.report.shots[1].outcome=="goal","Reports associate actual catches and goals with the preceding shot")
	game.playtest.event("receive",9,{"spill":true})
	game.playtest.event("tackle_miss",9)
	verify(game.playtest.finish("completed") and FileAccess.file_exists(game.playtest.last_file),"A bounded local report is written atomically")
	verify(game.playtest.feedback(4,3,4,"Sağanakta yerden pas daha kısa."),"Human ratings and comments are saved into the same match report")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.playtest.last_file))
	verify(saved.source=="automated" and int(saved.feedback.controls)==4 and saved.samples.size()==1 and int(saved.score[0])==1 and int(saved.score[1])==0,"Saved data distinguishes automated fixtures from human matches and preserves context")
	var count: int=game.playtest.report.events.size()
	game.playtest.event("contact",9)
	verify(game.playtest.report.events.size()==count,"Finished reports cannot collect events from later menus")
	game.state="finished"; game.hud.sync_navigation()
	verify(game.hud.nav_buttons.size()==3,"The final whistle exposes a keyboard/gamepad-accessible feedback button")
	game.match_menu.open_menu(); game.match_menu.show_page(5)
	button(JOY_BUTTON_RIGHT_SHOULDER); button(JOY_BUTTON_RIGHT_SHOULDER,false)
	verify(game.match_menu.page==0,"Controller shoulder navigation wraps across all six settings pages")
	button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_LEFT_SHOULDER,false)
	verify(game.match_menu.page==5,"Gameplay settings are reachable with the controller")
	button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_LEFT_SHOULDER,false)
	verify(game.match_menu.page==4,"Accessibility settings are reachable with the controller")
	game.controller.using_gamepad=false
	await snapshot("settings")
	game.match_menu.fields.back()[0].grab_focus()
	await snapshot("feedback")
	game.match_menu.close_menu()
	game.controls_help.open_panel(); game.controls_help.select_page(0)
	game.controls_help.tabs[0].grab_focus()
	button(JOY_BUTTON_DPAD_DOWN); button(JOY_BUTTON_DPAD_DOWN,false)
	verify(game.controls_help.row_content.is_ancestor_of(root.gui_get_focus_owner()),"Controller down enters guide cards and their scroll navigation")
	game.controller.using_gamepad=false
	await snapshot("guide")
	for frame in range(4): await process_frame
	verify(game.controls_help.row_content.size.y>game.controls_help.row_scroll.size.y,"Large guide text reflows into scrollable cards instead of overlapping rows")
	game.controls_help.close_panel()
	game.playtest.enabled=false
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	verify(game.playtest.report.is_empty(),"An unrecorded new match cannot receive feedback meant for an older match")
	game.experience.text_size=2; game.experience.team_symbols=true; game.update_camera(0)
	await snapshot("match")
	print("MATCH EXPERIENCE: %d checks, %d failures" % [assertions,failures])
	game.free(); quit(1 if failures else 0)
