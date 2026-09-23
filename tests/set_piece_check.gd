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
func setup(kind: String,team: int,point: Vector3) -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	await frames(3)
	game.begin_restart(kind,team,point)
	for tick in range(7200):
		game._physics_process(1.0/120)
		await physics_frame
		if game.state=="set_piece": break
	if game.state!="set_piece":
		push_error("Recovery failed for "+kind+": "+game.set_pieces.recovery.phase)
		quit(1)
		return
	await frames(3)
func key(code: int,pressed: bool) -> void:
	var event=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func snapshot(name: String) -> void:
	if not visual: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/"+name+".png")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	await setup("SERBEST VURUŞ",0,Vector3(-8,0,-25))
	var sp=game.set_pieces
	check(sp.wall.size()==4,"Shooting-range free kick creates a four-player wall")
	var legal=true
	for p in game.players:
		if p.team==1 and game.flat_distance(p.position,game.restart_point)<9.15: legal=false
	check(legal,"Every opponent respects the 9.15 m free-kick distance")
	legal=true
	for index in sp.wall:
		for p in game.players:
			if p.team==0 and game.flat_distance(p.position,game.players[index].position)<1: legal=false
	check(legal,"Attackers stay at least one metre from the wall")
	check(game.players[11].position.x>0 and game.players[11].position.z< -48,"Keeper covers the open side behind the wall")
	var clock=game.match_time
	var resting_position: Vector3=game.ball.position
	for i in range(120):
		game._physics_process(1.0/120)
		await physics_frame
	check(game.state=="set_piece" and game.ball.position.distance_to(resting_position)<0.03 and game.match_time==clock,"Restart waits for user input with a physically settled ball")
	game.camera_focus=Vector3(0,0,-32)
	game.update_camera(1)
	await snapshot("free-kick-wall")
	if visual:
		game.set_process(false)
		game.hud.visible=false
		game.camera.size=23
		game.camera.position=Vector3(-16,7,-20)
		game.camera.look_at(Vector3(-4,1,-37))
		await snapshot("free-kick-close")
		game.hud.visible=true
		game.set_process(true)
		game.update_camera(1)
	key(KEY_D,true)
	for i in range(70): game._physics_process(1.0/120)
	check(sp.power>0.45 and game.ball.position.distance_to(resting_position)<0.03,"D charges the shot without taking the restart early")
	key(KEY_D,false)
	for i in range(45): game._physics_process(1.0/120)
	await frames(3)
	check(game.state=="playing" and game.ball.linear_velocity.length()>20,"Release completes the run-up and launches a physical shot")
	var peak=0.0
	game.set_physics_process(true)
	for i in range(30):
		await physics_frame
		for index in sp.wall: peak=maxf(peak,game.players[index].position.y)
	check(peak>0.15,"The wall jumps with physical bodies, not only mesh animation")
	await snapshot("free-kick-jump")
	await setup("SERBEST VURUŞ",1,Vector3(10,0,25))
	legal=true
	for p in game.players:
		if p.team==0 and game.flat_distance(p.position,game.restart_point)<9.15: legal=false
	check(legal and sp.wall.size()==4,"Away free-kick geometry mirrors the home team's rules")
	game.set_physics_process(true)
	await frames(200)
	check(game.state=="playing" and game.shots[1]>0,"AI also waits for the whistle and takes its free kick")
	await setup("SERBEST VURUŞ",0,Vector3(3,0,8))
	check(sp.wall.is_empty(),"Deep free kicks use a build-up formation without a pointless wall")
	await setup("PENALTI",0,Vector3(8,0,-42))
	check(game.restart_point==Vector3(0,0,-39),"Penalty ball is placed on the eleven-metre mark")
	check(absf(game.players[11].position.z+50)<0.02,"Penalty keeper starts on the goal line")
	legal=true
	for i in range(22):
		if i in [sp.taker,11]: continue
		var p=game.players[i]
		if p.position.z< -33.5 or game.flat_distance(p.position,game.restart_point)<9.15: legal=false
	check(legal,"Other penalty players remain behind the ball, outside the box and arc")
	key(KEY_S,true)
	key(KEY_S,false)
	check(sp.runup<0,"Penalty cannot be taken with the pass button")
	game.camera_focus=Vector3(0,0,-34)
	game.update_camera(1)
	await snapshot("penalty-formation")
	await setup("KORNER",0,Vector3((P.HALF_WIDTH-0.4),0,-49.6))
	var attackers=0
	legal=true
	for i in range(22):
		var p=game.players[i]
		if p.team==1 and game.flat_distance(p.position,game.restart_point)<9.15: legal=false
		if p.team==0 and i!=sp.taker and absf(p.position.x)<15 and p.position.z< -32: attackers+=1
	check(legal and attackers>=4,"Corner organizes the box and keeps defenders clear of the corner arc")
	await setup("KALE VURUŞU",0,Vector3(0,0,44))
	legal=true
	for p in game.players:
		if p.team==1 and absf(p.position.x)<20.16 and p.position.z>33.5: legal=false
	check(legal and game.restart_point.z>=44.5 and game.players[sp.taker].keeper,"Goal kick is inside the goal area with opponents outside the penalty area")
	await setup("TAÇ",0,Vector3((P.HALF_WIDTH+0),0,10))
	check(game.players[sp.taker].position.x>=P.HALF_WIDTH and game.players[sp.taker].set_piece_pose=="throw" and game.ball.position.y>2,"Thrower stands on the touchline with the ball held overhead")
	legal=true
	for p in game.players:
		if p.team==1 and game.flat_distance(p.position,game.restart_point)<2: legal=false
	check(legal,"Throw-in opponents respect the two-metre distance")
	key(KEY_S,true)
	for i in range(30): game._physics_process(1.0/120)
	key(KEY_S,false)
	for i in range(45): game._physics_process(1.0/120)
	await frames(3)
	check(game.state=="playing" and game.ball.linear_velocity.x< -2 and game.ball.position.y>1,"S delivers a real overhead throw into the field")
	check(game.controlled==game.team_control.predicted_receiver and game.controlled!=sp.taker,"Automatic selection follows the receiving player after the throw")
	await setup("SERBEST VURUŞ",0,Vector3(0,0,-24))
	key(KEY_D,true)
	key(KEY_ESCAPE,true)
	key(KEY_D,false)
	check(game.state=="paused" and sp.runup<0,"Pause cannot accidentally release a prepared restart")
	game.resume()
	check(game.state=="set_piece" and game.ball.active,"Resume returns to the protected set piece with physics active")
	await setup("SERBEST VURUŞ",0,Vector3(-8,0,-25))
	sp.button=KEY_D
	sp.power=0.2
	sp.preview()
	var low_lift: float=sp.pending_velocity.y
	sp.power=0.88
	sp.preview()
	check(sp.pending_velocity.y>low_lift+4,"Holding the free-kick button raises the shot")
	game.players[sp.taker].position=game.restart_point-sp.direction*.55
	sp.launch()
	var wall_height := 0.0
	for frame in range(230):
		game.kick_contact.prepare(1.0/120)
		game.players[sp.taker].step(1.0/120)
		game.kick_contact.resolve()
		await physics_frame
		for index in sp.wall: game.players[index].step(1.0/120)
		var progress: float=(game.ball.position-game.restart_point).dot(sp.direction)
		if wall_height==0 and progress>9.6: wall_height=game.ball.position.y
	check(wall_height>2.6,"A high free kick can physically clear the jumping wall")
	game.start_match(false,false)
	game.set_physics_process(false)
	game.begin_restart("SERBEST VURUŞ",1,Vector3(1.13,0,29.91))
	for i in sp.wall:
		game.players[i].position=sp.targets[i]
		game.players[i].velocity=Vector3.ZERO
	var wall_left: Vector3=sp.targets[sp.wall.front()]
	var wall_right: Vector3=sp.targets[sp.wall.back()]
	var wall_center := (wall_left+wall_right)*0.5
	var across := (wall_right-wall_left).normalized()
	var normal := Vector3(-across.z,0,across.x)
	game.players[19].position=wall_center-normal*2
	game.players[19].velocity=Vector3.ZERO
	var destination := wall_center+normal*2
	var detour := 0.0
	for frame in range(1200):
		sp.move_player(19,destination,1.0/120)
		await physics_frame
		detour=maxf(detour,absf((game.players[19].position-wall_center).dot(across)))
		if game.flat_distance(game.players[19].position,destination)<0.15: break
	check(game.flat_distance(game.players[19].position,destination)<0.15 and detour>wall_left.distance_to(wall_right)*0.5+0.8,"Attackers walk around the end of a solid wall without blocking restart preparation")
	game.free()
	print("SET PIECE CHECK: %d failures" % failures)
	quit(0 if failures==0 else 1)
