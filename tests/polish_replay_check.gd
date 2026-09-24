extends "res://tests/replay_comfort_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.match_menu.config_path="/tmp/sefc-polish-replay-settings.cfg"
	var visual:=DisplayServer.get_name()!="headless" and "--visual" in OS.get_cmdline_user_args()
	for short in [false,true]:
		for end in [-1,1]:
			game.start_match(false,false); game.frontend.hide(); game.match_menu.hide()
			game.experience.short_presentation=short; game.half=1 if end<0 else 2
			game.goal_team=0; game.score=[1,0]; game.state="goal"
			game.ball.freeze=true; game.ball.pending_reset=false
			var r=game.replay
			for i in range(100):
				var flight:=clampf((i-40)/35.0,0,1)
				game.ball.position=Vector3(-4*(1-flight),.24+sin(flight*PI),end*(30+21*flight))
				game.players[9].position=Vector3(-4,0,end*29)
				game.players[9].rig.rotation.y=0 if end<0 else PI
				game.players[11].position=Vector3(-flight,.3*sin(flight*PI),end*48)
				if i==40: r.mark_shot(9)
				r.capture(.05)
			var original: Transform3D=game.ball.transform
			check(r.begin() and is_equal_approx(r.shot_at,.6 if short else 2.0),"Actual shot marker preserves the backswing in %s presentation, direction %d" % ["short" if short else "full",end])
			var previous: Vector3=game.camera.position; var fov: float=game.camera.fov; var cut: int=r.cut
			var stable:=true; var shot_visible:=true; var keeper_visible:=true; var contact_open:=true; var shot_seen:=false; var keeper_seen:=false
			while game.state=="replay":
				r.update(1.0/60)
				if game.state!="replay": break
				if cut==r.cut: stable=stable and game.camera.position.distance_to(previous)<=8.0/60+.001 and is_equal_approx(fov,game.camera.fov)
				if absf(r.age-r.shot_at)<.12:
					shot_visible=shot_visible and game.camera.is_position_in_frustum(game.ball.position) and game.camera.is_position_in_frustum(game.players[9].position+Vector3.UP)
					contact_open=contact_open and r.transition_alpha()<.01
					if visual and not shot_seen:
						shot_seen=true; await picture("shot-%d-%s" % [end,str(short)])
				if r.cut==1 and r.transition_alpha()<.01:
					keeper_seen=true
					keeper_visible=keeper_visible and game.camera.is_position_in_frustum(game.players[11].position+Vector3.UP*.8) and game.camera.is_position_in_frustum(game.ball.position)
				previous=game.camera.position; fov=game.camera.fov; cut=r.cut
			check(stable and contact_open,"Camera movement remains bounded and the kick is never covered by a fade")
			check(shot_visible and keeper_seen and keeper_visible,"The striker and ball stay framed at contact; the reaction angle contains both keeper and ball")
			check(game.ball.transform==original and game.score==[1,0],"Both presentation modes restore the original ball and score")
	print("POLISH REPLAY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)

func picture(label: String) -> void:
	game.hud.replay_frame.sync(); game.hud.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/sefc-polish-replay-"+label+".png")
