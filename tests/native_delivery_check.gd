extends "res://tests/performance_benchmark.gd"

func run() -> void:
	var status := GDExtensionManager.load_extension("res://native/match.cfg")
	if status!=GDExtensionManager.LOAD_STATUS_OK or not ClassDB.class_exists("MatchKernels"):
		push_error("Native extension failed: "+str(status)); quit(1); return
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	prepare()
	var old=load("res://tests/ai_delivery_native_before.gd").new(); old.game=game
	var current=load("res://scripts/ai_delivery.gd").new(); current.game=game
	var rng=RandomNumberGenerator.new(); rng.seed=932176
	var failures := 0; var checks := 0; var saturated := 0
	var old_time := 0; var new_time := 0; var max_error := 0.0
	for layout in range(400):
		game.weather.select(layout%3,true); game.management.difficulty=layout%3
		for p in game.players:
			p.position=Vector3(rng.randf_range(-32,32),0,rng.randf_range(-48,48))
			p.velocity=Vector3(rng.randf_range(-9,9),0,rng.randf_range(-9,9))
			p.visible=rng.randf()>.04; p.dismissed=rng.randf()<.03
		game.players[20].visible=true; game.players[20].dismissed=false
		game.ball.position=game.players[20].position+Vector3(0,.23,.5)
		for receiver in [-1,12,14,16,18,19]:
			for lob in [false,true]:
				var q=game.players[maxi(receiver,11)]
				var route: Dictionary=game.Passing.plan(game.ball.position,q.position,q.velocity,lob,game.weather)
				var a: Dictionary; var b: Dictionary
				for candidate in ([old,current] if layout%2==0 else [current,old]):
					preload("res://scripts/native_match.gd").enabled=candidate==current
					var start := Time.get_ticks_usec()
					var result: Dictionary=candidate.assess(20,route,receiver,game.ball.position,.065)
					var took := Time.get_ticks_usec()-start
					if candidate==old: a=result; old_time+=took
					else: b=result; new_time+=took
				checks+=1
				if a!=b:
					failures+=1
					max_error=maxf(max_error,absf(a.risk-b.risk))
					if failures<4: print("MISMATCH ",a," ",b)
				if a.risk==1.0: saturated+=1
	print("NATIVE DELIVERY checks=",checks," saturated=",saturated," failures=",failures," max_risk_error=",max_error," script_us=",float(old_time)/checks," native_us=",float(new_time)/checks)
	game.free(); quit(0 if failures==0 else 1)
