extends "res://tests/fps_bottleneck.gd"
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/performance-settings.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	prepare(); game.stadium.light_rig.select(1)
	game.set_process(true); game.set_physics_process(true); game.ball.freeze=false
	await measure("full-night")
	for p in game.players: p.rig.hide()
	for p in game.referees.actors: p.rig.hide()
	await measure("diagnostic-hidden-rigs-live-simulation")
	for p in game.players: p.rig.show()
	for p in game.referees.actors: p.rig.show()
	await measure("restored-night")
	game.free(); quit()
