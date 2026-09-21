extends SceneTree
const Pad = preload("res://scripts/gamepad.gd")
var game
var failures := 0
var assertions := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	assertions+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func tap(code: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device=0; event.button_index=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()
func key(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()
func settle() -> void:
	game.controller.menus.sync(); game.hud.sync_navigation()
	for frame in range(4): await process_frame
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw(); game.controls_help.queue_redraw(); game.match_menu.queue_redraw(); game.frontend.queue_redraw()
	await settle()
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/controller-"+label+".png")
func run() -> void:
	for controller_name in ["DualSense Wireless Controller","DualSense Edge","DUALSHOCK 4","PS4 Controller","PS3 Controller","Sony Interactive Entertainment Controller","PlayStation 5"]:
		check(Pad.detect_family(controller_name)=="playstation","Recognizes "+controller_name)
	check(Pad.detect_family("Wireless Controller",{"vendor_id":0x054c})=="playstation","Sony vendor identifies a generic wireless name")
	check(Pad.detect_family("Wireless Controller",{},"030000004c050000c405000000010000")=="playstation","Sony SDL GUID identifies PlayStation without a vendor record")
	check(Pad.detect_family("Gamepad",{"raw_name":"DualShock 4"})=="playstation","Raw device name survives a generic mapping name")
	check(Pad.detect_family("Xbox Wireless Controller")=="xbox" and Pad.detect_family("Wireless Controller")=="xbox","Xbox and unidentified pads retain normalized Xbox prompts")
	var square: Texture2D=Pad.Glyphs.icon(JOY_BUTTON_X,"playstation")
	check(square.get_width()==80 and square==Pad.Glyphs.icon(JOY_BUTTON_X,"playstation"),"Vector icons are rasterized once and cached")
	check(square.get_image().get_data()!=Pad.Glyphs.icon(JOY_BUTTON_X,"xbox").get_image().get_data(),"PlayStation Square and Xbox X have different actual artwork")
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.match_menu.config_path="/tmp/football-controller-prompts-settings.cfg"
	game.update_camera(0)
	var pad=game.controller
	pad.reset_bindings(); game.match_menu.keys.clear()
	pad.adopt_device(0,"DualSense Wireless Controller",{"vendor_id":0x054c})
	await settle()
	check(pad.using_gamepad and pad.family=="playstation" and pad.icon_for(KEY_D)==square,"Activating DualSense switches the shot prompt to Square")
	await capture("ps-menu")
	tap(JOY_BUTTON_Y)
	var guide=game.controls_help
	check(guide.visible and guide.use_pad and guide.device_buttons[0].text=="PLAYSTATION","Triangle opens the PlayStation guide from the menu")
	check(guide.rows().all(func(row): return row.pad_keys),"Every controller guide row renders button artwork")
	await capture("ps-guide")
	var focus_before: Control=root.gui_get_focus_owner()
	pad.adopt_device(0,"Xbox Wireless Controller")
	check(guide.device_buttons[0].text=="XBOX" and root.gui_get_focus_owner()==focus_before,"Switching controllers refreshes the visible guide without losing focus")
	await capture("xbox-guide")
	pad.adopt_device(0,"DualShock 4")
	tap(JOY_BUTTON_B)
	check(not guide.visible and game.state=="menu","Circle closes the guide without activating the menu behind it")
	game.match_menu.open_menu(); game.match_menu.show_page(2)
	await settle()
	var shot_index: int=game.match_menu.ACTIONS.find(KEY_D)
	var shot_button: Button=game.match_menu.fields[shot_index][1]
	check(shot_button.text=="" and shot_button.icon==square and "PLAYSTATION" in game.match_menu.binding_header.text,"Binding screen shows a Square icon instead of the Xbox letter X")
	await capture("ps-bindings")
	shot_button.grab_focus(); tap(JOY_BUTTON_A); tap(JOY_BUTTON_Y)
	shot_button=game.match_menu.fields[shot_index][1]
	check(pad.button_for(KEY_D)==JOY_BUTTON_Y and shot_button.icon==Pad.Glyphs.icon(JOY_BUTTON_Y,"playstation"),"Cross selects a binding and Triangle remaps the shot with an updated icon")
	pad.adopt_device(0,"Xbox Wireless Controller")
	check(shot_button.icon==Pad.Glyphs.icon(JOY_BUTTON_Y,"xbox"),"A remapped action also updates artwork when the controller family changes")
	pad.reset_bindings(); pad.adopt_device(0,"DualSense")
	game.match_menu.show_page(1)
	await capture("ps-settings")
	game.match_menu.close_menu()
	game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false
	game.controlled=9; game.carrier=9; game.player_lock=true; game.kick_lock=0
	game.players[9].position=Vector3(0,0,0.8); game.ball.position=Vector3(0,0.23,0)
	game.update_camera(1)
	check(game.hud.action_hints()[0]==["X","Şut"] and game.hud.action_hints()[2]==["A","Pas"],"Live possession hints show the correct physical shot and pass actions")
	await capture("ps-match")
	pad.rebind(KEY_D,JOY_BUTTON_Y)
	check(game.hud.action_hints()[0][0]=="Y","The lower shot prompt follows a custom controller binding")
	pad.reset_bindings()
	game.ball.position=Vector3(10,0.23,0); game.carrier=11
	check(game.hud.action_hints()[0][1]=="Müdahale" and game.hud.action_hints()[1][1]=="Kayma" and game.hud.action_hints()[3][1]=="Kaleciyi çıkar","Losing possession changes the same icons to defensive actions")
	await capture("ps-defence")
	key(KEY_LEFT)
	await settle()
	check(not pad.using_gamepad and not game.hud.help_glyphs.visible and "F1" in game.hud.help_launcher.text,"Keyboard input restores keyboard help without stale controller icons")
	pad.adopt_device(0,"Xbox Wireless Controller")
	await settle()
	await capture("xbox-match")
	check(pad.family=="xbox" and game.hud.help_glyphs.visible,"A newly active Xbox pad restores Xbox icons")
	pad.connection_changed(0,false)
	await settle()
	check(game.state=="paused" and not pad.using_gamepad and not game.hud.help_glyphs.visible,"Disconnect pauses the match and clears controller-only hints")
	pad.adopt_device(0,"DualSense")
	tap(JOY_BUTTON_A)
	check(game.state=="playing" and pad.family=="playstation","Reconnecting PlayStation resumes with Cross and the correct family")
	print("CONTROLLER PROMPTS CHECK: %d checks, %d failures" % [assertions,failures])
	game.free(); quit(0 if failures==0 else 1)
