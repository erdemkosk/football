extends SceneTree
const Guide = preload("res://scripts/shot_guide.gd")
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func key(code: int,down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode=code; e.physical_keycode=code; e.pressed=down
	Input.parse_input_event(e); Input.flush_buffered_events()
func setup() -> void:
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false)
	game.match_menu.config_path="/tmp/sefc-finesse-check.cfg"
	game.controller.held.clear(); game.controller.stick=Vector2.ZERO
	game.controller.using_gamepad=false
	game.aiming_mouse=false
	for p in game.players: p.collision_layer=0; p.visible=false
	game.players[9].position=Vector3(8,0,-27.3)
	game.players[9].facing=Vector3.FORWARD
	game.ball.place(Vector3(8,game.ball.GROUND_HEIGHT,-28))
	game.ball.freeze=false; game.ball.active=true
	game.last_direction=Vector3(-0.23,0,-1).normalized()
	game.kick_lock=0
	for frame in range(3): await physics_frame
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw()
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/sefc-"+label+".png")
func release_restart(restart) -> void:
	var taker=game.players[restart.taker]
	game.ball.release_hold(); game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false
	game.ball.position=game.restart_point+Vector3.UP*game.ball.GROUND_HEIGHT; game.ball.linear_velocity=Vector3.ZERO
	taker.visible=true; taker.action_timer=0; taker.set_piece_pose=""
	taker.position=game.restart_point-restart.direction*.55
	taker.velocity=Vector3.ZERO; taker.desired=Vector3.ZERO
	taker.facing=restart.direction; taker.rig.rotation.y=atan2(-restart.direction.x,-restart.direction.z)
	taker.animate(1)
	restart.launch()
	for frame in range(20):
		if game.kick_contact.pending.is_empty(): break
		game.kick_contact.prepare(1.0/120); taker.step(1.0/120); game.kick_contact.resolve()
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	await setup()
	game.begin_shot()
	var spin: float=game.finesse_curve(game.shot_direction)
	var stable := true
	for direction in [Vector3.FORWARD,Vector3(-0.5,0,-1).normalized(),Vector3(0.5,0,-1).normalized(),Vector3.BACK]:
		stable=stable and game.finesse_curve(direction)==spin
	game.ball.position.x=-0.05
	stable=stable and game.finesse_curve(Vector3.FORWARD)==spin
	check(stable and absf(spin)>1.4,"A held shot keeps its curl direction while aiming or crossing the centre")
	for weather in [0,2]:
		for power in [0.25,0.65,0.95]:
			await setup()
			game.weather.select(weather,true)
			var origin: Vector3=game.ball.position
			var launch: Vector3=game.shot_velocity(game.last_direction,power,true)
			spin=game.choose_finesse_curve(game.last_direction)
			var route := Guide.predict(origin,launch,spin,-50,game.weather)
			var first_flight := Guide.predict(origin,launch,spin,-50,game.weather,Vector3.INF,true)
			# Rain now absorbs enough pace for the weakest shot to stop short.
			var reaches_goal: bool=not (weather==2 and power==0.25)
			check(route.goal_plane==reaches_goal and route.points.size()>15 and Array(route.points).all(func(p): return p.y>=game.ball.RADIUS-0.001),"The preview distinguishes a goal-line finish from a shot stopped by wet turf (weather %d / power %.2f)" % [weather,power])
			game.ball.strike(launch,spin)
			var previous := origin
			var actual := Vector3.INF
			var first_landing := Vector3.INF
			var airborne := false
			var crossed := false
			for frame in range(480):
				await physics_frame
				var point: Vector3=game.ball.position
				if point.y>game.ball.GROUND_HEIGHT+.1: airborne=true
				if airborne and not first_landing.is_finite() and previous.y>point.y and point.y<=game.ball.GROUND_HEIGHT+.02:
					first_landing=point
				if point.z<=-50:
					actual=previous.lerp(point,(-50-previous.z)/(point.z-previous.z))
					crossed=true
					break
				if frame>2 and game.ball.linear_velocity.length()<.5 and point.y<game.ball.RADIUS+.1:
					actual=point
					break
				previous=point
			check(actual.is_finite() and crossed==reaches_goal,"The physical shot reaches the goal or stops as expected (weather %d / power %.2f)" % [weather,power])
			var error: float=actual.distance_to(route.target)
			print("Finesse target: expected=",route.target," actual=",actual," error=",error)
			check(error<0.65,"Visible target agrees with the unobstructed physical shot (weather %d / power %.2f)" % [weather,power])
			var first_end: Vector3=actual if first_flight.goal_plane else first_landing
			print("First-flight target: expected=",first_flight.target," actual=",first_end," launch=",launch)
			check(first_end.is_finite() and first_end.distance_to(first_flight.target)<.65,"The restricted guide ends at the physical first landing or an earlier goal crossing (weather %d / power %.2f)" % [weather,power])
			var descending := false
			var no_second_flight := true
			for i in range(1,first_flight.points.size()):
				var rise: float=first_flight.points[i].y-first_flight.points[i-1].y
				if rise<-.001: descending=true
				if descending and rise>.001: no_second_flight=false
			check(no_second_flight and first_flight.points[-1].is_equal_approx(first_flight.target),"Neither the line nor the marker reveals a second flight (weather %d / power %.2f)" % [weather,power])
	await setup()
	game.training=false
	game.begin_restart("SERBEST VURUŞ",0,Vector3(8,0,-28))
	game.state="set_piece"
	var restart=game.set_pieces
	restart.direction=(Vector3(0,0,game.attack_sign(0)*50)-game.restart_point).normalized()
	restart.preview()
	check(restart.kind()=="shot" and restart.button==0 and absf(restart.pending_curve)<0.05,"Left-stick aim without the right stick is a straight shot, not a pass")
	game.controller.aim_stick=Vector2(0.32,0)
	for frame in range(8): restart.preview(0.05)
	var nudge: float=restart.pending_curve
	check(nudge>0.04 and nudge<0.55,"A light right-stick hold adds a small curl")
	game.controller.aim_stick=Vector2(1,0)
	for frame in range(44): restart.preview(0.05)
	var steered: float=restart.pending_curve
	for x in [0.72,0.41,0.19,0.08,0.0]:
		game.controller.aim_stick=Vector2(x,0)
		restart.preview(0.05)
	check(absf(steered)>2.5 and is_equal_approx(restart.pending_curve,steered),"Right-stick curl stays after the stick is released")
	game.controller.aim_stick=Vector2(-1,0)
	for frame in range(10): restart.preview(0.05)
	var trimmed: float=restart.pending_curve
	game.controller.aim_stick=Vector2.ZERO
	restart.preview(0.05)
	check(trimmed<steered-0.35 and trimmed>1.2 and is_equal_approx(restart.pending_curve,trimmed),"The opposite stick trims the locked curl")
	game.controller.aim_stick=Vector2(1,0)
	for frame in range(20): restart.preview(0.05)
	game.controller.aim_stick=Vector2.ZERO
	restart.preview()
	steered=restart.pending_curve
	restart.button=KEY_D
	restart.power=0.5
	restart.preview()
	var launch_flat: Vector3=(restart.pending_velocity*Vector3(1,0,1)).normalized()
	var aim_flat: Vector3=(restart.direction*Vector3(1,0,1)).normalized()
	check(launch_flat.dot(aim_flat)>0.995,"Set-piece curl keeps the aimed heading")
	var origin: Vector3=game.ball.position
	var goal_z: float=game.attack_sign(0)*50
	var straight: Dictionary=Guide.predict(origin,restart.pending_velocity,0,goal_z,game.weather)
	var banana: Dictionary=Guide.predict(origin,restart.pending_velocity,restart.pending_curve,goal_z,game.weather)
	check(absf(banana.target.x-straight.target.x)>2.4,"Set-piece curl bends in flight")
	release_restart(restart)
	check(absf(game.ball.spin)>2.5 and is_equal_approx(game.ball.spin,steered),"The launched free kick keeps the set curl instead of going straight")
	game.begin_restart("KORNER",0,Vector3(32,0,-49.6))
	game.state="set_piece"
	restart.direction=Vector3(-0.8,0,0.4).normalized()
	game.controller.aim_stick=Vector2(-1,0)
	for frame in range(44): restart.preview(0.05)
	var corner_curve: float=restart.pending_curve
	for x in [-0.68,-0.33,-0.12,0.0]:
		game.controller.aim_stick=Vector2(x,0)
		restart.preview(0.05)
	check(restart.kind()=="cross" and absf(corner_curve)>2.5 and is_equal_approx(restart.pending_curve,corner_curve),"Released corner curl stays on the cross")
	game.begin_restart("SERBEST VURUŞ",0,Vector3(8,0,-28))
	game.state="set_piece"
	restart.direction=Vector3(-0.23,0,-1).normalized()
	var press := InputEventKey.new(); press.keycode=KEY_D; press.pressed=true
	key(KEY_E,true)
	restart.input(press)
	restart.power=0.4
	for frame in range(24): restart.preview(0.05)
	spin=restart.pending_curve
	press.pressed=false; restart.input(press)
	var committed: Vector3=restart.pending_velocity
	key(KEY_E,false)
	release_restart(restart)
	var intended: Vector3=game.strike_quality.last.get("intended",Vector3.INF)
	check(absf(spin)>1.4 and game.ball.spin==spin and intended.is_equal_approx(committed) and game.ball.kick_velocity.is_equal_approx(game.strike_quality.last.velocity),"Free-kick release commits the shown curl even when the modifier is released during run-up")
	restart.clear()
	check(restart.pending_curve==0,"The next restart cannot inherit a stale curl")
	check(game.hud.shot_warning({"target":Vector3(0,1.2,-50),"goal_plane":true,"on_target":true})=="","An on-target shot has no lock label")
	check(game.hud.shot_warning({"target":Vector3(0,2.6,-50),"goal_plane":true,"on_target":false})=="YÜKSEK","A high finish only warns when it is too high")
	check(game.hud.shot_warning({"target":Vector3(6,1.0,-50),"goal_plane":true,"on_target":false})=="","A wide finish has no out label")
	check(game.hud.shot_warning({"target":Vector3(2,0.8,-20),"goal_plane":false,"on_target":false})=="","A landing inside the pitch has no arrival label")
	check(game.hud.shot_warning({"target":Vector3(34,0.3,-10),"goal_plane":false,"on_target":false})=="","A shot leaving the pitch has no out label")
	if "--visual" in OS.get_cmdline_user_args():
		game.match_menu.display.set_fullscreen(false)
		game.match_menu.display.select_resolution(Vector2i(1440,900))
		for row in [["SERBEST VURUŞ",.28,-28.0,false,"free-kick-first-landing"],["PENALTI",.05,-39.0,false,"penalty-first-landing"],["SERBEST VURUŞ",.7,-28.0,true,"free-kick-airborne-finish"]]:
			await setup()
			game.training=false; game.begin_restart(row[0],0,Vector3(0,0,row[2]))
			game.set_pieces.snap_ready(); game.state="set_piece"
			game.ball.freeze=true; game.ball.pending_reset=false
			game.ball.position=game.restart_point+Vector3.UP*game.ball.GROUND_HEIGHT
			restart=game.set_pieces; restart.button=KEY_D; restart.power=row[1]
			restart.direction=Vector3.FORWARD; restart.preview()
			game.frontend.hide(); game.match_menu.hide(); game.controls_help.hide()
			game.hud.sync_navigation(); game.toast_timer=0
			game.camera.position=Vector3(0,37,-7); game.camera.look_at(Vector3(0,0,-35)); game.camera.size=42
			await capture(row[4])
			var shown: Dictionary=game.hud.shot_guide.cached
			check(not shown.is_empty() and shown.goal_plane==row[3] and (row[3] or shown.target.y<=game.ball.GROUND_HEIGHT+.001),"The rendered restart HUD ends at first ground contact or an earlier goal line: "+row[4])
	await setup()
	game.ball.freeze=true
	game.players[9].visible=true
	game.begin_shot(); game.charge=0.65; game.shot_finesse=true
	game.shot_direction=Vector3(-0.23,0,-1).normalized()
	game.players[9].shot_preparation=0.75; game.players[9].animate(0.5)
	game.camera.position=Vector3(0,37,-7); game.camera.look_at(Vector3(0,0,-35)); game.camera.size=42
	await capture("finesse-target")
	game.hud.hide()
	game.players[9].shot_preparation=0; game.players[9].animate(1)
	var player=game.players[9]
	game.camera.position=player.position+Vector3(2.5,3.2,-3.5)
	game.camera.look_at(player.position+Vector3(0,1.3,0)); game.camera.size=2.8
	await capture("hair-front")
	game.camera.position=player.position+Vector3(-2,4.5,2.8)
	game.camera.look_at(player.position+Vector3(0,1.25,0))
	await capture("hair-crown")
	print("FINESSE GUIDE CHECK: %d failures" % failures)
	game.free(); quit(0 if failures==0 else 1)
