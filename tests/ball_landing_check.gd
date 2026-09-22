extends SceneTree
const Guide=preload("res://scripts/ball_landing_guide.gd")
const DT := 1.0/120.0
var game
var guide
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func setup() -> void:
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false); game.hud.set_process(false)
	guide.reset(); game.kick_lock=0; game.dribbler=-1; game.carrier=-1
	for p in game.players:
		p.collision_layer=0; p.desired=Vector3.ZERO; p.velocity=Vector3.ZERO
	game.ball.collision_mask=1
func flight(weather: int,curve: float) -> void:
	setup(); game.weather.select(weather,true)
	game.ball.place(Vector3(-8,2.8,0),Vector3(12,5,-6))
	await physics_frame; await physics_frame
	game.ball.spin=curve
	var expected: Dictionary=Guide.predict(game.ball.position,game.ball.linear_velocity,curve,game.weather)
	var previous: Vector3=game.ball.position
	var actual := Vector3.INF
	for frame in range(600):
		await physics_frame
		var point: Vector3=game.ball.position
		if point.y<.25 and previous.y>point.y:
			actual=point; break
		previous=point
	var error: float=game.flat_distance(actual,expected.get("landing",Vector3.INF))
	print("LANDING ERROR weather=%d curve=%.1f: %.3f m" % [weather,curve,error])
	check(error<.55,"The landing marker matches the physical ball in weather %d with spin %.1f" % [weather,curve])
	guide.update(game,.1)
	check(guide.prediction.is_empty(),"A grounded descending ball clears its old airborne marker")
	var next: Dictionary={}
	for frame in range(50):
		await physics_frame; guide.update(game,DT)
		if game.ball.linear_velocity.y>2 and guide.prediction.has("landing"):
			next=guide.prediction.duplicate(); break
	check(next.has("landing") and game.flat_distance(next.landing,expected.landing)>1,"The actual bounce creates a new marker for its next landing")

func aerial_fixture() -> void:
	setup(); game.weather.select(0,true)
	var p=game.players[9]
	p.position=Vector3(0,0,-32); p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO
	p.body_language.enabled=false; p.animate(1)
	for n in range(5): p.step(DT); await physics_frame
	game.ball.place(Vector3(-6,4,-32),Vector3(10,0,0))
	await physics_frame; await physics_frame
	guide.update(game,.1)

func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.ball.freeze=true
	game.hud.queue_redraw()
	await process_frame; await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/landing-"+label+".png")
	game.ball.freeze=false

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	guide=game.hud.landing_guide
	for weather in [0,2]:
		for curve in [0.0,2.3]: await flight(weather,curve)
	var outside: Dictionary=Guide.predict(Vector3(31,3,0),Vector3(14,2,0),0)
	check(not outside.has("landing"),"An out-of-play ball is not falsely marked at the field edge")
	await aerial_fixture()
	check(guide.prediction.has("landing"),"An airborne cross displays its predicted ground landing")
	var before: Transform3D=game.ball.transform
	var velocity: Vector3=game.ball.linear_velocity
	var pending: bool=game.ball.pending_kick
	for n in range(20): guide.update(game,.1)
	check(game.ball.transform==before and game.ball.linear_velocity==velocity and game.ball.pending_kick==pending and game.shots==[0,0],"Showing the guide cannot move the ball or trigger a shot")
	var p=game.players[9]
	await aerial_fixture()
	var first: Vector3=guide.prediction.landing
	game.ball.strike(Vector3(-8,6,0)); guide.update(game,DT)
	check(guide.prediction.has("landing") and game.flat_distance(guide.prediction.landing,first)>5,"A new touch immediately moves the marker without waiting for the refresh interval")
	game.ball.pending_kick=false
	game.ball.hold(p); guide.update(game,.1)
	check(guide.prediction.is_empty() and guide.opacity==0,"Catching or holding the ball removes the landing marker")
	game.ball.release_hold()
	for state in ["restart","set_piece","goal","replay","paused","halftime","menu"]:
		game.state=state; guide.update(game,.1)
		check(guide.prediction.is_empty(),"No stale airborne marker during "+state)
	game.reset_practice(); guide.update(game,.1)
	check(guide.prediction.is_empty(),"A new drill clears the previous trajectory before the ball reset completes")
	if "--visual" in OS.get_cmdline_user_args():
		await aerial_fixture()
		game.match_camera.select("pitch"); game.update_camera(0)
		await capture("day")
		game.stadium.light_rig.select(1); game.weather.select(2,true)
		await capture("night-rain")
		game.stadium.light_rig.select(0); game.weather.select(0,true)
		game.match_camera.select("broadcast"); game.update_camera(0)
		await capture("broadcast")
	print("BALL LANDING CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
