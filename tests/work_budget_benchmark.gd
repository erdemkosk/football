extends "res://tests/performance_benchmark.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/performance-settings.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for trial in range(3):
		for scheduled in ([false,true] if trial%2==0 else [true,false]):
			game.work_budget.enabled=scheduled
			await sample(("scheduled" if scheduled else "reference")+"-"+str(trial),true,1,true)
	var file=FileAccess.open("res://tests/performance-work-budget-paired.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")); file.close()
	game.free(); quit()
