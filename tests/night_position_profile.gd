extends "res://tests/fps_bottleneck.gd"
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/performance-settings.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	prepare()
	print("POSITION PROFILE thread=",ProjectSettings.get_setting("rendering/driver/threads/thread_model"))
	for period in [0,1]:
		game.stadium.light_rig.select(period)
		for z in [-32.0,0.0,32.0]:
			game.ball.position=Vector3(0,game.ball.RADIUS,z)
			game.players[game.controlled].position=Vector3(0,0,z)
			game.match_camera.snap=true; game.update_camera(0)
			await measure("static period="+str(period)+" z="+str(z))
	game.set_process(true); game.set_physics_process(true); game.ball.freeze=false
	await measure("night-live")
	game.free(); quit()
