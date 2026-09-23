extends "res://tests/ai_attack_check.gd"

func keeper_setup(half: int=1) -> void:
	setup(); game.half=half
	for p in game.players: p.visible=false
	var f: float=game.attack_sign(1)
	player(11,Vector3(0,0,-45*f)); player(14,Vector3(-12,0,-33*f)); player(15,Vector3(12,0,-33*f))
	player(9,Vector3(-6,0,-39*f))
	for p in game.players:
		p.body_language.enabled=false
		if p.visible: p.animate(1)
	game.dribbler=-1; game.carrier=-1; game.last_kicker=11; game.last_touch=1
	game.ball.hold(game.players[11]); game.goalkeeping.holding=11; game.goalkeeping.hold_age=2
	game.ball.position=game.players[11].hand_center(); game.ball.pending_kick=false

func restart(kind: String,point: Vector3,team: int=1) -> void:
	game.state="set_piece"; game.restart_type=kind; game.restart_team=team; game.restart_point=point
	game.ball.release_hold(); game.ball.position=point+Vector3.UP*game.ball.GROUND_HEIGHT
	game.set_pieces.taker=11 if kind=="KALE VURUŞU" else 20
	game.set_pieces.ready_age=2; game.set_pieces.runup=-1
	player(game.set_pieces.taker,point-Vector3(0,0,game.attack_sign(team)*.48))

func keeper_flow(half: int,rain: bool,long_ball: bool=false) -> void:
	keeper_setup(half); game.weather.select(2 if rain else 0,true)
	var f: float=game.attack_sign(1)
	if long_ball:
		game.players[14].visible=false
		player(15,Vector3(-30,0,-7*f)); player(9,Vector3(30,0,-7*f))
		game.goalkeeping.hold_age=3.2
	game.controlled=9; game.players[9].desired=Vector3.ZERO
	game.ball.freeze=false
	for p in game.players:
		p.collision_layer=2 if p.visible else 0; p.collision_mask=3
	game.ball.place(game.players[11].hand_center()); await physics_frame; await physics_frame
	game.ball.hold(game.players[11]); game.goalkeeping.holding=11
	check(game.ai_attack.distribute(11),"Keeper queues a safe real delivery, half=%d rain=%s" % [half,rain])
	var expected: int=game.keeper_distribution.pending.ai_choice.receiver
	var caught := false
	var stolen := false
	var released := false
	for tick in range(720):
		game.kick_lock=maxf(0,game.kick_lock-DT); game.update_pass_request(DT)
		game.ai_attack.update(DT); game.update_ai(DT)
		game.keeper_distribution.update(DT); game.ai_attack.finishing.prepare(DT); game.kick_contact.prepare(DT)
		for p in game.players:
			if p.visible: p.step(DT)
		game.keeper_distribution.resolve(); game.ai_attack.finishing.resolve(); game.kick_contact.resolve()
		game.update_contacts(DT); await physics_frame
		if game.ball.held_by==null: released=true
		if released and game.last_touch==0: stolen=true; break
		if released and game.dribbler==expected: caught=true; break
	print("KEEPER FLOW half=",half," rain=",rain," long=",long_ball," receiver=",expected," caught=",caught," stolen=",stolen," ball=",game.ball.position," receiver_at=",game.players[expected].position)
	check(expected==15 and released and caught and not stolen,"Actual keeper distribution reaches the open teammate instead of the blocked flank")
	check(game.passes[1]>=1,"Distribution counts only after the actual release")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-ai-delivery.cfg"
	for half in [1,2]:
		keeper_setup(half)
		check(game.ai_attack.distribute(11) and game.keeper_distribution.pending.ai_choice.receiver==15,"Keeper chooses the uncovered outlet in half %d" % half)
		check(game.ai_receivers[1]<0 and game.passes[1]==0,"Preparing a distribution does not register a completed pass")
		var choice: Dictionary=game.keeper_distribution.pending.ai_choice
		player(9,choice.route.target*Vector3(1,0,1))
		game.keeper_distribution.pending.age=.4; game.keeper_distribution.resolve()
		check(game.ball.held_by==game.players[11] and game.keeper_distribution.pending.is_empty() and game.passes[1]==0,"A closed distribution lane is cancelled while the ball is still safely in the keeper's hands")
		keeper_setup(half); restart("KALE VURUŞU",game.players[11].position)
		check(game.set_pieces.plan_ai() and game.set_pieces.receiver==15,"Goal kicks target an actual free teammate in half %d" % half)
		var planned: Vector3=game.set_pieces.pending_velocity
		game.set_pieces.commit()
		check(game.set_pieces.pending_velocity==planned,"Restart run-up preserves the evaluated route instead of replacing it with fixed power")
		keeper_setup(half)
		var f: float=game.attack_sign(1)
		restart("SERBEST VURUŞ",Vector3(0,0,-35*f))
		game.set_pieces.plan_ai()
		check(game.set_pieces.kind()!="shot","A free kick deep in the own half never becomes an automatic shot")
		restart("SERBEST VURUŞ",Vector3(0,0,30*f))
		check(game.set_pieces.plan_ai() and game.set_pieces.kind()=="shot" and game.set_pieces.pending_velocity.z*f>0,"A close attacking free kick retains a genuine shot option")
		restart("ENDİREKT VURUŞ",Vector3(0,0,30*f)); game.set_pieces.ready_age=3.2
		check(game.set_pieces.plan_ai() and game.set_pieces.kind()!="shot","An indirect free kick always seeks a legal delivery")
	keeper_setup(); game.players[14].visible=false; game.players[15].visible=false
	check(not game.ai_attack.distribute(11) and game.ball.held_by!=null,"No safe outlet prompts a brief scan while retaining possession")
	game.goalkeeping.hold_age=3.2
	check(game.ai_attack.distribute(11) and game.keeper_distribution.pending.kind=="punt","The scan is bounded and a measured long distribution remains available")
	var first: Vector3=game.keeper_distribution.pending.ai_choice.route.target
	game.keeper_distribution.reset(); player(9,first*Vector3(1,0,1))
	game.ai_attack.distribute(11)
	check(signf(game.keeper_distribution.pending.ai_choice.route.target.x)!=signf(first.x),"A long clearance switches flank when an opponent occupies the previous landing area")
	setup(); player(18,Vector3(10,0,-10)); player(4,Vector3(-1.8,0,0)); game.ai_attack.skill_in[20]=2
	check(game.ai_attack.act(20) and not game.kick_contact.pending.is_empty(),"An ordinary safe pass enters the shared kick preparation")
	var route: Dictionary=game.kick_contact.pending.ai_choice.route
	check(game.ai_attack.delivery.safe(20,route,game.kick_contact.pending.ai_choice.receiver,game.ball.position,.065),"A selected ordinary pass meets the same safety threshold used at contact")
	player(4,game.ball.position.lerp(route.target,.45)*Vector3(1,0,1))
	for tick in range(24):
		game.kick_contact.prepare(DT); game.players[20].step(DT); game.kick_contact.resolve()
	check(not game.ball.pending_kick and game.passes[1]==0 and game.dribbler==20,"A field player aborts a newly blocked pass without donating possession")
	setup(); player(18,Vector3(0,0,20)); player(4,Vector3(4.3,0,10),Vector3(-5,0,0))
	route=game.Passing.plan(game.ball.position,game.players[18].position,Vector3.ZERO,false,game.weather)
	var read: Dictionary=game.ai_attack.delivery.assess(20,route,18,game.ball.position,.3)
	check(read.risk>.7,"A runner approaching the passing lane is considered before releasing the ball")
	setup(); game.ai_attack.decisions.game=game
	player(18,Vector3(0,0,22),Vector3(0,0,5)); player(4,Vector3(0,0,28)); player(19,Vector3(-12,0,4))
	var unsafe: Dictionary=game.ai_attack.pass_choice("pass",game.Passing.plan(game.ball.position,game.players[18].position,game.players[18].velocity,false,game.weather),18)
	check(game.ai_attack.delivery.assess(20,unsafe.route,18).risk>.7 and game.ai_attack.decisions.value(20,unsafe)==-INF,"A receiver moving into an opponent's control is rejected despite forward progress")
	game.players[18].velocity=Vector3.ZERO; game.players[18].energy=1; game.players[18].exhausted=false
	var fresh_arrival: float=game.ai_attack.delivery.arrival(game.players[18],game.players[18].position+Vector3(15,0,0))
	game.players[18].energy=.1
	check(game.ai_attack.delivery.arrival(game.players[18],game.players[18].position+Vector3(15,0,0))>fresh_arrival,"A tired receiver is evaluated at their real reduced running speed")
	keeper_setup(); game.menu_match.running=false
	player(0,Vector3(0,0,45)); game.ball.hold(game.players[0]); game.goalkeeping.holding=0
	check(not game.ai_attack.distribute(0),"Our keeper's distribution still belongs to the user")
	keeper_setup(); game.ball.release_hold(); game.goalkeeping.holding=-1
	game.ball.position=game.players[11].position+Vector3(0,game.ball.GROUND_HEIGHT,.5)
	check(game.ai_attack.keeper_foot_pass(11) and game.kick_contact.pending.ai_choice.receiver==15,"A keeper receiving a back pass selects an open teammate instead of a fixed clearance")
	setup(); player(18,Vector3(27,0,2)); player(19,Vector3(25,0,15)); player(4,Vector3(30,0,8))
	restart("TAÇ",Vector3(game.P.HALF_WIDTH,0,0))
	check(game.set_pieces.plan_ai() and game.set_pieces.receiver>=0 and game.set_pieces.pending_velocity.x<0,"AI throw-in identifies a teammate and throws into the pitch")
	for p in game.players: p.visible=false
	player(20,game.restart_point); game.set_pieces.ready_age=3.2
	check(game.set_pieces.plan_ai() and game.set_pieces.receiver<0 and game.set_pieces.pending_velocity.x<0 and game.flat_distance(game.ball.position,game.set_pieces.target)<=25.01,"A covered throw-in has a bounded fallback evaluated at its actual landing point")
	setup(); player(18,Vector3(5,0,40)); player(19,Vector3(24,0,39)); player(4,Vector3(5,0,40.5))
	restart("KORNER",Vector3(game.P.HALF_WIDTH-.4,0,49.6))
	check(game.set_pieces.plan_ai() and game.set_pieces.receiver==19,"A corner can use the open short option instead of feeding the marked central attacker")
	await keeper_flow(1,false)
	await keeper_flow(2,false)
	await keeper_flow(1,true)
	await keeper_flow(1,false,true)
	keeper_setup(); game.controlled=9
	var point: Vector3=game.players[11].position
	restart("KALE VURUŞU",point)
	game.set_pieces.recovery.phase="ready"; game.set_pieces.recovery.worker=11
	for p in game.players:
		p.collision_layer=2 if p.visible else 0; p.collision_mask=3
	game.ball.freeze=false; game.ball.place(point+Vector3.UP*game.ball.GROUND_HEIGHT)
	await physics_frame; await physics_frame
	var goal_kick_received := false
	for tick in range(720):
		game.simulate_match(DT); await physics_frame
		if game.dribbler==15: goal_kick_received=true; break
	check(goal_kick_received and game.passes[1]>0 and game.last_touch==1,"A goal kick completes its real run-up, release and controlled reception")
	print("AI DELIVERY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
