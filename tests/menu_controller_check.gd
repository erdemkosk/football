extends SceneTree
var game
var failures := 0
var assertions := 0
const NAV := [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]
const SIDES := [SIDE_TOP,SIDE_BOTTOM,SIDE_LEFT,SIDE_RIGHT]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	assertions+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func button(code: int,down: bool,device: int=0) -> void:
	var e := InputEventJoypadButton.new(); e.device=device; e.button_index=code; e.pressed=down
	Input.parse_input_event(e); Input.flush_buffered_events()
func tap(code: int,device: int=0) -> void:
	button(code,true,device); button(code,false,device)
func key(code: int) -> void:
	for down in [true,false]:
		var e := InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.pressed=down
		Input.parse_input_event(e); Input.flush_buffered_events()
func click(at: Vector2) -> void:
	at=root.get_final_transform()*at
	for down in [true,false]:
		var e := InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.position=at; e.global_position=at; e.pressed=down
		Input.parse_input_event(e); Input.flush_buffered_events()
func axis(code: int,value: float,device: int=0) -> void:
	var e := InputEventJoypadMotion.new(); e.device=device; e.axis=code; e.axis_value=value
	Input.parse_input_event(e); Input.flush_buffered_events()
func focus() -> Control: return root.gui_get_focus_owner()
func settle() -> void:
	game.controller.menus.sync()
	for i in range(4): await process_frame
func capture(name: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw(); game.frontend.queue_redraw(); game.match_menu.queue_redraw()
	await settle()
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/menu-controller-"+name+".png")
# Discover paths through actual focus neighbors, then navigate using real joypad events.
func go(target: Control) -> void:
	var pending: Array = [[focus(),[]]]
	var seen: Array = []
	while not pending.is_empty():
		var entry: Array=pending.pop_front()
		var current: Control=entry[0]
		if current==target:
			for code in entry[1]: tap(code)
			check(focus()==target,"Controller reaches "+str(target.get_path()))
			return
		if current==null or current in seen: continue
		seen.append(current)
		for i in range(4):
			if i>=2 and (current is HSlider or current is OptionButton): continue
			var next := current.find_valid_focus_neighbor(SIDES[i])
			if next!=null and next not in seen: pending.append([next,entry[1]+[NAV[i]]])
	check(false,"Unreachable menu control: "+str(target.get_path()))
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0
	game.match_menu.config_path="res://tests/menu-controller-settings.cfg"
	game.controller.reset_bindings()
	await settle()
	check(focus()==game.hud.nav_buttons[0],"Main menu starts on Quick Match")
	axis(JOY_AXIS_LEFT_Y,0.22)
	check(focus()==game.hud.nav_buttons[0],"Stick drift cannot change the menu selection")
	axis(JOY_AXIS_LEFT_Y,0.9)
	check(focus()==game.hud.nav_buttons[4],"Left analog moves to the career card directly below Quick Match")
	game.controller.menus.update(0.2)
	check(focus()==game.hud.nav_buttons[4],"Held stick waits before repeating")
	game.controller.menus.update(0.17)
	check(focus()==game.hud.nav_buttons[1],"Held analog repeats at a controlled rate")
	axis(JOY_AXIS_LEFT_Y,0)
	game.controller.menus.update(1)
	check(focus()==game.hud.nav_buttons[1],"Centering the stick stops repetition")
	tap(JOY_BUTTON_DPAD_DOWN)
	tap(JOY_BUTTON_DPAD_DOWN,1); tap(JOY_BUTTON_A,1)
	check(focus()==game.hud.nav_buttons[2] and not game.match_menu.visible,"A second controller cannot navigate or activate menus")
	await capture("main")
	tap(JOY_BUTTON_A)
	await settle()
	var settings=game.match_menu
	check(settings.visible and focus()==settings.navigation[0],"A opens the focused Settings item")
	tap(JOY_BUTTON_DPAD_RIGHT)
	var slider: HSlider=settings.fields[0][0]
	check(focus()==slider,"D-pad enters the settings controls")
	slider.value=0.5
	var initial: float=slider.value
	tap(JOY_BUTTON_DPAD_LEFT)
	check(slider.value<initial,"Left changes the focused audio slider")
	axis(JOY_AXIS_LEFT_X,0.85)
	game.controller.menus.update(0.38)
	axis(JOY_AXIS_LEFT_X,0)
	check(slider.value>initial,"Holding the analog adjusts sliders progressively")
	tap(JOY_BUTTON_DPAD_DOWN); tap(JOY_BUTTON_DPAD_DOWN); tap(JOY_BUTTON_DPAD_DOWN)
	var option: OptionButton=settings.fields[3][0]
	var before: int=option.selected
	tap(JOY_BUTTON_A)
	check(option.get_popup().visible and option.selected==before,"A opens the focused dropdown without changing its value")
	tap(JOY_BUTTON_DPAD_DOWN)
	await capture("dropdown")
	tap(JOY_BUTTON_A)
	check(not option.get_popup().visible and focus()==option and option.selected!=before,"D-pad and A confirm the dropdown choice")
	tap(JOY_BUTTON_A); tap(JOY_BUTTON_B)
	check(settings.visible and not option.get_popup().visible,"B cancels only the dropdown and leaves Settings open")
	tap(JOY_BUTTON_DPAD_LEFT)
	check(option.selected==before,"Left/right allow changing choices in either direction")
	tap(JOY_BUTTON_A)
	axis(JOY_AXIS_LEFT_Y,0.9); axis(JOY_AXIS_LEFT_Y,0); tap(JOY_BUTTON_A)
	check(option.selected!=before and not option.get_popup().visible,"Analog and A work inside the dropdown")
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(settings.page==1,"RB changes settings section")
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	await settle()
	check(settings.page==2,"Controller reaches button remapping")
	go(settings.fields[0][1]); tap(JOY_BUTTON_A)
	check(settings.capture_action==KEY_S and settings.capture_pad,"A starts Xbox button capture")
	button(JOY_BUTTON_A,true); button(JOY_BUTTON_A,true)
	check(settings.capture_action==-1 and game.controller.bindings[JOY_BUTTON_A]==KEY_S,"A can be rebound and a held duplicate cannot reopen capture")
	button(JOY_BUTTON_A,false)
	check(focus()==settings.fields[0][1],"Remapping restores the same button focus")
	tap(JOY_BUTTON_A); tap(JOY_BUTTON_BACK)
	check(settings.capture_action==-1 and settings.visible,"View cancels Xbox capture without closing Settings")
	go(settings.fields[1][0]); tap(JOY_BUTTON_A); tap(JOY_BUTTON_B)
	check(settings.capture_action==-1 and settings.visible,"B cancels keyboard capture from the controller")
	go(settings.fields[10][1])
	await settle()
	check(settings.scroll.scroll_vertical>0 and settings.scroll.get_global_rect().encloses(focus().get_global_rect()),"Long binding list follows controller focus when scrolling")
	await capture("bindings")
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	await settle()
	go(settings.fields[6][0])
	before=game.pass_assistance
	tap(JOY_BUTTON_DPAD_LEFT)
	check(game.pass_assistance==posmod(before-1,3),"Controller changes gameplay preferences")
	await capture("settings")
	tap(JOY_BUTTON_B)
	await settle()
	check(game.state=="menu" and focus()==game.hud.nav_buttons[2],"B saves and restores the main-menu selection")
	go(game.hud.nav_buttons[1]); tap(JOY_BUTTON_A)
	check(game.training_menu.visible and game.training_menu.selected==0,"Controller opens the training selector on the existing free practice mode")
	tap(JOY_BUTTON_A)
	check(game.training and game.state=="playing" and not game.pass_charging,"Controller starts training without passing")
	tap(JOY_BUTTON_START); await settle()
	go(game.hud.nav_buttons[4]); tap(JOY_BUTTON_A); await settle()
	check(game.state=="menu","Pause menu can return to the main menu")
	button(JOY_BUTTON_A,true); button(JOY_BUTTON_A,true)
	check(game.frontend.stage=="teams","A duplicate press cannot skip team selection")
	button(JOY_BUTTON_A,false); await settle()
	var front=game.frontend
	for side in range(2):
		var selected: int=game.clubs.selected[side]
		tap(JOY_BUTTON_DPAD_RIGHT)
		check(game.clubs.selected[side]!=selected and focus()==front.team_select[side],"The active team's carousel changes one team and retains confirmation focus")
		tap(JOY_BUTTON_A)
		check(front.picked[side] and front.select_wait>0,"A confirms the current team")
		front._process(1.0)
		check(front.pick_step==side+1,"Selection advances after the presentation")
	for property in ["weather_button","difficulty_button","duration_button","time_button"]:
		go(front.get(property)); tap(JOY_BUTTON_A); await settle()
		check(focus()==front.get(property),"Match preferences retain focus after rebuilding")
	go(front.go_button); tap(JOY_BUTTON_A); await settle()
	check(front.stage=="tactics","A continues into pre-match tactics")
	for index in range(11): go(front.slot_buttons[index])
	go(front.slot_buttons[9]); tap(JOY_BUTTON_A); await settle()
	var incoming: String=game.management.bench[0][1].name
	go(front.reserve_buttons[1]); tap(JOY_BUTTON_A); await settle()
	check(front.swap_stage=="confirm" and focus()==front.swap_action,"Controller previews the reserve before committing")
	tap(JOY_BUTTON_A); await settle()
	check(game.players[9].display_name==incoming,"Controller changes the starting lineup")
	tap(JOY_BUTTON_RIGHT_SHOULDER); await settle()
	check(front.pane==1,"RB opens the tactical plan")
	go(front.tactic_buttons[0][1]); tap(JOY_BUTTON_A); await settle()
	check(game.management.formation==1,"Controller selects 4-3-3")
	await capture("tactics")
	var previous_focus: Control=focus()
	tap(JOY_BUTTON_BACK); await settle(); tap(JOY_BUTTON_B); await settle()
	check(front.visible and focus()==previous_focus and game.state=="setup","Nested Settings restore the exact tactical focus and paused state")
	tap(JOY_BUTTON_LEFT_SHOULDER); await settle()
	check(front.pane==0,"LB returns to lineup management")
	tap(JOY_BUTTON_B); await settle()
	check(front.stage=="teams","B goes back one pre-match screen")
	tap(JOY_BUTTON_B); await settle()
	check(front.pick_step==1 and not front.picked[1],"B first releases the away-team selection")
	tap(JOY_BUTTON_B); await settle()
	check(front.pick_step==0 and not front.picked[0],"B then releases the home-team selection")
	tap(JOY_BUTTON_B); await settle()
	check(game.state=="menu","B returns from team selection")
	# A held analog must not navigate a newly opened screen until centered.
	axis(JOY_AXIS_LEFT_Y,0.9)
	go(game.hud.nav_buttons[0]); tap(JOY_BUTTON_A); await settle()
	var target: Control=focus()
	game.controller.menus.update(1)
	check(focus()==target,"Held analog cannot run away through a new screen")
	axis(JOY_AXIS_LEFT_Y,0)
	for side in range(2):
		tap(JOY_BUTTON_A); front._process(1.0); await settle()
	tap(JOY_BUTTON_A); await settle()
	go(front.first_focus); tap(JOY_BUTTON_A); await settle()
	check(game.state=="ceremony","Entire pre-match sequence works with the controller")
	button(JOY_BUTTON_A,true); button(JOY_BUTTON_A,true); button(JOY_BUTTON_A,false)
	check(game.state=="set_piece" and game.restart_type=="SANTRA" and not game.pass_charging,"Ceremony skip reaches kickoff without a held duplicate leaking into a pass")
	# Physics is disabled in this UI fixture; enter live play for the pause-menu checks.
	game.state="playing"; game.ball.freeze=false
	tap(JOY_BUTTON_START); await settle()
	await capture("pause")
	go(game.hud.nav_buttons[2]); tap(JOY_BUTTON_A); await settle(); tap(JOY_BUTTON_B); await settle()
	check(game.state=="paused" and game.ball.freeze,"Closing pause Settings keeps the match paused")
	tap(JOY_BUTTON_B)
	check(game.state=="playing" and not game.ball.freeze,"B resumes safely from pause")
	game.interval.begin(); await settle(); tap(JOY_BUTTON_A)
	check(game.half==2,"Controller starts the second half")
	game.state="finished"; await settle()
	go(game.hud.nav_buttons[1]); tap(JOY_BUTTON_A)
	check(game.state=="menu","Controller can leave the results screen")
	await settle(); tap(JOY_BUTTON_A); await settle()
	game.controller.connection_changed(0,false)
	check(game.frontend.visible and game.state=="setup","Disconnect leaves pre-match selections intact")
	game.controller.connection_changed(0,true)
	tap(JOY_BUTTON_B)
	check(game.state=="menu","Reconnected controller navigates immediately")
	await settle()
	go(game.hud.nav_buttons[2])
	key(KEY_ENTER); await settle()
	check(settings.visible,"Keyboard Enter activates the focused main-menu item")
	key(KEY_ESCAPE); await settle()
	var settings_button: Control=game.hud.nav_buttons[2]
	click(settings_button.get_global_transform_with_canvas()*(settings_button.size*.5)); await settle()
	check(settings.visible,"Mouse still activates the same main-menu buttons")
	tap(JOY_BUTTON_B); await settle()
	game.controller.rebind(KEY_S,JOY_BUTTON_X)
	tap(JOY_BUTTON_A); await settle()
	check(settings.visible,"Menu A stays fixed after remapping gameplay A")
	tap(JOY_BUTTON_B); await settle()
	check(game.state=="menu" and not game.pass_charging,"Menu B stays fixed and cannot trigger a gameplay action")
	game.controller.reset_bindings()
	print("MENU CONTROLLER CHECK: %d checks, %d failures" % [assertions,failures])
	DirAccess.remove_absolute(game.match_menu.config_path)
	game.free(); quit(0 if failures==0 else 1)
