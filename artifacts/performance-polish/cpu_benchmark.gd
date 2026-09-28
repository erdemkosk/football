extends SceneTree
var output: Array=[]
func _initialize() -> void: call_deferred("run")
func before(name: String):
	var script:=GDScript.new(); script.source_code=FileAccess.get_file_as_string("res://artifacts/performance-polish/baseline/"+name+".gd.txt")
	assert(script.reload()==OK); return script.new()
func report(label: String,old_times: Array[float],new_times: Array[float]) -> void:
	old_times.sort(); new_times.sort()
	var row:={"case":label,"before_us":old_times[old_times.size()/2],"after_us":new_times[new_times.size()/2]}
	row.reduction_percent=100*(1-row.after_us/row.before_us); output.append(row); print(JSON.stringify(row))
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	var p=game.players[9]
	var skin=p.shirt_skin
	var old_skin=before("shirt_skin"); old_skin.actor=p; old_skin.joints=skin.joints; old_skin.bind_inverse=skin.bind_inverse
	old_skin.poses.assign(skin.poses)
	old_skin.skeleton=RenderingServer.skeleton_create(); RenderingServer.skeleton_allocate_data(old_skin.skeleton,15)
	var old_motion=before("contextual_motion")
	for mode in ["paused-pose","moving-fixed-pose","running-pose-30hz","running-pose-120hz"]:
		var previous: Array[float]=[]; var next: Array[float]=[]
		for trial in range(8):
			var totals:=[0,0]
			for frame in range(480):
				if mode!="paused-pose": p.position=Vector3(sin(frame*.05)*32,0,cos(frame*.04)*48); p.rig.rotation.y=frame*.017
				if mode=="running-pose-120hz" or (mode=="running-pose-30hz" and frame%4==0):
					p.velocity=Vector3.FORWARD*8; p.run_phase+=.12; p.motion_clock+=1.0/120; p.animate(1.0/120)
				for variant in ([0,1] if trial%2==0 else [1,0]):
					var stamp:=Time.get_ticks_usec()
					if variant==0: old_skin.sync_pose()
					else: skin.sync_pose()
					totals[variant]+=Time.get_ticks_usec()-stamp
			previous.append(totals[0]/480.0); next.append(totals[1]/480.0)
		report(mode,previous,next)
	p.action_timer=0; p.kick_timer=0; p.receive_timer=0; p.celebration=""; p.prematch=false; p.saluting=false; p.set_piece_pose=""; p.shot_preparation=0
	game.ball.held_by=null; game.rules.tackles.clear(); game.support.movements.active.clear()
	for mode in ["context-carried-ball","context-free-ball"]:
		game.dribbler=9 if mode=="context-carried-ball" else -1
		var previous: Array[float]=[]; var next: Array[float]=[]
		for trial in range(8):
			for variant in ([0,1] if trial%2==0 else [1,0]):
				var motion=old_motion if variant==0 else p.contextual_motion
				motion.reset()
				var stamp:=Time.get_ticks_usec()
				for frame in range(4000): motion.observe(game,9,1.0/120); motion.apply(p); motion.resolve_block(game,9)
				var cost:=(Time.get_ticks_usec()-stamp)/4000.0
				if variant==0: previous.append(cost)
				else: next.append(cost)
		report(mode,previous,next)
	var file:=FileAccess.open("res://artifacts/performance-polish/paired-cpu.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t")); file.close()
	RenderingServer.free_rid(old_skin.skeleton); old_skin.skeleton=RID(); old_skin.free()
	game.free(); quit()
