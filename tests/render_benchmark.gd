extends SceneTree
## Run in a graphical Godot process, without --fixed-fps or --disable-render-loop.
## Identical cameras and animation phases make before/after captures comparable.
var game
var frame := 0
var results: Array = []
var label := "baseline"
var diagnostic := false
var live := false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
		diagnostic=diagnostic or arg=="--diagnostic"
		live=live or arg=="--live"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(false,false)
	game.set_physics_process(false); game.set_process(false)
	game.ball.freeze=true
	game.hud.visible=false
	game.weather.select(0,true)
	game.players[9].position=Vector3(0,0,0)
	game.players[10].position=Vector3(7,0,-4)
	game.ball.position=Vector3(0,0.23,-0.8)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	print("BENCHMARK ",label," viewport=",root.size," renderer=",RenderingServer.get_current_rendering_method())
	await measure("day-play",0,false)
	await measure("night-play",1,false)
	if diagnostic:
		for light in game.stadium.light_rig.floodlights: light.shadow_enabled=false
		await measure("night-no-shadows",1,false)
		for light in game.stadium.light_rig.floodlights: light.shadow_enabled=true
		for node in game.stadium.get_children():
			if node is MultiMeshInstance3D: node.visible=false
		await measure("night-no-crowd",1,false)
		for node in game.stadium.get_children():
			if node is MultiMeshInstance3D: node.visible=true
	await measure("day-stadium",0,true)
	await measure("night-stadium",1,true)
	game.weather.select(2,true)
	await measure("night-rain",1,false)
	if live:
		game.hud.visible=true
		game.set_process(true); game.set_physics_process(true)
		game.start_match(false,false,true)
		game.stadium.light_rig.select(1)
		await measure_live("night-live-stadium")
		game.state="playing"
		game.start_match(false,false)
		game.stadium.light_rig.select(1)
		game.weather.select(2,true)
		await measure_live("night-live-rain-match")
	var file := FileAccess.open("/tmp/football-render-"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")); file.close()
	game.free()
	quit()

func measure_live(scene: String) -> void:
	var started := Time.get_ticks_usec()
	while Time.get_ticks_usec()-started<2000000: await process_frame
	var times: Array[float] = []
	started=Time.get_ticks_usec()
	var tick := started
	while Time.get_ticks_usec()-started<6000000:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now-tick)/1000.0)
		tick=now
	var duration := (tick-started)/1000000.0
	times.sort()
	var row := {"scene":scene,"fps":times.size()/duration,"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*0.95)],"frames":times.size(),"duration":duration}
	results.append(row)
	print(JSON.stringify(row))
	root.get_texture().get_image().save_png("/tmp/football-render-"+label+"-"+scene+".png")

func measure(scene: String,period: int,wide: bool) -> void:
	game.stadium.light_rig.select(period)
	game.camera.size=180 if wide else 49
	game.camera.position=Vector3(98,144,166) if wide else Vector3(0,70,37)
	game.camera.look_at(Vector3(-26,0,22) if wide else Vector3.ZERO)
	game.stadium.crowd.reset()
	frame=0
	var warmup := Time.get_ticks_usec()
	while Time.get_ticks_usec()-warmup<1000000: await render_frame()
	var times: Array[float] = []
	var cpu := 0.0
	var gpu := 0.0
	var draws := 0.0
	var primitives := 0.0
	var started := Time.get_ticks_usec()
	while times.size()<120 or Time.get_ticks_usec()-started<3000000:
		var tick := Time.get_ticks_usec()
		await render_frame()
		times.append((Time.get_ticks_usec()-tick)/1000.0)
		cpu+=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var duration := (Time.get_ticks_usec()-started)/1000000.0
	times.sort()
	var count := times.size()
	var row := {"scene":scene,"fps":count/duration,"median_ms":times[count/2],"p95_ms":times[int(count*0.95)],"cpu_ms":cpu/count,"gpu_ms":gpu/count if gpu>0 else null,"draw_calls":draws/count,"primitives":primitives/count,"frames":count,"duration":duration}
	results.append(row)
	print(JSON.stringify(row))
	root.get_texture().get_image().save_png("/tmp/football-render-"+label+"-"+scene+".png")

func render_frame() -> void:
	frame+=1
	game.stadium.crowd.update(1.0/120,Vector3.ZERO,Vector3.ZERO,0,false,false)
	for p in game.players: p.animate(1.0/120)
	await process_frame
	await RenderingServer.frame_post_draw
