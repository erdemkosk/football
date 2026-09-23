extends SceneTree
var game
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func settle() -> void:
	for n in range(8): await process_frame

func click(point: Vector2) -> void:
	var move := InputEventMouseMotion.new(); move.position=point
	root.push_input(move,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		root.push_input(event,true)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await settle(); RenderingServer.force_draw(false)
	var frame := root.get_texture().get_image()
	check(frame.get_size()==root.size,"Rendered image covers every output pixel: "+label)
	# The reported bug was solid black columns at both edges. Sample each
	# side through its full height, including the menu's intentional dark fade.
	for side in [0,frame.get_width()-1]:
		var painted := 0
		for y in range(20,frame.get_height()-20,40):
			var color := frame.get_pixel(side,y)
			if color.r+color.g+color.b>.01: painted+=1
		check(painted>5,"Output edge contains scene/UI, not a black bar: %s side %d" % [label,side])
	if "--visual" in OS.get_cmdline_user_args(): frame.save_png("res://tests/screen-fill-"+label+".png")

func verify_layout(label: String) -> void:
	var logical: Vector2=root.get_visible_rect().size
	check(is_equal_approx(logical.x/logical.y,float(root.size.x)/root.size.y),"3D viewport follows the output aspect: "+label)
	var design := Rect2(game.ui.offset,game.ui.DESIGN_SIZE)
	check(Rect2(Vector2.ZERO,logical).encloses(design),"All menu content fits without clipping: "+label)
	check(game.ui.offset.is_equal_approx((logical-game.ui.DESIGN_SIZE)*.5),"Menu content remains centered: "+label)
	var stretch: Transform2D=root.get_stretch_transform()
	check(is_equal_approx(stretch.x.length(),stretch.y.length()),"Text and buttons retain their proportions: "+label)
	var point: Vector3=game.players[9].position+Vector3.UP
	var marker: Vector2=game.ui.transform*game.screen_position(point)
	check(marker.distance_to(game.camera.unproject_position(point))<.001,"World labels align with the expanded camera: "+label)
	var bounds: Rect2=game.ui.bounds()
	check((bounds.position+game.ui.offset).is_zero_approx() and bounds.size.is_equal_approx(logical),"Menu backgrounds cover the whole output: "+label)

func run() -> void:
	if DisplayServer.get_name()=="headless": root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false)
	game.controller.set_process(false)
	game.match_menu.config_path="res://tests/screen-fill-"+str(OS.get_process_id())+".cfg"
	var display=game.match_menu.display
	display.set_fullscreen(false)
	for output in [Vector2i(1600,900),Vector2i(1720,720),Vector2i(1200,900),Vector2i(1440,900)]:
		display.select_resolution(output)
		if DisplayServer.get_name()=="headless": root.size=output
		await settle()
		var label := "%dx%d" % [output.x,output.y]
		game.return_menu(); game.set_physics_process(false); game.hud.sync_navigation(); game.hud.queue_redraw()
		verify_layout(label)
		await capture("menu-"+label)
		click(game.ui.transform*Vector2(240,774)); await settle()
		check(game.match_menu.visible,"Mouse clicks the centered Settings button: "+label)
		if game.match_menu.visible:
			game.match_menu.show_page(3); game.match_menu.queue_redraw()
			if output==Vector2i(1600,900): await capture("settings-wide")
			game.match_menu.close_menu()
		game.controls_help.open_panel(); await settle()
		click(game.ui.transform*Vector2(398,820)); await settle()
		check(game.controls_help.visible,"Click inside the centered help card keeps it open: "+label)
		click(Vector2(4,root.get_visible_rect().size.y-4)); await settle()
		check(not game.controls_help.visible,"Click outside the help card closes it: "+label)
	display.set_fullscreen(true); display.select_resolution(Vector2i.ZERO); await settle()
	game.return_menu(); game.set_physics_process(false); game.hud.sync_navigation(); game.hud.queue_redraw()
	verify_layout("native-fullscreen"); await capture("fullscreen")
	game.frontend.open_selection(); game.frontend.queue_redraw(); await settle()
	await capture("teams")
	game.frontend.hide(); game.start_match(true); game.set_physics_process(false)
	game.hud.bug_age=1.0
	game.update_camera(0); game.hud.queue_redraw(); await settle()
	await capture("match")
	DirAccess.remove_absolute(game.match_menu.config_path)
	print("SCREEN FILL CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
