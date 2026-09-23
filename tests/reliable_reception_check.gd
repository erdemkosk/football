extends "res://tests/ai_attack_check.gd"

# No preassigned owner or collision exceptions: meet a freely travelling ball
# with a moving body, then keep running through the entire receive handover.
func reception(team: int,scenario: Dictionary) -> Dictionary:
	setup()
	for q in game.players: q.visible=false; q.collision_layer=0
	var index := 6 if team==0 else 18
	player(index,Vector3.ZERO)
	var p=game.players[index]
	p.collision_layer=2; p.facing=Vector3.FORWARD; p.rig.rotation.y=0
	p.attributes.control=scenario.get("control",72); p.energy=scenario.get("energy",1.0)
	p.desired=scenario.get("move",Vector3.ZERO); p.sprinting=scenario.get("sprint",false)
	p.velocity=p.desired*p.movement_speed()
	p.animate(1)
	if scenario.get("pressure",false):
		var opponent := 18 if team==0 else 6
		player(opponent,Vector3(1.1,0,.85)); game.players[opponent].collision_layer=2
	game.controlled=index if team==0 else 9
	game.dribbler=-1; game.carrier=-1; game.last_touch=team; game.last_kicker=8 if team==0 else 20
	game.ai_receivers[team]=-1; game.incoming_receiver=-1
	game.weather.select(scenario.get("weather",0),true)
	var origin: Vector3=scenario.origin
	var velocity: Vector3=scenario.velocity
	game.ball.freeze=false; game.ball.place(origin,velocity+p.velocity)
	await physics_frame; await physics_frame
	game.kick_lock=scenario.get("lock",0.0)
	var first := -1
	var lost := 0
	var peak := 0.0
	var reflected := false
	var fast_acquired := false
	var initial_velocity: Vector3=velocity.normalized()
	for frame in range(180):
		game.kick_lock=maxf(0,game.kick_lock-DT)
		p.desired=scenario.get("move",Vector3.ZERO); p.sprinting=scenario.get("sprint",false)
		p.step(DT)
		var before: Vector3=game.ball.position
		var incoming_speed: float=(game.ball.linear_velocity-p.velocity).length()
		game.update_contacts(DT)
		if incoming_speed>28 and game.dribbler==index: fast_acquired=true
		if before!=game.ball.position: check(false,"Receiving must not teleport the ball")
		if game.last_kicker==index and first<0: first=frame
		await physics_frame
		if (game.ball.linear_velocity-p.velocity).dot(initial_velocity)<-2: reflected=true
		if team==0 and scenario.get("name","")=="running chest trap" and frame in [8,60] and "--visual" in OS.get_cmdline_user_args():
			game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=42
			game.camera.position=p.position+Vector3(3.5,2.0,-4.2)
			game.camera.look_at(p.position+Vector3.UP*.75)
			await process_frame; RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("/tmp/sefc-receive-%d.png" % frame)
		if first>=0:
			peak=maxf(peak,game.flat_distance(p.position,game.ball.position))
			if frame>first+12 and game.dribbler!=index: lost+=1
	return {"first":first,"lost":lost,"peak":peak,"reflected":reflected,"fast_acquired":fast_acquired,"owner":game.dribbler,"gap":game.flat_distance(p.position,game.ball.position)}

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-reliable-reception.cfg"
	var cases := [
		{"name":"close quick pass", "origin":Vector3(0,.23,-1.55),"velocity":Vector3.BACK*19,"lock":.16},
		{"name":"shin-high pass", "origin":Vector3(0,.68,-1.4),"velocity":Vector3(0,-.4,10)},
		{"name":"running low bounce", "origin":Vector3(0,.82,-1.5),"velocity":Vector3(0,-1,12),"move":Vector3.FORWARD},
		{"name":"sprinting side pass", "origin":Vector3(-1.7,.23,-.3),"velocity":Vector3.RIGHT*16,"move":Vector3.FORWARD,"sprint":true},
		{"name":"running chest trap", "origin":Vector3(0,1.45,-1.4),"velocity":Vector3(0,-1,12),"move":Vector3.FORWARD},
		{"name":"wide tired-player touch", "origin":Vector3(-1.28,.23,-.1),"velocity":Vector3.RIGHT*8,"control":52,"energy":.25},
		{"name":"wet low bounce", "origin":Vector3(0,.65,-1.4),"velocity":Vector3(0,-.2,14),"move":Vector3.RIGHT,"weather":1},
		{"name":"slow loose ball", "origin":Vector3(0,.23,-1.15),"velocity":Vector3.ZERO,"move":Vector3.FORWARD},
		{"name":"slow pass to standing receiver", "origin":Vector3(0,.23,-1.12),"velocity":Vector3.BACK*1.7},
		{"name":"tired receiver under pressure", "origin":Vector3(-1.32,.23,-.1),"velocity":Vector3.RIGHT*9,"control":52,"energy":.25,"pressure":true}
	]
	for team in [0,1]:
		for scenario in cases:
			var result: Dictionary=await reception(team,scenario)
			print("RECEPTION team=",team," ",scenario.name," ",result)
			check(result.first>=0 and result.owner==(6 if team==0 else 18) and result.lost==0 and result.peak<1.4,"Team %d controls %s continuously into the next run" % [team,scenario.name])
		# The same physical approach behind an unturned player is awkward;
		# unlike ordinary front/side reception it must not grant secured possession.
		var rear: Dictionary=await reception(team,{"origin":Vector3(0,.23,1.6),"velocity":Vector3.FORWARD*18})
		check(rear.first>=0 and rear.lost>0,"Team %d can miscontrol a firm ball arriving behind the stance" % team)
		var shot: Dictionary=await reception(team,{"origin":Vector3(0,.23,-2),"velocity":Vector3.BACK*34})
		print("HARD SHOT team=",team," ",shot)
		check(not shot.fast_acquired and shot.reflected,"Team %d deflects a point-blank powerful shot before attempting to gather the rebound" % team)
		var unreachable: Dictionary=await reception(team,{"origin":Vector3(-2,.23,-1.8),"velocity":Vector3.RIGHT*12})
		check(unreachable.first<0 and unreachable.owner<0,"Team %d cannot pull in a pass outside physical reach" % team)
	print("RELIABLE RECEPTION CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); await process_frame; quit(1 if failures else 0)
