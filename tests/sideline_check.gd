extends SceneTree
var game
var sidelines
var failures := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func advance(seconds: float,ball_position: Vector3=Vector3.ZERO,playing: bool=false) -> void:
	for i in range(int(seconds*120)):
		sidelines.update(1.0/120.0,ball_position,Vector3(0,0,-20),0,playing)
func capture(label: String) -> void:
	if not visual: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/"+label+".png")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(true)
	game.set_physics_process(false)
	game.set_process(false)
	game.ball.freeze=true
	game.hud.visible=false
	sidelines=game.stadium.sidelines
	game.camera.position=Vector3(24,8,-4)
	game.camera.look_at(Vector3(36,1,-12))
	game.camera.size=13.5
	var subs=sidelines.actors.filter(func(a): return a.role=="substitute")
	var coach=sidelines.actors.filter(func(a): return a.role=="coach" and a.team==0)[0]
	var sub=subs[0]
	var other=subs[7]
	check(subs.size()==14 and sidelines.actors.size()==20,"Both teams have seven substitutes, coach, assistant and physio")
	check(sub.seated>0.99 and sub.legs[0].rotation.x>1.5 and sub.knees[0].rotation.x< -1.5,"Substitutes sit with articulated hips and knees")
	await capture("dugout-watching")
	var coach_before:Vector3=coach.position
	advance(2)
	check(coach.position.distance_to(coach_before)>0.3,"The coach paces inside the technical area")
	advance(1,Vector3(0,0,-45),true)
	check(coach.mode=="encourage" and coach.arms[1].rotation.x>1,"Dangerous play makes the coach point and substitutes rise")
	await capture("dugout-pressure")
	game.goal(0)
	advance(1.2)
	check(sub.mode=="celebrate" and other.mode=="disappointed","A goal produces different reactions on the two benches")
	check(sub.seated<0.1 and absf(sub.arms[0].rotation.z)>2,"Celebrating substitutes leave their seats and raise their arms")
	check(sub.position.x<sub.home.x-0.5,"Substitutes step forward from the bench to celebrate")
	check(sub.arms[0].rotation.distance_to(other.arms[0].rotation)>1,"Conceding substitutes use a distinct hands-to-head pose")
	await capture("dugout-celebration")
	game.camera.position=Vector3(24,8,20)
	game.camera.look_at(Vector3(36,1,12))
	await capture("dugout-disappointment")
	var bounds_ok:=true
	for actor in sidelines.actors:
		if actor.position.x<32.4 or actor.position.x>38.6: bounds_ok=false
	check(bounds_ok,"All sideline personnel stay outside the playing field")
	advance(16)
	check(sub.seated>0.99 and sub.position.distance_to(sub.home)<0.02,"Substitutes return to their seats after the reaction")
	sidelines.react("save",0,Vector3.ZERO)
	advance(0.7)
	check(sub.mode=="encourage" and other.mode=="disappointed","Saves bring encouragement and disappointment to the correct teams")
	sidelines.reset()
	game.ball.pending_reset=false
	game.ball.position=Vector3(6,1,-50.6)
	game.ball.linear_velocity=Vector3(0,0,-20)
	game.previous_ball=Vector3(6,1,-49.8)
	game.boundary_grace=0
	game.last_touch=0
	game.check_boundaries()
	advance(0.7)
	check(sidelines.event_kind=="miss" and sub.mode=="disappointed","A real missed shot triggers bench disappointment")
	var saved_clock:float=sidelines.clock
	game.state="paused"
	game._process(0.1)
	check(sidelines.clock==saved_clock,"Pausing the game also pauses sideline animation")
	game.start_match(true)
	check(sidelines.event_kind=="" and sub.seated==1,"A new match resets all bench reactions")
	print("SIDELINE CHECK: %d failures" % failures)
	game.free()
	await process_frame
	quit(0 if failures==0 else 1)
