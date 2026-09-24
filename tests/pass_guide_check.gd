extends "res://tests/attacking_combos_check.gd"
const Guide = preload("res://scripts/shot_guide.gd")

func snapshot(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.camera.size=43
	game.camera.position=Vector3(8,45,3); game.camera.look_at(Vector3(8,0,-20))
	if label=="corner":
		game.camera.size=42; game.camera.position=Vector3(13,38,-14); game.camera.look_at(Vector3(13,0,-39))
	game.hud.queue_redraw()
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/sefc-guide-"+label+".png")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-pass-guide.cfg"
	for weather in [0,2]:
		for lob in [false,true]:
			setup(); game.weather.select(weather,true)
			var origin := Vector3(12,game.ball.GROUND_HEIGHT,-12)
			var target := Vector3(-6,game.ball.GROUND_HEIGHT,-30)
			var plan: Dictionary=game.Passing.plan(origin,target,Vector3.ZERO,lob,game.weather)
			var guide=Guide.new()
			var route: Dictionary=guide.pass_preview(origin,plan,game.weather)
			check(Array(route.points).all(func(p): return p.y>=game.ball.RADIUS-0.001),"Pass and cross guides stay above the pitch (weather %d, lob %s)" % [weather,lob])
			game.ball.freeze=false; game.ball.place(origin)
			for frame in range(3): await physics_frame
			game.ball.strike(plan.velocity)
			var previous := origin
			var actual := Vector3.INF
			var heading := (target-origin).normalized()
			var reach := origin.distance_to(target)
			var descended := false
			for frame in range(720):
				await physics_frame
				var point: Vector3=game.ball.position
				if lob:
					if point.y>0.6 and game.ball.linear_velocity.y<0: descended=true
					if descended and point.y<game.ball.GROUND_HEIGHT+0.03: actual=point; break
				elif (point-origin).dot(heading)>=reach:
					actual=previous.lerp(point,(reach-(previous-origin).dot(heading))/(point-previous).dot(heading)); break
				previous=point
			print("Pass guide error: ",actual.distance_to(route.target)," lob=",lob," weather=",weather)
			check(actual.distance_to(route.target)<0.8,"The visible receiving/landing point matches the physical pass (weather %d, lob %s)" % [weather,lob])
	setup()
	var weak := {"target":Vector3(20,game.ball.GROUND_HEIGHT,-46),"velocity":Vector3(0,0.32,-10),"flight":6.0,"lob":false,"receiver":-1}
	var short_route: Dictionary=Guide.new().pass_preview(game.ball.position,weak,game.weather)
	check(short_route.target.distance_to(weak.target)>5,"An underpowered pass ends where friction stops it instead of promising the requested target")
	setup()
	var plan: Dictionary=game.cross_plan(game.last_direction)
	var velocity: Vector3=plan.velocity
	game.pass_ball(true)
	contact()
	check(game.strike_quality.last.get("intended",Vector3.INF).is_equal_approx(velocity) and game.ball.kick_velocity.is_equal_approx(game.strike_quality.last.velocity),"The normal cross releases the velocity used by its preview plus its recorded crossing error")
	check(game.hud.pass_trail_time==0 and game.hud.last_pass.is_empty(),"The pass guide disappears as soon as the ball is released")
	await snapshot("cross")
	setup(); game.begin_pass()
	check(not game.pass_charging and game.pass_preview.is_empty(),"Automatic normal passing has no charged aim guide")
	await snapshot("pass")
	setup(); game.begin_pass(true); game.pass_power=0.55; game.update_pass_preview()
	await snapshot("through")
	setup(); game.begin_pass(false,true); game.pass_power=0.7; game.update_pass_preview()
	await snapshot("lofted")
	setup(); game.driven_cross()
	await snapshot("driven")
	setup(); game.begin_restart("KORNER",0,Vector3(31.5,0,-49.5))
	game.set_pieces.snap_ready(); game.state="set_piece"
	game.ball.position=game.restart_point+Vector3.UP*game.ball.GROUND_HEIGHT; game.ball.pending_reset=false
	game.set_pieces.button=KEY_A; game.set_pieces.power=0.6; game.set_pieces.direction=Vector3(-1,0,0.55).normalized(); game.set_pieces.preview()
	await snapshot("corner")
	print("PASS GUIDE CHECK: %d checks, %d failures" % [count,failures])
	game.free(); quit(0 if failures==0 else 1)
