extends SceneTree
var game
var checks := 0
var failures := 0
var capture_prefix := "screen-fill-"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-prefix="): capture_prefix=arg.trim_prefix("--capture-prefix=")
	call_deferred("run")

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
	if (label.begins_with("menu-") or label=="fullscreen") and game.ui.offset.x>16:
		# The old menu painted a non-black, opaque filler column, which the
		# previous brightness-only check incorrectly accepted as a filled screen.
		var x := roundi(12*root.get_stretch_transform().x.length())
		var filler := Color("081416")
		var matches := 0; var count := 0
		for y in range(20,frame.get_height()-20,40):
			var color := frame.get_pixel(x,y)
			count+=1
			if Vector3(color.r-filler.r,color.g-filler.g,color.b-filler.b).length()<.0025: matches+=1
		check(matches<count*.9,"Main menu has no opaque filler strip beside its content: "+label)
	if "--visual" in OS.get_cmdline_user_args(): frame.save_png("res://tests/"+capture_prefix+label+".png")

func verify_layout(label: String) -> void:
	var logical: Vector2=root.get_visible_rect().size
	check(is_equal_approx(logical.x/logical.y,float(root.size.x)/root.size.y),"3D viewport follows the output aspect: "+label)
	var design := Rect2(game.ui.offset,game.ui.DESIGN_SIZE)
	check(Rect2(Vector2.ZERO,logical).encloses(design),"All menu content fits without clipping: "+label)
	check(game.ui.offset.is_equal_approx((logical-game.ui.DESIGN_SIZE)*.5),"Modal content retains its centered canvas: "+label)
	var stretch: Transform2D=root.get_stretch_transform()
	check(is_equal_approx(stretch.x.length(),stretch.y.length()),"Text and buttons retain their proportions: "+label)
	var point: Vector3=game.players[9].position+Vector3.UP
	var marker: Vector2=game.ui.transform*game.screen_position(point)
	check(marker.distance_to(game.camera.unproject_position(point))<.001,"World labels align with the expanded camera: "+label)
	var bounds: Rect2=game.ui.bounds()
	check((bounds.position+game.ui.offset).is_zero_approx() and bounds.size.is_equal_approx(logical),"Menu backgrounds cover the whole output: "+label)
	var first: Vector2=game.ui.transform*game.hud.nav_buttons[0].position
	var last: Vector2=game.ui.transform*(game.hud.nav_buttons[3].position+game.hud.nav_buttons[3].size)
	check(is_equal_approx(first.x,32) and is_equal_approx(logical.y-last.y,68),"Main-menu actions follow the real left and bottom edges: "+label)
	var hero: Vector2=game.ui.transform*(game.hud.home_menu.content_offset()+Vector2(62,32))
	check(hero.is_equal_approx(Vector2(30,32)),"Branding follows the real top-left corner: "+label)
	var live: Vector2=game.ui.transform*(Vector2(1404,36)+game.ui.edge_offset(1,-1))
	check(is_equal_approx(logical.x-live.x,36) and is_equal_approx(live.y,36),"Live badge follows the real top-right corner: "+label)
	for button in game.hud.nav_buttons:
		check(bounds.encloses(button.get_rect()),"Resized action remains fully clickable: "+str(button.get_meta("home_action")))
	var focused: Control=root.gui_get_focus_owner()
	if game.hud.nav_buttons.has(focused):
		var feedback=game.hud.ui_feedback
		var focused_at: Vector2=feedback.get_global_transform_with_canvas().affine_inverse()*focused.get_global_transform_with_canvas().origin
		check(feedback.rect.position.is_equal_approx(focused_at-Vector2(3,3)),"Focus outline stays attached when the screen is resized: "+label)

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
		game.return_menu(); game.set_physics_process(false); game.update_camera(0); game.hud.sync_navigation(); game.hud.queue_redraw()
		await settle()
		verify_layout(label)
		await capture("menu-"+label)
		var settings_rect: Rect2=game.hud.home_menu.card_rect(2)
		click(game.ui.transform*settings_rect.get_center()); await settle()
		check(game.match_menu.visible,"Mouse clicks the edge-anchored Settings button: "+label)
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
	game.return_menu(); game.set_physics_process(false); game.update_camera(0); game.hud.sync_navigation(); game.hud.queue_redraw()
	await settle()
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
