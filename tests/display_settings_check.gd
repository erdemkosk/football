extends SceneTree
const DisplaySettings=preload("res://scripts/display_settings.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)

func settle() -> void:
	for i in range(8): await process_frame

func pad(code: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device=0; event.button_index=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()

func key(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()

func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	await settle(); RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/display-settings-"+label+".png")

func run() -> void:
	var planner := DisplaySettings.new()
	for native in [Vector2i(1366,768),Vector2i(1920,1080),Vector2i(2304,1440),Vector2i(2560,1440),Vector2i(3440,1440),Vector2i(3840,2160),Vector2i(1280,800)]:
		planner.native_size=native
		planner.work_area=Rect2i(Vector2i(-native.x,40),native-Vector2i(0,80))
		planner.fullscreen=true
		check(planner.automatic_size()==native,"Fullscreen automatic uses detected native resolution "+str(native))
		var available: Array=planner.available_resolutions()
		check(available[0]==Vector2i.ZERO and native in available,"Auto and native are offered on "+str(native))
		var correct := true
		for size in available:
			correct=correct and planner.normalized(size)==size and size.x<=native.x and size.y<=native.y
		check(correct,"Fullscreen resolutions preserve aspect and do not drift on repeated application")
		var normalized: Vector2i=planner.normalized(Vector2i(1280,720))
		check(planner.normalized(normalized)==normalized,"Changing aspect normalizes once without losing pixels on reload")
		planner.fullscreen=false
		var auto_size: Vector2i=planner.automatic_size()
		check(auto_size.x<=planner.window_limit().x and auto_size.y<=planner.window_limit().y,"Automatic window fits the usable desktop with borders and taskbar")
		check(planner.available_resolutions().all(func(value): return value.x<=planner.window_limit().x and value.y<=planner.window_limit().y),"Window choices cannot exceed the current monitor")
		check(planner.normalized(native)==Vector2i.ZERO,"Oversized window preference falls back to automatic")
	planner.free()
	# Headless Godot starts with a 64px dummy window; use a representative output.
	if DisplayServer.get_name()=="headless": root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0
	var settings=game.match_menu
	settings.config_path="res://tests/display-settings-check-"+str(OS.get_process_id())+".cfg"
	var display=settings.display
	await settle()
	check(display.resolution==Vector2i.ZERO,"First launch without a resolution preference defaults to automatic")
	if DisplayServer.get_name()!="headless":
		check(display.native_size==DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()),"Startup detects the actual monitor's native size")
	display.set_fullscreen(false); display.select_resolution(Vector2i.ZERO); await settle()
	if DisplayServer.get_name()!="headless":
		check(root.size==display.automatic_size(),"Automatic startup applies a real window size")
		check(display.work_area.encloses(Rect2i(root.position,root.size)),"Window is centered inside this monitor, including non-zero origins")
	settings.open_menu(); settings.show_page(3); await settle()
	check(settings.fields[0][0]==settings.display_mode_field and settings.fields[1][0]==settings.resolution_field,"Resolution is immediately visible below screen mode")
	check(settings.resolution_field.get_item_text(0).begins_with("Otomatik") and settings.display_description.text.contains(display.size_label(display.native_size)),"The menu shows automatic and the detected display size")
	var logical_size := root.content_scale_size
	var manual: Vector2i=display.available_resolutions()[1]
	settings.resolution_field.grab_focus(); pad(JOY_BUTTON_DPAD_RIGHT); await settle()
	check(display.resolution==manual and root.gui_get_focus_owner()==settings.resolution_field,"Controller changes resolution without losing focus")
	if DisplayServer.get_name()!="headless": check(root.size==manual,"Window selection changes the actual output dimensions")
	check(root.content_scale_size==logical_size and game.state=="paused" and game.ball.freeze,"Resolution changes preserve the menu layout and paused match")
	pad(JOY_BUTTON_A); await settle()
	check(settings.resolution_field.get_popup().visible,"Controller opens the resolution list")
	pad(JOY_BUTTON_DPAD_DOWN); pad(JOY_BUTTON_A); await settle()
	manual=display.available_resolutions()[2]
	check(display.resolution==manual and not settings.resolution_field.get_popup().visible and root.gui_get_focus_owner()==settings.resolution_field,"Choosing from the popup applies resolution and returns focus to the same setting")
	await capture("window")
	settings.close_menu()
	var cfg := ConfigFile.new(); cfg.load(settings.config_path)
	check(cfg.get_value("display","resolution")==manual and not cfg.get_value("display","fullscreen"),"Manual resolution and window mode are saved together")
	display.select_resolution(Vector2i.ZERO); settings.load_settings(); await settle()
	check(display.resolution==manual and not display.fullscreen,"Manual output preference survives a settings reload")
	settings.open_menu(); settings.show_page(3)
	var focus_before: Control=settings.resolution_field
	focus_before.grab_focus(); key(KEY_F11); await settle()
	check(display.fullscreen and settings.visible and root.gui_get_focus_owner()==focus_before,"F11 switches mode inside Settings without closing or losing focus")
	display.select_resolution(Vector2i.ZERO); await settle()
	check(is_equal_approx(root.scaling_3d_scale,1.0),"Automatic fullscreen renders at native quality")
	if DisplayServer.get_name()!="headless":
		check(root.mode==Window.MODE_FULLSCREEN and absi(root.size.x-display.native_size.x)<=1 and absi(root.size.y-display.native_size.y)<=1,"Fullscreen fills the current monitor")
	await capture("automatic")
	var full_output := root.size
	var low: Vector2i=display.available_resolutions()[1]
	display.select_resolution(low); await settle()
	check(display.resolution==low and root.size==full_output and root.scaling_3d_scale<1,"Lower fullscreen resolution changes 3D rendering while keeping the monitor filled")
	check(root.content_scale_size==logical_size and settings.display_description.text.contains(display.size_label(display.render_size())),"Fullscreen keeps UI coordinates and reports the effective rendered dimensions")
	await capture("fullscreen")
	display.select_resolution(Vector2i.ZERO); settings.save_settings()
	cfg.load(settings.config_path)
	check(cfg.get_value("display","resolution")==Vector2i.ZERO,"Automatic is saved as a preference, not an obsolete detected monitor size")
	var legacy := ConfigFile.new(); legacy.set_value("display","fullscreen",false)
	display.load_config(legacy); await settle()
	check(not display.fullscreen and display.resolution==Vector2i.ZERO,"Old settings containing only fullscreen migrate to automatic resolution")
	for invalid in [Vector2i(-1,720),Vector2i(99000,99000),"broken",Vector2i(0,720)]:
		legacy.set_value("display","resolution",invalid)
		display.load_config(legacy); await settle()
		check(display.resolution==Vector2i.ZERO,"Invalid or unsupported saved resolution falls back safely: "+str(invalid))
	settings.close_menu()
	DirAccess.remove_absolute(settings.config_path)
	print("DISPLAY SETTINGS CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
