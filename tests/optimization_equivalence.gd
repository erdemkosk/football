extends "res://tests/performance_benchmark.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	prepare()
	var old=load("res://tests/optimization_decisions_before.gd").new(); old.game=game
	var current=load("res://scripts/attack_decisions.gd").new(); current.game=game
	var failures := 0
	var checked := 0
	var options: Array[Dictionary]=[]
	for scenario in range(24):
		game.players[20].position=Vector3(float(scenario%6)*4-10,0,float(scenario/6)*12-18)
		game.ball.position=game.players[20].position+Vector3(0,.23,.5)
		game.weather.select(scenario%3,true)
		game.management.difficulty=scenario%3
		options=[{"kind":"carry"},{"kind":"shield"},{"kind":"invite"}]
		for kind in ["push","feint","roll","stop_go","knock_around"]:
			options.append({"kind":kind,"exit":game.players[20].position+Vector3(2,0,4)})
		for receiver in [15,17,19]:
			var p=game.players[receiver]
			options.append({"kind":"pass","receiver":receiver,"route":game.Passing.plan(game.ball.position,p.position,p.velocity,false,game.weather)})
		options.append({"kind":"power","velocity":Vector3(0,1,20)})
		var initial_cache: Dictionary=game.ai_attack.carry_cache.duplicate(true)
		var a: Dictionary=old.select(20,options)
		var old_cache: Dictionary=game.ai_attack.carry_cache.duplicate(true)
		game.ai_attack.carry_cache=initial_cache.duplicate(true)
		var b: Dictionary=current.select(20,options)
		checked+=1
		if a!=b or old.rankings[20]!=current.rankings[20] or old_cache!=game.ai_attack.carry_cache: failures+=1
	var old_times: Array[float]=[]
	var new_times: Array[float]=[]
	for trial in range(8):
		for candidate in ([old,current] if trial%2==0 else [current,old]):
			var start := Time.get_ticks_usec()
			for iteration in range(100): candidate.select(20,options)
			var elapsed := float(Time.get_ticks_usec()-start)/100
			if candidate==old: old_times.append(elapsed)
			else: new_times.append(elapsed)
	old_times.sort(); new_times.sort()
	print("EQUIVALENCE: ",checked," scenarios, ",failures," failures; ranked options and scores compared exactly")
	print("PAIRED DECISION: before_us=",old_times[4]," after_us=",new_times[4])
	game.free(); quit(0 if failures==0 else 1)
