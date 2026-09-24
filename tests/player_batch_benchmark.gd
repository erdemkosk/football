extends "res://tests/fps_compare_benchmark.gd"
var batch_enabled:=true
func prepare() -> void:
	super.prepare()
	for player in game.players+game.referees.actors:
		if is_instance_valid(player.render_batch): player.render_batch.set_active(batch_enabled)
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="user://benchmark-settings.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	print("PLAYER BATCH debug=",OS.is_debug_build()," GPU=",RenderingServer.get_video_adapter_name())
	await sample("warmup",true,1,true); results.clear()
	for trial in range(3):
		for enabled in ([false,true] if trial%2==0 else [true,false]):
			batch_enabled=enabled; label="batched" if enabled else "original"
			await sample(label+"-day-"+str(trial),true,0)
			await sample(label+"-night-"+str(trial),true,1)
			await sample(label+"-rain-"+str(trial),true,1,true)
	var path: String=OS.get_executable_path().get_base_dir().path_join("results.json") if not OS.is_debug_build() else "res://tests/performance-player-batch.json"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(results,"\t")); file.close()
	game.free(); quit()
