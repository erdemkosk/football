extends "res://tests/performance_benchmark.gd"
func run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var methods := {"_physics_process":"delta","_process":"delta","simulate_match":"delta","update_ai":"delta","update_contacts":"delta","update_camera":"delta","flush_running_poses":"","update_stadium_score":""}
	source+="\nvar cpu_samples: Dictionary={}\n"
	for method in methods:
		source=source.replace("func "+method+"(","func cpu_inner_"+method+"(")
		var arg: String=methods[method]
		source+="\nfunc "+method+"("+("delta: float" if arg!="" else "")+") -> void:\n\tvar started := Time.get_ticks_usec()\n\tcpu_inner_"+method+"("+arg+")\n\tif not cpu_samples.has(\""+method+"\"): cpu_samples[\""+method+"\"]=[]\n\tcpu_samples[\""+method+"\"].append(Time.get_ticks_usec()-started)\n"
	var script=GDScript.new(); script.source_code=source
	if script.reload()!=OK: quit(1); return
	game=script.new(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/performance-settings.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	prepare(); game.stadium.light_rig.select(1)
	game.set_process(true); game.set_physics_process(true); game.ball.freeze=false
	var started := Time.get_ticks_usec()
	while Time.get_ticks_usec()-started<10000000: await process_frame
	game.set_process(false); game.set_physics_process(false)
	for method in game.cpu_samples:
		var samples: Array=game.cpu_samples[method]; samples.sort()
		var total := 0.0
		for value in samples: total+=value
		print(method," calls=",samples.size()," mean_us=",total/samples.size()," p95_us=",samples[int(samples.size()*.95)]," max_us=",samples[-1])
	game.free(); quit()
