extends "res://tests/ai_attack_check.gd"

func reception(team: int,kind: String,moving: bool=false,half: int=1,rain: bool=false,user_control: bool=false) -> void:
	setup()
	game.weather.select(2 if rain else 0,true)
	game.half=half; game.menu_match.running=not user_control; game.ball.freeze=false
	for p in game.players: p.visible=false; p.collision_layer=0
	var forward: float=game.attack_sign(team)
	var passer := team*11+9
	var receiver := team*11+7
	game.pass_assistance=1
	if user_control: game.team_control.select(receiver,true)
	var wide := kind in ["cross","driven_cross"]
	player(passer,Vector3(26 if wide else 0,0,forward*(33 if wide else -8)))
	player(receiver,Vector3(1 if wide else 0,0,forward*(40 if wide else 9)),Vector3(0,0,forward*4) if moving else Vector3.ZERO)
	player((1-team)*11,Vector3(0,0,forward*49))
	player((1-team)*11+2,Vector3(-29,0,forward*48))
	for p in game.players:
		p.collision_layer=2 if p.visible else 0
		p.collision_mask=3
	game.ball.place(game.players[passer].position+Vector3(0,.23,forward*.6))
	await physics_frame; await physics_frame
	game.dribbler=passer; game.carrier=passer; game.last_kicker=passer; game.last_touch=team
	game.previous_ball=game.ball.position; game.kick_lock=0
	var q=game.players[receiver]
	var route: Dictionary
	if kind=="cross": route=game.ai_attack.cross_choice(passer).route
	elif kind=="driven_cross": route=game.Passing.driven_cross(game.ball.position,q.position,q.velocity,game.weather)
	else: route=game.Passing.plan(game.ball.position,q.position,q.velocity,kind=="lob",game.weather)
	var choice: Dictionary=game.ai_attack.pass_choice(kind,route,receiver)
	check(game.strike(passer,route.velocity,0,false,"cross" if kind=="cross" else "kick"),"Delivery starts: team %d %s" % [team,kind])
	if not game.kick_contact.pending.is_empty(): game.kick_contact.pending.ai_choice=choice
	else: game.ai_attack.kick_completed(passer,choice)
	game.ai_attack.think_in[passer]=20; game.ai_attack.think_in[receiver]=20
	var touched := false
	var settled := 0.0
	var first_contact := -1.0
	var closest := INF
	for frame in range(120*5):
		game.simulate_match(DT)
		await physics_frame
		closest=minf(closest,q.position.distance_to(game.ball.position))
		if game.last_kicker==receiver:
			if not touched: first_contact=frame*DT
			touched=true
		if game.dribbler==receiver: settled+=DT
		if touched and kind=="cross" and game.shots[team]>0: break
		if settled>.65: break
		if game.state!="playing": break
	print("RECEPTION team=",team," kind=",kind," moving=",moving," half=",half," touch=",touched," settled=",snapped(settled,.01)," first=",first_contact," shots=",game.shots[team]," nearest=",closest," final=",game.ball.position," receiver=",q.position)
	check(touched,"Intended receiver meets the real %s, team %d moving=%s half=%d" % [kind,team,moving,half])
	if kind=="cross" and not user_control: check(first_contact>=0 and first_contact<float(route.flight)+.35,"The cross meets the head on its first flight, before a body ricochet")
	check((game.shots[team]>0 if kind=="cross" and not user_control else settled>.6),"Reception continues into a controlled carry or aerial finish: %s team %d" % [kind,team])
	if user_control: check(game.controlled==receiver and game.shots[team]==0,"Assisted reception leaves possession and the decision to shoot with the user")
	if kind=="cross" and not user_control:
		for frame in range(20):
			game.heading.prepare(DT); await physics_frame
		check(not game.ball.get_collision_exceptions().has(q),"Header follow-through restores normal player collision")
	game.menu_match.running=false

func firm_delivery(team: int) -> void:
	setup()
	for p in game.players: p.visible=false; p.collision_layer=0
	var receiver := team*11+7
	player(receiver,Vector3.ZERO)
	var p=game.players[receiver]
	p.collision_layer=2; p.facing=Vector3.LEFT; p.rig.rotation.y=PI*.5; p.animate(1)
	game.dribbler=-1; game.carrier=-1; game.last_touch=team; game.last_kicker=team*11+9
	game.ai_receivers[team]=receiver; game.ai_pass_time[team]=2
	game.ball.freeze=false; game.ball.place(Vector3(-3,.23,0),Vector3.RIGHT*31)
	await physics_frame; await physics_frame
	var received := false
	for frame in range(100):
		p.desired=Vector3.ZERO; p.step(DT); game.update_contacts(DT)
		if game.dribbler==receiver: received=true
		await physics_frame
	check(received and game.dribbler==receiver and game.flat_distance(p.position,game.ball.position)<1.2,"Team %d cushions an intended firm cutback without a capsule rebound" % team)

func receiving_lane() -> void:
	setup(); game.menu_match.running=true
	game.players[20].position=Vector3(-12,0,-8)
	player(18,Vector3(2,0,12)); player(17,Vector3(3,0,7))
	game.ball.position=Vector3(0,.23,0); game.ball.linear_velocity=Vector3.BACK*12
	game.dribbler=-1; game.carrier=-1; game.last_kicker=20; game.last_touch=1
	game.ai_receivers[1]=18; game.ai_pass_time[1]=2
	game.players[17].home=Vector3(15,0,9)
	game.update_ai(DT)
	check(game.players[17].desired.x>0,"A nearer teammate leaves the receiving lane to the intended player")
	game.first_touch.prepare()
	game.players[18].position=Vector3(1,0,3)
	game.first_touch.prepare(); game.players[18].step(DT)
	check(game.players[18].facing.z<-.8,"A receiver watches the delivery while moving to meet it")
	game.state="paused"; game.simulate_match(DT)
	check(game.players[18].receiving_facing==Vector3.ZERO,"Reception assistance clears at a stoppage")
	game.menu_match.running=false

func short_throw(height: int) -> void:
	setup()
	for p in game.players: p.visible=false; p.collision_layer=0
	player(21,Vector3(-36.32,0,44))
	var p=game.players[21]
	p.height_cm=height; p.apply_build(); p.collision_layer=2
	game.ball.freeze=false; game.ball.place(Vector3(-37,.23,44))
	await physics_frame; await physics_frame
	game.begin_restart("TAÇ",1,Vector3(-36,0,44))
	for frame in range(120*12):
		game.simulate_match(DT); game._process(DT); await physics_frame
		if game.state=="set_piece": break
	check(game.state=="set_piece" and game.ball.held_by==p,"A %d cm taker raises the real ball and completes throw-in preparation" % height)
	if game.state!="set_piece": print("THROW state=",game.state," phase=",game.set_pieces.recovery.phase," ball=",game.ball.position," hands=",p.hand_center()," held=",game.ball.held_by==p," blend=",p.handling_blend," pose=",p.set_piece_pose," at=",p.position," target=",game.set_pieces.targets[21]," ready=",game.set_pieces.recovery.can_ready()," referee=",game.referees.ready_for_restart())

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	for team in range(2):
		for kind in ["pass","lob","cross","driven_cross"]:
			await reception(team,kind)
		await reception(team,"cross",true,2)
		await reception(team,"cross",true,1,true)
		await reception(team,"lob",true,2,true)
		await firm_delivery(team)
	await reception(0,"cross",false,1,false,true)
	await reception(0,"lob",true,2,true,true)
	receiving_lane()
	for height in [166,180,199]: await short_throw(height)
	print("RECEPTION FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
