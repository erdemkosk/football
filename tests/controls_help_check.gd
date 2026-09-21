extends SceneTree
var game
var failures := 0
var assertions := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	assertions+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func key(code: int,pressed: bool=true) -> void:
	var event := InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func tap(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index=code; event.pressed=pressed; event.device=0
		Input.parse_input_event(event); Input.flush_buffered_events()
func click(at: Vector2) -> void:
	at=root.get_final_transform()*at
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		event.position=at; event.global_position=at
		Input.parse_input_event(event); Input.flush_buffered_events()
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw(); game.controls_help.queue_redraw()
	for frame in range(3): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/controls-help-"+label+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.set_physics_process(false); game.set_process(false)
	game.match_menu.config_path="/tmp/football-controls-help-settings.cfg"
	game.controller.device=0; game.controller.reset_bindings(); game.match_menu.keys.clear()
	game.update_camera(0); game.hud.sync_navigation()
	var guide=game.controls_help
	await capture("menu")
	click(Vector2(200,844))
	check(guide.visible and game.state=="menu" and not game.ball.freeze,"Main menu button opens the guide without stopping the exhibition")
	var clock_before: float=game.match_time
	for frame in range(120): game._physics_process(1.0/120); await physics_frame
	check(game.match_time>clock_before and game.state=="menu","The stadium match keeps playing behind the menu guide")
	check(game.hud.nav_buttons.all(func(b): return not b.visible),"Underlying menu buttons cannot receive clicks or focus")
	key(KEY_F1); key(KEY_F1,false)
	check(not guide.visible and game.state=="menu","F1 closes an open guide")
	key(KEY_F1); key(KEY_F1,false)
	check(guide.visible and not guide.use_pad,"F1 opens the keyboard reference")
	check(guide.rows()[1].keys=="Y" and guide.rows()[2].keys=="LB + X" and guide.rows()[2].pad_keys and guide.rows()[2].detail.begins_with("Kontrolcü kombosu"),"Keyboard help distinguishes controller combinations and renders their button icons")
	game.match_menu.keys[KEY_J]=KEY_Y; game.match_menu.keys[KEY_Y]=KEY_J
	check(guide.rows()[1].keys=="J","Keyboard help reflects the current through-ball binding")
	await capture("keyboard")
	key(KEY_ESCAPE); key(KEY_ESCAPE,false)
	tap(JOY_BUTTON_Y)
	check(guide.visible and guide.use_pad,"Xbox Y opens the controller reference from the menu")
	check(guide.rows()[2].keys=="LB + X" and guide.rows()[3].keys=="LB + Y" and guide.rows()[5].keys=="B × 2","All requested attacking combinations are easy to find")
	game.controller.rebind(KEY_Y,JOY_BUTTON_A)
	check(guide.rows()[1].keys=="A" and guide.rows()[0].keys=="Y","Controller help follows remapped gameplay buttons")
	game.controller.rebind(KEY_Q,JOY_BUTTON_RIGHT_SHOULDER)
	check(guide.rows()[2].keys=="ATAMA GEREKLİ","A disabled physical LB combo does not advertise a working gesture")
	game.controller.reset_bindings()
	await capture("xbox")
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(guide.page==1 and root.gui_get_focus_owner()==guide.tabs[1],"RB switches to Defence and keeps visible focus")
	check(guide.rows()[0].keys=="X / RT" and guide.rows()[1].keys=="B" and guide.rows()[2].keys=="Y","Defensive X, B and held Y actions are documented separately")
	await capture("defence")
	tap(JOY_BUTTON_LEFT_SHOULDER)
	check(guide.page==0,"LB returns to Attack")
	tap(JOY_BUTTON_DPAD_RIGHT); tap(JOY_BUTTON_A)
	check(guide.page==1,"D-pad and A activate tabs through real UI focus")
	tap(JOY_BUTTON_B)
	check(not guide.visible and game.state=="menu" and not game.frontend.visible,"B closes only the guide without starting a match")
	game.start_match(true)
	game.update_camera(1)
	await capture("playing")
	game.begin_pass()
	key(KEY_F1); key(KEY_F1,false)
	check(guide.visible and game.state=="paused" and game.ball.freeze and not game.pass_charging,"Opening help during play pauses physics and cancels the prepared pass")
	var time_before: float=game.match_time
	var shots_before: Array=game.shots.duplicate()
	var passes_before: Array=game.passes.duplicate()
	key(KEY_D); key(KEY_D,false); key(KEY_S); key(KEY_S,false)
	for frame in range(60): game._physics_process(1.0/120); await physics_frame
	check(game.match_time==time_before and game.shots==shots_before and game.passes==passes_before,"Gameplay keys cannot shoot, pass or advance the clock through the guide")
	guide.select_page(2)
	await capture("control")
	guide.select_page(3)
	await capture("match")
	key(KEY_ESCAPE); key(KEY_ESCAPE,false)
	check(game.state=="playing" and not game.ball.freeze and not game.charging and not game.pass_charging,"Closing help resumes play without an accidental kick")
	tap(JOY_BUTTON_START); tap(JOY_BUTTON_Y)
	check(guide.visible and game.state=="paused","Start then Y opens help from the pause menu")
	tap(JOY_BUTTON_B)
	check(not guide.visible and game.state=="paused" and game.ball.freeze,"Closing a guide opened from pause keeps the match paused")
	tap(JOY_BUTTON_B)
	check(game.state=="playing" and not game.ball.freeze,"A second B resumes normal play")
	game.match_menu.open_menu()
	var focus_before: Control=root.gui_get_focus_owner()
	key(KEY_F1); key(KEY_F1,false); key(KEY_ESCAPE); key(KEY_ESCAPE,false)
	check(game.match_menu.visible and game.state=="paused" and game.ball.freeze and root.gui_get_focus_owner()==focus_before,"Nested settings and their focus survive opening the guide")
	game.match_menu.close_menu()
	game.frontend.open_selection()
	key(KEY_F1); key(KEY_F1,false); key(KEY_ESCAPE); key(KEY_ESCAPE,false)
	check(game.state=="setup" and game.frontend.visible and game.ball.freeze,"Team selection is preserved when the reference is closed")
	print("CONTROLS HELP CHECK: %d checks, %d failures" % [assertions,failures])
	game.free(); quit(0 if failures==0 else 1)
