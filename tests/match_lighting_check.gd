extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func settle() -> void:
	game.controller.menus.sync()
	for i in range(6): await process_frame
func tap(code: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new(); event.device=0; event.button_index=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events()
func click(control: Control) -> void:
	var at := root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size*.5)
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.position=at; event.global_position=at; event.pressed=down; event.button_index=MOUSE_BUTTON_LEFT
		Input.parse_input_event(event); Input.flush_buffered_events()
	await settle()
func capture(label: String) -> Image:
	game.hud.queue_redraw(); game.frontend.queue_redraw()
	await settle(); RenderingServer.force_draw(false)
	var result := root.get_texture().get_image()
	if label!="": result.save_png("res://tests/lighting-"+label+".png")
	return result
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_physics_process(false); game.set_process(false); game.controller.device=0
	var rig=game.stadium.light_rig
	check(rig.period==0 and game.stadium.sun.visible and game.stadium.sun.shadow_enabled,"Default daytime uses one real shadow-casting sun")
	check(rig.floodlights.size()==4 and rig.floodlights.all(func(light): return not light.visible and light.light_energy==0),"Four roof floodlights are present and off during the day")
	rig.select(1)
	game.weather.select(2,true)
	game.weather.update(8)
	check(not game.stadium.env.fog_enabled and rig.shafts.size()==4 and rig.shafts.all(func(shaft): return not shaft.visible),"A rainy night stays clear without pitch fog or floodlight shafts")
	rig.select(0)
	check(not game.stadium.env.fog_enabled and rig.shafts.all(func(shaft): return not shaft.visible),"Daylight also keeps fog and floodlight volumes off")
	game.weather.select(0,true)
	game.frontend.open_selection(); await settle()
	# Finish both current team-pick animations before navigating the match options.
	for side in range(2):
		game.frontend.pick_side(side)
		game.frontend._process(1.0)
	await settle()
	# The new choice is reachable naturally from the confirmation button with D-pad left.
	game.frontend.go_button.grab_focus(); tap(JOY_BUTTON_DPAD_LEFT)
	check(root.gui_get_focus_owner()==game.frontend.time_button,"D-pad reaches match time from the pre-match continue button")
	tap(JOY_BUTTON_A); await settle()
	check(rig.period==2 and root.gui_get_focus_owner()==game.frontend.time_button,"Xbox A selects warm evening and preserves menu focus")
	check(game.stadium.sun.visible and game.stadium.sun.rotation_degrees.x> -45,"Evening uses a low golden sun")
	tap(JOY_BUTTON_A); await settle()
	check(rig.period==1 and root.gui_get_focus_owner()==game.frontend.time_button,"Xbox A selects night and preserves menu focus")
	check(not game.stadium.sun.visible and game.stadium.sun.light_energy==0,"Night completely disables sunlight")
	check(rig.floodlights.all(func(light): return light.visible and light.shadow_enabled and light.light_energy>0),"All four real spotlights illuminate and cast shadows at night")
	check(game.stadium.architecture.lamp_glass.emission_enabled,"Visible roof lamp glass lights up at night")
	for light in rig.floodlights:
		check(absf(light.position.x)>45 and light.position.y>15 and absf(light.position.z)>30 and (-light.basis.z).y<0,"Floodlight is mounted on the roof and aimed down into the pitch")
	await click(game.frontend.time_button)
	check(rig.period==0 and not game.stadium.architecture.lamp_glass.emission_enabled,"Mouse toggles back to daytime and turns off emissive lamps")
	await click(game.frontend.time_button)
	check(rig.period==2,"Mouse cycles from noon to evening")
	await click(game.frontend.time_button)
	game.frontend.cycle_weather(); game.frontend.cycle_weather()
	check(rig.period==1 and game.weather.preset==2 and not game.stadium.sun.visible,"Weather and time choices are independent, including a rainy night")
	if "--visual" in OS.get_cmdline_user_args(): await capture("selection")
	game.frontend.open_tactics(true); game.frontend.confirm()
	check(game.state=="ceremony" and rig.period==1 and not game.stadium.sun.visible,"Night and rain persist into the entrance ceremony")
	game.ceremony.finish(true); game.set_physics_process(false)
	game.weather.update(10)
	check(rig.period==1 and rig.floodlights.all(func(light): return light.visible) and not game.stadium.sun.visible,"Repeated weather updates cannot restore the day sun")
	var forward: Vector3=-rig.floodlights[0].basis.z
	game.interval.begin(); game.interval.finish()
	check(rig.period==1 and (-rig.floodlights[0].basis.z).is_equal_approx(forward),"Changing ends at halftime does not rotate the stadium lights")
	var before: float=game.weather.ball_drag(Vector3(15,0,0))
	rig.select(0)
	check(is_equal_approx(before,game.weather.ball_drag(Vector3(15,0,0))) and game.weather.preset==2,"Changing match time does not alter weather or physical friction")
	if "--visual" in OS.get_cmdline_user_args(): await visual_checks()
	print("MATCH LIGHTING CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)

func visual_checks() -> void:
	var rig=game.stadium.light_rig
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	game.toast_timer=0; game.ball.freeze=true
	game.players[9].position=Vector3(0,0,0); game.players[9].facing=Vector3.FORWARD
	game.players[10].position=Vector3(7,0,-4); game.players[10].facing=Vector3.LEFT
	game.ball.position=Vector3(0,0.23,-0.8)
	game.camera.size=49; game.camera.position=Vector3(0,70,37); game.camera.look_at(Vector3.ZERO)
	game.weather.select(0,true); rig.select(0)
	await capture("day-play")
	rig.select(1); var playable: Image=await capture("night-play")
	check(playable.get_pixel(900,700).get_luminance()>0.12,"Night grass stays bright enough to read the game")
	game.weather.select(2,true); await capture("night-rain")
	game.weather.select(0,true); game.hud.visible=false
	game.camera.size=22; game.camera.position=Vector3(4,19,16); game.camera.look_at(Vector3(2,0,-1))
	rig.select(0); var daylight: Image=await capture("day-shadows")
	game.stadium.sun.shadow_enabled=false
	var day_without: Image=await capture("")
	check(shadow_pixels(daylight,day_without)>150,"Rendered daylight contains actual directional shadows on the turf")
	game.stadium.sun.shadow_enabled=true
	rig.select(1); var night: Image=await capture("night-shadows")
	# Keep the same per-pixel lighting path when comparing shadow visibility.
	for light in rig.floodlights: light.shadow_opacity=0
	var night_without: Image=await capture("")
	var changed := shadow_pixels(night,night_without)
	check(changed>150 and changed<120000,"Rendered floodlights cast localized player shadows without striping the whole pitch")
	for light in rig.floodlights: light.shadow_opacity=0.70
	game.camera.size=176; game.camera.position=Vector3(0,108,89); game.camera.look_at(Vector3.ZERO)
	await capture("night-stadium")

func shadow_pixels(with_shadows: Image,without_shadows: Image) -> int:
	var count := 0
	for y in range(100,with_shadows.get_height()-100):
		for x in range(120,with_shadows.get_width()-120):
			var a := with_shadows.get_pixel(x,y).get_luminance()
			var b := without_shadows.get_pixel(x,y).get_luminance()
			if b-a>0.018: count+=1
	print("SHADOW PIXELS: ",count)
	return count
