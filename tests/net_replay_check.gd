extends "res://tests/net_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await frames(3)
	game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	game.replay.enabled=true
	for player in game.players: player.visible=false; player.collision_layer=0
	game.players[9].visible=true; game.players[9].position=Vector3(8,0,-40)
	game.last_kicker=9; game.last_touch=0
	game.boundary_grace=0
	for frame in range(25): game.replay.capture(0.05)
	game.ball.place(Vector3(0.8,1.0,-49),Vector3(0,1,-30))
	game.previous_ball=Vector3(0.8,1,-49)
	var live_peak := 0.0
	var seen_goal := false
	for frame in range(240):
		await physics_frame
		if game.state=="playing":
			game.check_boundaries()
			game.previous_ball=game.ball.position
		elif game.state=="goal":
			seen_goal=true
			game.replay.capture_goal(1.0/120)
		live_peak=maxf(live_peak,game.stadium.nets[0].max_deformation())
		if game.state=="replay": break
	check(seen_goal and live_peak>0.4 and game.stadium.nets[0].impact_count>0,"A real scored goal hits and stretches the live net before replay freezes the ball")
	check(game.state=="replay" and game.score==[1,0],"The delayed replay still starts once and preserves the score")
	check(game.broadcast.graphic=="goal","Replay opens with a one-second goal lower-third")
	if game.replay.saved.is_empty(): game.free(); quit(1); return
	var net=game.stadium.nets[0]
	var saved: Dictionary=game.replay.saved.net_physics[0].duplicate(true)
	var replay_peak := 0.0
	var cuts := {}
	var seen_perspective := false
	var empty := 0
	for frame in range(100):
		game.replay.update(0.04)
		if game.state!="replay": break
		cuts[game.replay.cut]=true
		if game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE: seen_perspective=true
		var to_ball: Vector3=game.ball.position-game.camera.position
		var facing: Vector3=-game.camera.global_transform.basis.z
		if to_ball.length()>0.5 and facing.dot(to_ball.normalized())<0.2: empty+=1
		if game.replay.cut>=1 and Vector3(game.ball.position.x,0,game.ball.position.z).distance_to(Vector3(0,0,game.replay.goal_end*50))>20: empty+=1
		replay_peak=maxf(replay_peak,net.max_deformation())
		var before: Array=net.capture_pose()
		net._physics_process(0.1)
		if frame==30: check(net.capture_pose()==before,"Playback does not simulate a second net collision")
	check(replay_peak>0.4,"The recorded replay includes the actual net pocket and rebound")
	check(cuts.size()>=2 and seen_perspective,"Goal replay cuts between at least two broadcast cameras")
	check(empty==0,"Replay cameras stay on the ball instead of an empty goal")
	game.replay.finish()
	check(not net.playback and net.capture_physics()==saved,"Finishing replay restores the live net position and velocity exactly")
	check(not game.ball.freeze and game.state=="goal","The ball resumes physical motion after replay")
	for frame in range(25): game.replay.capture(0.05)
	game.replay.queue_goal()
	game.begin_restart("SANTRA",1,Vector3.ZERO)
	check(game.replay.goal_tail==0,"Skipping directly to kickoff cancels the pending replay")
	print("NET REPLAY CHECK: %d failures" % failures)
	game.free(); quit(0 if failures==0 else 1)
