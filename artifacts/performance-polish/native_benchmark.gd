extends "res://tests/fps_compare_benchmark.gd"
var output:="res://artifacts/performance-polish/after.json"
func prepare() -> void:
	super.prepare()
	game.state="playing"
	game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	game.goalkeeping.variation.seed=742
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-recent-performance.cfg"
	game.match_menu.display.set_fullscreen(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	print("DEVICE ",OS.get_processor_name()," / ",RenderingServer.get_video_adapter_name()," / ",RenderingServer.get_current_rendering_method())
	prepare()
	game.stadium.light_rig.select(1); game.weather.select(2,true)
	game.ball.freeze=false; game.set_process(true); game.set_physics_process(true)
	var warmup:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warmup<6500000: await process_frame
	results.clear()
	for trial in range(2):
		for scene in ([0,1,2] if trial==0 else [2,1,0]):
			await sample(["day","night","rain"][scene]+"-"+str(trial),true,0 if scene==0 else 1,scene==2)
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")); file.close()
	print("RECENT PERFORMANCE COMPLETE ",output," viewport=",root.size)
	game.free(); quit()
