extends "res://tests/performance_benchmark.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	prepare(); game.weather.presence.set_process(false)
	var old=load("res://tests/presence_before.gd").new(); old.game=game; root.add_child(old); old.set_process(false); old.hide()
	var current=load("res://scripts/pitch_presence.gd").new(); current.game=game; root.add_child(current); current.set_process(false); current.hide()
	var failures := 0
	var compared := 0
	for scenario in range(18):
		game.weather.wetness=[0.0,.25,.251,.55,1.0,0.0][scenario%6]
		game.weather.clock=float(scenario)
		game.players[3].visible=scenario%3!=0
		game.ball.visible=scenario%4!=0
		game.players[7].position.x=float(scenario)*5-40
		game.players[5].kit_materials.jersey.albedo_color=Color(.1+scenario*.02,.4,.6)
		for p in game.players:
			p.run_phase+=.13; p.animate(1.0/120)
		old.update_visuals(); current.update_visuals()
		if old.reflections.visible!=current.reflections.visible: failures+=1
		for pair in [[old.shadows,current.shadows],[old.reflections,current.reflections]]:
			var a: MultiMesh=pair[0].multimesh
			var b: MultiMesh=pair[1].multimesh
			if a.visible_instance_count!=b.visible_instance_count: failures+=1
			for i in range(a.visible_instance_count):
				compared+=1
				if a.get_instance_transform(i)!=b.get_instance_transform(i) or a.get_instance_color(i)!=b.get_instance_color(i): failures+=1
		if old.reflection_material.get_shader_parameter("wetness")!=current.reflection_material.get_shader_parameter("wetness"): failures+=1
		if old.reflection_material.get_shader_parameter("clock")!=current.reflection_material.get_shader_parameter("clock"): failures+=1
	for wet in [0.0,1.0]:
		game.weather.wetness=wet
		var old_times: Array[float]=[]; var new_times: Array[float]=[]
		for trial in range(8):
			for candidate in ([old,current] if trial%2==0 else [current,old]):
				candidate.update_visuals()
				var started := Time.get_ticks_usec()
				for iteration in range(200): candidate.update_visuals()
				var elapsed := float(Time.get_ticks_usec()-started)/200
				if candidate==old: old_times.append(elapsed)
				else: new_times.append(elapsed)
		old_times.sort(); new_times.sort()
		print("PRESENCE paired fixed-layout wet=",wet," old_us=",old_times[4]," new_us=",new_times[4])
	print("PRESENCE EQUIVALENCE: 18 scenarios, ",compared," instance comparisons, ",failures," failures")
	old.free(); current.free(); game.free(); quit(0 if failures==0 else 1)
