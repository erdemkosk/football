extends "res://tests/ai_attack_check.gd"
const Attributes = preload("res://scripts/player_attributes.gd")

func ratings(index: int,changes: Dictionary={}) -> void:
	var p=game.players[index]
	for key in ["pace","acceleration","control","balance","heading","finishing","passing","defending","strength","stamina","positioning","agility","reactions","composure","vision","interceptions","tackling"]: p.attributes[key]=72
	p.attributes.preferred_foot=1; p.attributes.weak_foot=5
	for key in changes: p.attributes[key]=changes[key]
	Attributes.refresh(p)
	p.energy=1; p.match_fatigue=0; p.appearance_id=902

func receive_sample(control: int) -> Dictionary:
	setup(); game.controlled=9
	for q in game.players: q.visible=false
	player(9,Vector3.ZERO)
	var p=game.players[9]
	ratings(9,{"control":control})
	p.collision_layer=2; p.collision_mask=1; p.body_language.enabled=false
	p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO; p.animate(1)
	game.dribbler=-1; game.carrier=-1; game.last_touch=0; game.last_kicker=6
	game.ai_receivers[0]=9; game.ai_pass_time[0]=2
	game.ball.freeze=false; game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,-2.8),Vector3.BACK*22)
	await physics_frame; await physics_frame
	var received := false
	var recovery := 0.0
	var max_gap := 0.0
	var touches := 0
	for tick in range(70):
		p.desired=Vector3.RIGHT if received else Vector3.ZERO
		game.first_touch.prepare(DT)
		p.step(DT)
		var before: Vector3=game.ball.position
		game.update_contacts(DT)
		if tick==15: check(before==game.ball.position,"Reception and guidance preserve the ball transform")
		if not received and p.receive_timer>0:
			received=true; recovery=p.receive_duration
		await physics_frame
		if received:
			touches+=1
			# The initial acquisition gap is identical. Compare the subsequent
			# control window, after the contact impulse enters the rigid body.
			if touches>=8 and touches<36: max_gap=maxf(max_gap,game.flat_distance(p.position,game.ball.position))
			if touches==16: await capture("receive-%d" % control,p)
	return {"received":received,"recovery":recovery,"gap":max_gap,"owner":game.dribbler}

func carry_sample(agility: int,cut: bool=false) -> Dictionary:
	setup(); game.controlled=9
	for q in game.players: q.visible=false
	player(9,Vector3.ZERO)
	var p=game.players[9]
	ratings(9,{"agility":agility})
	p.collision_layer=2; p.collision_mask=1; p.body_language.enabled=false
	p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO; p.animate(1)
	game.dribbler=-1; game.carrier=-1; game.last_touch=0; game.last_kicker=9
	game.ball.freeze=false; game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,-.7))
	await physics_frame; await physics_frame
	var total := 0.0
	for tick in range(180):
		p.desired=Vector3.FORWARD; p.sprinting=true
		p.step(DT); game.update_contacts(DT); await physics_frame
		if tick>=120: total+=game.flat_distance(p.position,game.ball.position)
	var start: Vector3=p.position
	var turn_ticks := 60
	if cut:
		for tick in range(60):
			p.desired=Vector3.RIGHT; p.sprinting=true
			p.step(DT); game.update_contacts(DT); await physics_frame
			if absf(p.velocity.z)<1 and p.velocity.x>3:
				turn_ticks=tick; break
		await capture("turn-%d" % agility,p)
	return {"gap":total/60,"turn_ticks":turn_ticks,"overshoot":absf(p.position.z-start.z),"owner":game.dribbler,"contacts":p.dribble_motion.contacts}

func passing_accuracy() -> void:
	setup(); game.controlled=9
	for q in game.players: q.visible=false
	player(9,Vector3.ZERO); player(12,Vector3(.9,0,0))
	var p=game.players[9]
	var errors: Array[float]=[]
	for rating in [50,92]:
		ratings(9,{"passing":rating,"vision":rating})
		p.velocity=Vector3.RIGHT*6; p.active_sprint=true
		var total := 0.0
		for sample in range(24):
			p.position=Vector3(float(sample)*.17,0,0)
			game.players[12].position=p.position+Vector3(.9,0,0)
			game.ball.position=p.position+Vector3(0,game.ball.GROUND_HEIGHT,-.55)
			game.dribbler=9
			var intended := Vector3(0,.32,-16)
			var result: Dictionary=game.strike_quality.assess(9,intended,"kick")
			total+=absf((result.velocity*Vector3(1,0,1)).length()-16)
			if sample==0: check(result.velocity==game.strike_quality.assess(9,intended,"kick").velocity,"Pass contact is deterministic")
		errors.append(total/24)
	print("PASS WEIGHT ERRORS ",errors)
	check(errors[0]>errors[1]*2.0 and errors[0]>.10,"A poor passer misweights the same hurried ground pass more than a specialist")
	p.velocity=Vector3.ZERO; p.active_sprint=false; game.players[12].visible=false
	var easy := Vector3(0,.32,-14)
	check(game.strike_quality.assess(9,easy,"kick").velocity.is_equal_approx(easy),"A clean standing pass remains exact")
	game.strike_quality.pass_error_scale[0]=0
	p.velocity=Vector3.RIGHT*6; game.players[12].visible=true
	check(game.strike_quality.assess(9,easy,"kick").velocity.is_equal_approx(easy),"Turning off pass error also turns off weight error")
	game.strike_quality.pass_error_scale[0]=1
	var route: Dictionary=game.Passing.plan(game.ball.position,Vector3(4,0,-16),Vector3(0,0,-5),false,game.weather)
	check(route.target.z< -18,"The intended delivery still leads the moving receiver")

func striker_ratings(index: int,style: String) -> void:
	match style:
		"target": ratings(index,{"strength":94,"balance":88,"heading":92,"pace":64,"acceleration":60})
		"runner": ratings(index,{"pace":94,"acceleration":94,"strength":60,"heading":60})
		"poacher": ratings(index,{"finishing":94,"positioning":94,"reactions":94,"pace":72,"acceleration":72})

func forward_jobs() -> void:
	for half in [1,2]:
		setup(); game.half=half; game.management.opponent_formation=1
		var f: float=game.attack_sign(1)
		player(0,Vector3(0,0,f*49)); player(2,Vector3(-27,0,f*48))
		player(16,Vector3.ZERO); possession(16)
		player(19,Vector3(-4,0,f*4)); striker_ratings(19,"target")
		player(20,Vector3(5,0,f*5)); striker_ratings(20,"runner")
		player(21,Vector3(0,0,f*7)); striker_ratings(21,"poacher")
		# A saved wide formation may reserve a winger before coordination.
		# Compare central forwards in the same formation, independent of settings.
		for i in [19,20,21]: game.players[i].home=Vector3((i-20)*6,0,f*8)
		game.support.update(.1)
		print("FORWARD JOBS ",game.support.shape.jobs)
		if "--trace" in OS.get_cmdline_user_args():
			for i in [19,20,21]: print("FORWARD TRACE ",i," slot=",game.players[i].number," role=",game.management.slot_role(i)," style=",Attributes.forward_style(game.players[i])," duty=",game.support.roles.get(i,"")," target=",game.support.targets.get(i)," home=",game.players[i].home," order=",game.management.instruction(i)," user=",game.is_user_player(i))
		check(game.support.shape.jobs.get("short_outlet",-1)==19,"A target forward offers feet ahead of the carrier, half=%d" % half)
		check(game.support.shape.jobs.get("channel_run",-1)==20,"A fast forward takes the run behind, half=%d" % half)
		check(game.support.targets[19].z*f>0 and game.support.targets[20].z*f>game.support.targets[19].z*f+4,"The two forward types create different receiving depths")
		for i in [19,20,21]: check(game.support.targets[i].z*f<=game.rules.offside_line(1)-.8,"Forward preferences respect offside")
		# Equal starting distances expose preference rather than an easy race.
		player(16,Vector3(22,0,f*34)); possession(16)
		for i in [19,20,21]: player(i,Vector3(0,0,f*35))
		player(18,Vector3(0,0,f*28))
		game.support.reset(); game.support.update(.1)
		print("BOX JOBS ",game.support.box.jobs)
		check(game.support.box.jobs.get("near",-1)==21,"The poacher attacks the near post")
		check(game.support.box.jobs.get("far",-1)==19,"The aerial target forward attacks the far delivery")
		# Rebound recognition wins close races only.
		game.dribbler=-1; game.carrier=-1
		game.ball.position=Vector3(0,game.ball.GROUND_HEIGHT,f*39); game.ball.linear_velocity=Vector3.ZERO
		game.second_balls.alert("rebound",1); game.second_balls.update(DT)
		check(game.second_balls.jobs.get(1,[-1])[0]==21,"The poacher reacts first to an equally reachable rebound")
		game.players[20].position=game.ball.position-Vector3(0,game.ball.GROUND_HEIGHT,f)
		game.second_balls.alert("rebound",1); game.second_balls.update(DT)
		check(game.second_balls.jobs.get(1,[-1])[0]==20,"A much closer teammate still wins the rebound assignment")
		game.players[19].position=Vector3(0,0,f*15); possession(19)
		game.players[19].facing=Vector3(0,0,-f)
		player(4,game.players[19].position+Vector3(0,0,f*1.5))
		player(17,game.players[19].position+Vector3(7,0,-f*3),Vector3.RIGHT*2)
		var choice: Dictionary=game.ai_attack.hold_choice(19,game.ai_attack.pressure_read(19))
		check(choice.get("kind","")=="shield","A target forward with a real arriving outlet offers back-to-goal protection")
		game.ai_attack.holds[19]={"age":.7,"kind":"shield"}
		check(game.ai_attack.holding_action(19) and game.players[19].protecting,"The target forward can wait through a longer short shield")
		player(5,game.players[19].position+Vector3(1,0,0))
		check(not game.ai_attack.holding_action(19),"A second defender ends the shield instead of granting immunity")

func defensive_reading() -> void:
	for half in [1,2]:
		setup(); game.half=half
		var f: float=game.attack_sign(0)
		player(9,Vector3.ZERO); possession(9); game.controlled=9
		player(6,Vector3(7,0,f*10),Vector3(4,0,f*3))
		player(17,Vector3(8,0,f*5)); player(14,Vector3(0,0,f*1.5)); player(13,Vector3(0,0,f*7))
		var points: Array[Vector3]=[]
		for rating in [45,95]:
			ratings(17,{"interceptions":rating,"positioning":rating,"reactions":rating})
			game.team_tactics.age=0; game.team_tactics.update(DT)
			check(game.team_tactics.roles.get(17,"")=="screen","The midfielder gets a real pass-screening job")
			points.append(game.team_tactics.targets[17])
		check(points[1].x>points[0].x+.25,"The better reader covers the receiver's moving lane before a pass, half=%d" % half)
		# Same released ball, no change to reach or physics.
		player(17,Vector3.ZERO); game.dribbler=-1; game.carrier=-1; game.last_touch=0; game.last_kicker=9
		game.ball.position=Vector3(0,game.ball.GROUND_HEIGHT,-1.8); game.ball.linear_velocity=Vector3.BACK*8
		game.team_tactics.observe_flight(.08)
		ratings(17,{"interceptions":45,"positioning":45,"reactions":45})
		check(not game.ai_attack.defend(17),"A weak reader has not yet recognized the released pass")
		ratings(17,{"interceptions":95,"positioning":95,"reactions":95})
		check(game.ai_attack.defend(17) and game.players[17].pose=="intercept","A good reader starts a physical interception earlier")
		check(game.last_kicker==9 and not game.ball.pending_touch,"Recognition alone cannot steal or redirect the ball")
		game.ball.pending_kick=true; game.team_tactics.observe_flight(.3)
		check(game.team_tactics.flight_age==0,"A queued kick gives no advance flight observation")
		game.ball.pending_kick=false; game.state="restart"; game.team_tactics.observe_flight(.3)
		check(game.team_tactics.flight_age==0,"A whistle clears the flight observation")

func capture(label: String,p) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	game.hud.hide()
	game.ball.freeze=true
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=40
	game.camera.position=p.position+Vector3(4.5,3.0,-5.0)
	game.camera.look_at(p.position+Vector3(0,.65,0))
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-personality-"+label+".png")
	game.ball.freeze=false

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-player-personality.cfg"
	var poor := await receive_sample(50)
	var good := await receive_sample(92)
	print("RECEIVE poor=",poor," good=",good)
	check(poor.received and good.received,"Both technicians meet a real incoming hard pass")
	check(poor.recovery>good.recovery+.08,"The better technician releases the receiving foot sooner")
	check(poor.gap>good.gap+.08,"A poor first touch exposes more ball during the actual handover")
	var heavy := await carry_sample(50,true)
	var agile := await carry_sample(92,true)
	print("CARRY heavy=",heavy," agile=",agile)
	check(agile.turn_ticks<heavy.turn_ticks and agile.overshoot<heavy.overshoot,"An agile carrier completes the same right-angle turn sooner")
	check(agile.gap<heavy.gap-.03 and agile.contacts>0 and heavy.contacts>0,"Agility changes actual carrying distance with real foot contacts")
	check(agile.owner==9 and heavy.owner==9,"Both carrying styles retain playable control")
	passing_accuracy()
	forward_jobs()
	defensive_reading()
	print("PLAYER PERSONALITY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
