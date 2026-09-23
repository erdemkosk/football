extends "res://tests/performance_benchmark.gd"
func measure(title: String) -> void:
	var began:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-began<700000: await process_frame
	began=Time.get_ticks_usec(); var last:=began
	var samples: Array[float]=[]; var physics:=0.0; var render:=0.0; var gpu:=0.0; var draws:=0.0
	while Time.get_ticks_usec()-began<2500000:
		await process_frame
		var now:=Time.get_ticks_usec(); samples.append((now-last)/1000.0); last=now
		physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		render+=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	samples.sort(); var n:=samples.size()
	print(title," fps=",n*1000000.0/(last-began)," p95=",samples[int(n*.95)]," physics=",physics/n," render=",render/n," gpu=",gpu/n," draws=",draws/n)
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/performance-settings.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	prepare(); game.weather.select(2,true); game.stadium.light_rig.select(1)
	game.set_process(true); game.set_physics_process(true); game.ball.freeze=false
	await measure("full")
	game.set_physics_process(false); game.ball.freeze=true
	await measure("no-match-physics")
	game.set_process(false)
	await measure("no-main-process")
	var crowds: Array=[]
	for node in game.stadium.find_children("*","MultiMeshInstance3D",true,false):
		if node.name.begins_with("Crowd") or node.name.begins_with("Fan"): crowds.append(node); node.hide()
	await measure("no-crowd")
	for node in crowds: node.show()
	for light in game.stadium.light_rig.floodlights: light.shadow_enabled=false
	await measure("no-flood-shadows")
	for light in game.stadium.light_rig.floodlights: light.shadow_enabled=true
	game.set_process(true); game.set_physics_process(true); game.ball.freeze=false
	await measure("full-again")
	game.free(); quit()
