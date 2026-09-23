extends "res://tests/ai_attack_check.gd"

func method(path: String,start: String,end: String) -> String:
	var source := FileAccess.get_file_as_string(path)
	return source.substr(source.find("func "+start),source.find("func "+end)-source.find("func "+start))

func reference_support():
	var source := method("res://scripts/support_play.gd","update(","return_option(")
	var begin := source.find("\t# The candidate search")
	var end := source.find("\tfor i in range(game.players.size()):",begin)
	source=source.left(begin)+source.substr(end)
	begin=source.find("\t\t\tvar clearance_squared")
	end=source.find("\t\t\tif value>best_value",begin)
	var original := "\t\t\tvar clearance := 8.0\n\t\t\tvar lane := 5.0\n\t\t\tfor q in game.players:\n\t\t\t\tif not q.visible or q.team==team: continue\n\t\t\t\tclearance=minf(clearance,game.flat_distance(q.position,candidate))\n\t\t\t\tvar near := Geometry3D.get_closest_point_to_segment(q.position*Vector3(1,0,1),ball*Vector3(1,0,1),candidate)\n\t\t\t\tlane=minf(lane,game.flat_distance(near,q.position))\n\t\t\tvar value: float=clearance+lane*lerpf(.35,.9,awareness)-offset.length()*.5\n"
	source=source.left(begin)+original+source.substr(end)
	var script := GDScript.new()
	script.source_code="extends \"res://scripts/support_play.gd\"\n"+source
	assert(script.reload()==OK)
	return script.new()

func reference_attack():
	var source := method("res://scripts/ai_attack.gd","carry_target(","receiving_target(")
	var begin := source.find("\t# All candidate directions")
	var end := source.find("\tvar best :=",begin)
	source=source.left(begin)+source.substr(end)
	source=source.replace("sampled_clearance(at,far_positions)","future_clearance(at,p.team,.55)")
	source=source.replace("sampled_clearance(p.position+aim*2.2,near_positions)","future_clearance(p.position+aim*2.2,p.team,.26)")
	source=source.replace("sampled_clearance(p.position+aim*2.2,turn_positions)","future_clearance(p.position+aim*2.2,p.team,.3)")
	var script := GDScript.new()
	script.source_code="extends \"res://scripts/ai_attack.gd\"\n"+source
	assert(script.reload()==OK)
	return script.new()

func reference_shape():
	var source := FileAccess.get_file_as_string("res://scripts/attack_shape.gd")
	source=source.substr(source.find("func plan("))
	source=source.replace("\tvar offside_limit: float=maxf(0,game.rules.offside_line(team)-.9)\n","")
	source=source.replace("\t\tvar space_scores: Dictionary={}\n","")
	source=source.replace("clampf(at.z*forward,-42,44),offside_limit)","clampf(at.z*forward,-42,44),maxf(0,game.rules.offside_line(team)-.9))")
	var begin := source.find("\t\t\t\t# Lane safety")
	var end := source.find("\t\t\t\tvar group:",begin)
	assert(begin>=0 and end>begin)
	var original := "\t\t\t\tvar lane := 5.0\n\t\t\t\tfor opponent in game.players:\n\t\t\t\t\tif not opponent.visible or opponent.dismissed or opponent.team==team: continue\n\t\t\t\t\tvar near := Geometry3D.get_closest_point_to_segment(opponent.position*Vector3(1,0,1),ball,at)\n\t\t\t\t\tlane=minf(lane,game.flat_distance(near,opponent.position))\n\t\t\t\tvar score: float=minf(8,game.ai_attack.clearance(at,team))*1.1+lane*1.5-travel*.42-offset.length()*.25\n"
	source=source.left(begin)+original+source.substr(end)
	var script := GDScript.new()
	script.source_code="extends \"res://scripts/attack_shape.gd\"\n"+source
	assert(script.reload()==OK)
	return script.new()

func run() -> void:
	var motion=preload("res://scripts/ball_motion.gd")
	var source := method("res://scripts/ball_motion.gd","sample_flight(","lob_velocity(")
	source=source.replace("func sample_flight(","static func sample_flight(")
	var begin := source.find("\t# Cover, receiving runs")
	var end := source.find("\tvar points :=",begin)
	source=source.left(begin)+source.substr(end)
	source=source.replace("\tif flight_samples.size()>=8: flight_samples.clear()\n","").replace("\tflight_samples[key]=points.duplicate()\n","")
	# method() slices at 'func', so its trailing static keyword belongs to the next method.
	source=source.strip_edges().trim_suffix("static").strip_edges()+"\n"
	var original_motion := GDScript.new()
	original_motion.source_code="extends \"res://scripts/ball_motion.gd\"\n"+source
	assert(original_motion.reload()==OK)
	var flights_equal := true
	for origin in [Vector3(2,.2,3),Vector3(-15,2.1,26)]:
		for velocity in [Vector3(4,6,-12),Vector3(-17,-3,8),Vector3(0,0,0)]:
			for spin in [-3.0,0.0,2.4]:
				var expected: PackedVector3Array=original_motion.sample_flight(origin,velocity,spin,1.4,28)
				var actual: PackedVector3Array=motion.sample_flight(origin,velocity,spin,1.4,28)
				flights_equal=flights_equal and expected==actual
				actual[0]=Vector3.INF
				flights_equal=flights_equal and motion.sample_flight(origin,velocity,spin,1.4,28)==expected
	check(flights_equal,"Cached flights exactly preserve integration and isolate caller mutations")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	setup(); game.menu_match.running=true
	var old_support=reference_support(); old_support.game=game
	old_support.shape=reference_shape()
	var old_attack=reference_attack(); old_attack.game=game
	var random := RandomNumberGenerator.new(); random.seed=92524
	var support_equal := true; var carry_equal := true
	var support_old_us := 0; var support_new_us := 0
	var carry_old_us := 0; var carry_new_us := 0
	for trial in range(80):
		for i in range(22):
			player(i,Vector3(random.randf_range(-30,30),0,random.randf_range(-45,45)),Vector3(random.randf_range(-9,9),0,random.randf_range(-9,9)))
			game.players[i].dismissed=false
		possession(20)
		# Include dense pressure, not only an empty pitch.
		if trial%2==0: player(2,game.players[20].position+Vector3(.9,0,.2),Vector3(4,0,2))
		old_support.reset(); game.support.reset()
		var started := Time.get_ticks_usec(); old_support.update(DT); support_old_us+=Time.get_ticks_usec()-started
		started=Time.get_ticks_usec(); game.support.update(DT); support_new_us+=Time.get_ticks_usec()-started
		support_equal=support_equal and old_support.roles==game.support.roles and old_support.targets.size()==game.support.targets.size()
		for key in old_support.targets:
			support_equal=support_equal and game.support.targets.has(key) and old_support.targets[key].distance_to(game.support.targets.get(key,Vector3.INF))<.0001
		old_attack.carry_cache.clear(); game.ai_attack.carry_cache.clear()
		started=Time.get_ticks_usec(); var old_target: Vector3=old_attack.carry_target(20); carry_old_us+=Time.get_ticks_usec()-started
		started=Time.get_ticks_usec(); var new_target: Vector3=game.ai_attack.carry_target(20); carry_new_us+=Time.get_ticks_usec()-started
		carry_equal=carry_equal and old_target.distance_to(new_target)<.0001
	check(support_equal,"80 randomized support layouts preserve destinations and assignments")
	check(carry_equal,"80 randomized carrying/pressure layouts preserve chosen direction")
	print("SUPPORT old_us=",support_old_us/80.0," new_us=",support_new_us/80.0)
	print("CARRY old_us=",carry_old_us/80.0," new_us=",carry_new_us/80.0)
	setup(); var p=game.players[18]
	p.position=Vector3(20,0,0); p.desired=Vector3.FORWARD
	p.defer_running_pose=true; p.pose="run"; p.dribble_motion.reset()
	p.step(DT); p.step(DT)
	check(p.pending_pose_delta>DT,"Off-ball running accumulates unseen pose work")
	var pending: float=p.pending_pose_delta
	p.flush_running_pose()
	check(p.pending_pose_delta==0 and pending<.03,"Rendering consumes the accumulated time without dropping animation time")
	p.step(DT); game.replay.snapshot()
	check(p.pending_pose_delta==0,"Replay snapshots flush pending poses before recording joints")
	p.kick_timer=.2; p.step(DT)
	check(p.pending_pose_delta==0,"A kick bypasses deferred rendering for physical contact")
	p.kick_timer=0; p.protecting=true; p.step(DT)
	check(p.pending_pose_delta==0,"Shielding and physical contests retain synchronous poses")
	p.protecting=false; p.step(DT); p.animate(1.0)
	check(p.pending_pose_delta==0,"Reset/identity poses discard pending old-match time")
	check(Engine.physics_ticks_per_second==120 and root.scaling_3d_scale==1.0,"Physics frequency and render resolution remain unchanged")
	print("FPS REGRESSION: ",checks," checks, ",failures," failures")
	game.free(); quit(1 if failures>0 else 0)
