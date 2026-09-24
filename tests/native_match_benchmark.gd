extends "res://tests/fps_compare_benchmark.gd"
const Native=preload("res://scripts/native_match.gd")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/performance-settings.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	if Native.get_kernel()==null: push_error("Native kernel unavailable"); game.free(); quit(1); return
	await sample("warmup",true,1,true)
	results.clear()
	for trial in range(2):
		for enabled in ([false,true] if trial==0 else [true,false]):
			Native.enabled=enabled
			label="native" if enabled else "script"
			await sample(label+"-day-"+str(trial),true,0)
			await sample(label+"-night-"+str(trial),true,1)
			await sample(label+"-rain-"+str(trial),true,1,true)
	var file := FileAccess.open("res://tests/performance-native-paired.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")); file.close()
	game.free(); quit()
