extends "res://tests/fps_compare_benchmark.gd"
var original_shader:=false
func prepare() -> void:
	super.prepare()
	game.stadium.grass.shader=load("res://tests/grass_wet_before.gdshader") if original_shader else load("res://shaders/grass.gdshader")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="user://benchmark-settings.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	print("WET TURF debug=",OS.is_debug_build()," GPU=",RenderingServer.get_video_adapter_name())
	await sample("warmup",true,1,true); results.clear()
	for trial in range(2):
		for old in ([true,false] if trial==0 else [false,true]):
			original_shader=old; label="original" if old else "revised"
			await sample(label+"-rain-day-"+str(trial),true,0,true)
			await sample(label+"-rain-night-"+str(trial),true,1,true)
	var path: String=OS.get_executable_path().get_base_dir().path_join("results.json") if not OS.is_debug_build() else "res://tests/performance-wet-turf.json"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(results,"\t")); file.close()
	game.free(); quit()
