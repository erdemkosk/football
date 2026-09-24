extends "res://tests/performance_benchmark.gd"
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	prepare()
	var source=FileAccess.get_file_as_string("res://tests/delivery_saturation_before.gd").replace("res://scripts/passing.gd","res://tests/passing_saturation_before.gd")
	var script=GDScript.new(); script.source_code=source
	if script.reload()!=OK: quit(1); return
	var old=script.new(); old.game=game
	var current=load("res://scripts/ai_delivery.gd").new(); current.game=game
	var rng=RandomNumberGenerator.new(); rng.seed=7321
	var failures := 0; var checks := 0; var saturated := 0
	var old_time := 0; var new_time := 0
	for layout in range(40):
		game.weather.select(layout%3,true); game.management.difficulty=layout%3
		for p in game.players:
			p.position=Vector3(rng.randf_range(-16,16),0,rng.randf_range(-22,22))
			p.velocity=Vector3(rng.randf_range(-5,5),0,rng.randf_range(-5,5))
			p.visible=true; p.dismissed=false
		game.ball.position=game.players[20].position+Vector3(0,.23,.5)
		for receiver in [12,14,16,18,19]:
			for lob in [false,true]:
				var q=game.players[receiver]
				var route: Dictionary=game.Passing.plan(game.ball.position,q.position,q.velocity,lob,game.weather)
				var a: Dictionary; var b: Dictionary
				for candidate in ([old,current] if layout%2==0 else [current,old]):
					var start := Time.get_ticks_usec()
					var result: Dictionary=candidate.assess(20,route,receiver,game.ball.position,.065)
					var took := Time.get_ticks_usec()-start
					if candidate==old: a=result; old_time+=took
					else: b=result; new_time+=took
				checks+=1
				if a!=b: failures+=1
				if a.risk==1.0: saturated+=1
	print("DELIVERY EQUIVALENCE checks=",checks," saturated=",saturated," failures=",failures," old_us=",float(old_time)/checks," new_us=",float(new_time)/checks)
	game.free(); quit(0 if failures==0 else 1)
