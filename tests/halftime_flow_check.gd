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

func start() -> void:
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.opponent_coach.next_sub=INF
	game.match_time=game.LENGTH*.5
	game.ball.place(Vector3(-20,game.ball.GROUND_HEIGHT,43))
	await physics_frame; await physics_frame
	game.interval.begin()

func tick() -> void:
	game._physics_process(DT)
	game.update_camera(DT)
	await physics_frame

func capture(label: String) -> void:
	if not visual: return
	game.hud.queue_redraw()
	for frame in range(3): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/football-halftime-"+label+".png")

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.playtest.enabled=false
	game.match_menu.config_path="/tmp/football-halftime-settings.cfg"
	await start()
	game.score=[2,1]; game.shots=[7,4]; game.players[4].yellow_cards=1
	var tired=game.players[9]; tired.energy=.3; tired.match_fatigue=.25
	var initial: Vector3=tired.position
	for frame in range(120): await tick()
	check(game.match_time==game.LENGTH*.5 and tired.position.distance_to(initial)>.5,"The half-time whistle stops the clock while players physically leave")
	check(tired.energy==.3 and tired.match_fatigue==.25,"Walking to the dressing room neither drains nor restores match fitness")
	game.state="paused"; game.before_pause="halftime"
	var age: float=game.interval.age; initial=tired.position
	for frame in range(30): await tick()
	check(game.interval.age==age and tired.position==initial,"Pause freezes the departure")
	game.state="halftime"
	game.interval.finish()
	check(game.half==2 and game.state in ["restart","set_piece"] and game.ceremony.phase=="","Early Continue skips directly to second-half kickoff, without an entrance or salute")
	check(game.set_pieces.recovery.phase in ["arrange","ready"] and game.set_pieces.formation_ready(),"Players are already in legal kickoff positions, with no retrieval or return walk")
	check(game.score==[2,1] and game.shots==[7,4] and game.players[4].yellow_cards==1 and is_equal_approx(tired.energy,.5) and tired.match_fatigue==.25,"The cut preserves score, cards and fatigue and grants recovery once")
	game.interval.finish()
	check(is_equal_approx(tired.energy,.5),"A repeated Continue cannot apply interval recovery twice")
	for frame in range(65):
		await tick()
		if game.state=="set_piece": break
	check(game.state=="set_piece" and game.restart_team==1 and game.ball.position.distance_to(Vector3(0,game.ball.GROUND_HEIGHT,0))<.08,"The actual ball settles on the centre spot and the opponent owns the kickoff")
	check(game.match_time==game.LENGTH*.5,"Second-half time stays frozen until the kickoff is played")
	await capture("kickoff")
	await start()
	game.players[5].dismissed=true; game.players[5].hide(); game.players[5].collision_layer=0
	var max_step := 0.0
	var previous: Array[Vector3]=[]
	for p in game.players: previous.append(p.position)
	for frame in range(10800):
		await tick()
		for i in range(game.players.size()):
			max_step=maxf(max_step,game.players[i].position.distance_to(previous[i]))
			previous[i]=game.players[i].position
		if frame==1100: await capture("leaving")
		if game.interval.phase=="room": break
		if frame%2400==0: print("HALFTIME EXIT age=",game.interval.age," remaining=",game.interval.leaving.values().filter(func(item): return item.stage!=2).size())
	if game.interval.phase!="room":
		for i in game.interval.leaving:
			if game.interval.leaving[i].stage!=2: print("WAITING ",i," ",game.players[i].position," stage=",game.interval.leaving[i].stage)
	check(game.interval.phase=="room" and max_step<.16,"Both teams reach the tunnel continuously, without teleporting on the pitch")
	var all_inside := true
	for p in game.players:
		if p.dismissed: continue
		all_inside=all_inside and p.position.x>=game.interval.TUNNEL_X-.5 and not p.rig.visible and p.collision_layer==0 and not p.marker.visible
	check(all_inside,"Players disappear only inside the tunnel and leave no selectable rings or collision bodies on the field")
	for frame in range(600): await tick()
	check(game.half==1 and game.state=="halftime" and game.match_time==game.LENGTH*.5,"The dressing-room interval waits for the player's Continue command")
	check(game.referees.actors.all(func(actor): return not actor.visible and actor.gesture==""),"The officials lower their signals and leave the pitch during the interval")
	await capture("room")
	var reserve: Dictionary=game.management.bench[0][1]
	var expected_shirt: int=reserve.shirt
	game.management.queue_sub(9,1)
	game.interval.finish()
	for frame in range(4800):
		await tick()
		if game.half==2: break
	check(game.half==2 and game.management.used[0]==1 and game.players[9].shirt_number==expected_shirt and game.management.transit.is_empty(),"A change requested in the dressing room completes before kickoff")
	var restored := true
	for p in game.players:
		if p.dismissed: restored=restored and not p.visible and p.collision_layer==0
		else: restored=restored and p.rig.visible and p.collision_layer==2 and p.collision_mask==3 and not p.prematch
	check(restored and game.referees.actors.all(func(actor): return actor.visible),"Continue restores players and officials but never revives a sent-off player")
	check(game.ceremony.phase=="" and game.set_pieces.recovery.phase in ["arrange","ready"],"A completed departure also resumes at kickoff without a ceremony")
	if not visual:
		await start()
		game.weather.select(2,true)
		for i in range(game.players.size()):
			game.players[i].position=Vector3((i%5-2)*14,0,(i/5)*23-46)
		game.players[0].position=Vector3(0,0,54)
		game.players[21].position=Vector3(0,0,-54)
		for frame in range(10800):
			await tick()
			if game.interval.phase=="room": break
		check(game.interval.phase=="room","Players scattered across a wet pitch and behind either goal still reach the dressing room")
		game.weather.select(0,true)
	await start()
	game.interval.leaving[9].stage=2; game.players[9].rig.hide(); game.players[9].collision_layer=0
	game.return_menu()
	check(game.players[9].rig.visible and game.half==1,"Leaving the interval for the menu restores hidden player models for the next match")
	print("HALFTIME FLOW: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
