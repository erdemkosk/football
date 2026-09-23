extends "res://tests/attacking_combos_check.gd"
var visual := false
func render(label: String,close: bool=false) -> void:
	if not visual: return
	game.hud.visible=not close; game.hud.queue_redraw()
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/polish-"+label+".png")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/polish-layout.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.set_process(false)
	game.controller.set_process(false)
	setup(); game.frontend.hide(); game.match_menu.hide(); game.hud.bug_age=2
	for output in [Vector2i(1600,900),Vector2i(1720,720),Vector2i(1200,900),Vector2i(1440,900)]:
		root.size=output
		for i in range(5): await process_frame
		game.ui.refresh()
		var full: Rect2=game.ui.bounds()
		var tl: Vector2=Vector2(32,28)+game.ui.edge_offset(-1,-1)
		var br: Vector2=Vector2(1406,869)+game.ui.edge_offset(1,1)
		check(tl-full.position==Vector2(32,28) and full.end-br==Vector2(34,31),"HUD margins follow actual screen edges at "+str(output))
		game.state="goal"; game.hud.sync_navigation()
		check(game.hud.nav_buttons[0].position==Vector2(1177,74)+game.ui.edge_offset(1,-1),"Skip button hit area follows top-right drawing at "+str(output))
		game.state="playing"; game.hud.sync_navigation(); game.update_camera(1)
		await render("hud-%dx%d" % [output.x,output.y])
	setup(); var combo=game.controller.combos
	game.match_camera.select("pitch")
	button(JOY_BUTTON_B); combo.update(1.3)
	check(combo.cross_player==9 and combo.cross_power==1 and game.passes[0]==0,"Full cross power waits for release indefinitely")
	game.controller.stick=Vector2(0,1); combo.update(.25)
	check(combo.cross_direction.distance_to(Vector3.FORWARD)>.2,"Cross heading follows aim during the hold")
	var direction: Vector3=combo.cross_direction
	button(JOY_BUTTON_B,false)
	check(game.passes[0]==1 and combo.cross_player<0,"Release immediately queues exactly one cross")
	contact()
	var launch: Vector3=game.ball.kick_velocity*Vector3(1,0,1)
	check(launch.normalized().dot(direction)>.85,"Actual cross follows the chosen side after release")
	setup(); game.pass_assistance=0
	var short: Dictionary=game.cross_plan(Vector3.FORWARD,false,.05)
	var long: Dictionary=game.cross_plan(Vector3.FORWARD,false,1)
	check(game.flat_distance(game.ball.position,long.target)>game.flat_distance(game.ball.position,short.target)+15,"Cross power changes actual distance even near the byline")
	button(JOY_BUTTON_RIGHT_SHOULDER); button(JOY_BUTTON_B); combo.update(.6); button(JOY_BUTTON_B,false); button(JOY_BUTTON_RIGHT_SHOULDER,false); contact()
	check(game.passes[0]==1 and game.ball.kick_velocity.y<.2,"Sprint plus cross releases a driven delivery")
	setup(); button(JOY_BUTTON_B); game.ball.position+=Vector3(5,0,0); combo.update(.03); button(JOY_BUTTON_B,false)
	check(game.passes[0]==0,"Losing possession cancels a held cross without a remote kick")
	setup(); var p=game.players[9]; var defender=game.players[20]
	p.position=Vector3(0,0,-20); p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO
	defender.visible=true; defender.position=p.position+Vector3(.5,0,.9)
	game.ball.position=p.position+Vector3(0,.155,-.55); game.dribbler=9
	var before: Vector3=p.position
	for frame in range(45):
		p.body_language.observe(game,9); p.body_language.update(p,DT); p.animate(DT)
	check(p.body_language.shielding>.9 and p.right_arm.rotation.z>.7 and p.right_elbow.rotation.x>.7,"Rear pressure produces a bent forearm on the opponent's side")
	check(p.position==before and defender.velocity==Vector3.ZERO,"Shielding animation does not shove or teleport either player")
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=38
	game.camera.position=p.position+Vector3(4,2.6,-5); game.camera.look_at(p.position+Vector3.UP)
	await render("shield",true)
	defender.position=p.position+Vector3(0,0,-1)
	for frame in range(45): p.body_language.observe(game,9); p.body_language.update(p,DT); p.animate(DT)
	check(p.body_language.shielding<.01,"Forearm relaxes when pressure is no longer behind the player")
	setup(); p=game.players[9]; defender=game.players[20]
	defender.visible=true; defender.position=Vector3.ZERO; defender.reset_stamina()
	game.dribbler=-1; game.carrier=-1; game.ball.position=Vector3(0,.155,-6); game.ball.linear_velocity=Vector3(0,0,-8)
	p.position=Vector3(1,0,1); p.velocity=Vector3(0,0,-7)
	game.update_ai(DT)
	check(defender.sprinting and defender.desired.z<-.5,"Nearest AI contests a six-metre through-ball race at a sprint")
	defender.energy=.07; defender.exhausted=true; game.update_ai(DT)
	check(not defender.sprinting,"An exhausted defender respects the same sprint restriction")
	var target: Vector3=defender.position
	game.ai_attack.positioning.clear()
	var stayed := true
	for frame in range(120):
		var movement: Vector3=game.ai_attack.positional_movement(20,target+Vector3(sin(frame*.1)*.35,0,0),DT)
		stayed=stayed and movement.is_zero_approx()
	check(stayed,"Small formation shifts do not make every off-ball player turn and walk")
	check(game.ai_attack.positional_movement(20,target+Vector3(7,0,0),DT).x>.9,"A meaningful tactical move still starts promptly")
	setup(); p=game.players[9]; p.position=Vector3(0,0,-20)
	var styles: Array=[]
	for goal in range(5):
		game.last_kicker=9; game.goal_team=0; game.state="goal"; game.celebration.begin(0)
		styles.append(game.celebration.style)
		p.position=game.celebration.gathering; game.celebration.update(.02)
		check(p.celebration==game.celebration.style,"Scorer uses selected celebration "+game.celebration.style)
		p.body_language.clear_intent(); p.velocity=Vector3.ZERO
		for frame in range(50): p.motion_clock+=DT; p.animate(DT)
		game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=38
		game.camera.position=p.position+Vector3(3,2.5,-5); game.camera.look_at(p.position+Vector3.UP)
		await render("celebration-"+game.celebration.style,true)
	check(styles.size()==5 and styles.count("fist")==1 and styles.count("badge")==1 and styles.count("heart")==1 and styles.count("wings")==1 and styles.count("crowd")==1,"Repeated goals rotate through all five scorer celebrations")
	game.celebration.clear()
	check(game.players.all(func(q): return q.celebration==""),"Restart clears all celebration poses")
	print("MATCH POLISH CHECK: %d checks, %d failures" % [count,failures])
	game.free(); quit(1 if failures else 0)
