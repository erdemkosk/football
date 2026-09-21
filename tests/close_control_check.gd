extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func setup() -> void:
	game.start_match(true)
	game.set_physics_process(false)
	game.set_process(false)
	for p in game.players:
		p.visible=false
		p.collision_layer=0
	var p=game.players[9]
	p.visible=true
	p.collision_layer=2
	p.position=Vector3.ZERO
	p.facing=Vector3.FORWARD
	game.ball.place(Vector3(0,0.23,-0.82))
	game.kick_lock=0
	await physics_frame
	await physics_frame
func drive(direction: Vector3,count: int,sprint: bool=false) -> float:
	var maximum := 0.0
	var p=game.players[9]
	for i in range(count):
		p.desired=direction
		p.sprinting=sprint
		p.step(1.0/120)
		game.update_contacts(1.0/120)
		await physics_frame
		maximum=maxf(maximum,game.flat_distance(p.position,game.ball.position))
	return maximum
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await setup()
	var run_gap: float=await drive(Vector3.FORWARD,360)
	print("RUN gap=",run_gap)
	check(run_gap<1.1 and game.dribbler==9,"Running keeps the ball at the player's feet")
	var turn_gap: float=await drive(Vector3.RIGHT,120)
	var reverse_gap: float=await drive(Vector3.LEFT,120)
	print("TURN gaps=",turn_gap," / ",reverse_gap)
	check(maxf(turn_gap,reverse_gap)<1.35 and game.dribbler==9,"Right-angle and full reversal retain close control")
	await setup()
	var sprint_gap: float=await drive(Vector3.FORWARD,480,true)
	print("SPRINT gap=",sprint_gap)
	check(sprint_gap<1.1 and game.dribbler==9,"Sprint follows the runner without repeated runaway touches")
	await drive(Vector3.ZERO,120)
	check(game.ball.linear_velocity.length()<0.2 and game.flat_distance(game.players[9].position,game.ball.position)<0.95,"Stopping settles the ball beside the foot")
	game.strike(9,Vector3(0,3,-25),0,false,"shot")
	check(game.dribbler==-1,"Shooting immediately releases close control")
	for i in range(35):
		game.kick_lock=maxf(0,game.kick_lock-1.0/120)
		await drive(Vector3.ZERO,1)
	check(game.flat_distance(game.players[9].position,game.ball.position)>5 and game.dribbler==-1,"A released shot travels freely without being pulled back")
	await setup()
	game.ball.place(Vector3(0,0.23,-0.7),Vector3(0,0,-25))
	await physics_frame
	await physics_frame
	await drive(Vector3.ZERO,1)
	check(game.dribbler==-1,"A hard incoming shot is not captured as a dribble")
	await setup()
	await drive(Vector3.FORWARD,30)
	game.players[9].receive_impact(Vector3.RIGHT,0.85)
	await drive(Vector3.ZERO,1)
	check(game.dribbler==-1,"A knocked-down player loses close control")
	await setup()
	await drive(Vector3.ZERO,30)
	game.players[17].visible=true
	game.players[17].position=game.ball.position+Vector3(0.15,0,0)
	game.players[17].touch_cooldown=0
	game.update_contacts(1.0/120)
	check(game.dribbler==17 and game.last_touch==1,"An opponent reaching the ball can still win possession")
	game.begin_restart("TAÇ",0,Vector3(32,0,0))
	check(game.dribbler==-1,"Whistles release close control for the physical restart")
	print("CLOSE CONTROL CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
