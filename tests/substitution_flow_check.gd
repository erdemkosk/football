extends SceneTree
const DT := 1.0/120
var game
var checks := 0
var failures := 0
var visual := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func capture(label: String,focus: Vector3) -> void:
	if not visual: return
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=46
	game.camera.position=focus+Vector3(-9,4,7); game.camera.look_at(focus+Vector3.UP)
	game.hud.hide()
	await process_frame; await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/substitution-flow-"+label+".png")

func tick() -> void:
	game.management.update_substitutions(DT)
	game.stadium.sidelines._physics_process(DT)
	game.broadcast.update(DT)
	game.stadium.sidelines.update(DT,game.ball.position,Vector3.ZERO,0,false)
	for p in game.players: p.flush_running_pose()
	await physics_frame

func scenario(team: int,keeper: bool,multiple: bool=false) -> void:
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.set_process_input(false)
	game.stadium.sidelines.set_physics_process(false)
	game.state="restart"; game.ball.freeze=true; game.match_time=40
	var slots: Array[int]=[team*11+(0 if keeper else 9)]
	if multiple: slots=[team*11+1,team*11+6,team*11+9]
	var records: Array=[]
	for n in range(slots.size()):
		var slot: int=slots[n]; var p=game.players[slot]
		p.position=Vector3(-27+n*18,0,-35+n*28 if team==0 else 35-n*28)
		p.energy=.17; p.kit_soil=.62; p.update_soil(.5); p.velocity=Vector3.ZERO
		var reserve: int=0 if keeper else n+1
		game.management.queue_sub(slot,reserve)
		records.append({"slot":slot,"old":p.identity(),"new":game.management.bench[team][reserve].duplicate(true),"out_pos":p.position,"max_step":0.0,"min_energy":p.energy,"seat_time":-1.0,"in_time":-1.0})
	game.management.prepare_substitutions()
	check(game.management.transit.size()==slots.size(),"All requested substitutions start (%d, keeper=%s, count=%d)" % [team,keeper,slots.size()])
	for item in records:
		var entry: Dictionary=game.stadium.sidelines.entries[item.slot]
		item.preview=weakref(entry.actor); item.in_pos=entry.actor.position; item.seat=entry.seat
		check(entry.actor.display_name==item.new.name and entry.actor.appearance_id==item.new.appearance_id and not entry.seat.visible,"Bench runner already has the incoming player's appearance")
	if visual: await capture("bench-start",records[0].seat.home)
	var handoff_picture := false
	for frame in range(3600):
		await tick()
		if visual and frame==120: await capture("running",game.stadium.sidelines.entries[records[0].slot].actor.position)
		var finished := true
		for item in records:
			var p=game.players[item.slot]
			var outgoing=p
			var incoming=item.preview.get_ref()
			if p.display_name==item.new.name:
				incoming=p
				for departure in game.stadium.sidelines.departures:
					if departure.player.display_name==item.old.name:
						outgoing=departure.player
						if departure.phase=="seated" and item.seat_time<0: item.seat_time=(frame+1)*DT
				if not game.management.transit.has(item.slot) and item.in_time<0: item.in_time=(frame+1)*DT
			else: item.min_energy=minf(item.min_energy,p.energy)
			if not is_instance_valid(incoming) or not outgoing.visible or not incoming.visible:
				check(false,"Both identities remain visible through the handoff"); return
			item.max_step=maxf(item.max_step,maxf(item.out_pos.distance_to(outgoing.position),item.in_pos.distance_to(incoming.position)))
			item.out_pos=outgoing.position; item.in_pos=incoming.position
			if visual and not handoff_picture and p.celebration=="handshake":
				await capture("handoff-"+str(team),p.position); handoff_picture=true
			finished=finished and item.seat_time>=0 and item.in_time>=0
		if finished: break
	for item in records:
		var p=game.players[item.slot]
		check(item.in_time>0 and item.in_time<22,"Incoming player runs back to position within 22 seconds: %.2f" % item.in_time)
		check(item.seat_time>0 and item.seat_time<17,"Outgoing player reaches and sits in the vacated seat: %.2f" % item.seat_time)
		if item.seat_time<0:
			for departure in game.stadium.sidelines.departures:
				print("DEPARTURE DIAGNOSTIC phase=",departure.phase," position=",departure.player.position," target=",departure.target," state=",game.state)
		check(item.max_step<.18,"Neither visible identity teleports at the touchline: max step %.4f" % item.max_step)
		check(p.display_name==item.new.name and p.shirt_number==item.new.shirt and p.attributes==item.new.attributes and p.appearance_id==item.new.appearance_id and game.management.used[team]==slots.size(),"Identity, attributes and substitution allowance transfer exactly once")
		check(item.min_energy>=.169 and game.match_time==40,"Stoppage movement preserves fatigue and the match clock")
		for departure in game.stadium.sidelines.departures:
			if departure.player.display_name!=item.old.name: continue
			var actor=departure.player
			check(actor.position.distance_to(item.seat.home)<.19 and actor.left_leg.rotation.x>.8 and actor.left_knee.rotation.x<-.8,"Departing body sits on its own bench seat with bent knees")
			check(actor.visible and actor.identity()==item.old and actor.kit_soil>=.62,"Seated player retains the outgoing face, shirt, body and dirt")
			check(not item.seat.visible and actor.collision_layer==0,"Vacated reserve model stays hidden and the seated player cannot touch the ball")
			if visual: await capture("seated-"+str(team)+("-keeper" if keeper else ""),actor.position)
	if not game.stadium.sidelines.departures.is_empty():
		var actor=game.stadium.sidelines.departures[0].player
		var transform: Transform3D=actor.global_transform
		game.state="paused"; game.stadium.sidelines._physics_process(1)
		check(actor.global_transform==transform,"Pause stops the departing player")
	game.start_match(false,false)
	await process_frame
	check(game.stadium.sidelines.entries.is_empty() and game.stadium.sidelines.departures.is_empty(),"A new match clears all substitution presentation actors")
	check(game.stadium.sidelines.actors.filter(func(a): return a.role=="substitute").all(func(a): return a.visible),"A new match restores every reserve to the bench")

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	if visual: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.controller.set_process(false)
	if visual: await scenario(0,false)
	else:
		for team in [0,1]:
			await scenario(team,false)
			await scenario(team,true)
		await scenario(0,false,true)
	print("SUBSTITUTION FLOW: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
