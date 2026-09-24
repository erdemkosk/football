extends SceneTree
var game
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func pad(code: int) -> void:
	for down in [true,false]:
		var event:=InputEventJoypadButton.new()
		event.device=0; event.button_index=code; event.pressed=down
		game._input(event)
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false)
	game.match_menu.config_path="res://tests/scale-camera-settings.cfg"
	game.start_match(true)
	game.match_camera.defaults()
	for mode in game.match_camera.IDS:
		game.match_camera.select(mode)
		game.match_camera.set_distance(.75)
		var close: Dictionary=game.match_camera.pose(Vector3.ZERO,49)
		game.match_camera.set_distance(1.45)
		var far: Dictionary=game.match_camera.pose(Vector3.ZERO,49)
		check(far.size>close.size if close.projection==Camera3D.PROJECTION_ORTHOGONAL else far.eye.distance_to(far.look)>close.eye.distance_to(close.look)*1.5,"Distance changes the framing for camera: "+mode)
		game.match_camera.set_distance(1)
		game.match_camera.set_height(.7)
		var low: Dictionary=game.match_camera.pose(Vector3.ZERO,49)
		game.match_camera.set_height(1.5)
		var high: Dictionary=game.match_camera.pose(Vector3.ZERO,49)
		check(high.eye.y>low.eye.y and high.look==low.look,"Height changes the viewing angle while keeping the focus: "+mode)
	game.match_camera.defaults(); game.match_camera.preference("broadcast")
	game.match_camera.set_distance(1.24); game.match_camera.set_height(1.33)
	game.match_menu.save_settings()
	game.match_camera.defaults(); game.match_menu.load_settings()
	check(game.match_camera.preferred=="broadcast" and is_equal_approx(game.match_camera.distance,1.24) and is_equal_approx(game.match_camera.height,1.33),"Profile, distance and height survive a settings round trip")
	game.management.difficulty=2
	game.clubs.ensure_world()
	game.clubs.set_league(0,0)
	game.clubs.choose(0,2)
	game.clubs.set_league(1,1)
	game.clubs.choose(1,1)
	var stored_home: String=game.clubs.club_id(0)
	var stored_away: String=game.clubs.club_id(1)
	game.match_menu.last_career_club="c03"; game.match_menu.last_career_division=1
	game.match_menu.save_settings()
	game.management.difficulty=0
	game.match_menu.last_home=""; game.match_menu.last_away=""
	game.match_menu.last_home_league=0; game.match_menu.last_away_league=0
	game.match_menu.last_career_club="c00"; game.match_menu.last_career_division=0
	game.match_menu.load_settings()
	check(game.management.difficulty==2,"Difficulty survives a settings round trip")
	check(game.match_menu.last_home==stored_home and game.match_menu.last_away==stored_away and game.match_menu.last_away_league==1,"Last selected clubs survive a settings round trip")
	check(game.match_menu.last_career_club=="c03" and game.match_menu.last_career_division==1,"Last career club survives a settings round trip")
	game.start_match(true)
	check(game.match_camera.id()=="broadcast","A new match uses the saved starting camera")
	game.controller.device=0; game.controller.held.clear()
	game.match_menu.open_menu(); game.match_menu.show_page(3)
	check(game.match_menu.navigation.all(func(b): return b.icon!=null and b.text in ["SES","KONTROLÇÜ","TUŞ ATAMA","GÖRÜNTÜ","ERİŞİLEBİLİRLİK","OYNANIŞ"]),"Settings sections use drawn icons and clean labels")
	await process_frame; await process_frame
	game.match_menu.fields[8][0].grab_focus()
	var before: float=game.match_camera.distance
	pad(JOY_BUTTON_DPAD_RIGHT)
	check(game.match_camera.distance>before and game.state=="paused" and game.ball.freeze,"The controller adjusts camera distance safely in Settings")
	game.match_menu.fields[9][0].grab_focus()
	before=game.match_camera.height; pad(JOY_BUTTON_DPAD_LEFT)
	check(game.match_camera.height<before,"The controller adjusts camera elevation")
	if "--visual" in OS.get_cmdline_user_args():
		await process_frame; RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("/tmp/sefc-camera-settings.png")
	pad(JOY_BUTTON_B)
	check(not game.match_menu.visible and game.state=="playing" and not game.ball.freeze,"Closing camera settings saves and resumes the match")
	before=game.match_camera.distance
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=true
	game._input(wheel)
	check(game.match_camera.distance<before,"The mouse wheel zooms perspective cameras too")
	game.match_camera.set_distance(90); game.match_camera.set_height(-90)
	check(game.match_camera.distance==1.50 and game.match_camera.height==.65,"Camera values are clamped to usable bounds")
	game.match_camera.defaults()
	check(game.match_camera.preferred=="sideline" and game.match_camera.distance==1 and game.match_camera.height==1,"Camera defaults restore the original view")
	print("CAMERA SETTINGS CHECK: %d checks, %d failures" % [checks,failures])
	DirAccess.remove_absolute(game.match_menu.config_path)
	game.free(); quit(1 if failures else 0)
