extends SceneTree
const P = preload("res://scripts/pitch_dimensions.gd")
var game
var failures := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func capture(name: String) -> void:
	if not visual: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/"+name+".png")
func scenario(kind: String,team: int,point: Vector3,ball_pos: Vector3,velocity: Vector3,close_player: int,close_pos: Vector3) -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	game.players[close_player].position=close_pos
	game.ball.place(ball_pos,velocity)
	await frames(3)
	var before: Vector3=game.ball.position
	var momentum: Vector3=game.ball.linear_velocity
	var bodies: Array[Vector3]=[]
	for p in game.players: bodies.append(p.position)
	game.begin_restart(kind,team,point)
	check(game.ball.active and not game.ball.pending_reset and game.ball.position==before and game.ball.linear_velocity==momentum,kind+": whistle preserves the ball position and momentum")
	var unchanged=true
	for i in range(22):
		if bodies[i]!=game.players[i].position: unchanged=false
	check(unchanged,kind+": players are not teleported into formation")
	var expected=-1
	var closest=INF
	for i in range(22):
		var p=game.players[i]
		if not p.visible or p.dismissed: continue
		var distance=game.flat_distance(p.position,before)
		if distance<closest: expected=i; closest=distance
	check(game.set_pieces.recovery.collector==expected,kind+": nearest player from either team goes to the actual ball")
	var phases: Array[String]=[]
	var max_step=0.0
	var previous: Vector3=before
	var moving_before_pickup=false
	var acquired_nearby=true
	var walk_distance=0.0
	var old_player: Vector3=game.players[expected].position
	var ready=false
	var last_phase=""
	for frame in range(6000):
		var recovery=game.set_pieces.recovery
		var held_before=game.ball.held_by!=null
		var ball_before: Vector3=game.ball.position
		var hand_before: Vector3=game.players[recovery.worker].hand_center()
		game._physics_process(1.0/120)
		if not held_before and game.ball.held_by!=null:
			acquired_nearby=acquired_nearby and hand_before.distance_to(ball_before)<(0.9 if recovery.phase=="carry" else 0.65)
		await physics_frame
		max_step=maxf(max_step,previous.distance_to(game.ball.position))
		previous=game.ball.position
		walk_distance+=old_player.distance_to(game.players[expected].position)
		old_player=game.players[expected].position
		if recovery.phase in ["watch","retrieve"] and before.distance_to(game.ball.position)>0.5: moving_before_pickup=true
		if not recovery.phase in phases: phases.append(recovery.phase)
		if visual and kind=="TAÇ" and recovery.phase!=last_phase and recovery.phase in ["retrieve","pickup","carry","raise"]:
			await capture("recovery-"+recovery.phase)
		last_phase=recovery.phase
		if game.state=="set_piece": ready=true; break
		if frame%1200==0: print("%s %.1fs: %s ball=%s player=%s" % [kind,frame/120.0,recovery.phase,game.ball.position,old_player])
	check(ready,kind+": collection and preparation finish without a timeout teleport")
	check(moving_before_pickup,kind+": ball continues to fall, bounce or roll before collection")
	check(acquired_nearby and "lift" in phases and "carry" in phases,kind+": pickup occurs only within hand reach before carrying")
	check(max_step<0.6,kind+": ball stays continuous through pickup, carry and placement")
	check(walk_distance>2,kind+": taker physically runs to retrieve and return the ball")
	if kind=="TAÇ": check(game.ball.held_by!=null and game.ball.position.y>1.7,"Throw-in finishes with the same ball held overhead")
	else: check(game.ball.held_by==null and game.flat_distance(game.ball.position,game.restart_point)<0.3 and game.ball.position.y<0.3,"Ground restart finishes only after the placed ball settles")
	check(game.set_pieces.formation_ready(),kind+": legal restart distances are still enforced")
	if ready:
		var at: Vector3=game.ball.position
		game.set_pieces.button=KEY_A if kind=="KORNER" else KEY_S
		game.set_pieces.power=0.35
		game.set_pieces.commit()
		for frame in range(45):
			game._physics_process(1.0/120)
			await physics_frame
		check(game.state=="playing" and game.ball.held_by==null and game.ball.position.distance_to(at)>0.5,kind+": release puts the retrieved ball back into play")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	await scenario("TAÇ",0,Vector3((P.HALF_WIDTH+0),0,10),Vector3((P.HALF_WIDTH+0.5),3,10),Vector3(6,2,3),8,Vector3(28,0,8))
	await scenario("KORNER",0,Vector3((P.HALF_WIDTH-0.4),0,-49.6),Vector3(25,3,-51),Vector3(6,2,-6),8,Vector3(23,0,-43))
	await scenario("KALE VURUŞU",1,Vector3(0,0,-45),Vector3(0,1,-53.2),Vector3(1,1,-2),11,Vector3(0,0,-46))
	await scenario("TAÇ",1,Vector3(-(P.HALF_WIDTH+0),0,-12),Vector3(-(P.HALF_WIDTH+0.5),4,-12),Vector3(-7,1,-2),18,Vector3(-27,0,-9))
	await scenario("KALE VURUŞU",1,Vector3(0,0,-45),Vector3(1.27,0.23,-50.64),Vector3(0,0,-3),11,Vector3(6,0,-52))
	game.free()
	print("RESTART RECOVERY CHECK: %d failures" % failures)
	quit(0 if failures==0 else 1)
