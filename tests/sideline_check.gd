extends SceneTree
const P = preload("res://scripts/pitch_dimensions.gd")
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
	var boys=sidelines.actors.filter(func(a): return a.role=="ball_boy")
	var fourth=sidelines.actors.filter(func(a): return a.role=="fourth")
	var photographer=sidelines.actors.filter(func(a): return a.role=="photographer")
	check(subs.size()==14 and boys.size()==6 and fourth.size()==1 and photographer.size()==1,"Benches stay, and the touchline now has ball boys, a fourth official and a photographer")
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
		if actor.role in ["ball_boy","photographer","fourth"]:
			if absf(actor.position.x)<P.HALF_WIDTH+.2 and absf(actor.position.z)<50.2: bounds_ok=false
		elif actor.position.x<P.HALF_WIDTH+.4 or actor.position.x>P.HALF_WIDTH+6.6: bounds_ok=false
	check(bounds_ok,"All sideline personnel stay outside the playing field")
	advance(16)
	check(sub.seated>0.99 and sub.position.distance_to(sub.home)<0.02,"Substitutes return to their seats after the reaction")
	sidelines.react("save",0,Vector3.ZERO)
	advance(0.7)
	check(sub.mode=="encourage" and other.mode=="disappointed","Saves bring encouragement and disappointment to the correct teams")
	sidelines.reset()
	var restart_at := Vector3((P.HALF_WIDTH+0),0,-18)
	sidelines.update(0.8,restart_at,Vector3.ZERO,0,false,"TAÇ",restart_at)
	var walker=sidelines.collector_for("TAÇ",restart_at)
	check(walker!=null and walker.mode=="collect" and walker.position.distance_to(walker.home)>0.15,"A throw-in sends the nearest ball boy along the touchline")
	sidelines.reset()
	sidelines.game=game
	game.training=false
	game.state="restart"
	game.restart_type="TAÇ"
	game.restart_point=Vector3((P.HALF_WIDTH+0),0,0)
	for p in game.players:
		p.position=Vector3(0,0,0)
		p.visible=true
	game.ball.release_hold()
	game.ball.position=Vector3((P.HALF_WIDTH+1.2),0.23,0)
	game.ball.place(Vector3((P.HALF_WIDTH+1.2),0.23,0))
	game.ball.linear_velocity=Vector3.ZERO
	game.ball.pending_reset=false
	var liner=sidelines.actors.filter(func(a): return a.role=="ball_boy" and absf(a.home.z)<1.0 and a.home.x>0)[0]
	for i in range(120):
		sidelines.update(1.0/120.0,game.ball.position,Vector3.ZERO,0,false,"TAÇ",game.restart_point)
	check(game.ball.held_by==liner and liner.mode=="carry","A ball sitting on the touchline is picked up by the ball boy, not only walked toward")
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
