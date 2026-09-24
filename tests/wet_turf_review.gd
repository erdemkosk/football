extends "res://tests/fps_bottleneck.gd"
var original: Shader=load("res://tests/grass_wet_before.gdshader")
var revised: Shader=load("res://shaders/grass.gdshader")
func frame(label: String,old: bool) -> void:
	game.stadium.grass.shader=original if old else revised
	game.weather.apply_look()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/wet-turf-"+label+("-before" if old else "-after")+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/performance-settings.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	prepare(); game.hud.hide(); game.weather.select(2,true); game.weather.clock=6.25
	game.weather.set_process(false); game.stadium.light_rig.set_process(false)
	game.match_time=game.LENGTH*.4; game.weather.apply_look()
	for period in [0,1]:
		game.stadium.light_rig.select(period)
		game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=48
		game.camera.position=Vector3(9,6,35); game.camera.look_at(Vector3(0,0,46))
		for old in [true,false]: await frame("goalmouth-"+str(period),old)
		game.camera.position=Vector3(37,31,8); game.camera.look_at(Vector3(0,0,0)); game.camera.fov=64
		for old in [true,false]: await frame("match-"+str(period),old)
		for trial in range(2):
			for old in ([true,false] if trial==0 else [false,true]):
				game.stadium.grass.shader=original if old else revised; game.weather.apply_look()
				await measure(("original" if old else "revised")+" period="+str(period)+" trial="+str(trial))
	game.weather.select(0,true)
	for old in [true,false]: await frame("dry",old)
	game.weather.select(2,true); game.stadium.light_rig.select(0)
	game.camera.position=Vector3(1,1.1,40); game.camera.look_at(Vector3(0,.1,46)); game.camera.fov=60
	for old in [true,false]: await frame("low-close",old)
	game.free(); quit()
