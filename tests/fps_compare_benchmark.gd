extends "res://tests/fps_regression_check.gd"
var results: Array=[]
var label := "paired-fps"
func prepare() -> void:
	game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	game.frontend.hide(); game.match_menu.hide(); game.controls_help.hide()
	game.ball.freeze=true; game.ball.pending_reset=false
	game.weather.select(0,true); game.stadium.light_rig.select(0)
	game.rng.seed=541; game.management.difficulty=2
	for p in game.players:
		p.position=p.home; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	game.players[20].position=Vector3(0,0,0)
	game.ball.position=Vector3(0,game.ball.GROUND_HEIGHT,.65)
	game.dribbler=20; game.carrier=20; game.last_touch=1
	game.menu_match.running=true
	game.match_camera.select("sideline"); game.camera_focus=Vector3.ZERO; game.update_camera(0)

func cpu(name: String,action: Callable,count: int=120) -> void:
	prepare()
	for i in range(8): action.call()
	var start := Time.get_ticks_usec()
	for i in range(count): action.call()
	var row := {"system":name,"us_per_call":float(Time.get_ticks_usec()-start)/count,"calls":count}
	results.append(row); print(JSON.stringify(row))

func compare_planning() -> void:
	# A paired measurement isolates planning reuse from machine/load changes.
	# Both paths use the current equations and exactly the same static layout.
	prepare()
	var eager: Array[float]=[]; var reused: Array[float]=[]
	for trial in range(8):
		for force in ([true,false] if trial%2==0 else [false,true]):
			game.support.reset()
			var started := Time.get_ticks_usec()
			for tick in range(240):
				if force: game.support.plan_age=0
				game.support.update(DT)
			var cost := float(Time.get_ticks_usec()-started)/240
			if force: eager.append(cost)
			else: reused.append(cost)
		eager.sort(); reused.sort()
	var row := {"system":"paired-support-planning","eager_us":eager[eager.size()/2],"reused_us":reused[reused.size()/2],"trials":8,"ticks_per_trial":240}
	row.reduction_percent=100*(1-row.reused_us/row.eager_us)
	results.append(row); print(JSON.stringify(row))

func sample(scene: String,live: bool,period: int,rain: bool=false,wide: bool=false) -> void:
	prepare()
	game.stadium.light_rig.select(period); game.weather.select(2 if rain else 0,true)
	game.menu_match.running=live; game.ball.freeze=not live
	game.set_process(live); game.set_physics_process(live)
	game.hud.visible=live
	if wide:
		game.set_process(false)
		game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		game.camera.size=180; game.camera.position=Vector3(98,144,166); game.camera.look_at(Vector3(-26,0,22))
	var started := Time.get_ticks_usec()
	while Time.get_ticks_usec()-started<1500000: await process_frame
	var samples: Array[float]=[]
	var states: Dictionary={}
	var active_usec := 0
	var cpu_ms := 0.0; var gpu_ms := 0.0; var draws := 0.0; var physics_ms := 0.0
	var ticks := Engine.get_physics_frames()
	started=Time.get_ticks_usec()
	var previous := started
	while Time.get_ticks_usec()-started<5000000:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := now-previous; previous=now
		states[game.state]=int(states.get(game.state,0))+1
		if game.state!="playing": continue
		active_usec+=elapsed
		samples.append(elapsed/1000.0)
		cpu_ms+=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		gpu_ms+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		physics_ms+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
	var duration := (previous-started)/1000000.0
	samples.sort()
	var count := samples.size()
	assert(count>0)
	var row := {"scene":scene,"fps":count*1000000.0/active_usec,"states":states,"p50_ms":samples[count/2],"p95_ms":samples[int(count*.95)],"p99_ms":samples[int(count*.99)],"render_cpu_ms":cpu_ms/count,"gpu_ms":gpu_ms/count,"physics_ms":physics_ms/count,"physics_hz":(Engine.get_physics_frames()-ticks)/duration,"draws":draws/count,"frames":count}
	row.valid=count>=120
	results.append(row); print(JSON.stringify(row))
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/performance-"+label+"-"+scene+".png")


func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/performance-settings.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var optimized_support=game.support
	var optimized_attack=game.ai_attack
	var old_support=reference_support(); old_support.game=game; old_support.shape=reference_shape()
	var old_attack=reference_attack(); old_attack.game=game
	# Prime match initialization and render pipelines before either variant.
	await sample("warmup",true,0)
	results.clear()
	for trial in range(1 if "--single" in OS.get_cmdline_user_args() else 2):
		for optimized in ([false,true] if trial==0 else [true,false]):
			game.support=optimized_support if optimized else old_support
			game.ai_attack=optimized_attack if optimized else old_attack
			game.render_running_poses=optimized
			label="optimized" if optimized else "baseline"
			await sample(label+"-day-"+str(trial),true,0)
			await sample(label+"-night-"+str(trial),true,1)
			await sample(label+"-rain-"+str(trial),true,1,true)
	var file := FileAccess.open("res://tests/performance-paired-fps.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")); file.close()
	game.free(); quit()
