extends "res://tests/advanced_play_check.gd"

func trail_fixture(style: String="power") -> void:
	await reset()
	game.frontend.hide(); game.match_menu.hide()
	game.ball.set_process(false)
	p.position=Vector3(-5,0,3); p.facing=Vector3(1,0,-.25).normalized()
	p.rig.rotation.y=atan2(-p.facing.x,-p.facing.z)
	game.last_direction=p.facing
	game.ball.place(p.position+p.facing*.65+Vector3.UP*game.ball.GROUND_HEIGHT)
	await physics_frame; await physics_frame
	game.finishing.style=style

func flight(frames: int) -> void:
	for n in range(frames):
		await tick()
		game.ball.power_trail.update(DT)

func trail_capture(label: String,close: bool) -> void:
	if not visual: return
	var focus: Vector3=game.ball.position-p.facing*2.5
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=42 if close else 48
	game.camera.position=focus+(Vector3(3,6,9) if close else Vector3(8,24,31))
	game.camera.look_at(focus)
	game.ball.power_trail.draw()
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-power-shot-trail-"+label+".png")

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-power-trail.cfg"
	for style in ["power","low","outside"]:
		await trail_fixture(style)
		var trail=game.ball.power_trail
		check(trail.remaining==0 and not trail.node.visible,"Preparing "+style+" does not emit a trail")
		check(game.finishing.release_charged(9,p.facing,.65),"Physical special-shot release: "+style)
		check((trail.remaining>0)==(style=="power"),"Only an actual power shot starts the effect: "+style)
		await flight(20)
		check(trail.node.visible==(style=="power"),"Trail visibility matches the shot type in flight: "+style)
		if style=="power":
			var path := 0.0
			for i in range(1,trail.points.size()): path+=trail.points[i-1].distance_to(trail.points[i])
			check(path>2 and path<=trail.MAX_LENGTH and trail.points.size()<=trail.MAX_POINTS,"The visible ribbon follows a bounded recent flight path")
			var at: Vector3=game.ball.position
			var velocity: Vector3=game.ball.linear_velocity
			trail.update(DT)
			check(game.ball.position==at and game.ball.linear_velocity==velocity,"Rendering the effect never changes ball physics")
			if visual:
				# Render both cameras at the same instant; otherwise the rigid ball
				# advances while this manually stepped fixture waits for a draw.
				game.ball.reset_physics_interpolation()
				trail.update(0)
				game.ball.freeze=true
				await trail_capture("close",true)
				await trail_capture("match",false)
				game.ball.freeze=false
			game.ball.touch(Vector3.ZERO,1)
			check(trail.remaining==0,"A subsequent touch stops new trail emission")
			await flight(30)
			check(not trail.node.visible and trail.points.is_empty(),"The remaining ribbon fades completely after contact")
	await trail_fixture()
	game.finishing.release_charged(9,p.facing,.6); await flight(12)
	game.ball.place(Vector3(20,.23,20))
	check(game.ball.power_trail.points.is_empty() and not game.ball.power_trail.node.visible,"Repositioning clears the ribbon immediately")
	await trail_fixture()
	game.finishing.release_charged(9,p.facing,.6); await flight(12)
	game.ball.freeze=true; game.ball.power_trail.update(DT)
	check(game.ball.power_trail.points.is_empty(),"Pause and frozen replay playback cannot leave a stale trail")
	await trail_fixture()
	game.finishing.queue(9,p.facing,.65,"power")
	check(game.ball.power_trail.remaining==0,"An AI-style wind-up does not produce a phantom trail")
	await flight(65)
	check(game.shots[0]==1 and game.ball.power_trail.remaining>0,"A queued power shot starts its trail only at actual boot contact")
	game.ball.hold(game.players[0]); await flight(30)
	check(not game.ball.power_trail.node.visible,"A keeper's catch leaves no continuing trail")
	print("POWER SHOT TRAIL CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
