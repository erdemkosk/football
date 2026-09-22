extends SceneTree
var game
var failures := 0
var checks := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func tick() -> void:
	game._physics_process(1.0/120); game._process(1.0/120)
	await physics_frame
func setup() -> void:
	game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	game.replay.enabled=false
func capture(label: String) -> void:
	if not visual: return
	game.hud.queue_redraw()
	await process_frame; await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/realism-"+label+".png")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	setup()
	game.half=2; game.match_time=game.LENGTH*.9; game.score=[0,2]
	game.management.apply_formation()
	for p in game.players: p.position=p.home
	game.players[9].position=Vector3(1,0,44); game.players[9].energy=.32
	game.ball.place(Vector3(1,.3,51)); await physics_frame; await physics_frame
	game.last_kicker=9
	game.replay.enabled=true
	for n in range(25): game.replay.capture(.05)
	var ball_start: Vector3=game.ball.position
	game.goal(0)
	check(game.celebration.urgent and not game.celebration.late_winner and game.score==[1,2],"A late goal while still behind switches to the hurry-to-kickoff sequence")
	check(game.ball.position==ball_start and not game.ball.freeze and game.replay.goal_tail==0,"The urgent sequence preserves the live ball and avoids a goal replay delay")
	var phases: Array[String]=[]
	var max_player_step := 0.0; var max_ball_step := 0.0; var minimum_energy := .32
	var held := false; var pictured := false
	var goal_age := 0.0
	for frame in range(3500):
		if game.state!="goal": break
		if game.celebration.collection not in phases: phases.append(game.celebration.collection)
		var previous: Vector3=game.players[9].position
		var ball_previous: Vector3=game.ball.position
		held=held or game.ball.held_by==game.players[9]
		minimum_energy=minf(minimum_energy,game.players[9].energy)
		goal_age=game.celebration.age
		await tick()
		max_player_step=maxf(max_player_step,previous.distance_to(game.players[9].position))
		max_ball_step=maxf(max_ball_step,ball_previous.distance_to(game.ball.position))
		if held and not pictured and game.players[9].position.z<40:
			await capture("urgent-return"); pictured=true
	check("pickup" in phases and "carry" in phases and "place" in phases and held,"The scorer physically picks up, carries and puts down the same goal ball")
	check(game.state=="restart" and game.restart_type=="SANTRA" and game.restart_team==1 and goal_age<23,"The trailing scorer returns directly to the opponent's centre kickoff")
	check(game.flat_distance(game.ball.position,Vector3.ZERO)<.6 and game.ball.held_by==null,"The ball reaches centre through the real carry sequence")
	check(game.flat_distance(game.players[9].position,Vector3.ZERO)<.8,"The scorer brakes at centre before lowering the ball")
	check(max_player_step<.3 and max_ball_step<.65,"The urgent return contains no player or ball teleport")
	check(minimum_energy>=.319 and game.match_time==game.LENGTH*.9,"The stopped-clock return does not spend the scorer's stamina")
	if "carry" not in phases: print("URGENT DIAGNOSTIC phases=%s position=%s ball=%s age=%.2f" % [phases,game.players[9].position,game.ball.position,goal_age])
	setup(); game.half=2; game.match_time=game.LENGTH*.9; game.score=[2,0]
	game.management.apply_formation()
	for actor in game.players: actor.position=actor.home
	game.players[20].position=Vector3(-1,0,-44); game.ball.place(Vector3(-1,.3,-51))
	await physics_frame; await physics_frame
	game.last_kicker=20; game.goal(1)
	var away_carried := false
	for n in range(3000):
		if game.state!="goal": break
		await tick(); away_carried=away_carried or game.ball.held_by==game.players[20]
	check(away_carried and game.state=="restart" and game.restart_team==0 and game.flat_distance(game.ball.position,Vector3.ZERO)<.6,"The same physical urgent return works for the away team at the opposite goal")
	setup(); game.half=2; game.match_time=game.LENGTH*.95; game.score=[1,1]; game.last_kicker=9
	game.goal(0)
	check(game.celebration.late_winner and not game.celebration.urgent and game.stadium.sidelines.event_duration>=20,"A late winner produces the extended team and bench celebration")
	game.celebration.skip()
	check(game.state in ["restart","set_piece"] and game.restart_type=="SANTRA" and game.restart_team==1 and game.celebration.group.is_empty(),"The larger celebration is immediately skipped into centre-kickoff preparation")
	setup(); game.last_kicker=9; game.goal(0)
	check(not game.celebration.urgent and not game.celebration.late_winner,"An early goal keeps the ordinary celebration")
	setup()
	game.players[9].position=Vector3(28,0,8); game.players[9].energy=.22
	var old: String=game.players[9].display_name
	var incoming: Dictionary=game.management.bench[0][2].duplicate(true)
	game.management.queue_sub(9,2)
	game.ball.place(Vector3(32.5,.23,10)); await physics_frame
	game.begin_restart("TAÇ",0,Vector3(32,0,10))
	var seen_handshake := false; var seen_insert := false; var seen_hidden := false
	var min_outgoing_energy := .22; var maximum_step := 0.0; var hand_gap := INF
	var actor=game.stadium.sidelines.entries[9].actor
	var started: Vector3=actor.position
	var clock_start: float=game.match_time
	for frame in range(2600):
		var previous: Vector3=game.players[9].position
		await tick()
		maximum_step=maxf(maximum_step,previous.distance_to(game.players[9].position))
		if game.players[9].display_name==old: min_outgoing_energy=minf(min_outgoing_energy,game.players[9].energy)
		seen_handshake=seen_handshake or game.players[9].celebration=="handshake"
		if game.players[9].celebration=="handshake":
			hand_gap=minf(hand_gap,game.players[9].right_hand.global_position.distance_to(actor.elbows[1].to_global(Vector3(0,-.285,0))))
		if game.broadcast.active and game.broadcast.kind=="substitution" and not seen_insert:
			seen_insert=true
			for n in range(25): await tick()
			await capture("substitution")
		seen_hidden=seen_hidden or not actor.visible
		if game.management.transit.is_empty(): break
	check(actor.position.distance_to(started)>5 and seen_handshake,"The incoming substitute walks from the bench and greets the outgoing player")
	check(hand_gap<.4,"The two greeting hands approach each other instead of gesturing across an empty gap")
	check(seen_insert and seen_hidden,"The substitution receives a brief camera insert and does not leave a duplicate reserve on the bench")
	check(game.players[9].display_name==incoming.name and game.players[9].attributes==incoming.attributes and game.management.used[0]==1,"One completed handoff transfers the incoming identity and attributes exactly once")
	check(game.management.transit.is_empty() and maximum_step<.3,"The replacement physically returns to position before the restart continues")
	check(min_outgoing_energy>=.219 and game.match_time==clock_start,"Substitution running and camera coverage do not drain stamina or advance the stopped clock")
	setup()
	var p=game.players[9]
	p.position=Vector3(0,1.4,0); p.velocity=Vector3(0,-3,0); p.header_airborne=true
	var landed := false; var knee_bend := false
	for frame in range(100):
		p.desired=Vector3.ZERO; p.step(1.0/120); await physics_frame
		if p.landing_age<.32: landed=true; knee_bend=knee_bend or p.landing_strength>.1
	check(landed and knee_bend and not p.header_airborne,"A real aerial landing activates brief knee and body absorption")
	if visual:
		setup()
		game.frontend.open_tactics(true)
		game.frontend.selected_slot=9; game.frontend.preview_reserve=5; game.frontend.build()
		for frame in range(70): await process_frame
		await capture("attributes")
		game.frontend.visible=false
		game.state="restart"; game.half=2; game.match_time=game.LENGTH*.94; game.score=[0,1]
		game.broadcast.restart(); game.broadcast.update(.1)
		for n in range(25): game.stadium.sidelines.update(1.0/120,game.ball.position,Vector3.ZERO,0,false)
		game.broadcast.camera(); await capture("coach")
	print("REALISM FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
