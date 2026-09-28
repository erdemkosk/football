extends "res://tests/motion_contact_check.gd"

func snapshot(label: String,actor=p) -> void:
	if not visual: return
	game.match_menu.display.select_resolution(Vector2i(1280,800))
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=40
	game.camera.position=actor.position+Vector3(3,2.1,-3.8)
	game.camera.look_at(actor.position+Vector3(0,.95,0))
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://artifacts/match-animations/"+label+".png")

func pass_variants() -> void:
	for rate in [30,60,120]:
		for scenario in [["compact",Vector3.FORWARD*10],["outside_pass",Vector3(10,0,-4)],["backheel",Vector3.BACK*10]]:
			setup(); game.ball.position=p.position+Vector3(.18,.23,-.55)
			var start: Vector3=p.position
			check(game.strike(9,scenario[1]),"Context pass queues at %d Hz: %s" % [rate,scenario[0]])
			check(p.kick_style==scenario[0],"Angle selects %s without changing the intended pass" % scenario[0])
			for frame in range(ceili(rate*.16)):
				tick(1.0/rate)
				if game.ball.pending_kick: break
			check(game.ball.pending_kick and game.feedback.event_count==1 and game.kick_contact.last_gap<=.36,"Exactly one physical %s contact at %d Hz" % [scenario[0],rate])
			check(game.strike_quality.last.get("intended",Vector3.ZERO).distance_to(scenario[1])<.001 and p.position.distance_to(start)<.04,"Pass animation preserves aim and does not move the body")
			if rate==120:
				await snapshot(scenario[0])

func receptions() -> void:
	for scenario in [["half_turn",Vector3(.05,.23,-.6),Vector3.RIGHT,Vector3.BACK*9,0.0],["trailing",Vector3(-.20,.23,.35),Vector3.FORWARD,Vector3.FORWARD*8,0.0],["reach",Vector3(.62,.23,-.85),Vector3.FORWARD,Vector3.BACK*8,.75]]:
		setup(); p.velocity=Vector3.FORWARD*4; p.desired=scenario[2]
		p.ball_actions.intent_direction=scenario[2]
		var point: Vector3=p.position+scenario[1]
		game.ball.position=point
		p.begin_receive("foot",point,scenario[3],scenario[4])
		p.ball_actions.receive_direction=scenario[2]; p.ball_actions.receive_distance=.8
		p.ball_actions.configure_receive(p)
		check(p.ball_actions.receive_variant==scenario[0],"Receive selects "+scenario[0])
		var velocity: Vector3=p.velocity
		p.receive_timer=p.receive_duration*.60; p.animate(.12)
		check(p.velocity==velocity and p.desired==scenario[2] and game.ball.position==point and p.action_timer==0,"Reception pose preserves input, momentum and physical ball")
		var boot: Vector3=(p.left_knee if p.ball_actions.receive_foot==0 else p.right_knee).to_global(p.ball_actions.BOOT)
		check(boot.distance_to(point)<.55,"Receiving boot stays close to the real "+scenario[0]+" contact")
		await snapshot(scenario[0])
	setup(); p.ball_actions.intent_direction=Vector3.RIGHT
	check(p.ball_actions.receiving_foot(p,p.position+Vector3(0,.23,-.5))==1,"Half-turn selects the opening foot for a central delivery")
	check(p.ball_actions.receiving_foot(p,p.position+Vector3(-.55,.23,-.5))==0,"A wide delivery retains the physically nearer foot")
	p.desired=Vector3.RIGHT; game.ball.position=p.position+Vector3(0,.23,-2)
	game.ball.linear_velocity=Vector3.BACK*8; game.last_touch=p.team; game.last_kicker=5; game.dribbler=-1
	p.contextual_motion.observe(game,9,.1); p.animate(.1)
	check(p.contextual_motion.preparation>.2 and absf(p.spine.rotation.y)>.05,"Incoming pass visibly opens the body before contact")
	await snapshot("prepare-half-turn")

func blocks() -> void:
	for side in [-1.0,1.0]:
		for height in [.35,1.0]:
			setup(); game.last_touch=1; game.last_kicker=20; game.dribbler=-1
			game.ball.position=p.position+Vector3(side*.65,height,-4)
			game.ball.linear_velocity=Vector3.BACK*22
			p.contextual_motion.observe(game,9,DT)
			check(p.contextual_motion.block==("leg" if height<.65 else "body"),"Incoming shot selects a height-aware block on either side")
			p.contextual_motion.block_age=.13; p.animate(.13)
			check(p.action_timer==0 and p.desired==Vector3.ZERO and p.velocity==Vector3.ZERO,"Block animation adds no automatic lunge or movement lock")
			game.ball.position=p.position+Vector3(3,height,-1)
			p.contextual_motion.resolve_block(game,9)
			check(not game.ball.pending_touch,"A visible block cannot deflect a distant ball")
			if height<.65:
				var boot: Vector3=(p.left_knee if p.contextual_motion.block_foot==0 else p.right_knee).to_global(p.ball_actions.BOOT)
				game.ball.position=boot+Vector3.FORWARD*.22
				p.contextual_motion.resolve_block(game,9)
				check(game.ball.pending_touch and game.last_touch==p.team and game.ball.touch_velocity.length()<22,"Only a measured boot collision deflects the shot with energy loss")
			if side>0: await snapshot("block-leg" if height<.65 else "block-body")

func hurdles() -> void:
	setup(); game.ball.position=p.position+Vector3(0,.23,-6)
	for frame in range(8): p.step(DT); await physics_frame
	var q=game.players[20]; q.visible=true; q.position=p.position+Vector3(-.22,0,-1.6)
	q.pose="slide"; q.action_timer=.9; q.velocity=Vector3.BACK*8; q.facing=Vector3.BACK
	p.velocity=Vector3.RIGHT*4; p.desired=Vector3.RIGHT; game.rules.tackles={20:q.position}
	p.contextual_motion.observe(game,9,DT)
	check(p.pose=="hurdle" and p.velocity.y>3 and p.action_timer>.3,"An early moving sidestep can lift over a sliding leg")
	var layer: int=p.collision_layer
	for frame in range(13):
		p.contextual_motion.observe(game,9,DT); p.step(DT); await physics_frame
	check(p.position.y>.1 and p.collision_layer==layer and p.velocity.x>3,"Hop uses real gravity and keeps horizontal control and collisions")
	q.animate(.1)
	await snapshot("hurdle")
	p.desired=Vector3.LEFT
	for frame in range(55):
		p.contextual_motion.observe(game,9,DT); p.step(DT); await physics_frame
	check(p.action_timer==0 and p.is_on_floor() and p.velocity.x<0,"Hop lands and accepts a direction change without waiting for a cutscene")
	setup()
	for frame in range(8): p.step(DT); await physics_frame
	q.visible=true; q.position=p.position+Vector3.FORWARD*1.6; q.pose="slide"; q.action_timer=.9; q.velocity=Vector3.BACK*8
	p.velocity=Vector3.FORWARD*4; p.desired=Vector3.FORWARD; game.rules.tackles={20:q.position}
	p.contextual_motion.observe(game,9,DT)
	check(p.pose!="hurdle","A head-on tackle grants no automatic escape")

func marking() -> void:
	setup(); var q=game.players[20]; q.visible=true; q.position=p.position+Vector3(1,0,-2); q.desired=Vector3.LEFT
	game.support.movements.active={"runner":9,"marker":20,"phase":"check","target":p.position+Vector3(4,0,-6)}
	var position: Vector3=p.position
	p.contextual_motion.observe(game,9,.12); p.animate(.12)
	check(p.contextual_motion.run_kind=="check" and absf(p.spine.rotation.z)>.05,"Marked runner shows a loaded checking step")
	await snapshot("check-run")
	game.support.movements.active.phase="burst"
	p.contextual_motion.observe(game,9,.12); q.contextual_motion.observe(game,20,.12)
	p.animate(.12); q.animate(.12)
	check(p.contextual_motion.run_kind=="burst" and q.contextual_motion.run_kind=="track","Burst and defender hip opening follow the existing marking decision")
	check(p.position==position and q.desired==Vector3.LEFT,"Marking animation never moves or stuns the defender")
	await snapshot("burst-run")
	await snapshot("defender-track",q)
	game.support.movements.active.clear(); p.contextual_motion.observe(game,9,1)
	check(p.contextual_motion.run_weight==0,"Run gesture fades after the tactical movement ends")

func high_saves() -> void:
	for team in [0,1]:
		for kind in ["punch","tip"]:
			setup(); p.hide(); var keeper=game.players[team*11]; keeper.show()
			keeper.position=Vector3(0,0,-game.attack_sign(team)*47)
			keeper.facing=Vector3(0,0,game.attack_sign(team)); keeper.rig.rotation=Vector3(0,PI if keeper.facing.z>0 else 0,0)
			keeper.action_timer=0; keeper.tackle_cooldown=0; keeper.animate(1)
			var target: Vector3=keeper.position+keeper.facing*.25+Vector3(.15,2.1,0)
			keeper.start_claim(2.1,.3); keeper.keeper_motion.high_save(keeper,kind,target)
			keeper.action_timer=.60; keeper.animate(.2)
			check(keeper.keeper_motion.special(keeper),"High save has a distinct "+kind+" pose on team "+str(team))
			check(not keeper.can_save(target+Vector3.RIGHT*4),"High save cannot reach a remote ball")
			var hand: Vector3=keeper.left_hand.global_position if keeper.keeper_motion.foot==0 else keeper.right_hand.global_position
			game.ball.position=hand; game.ball.linear_velocity=-keeper.facing*22; game.last_touch=1-team; game.last_kicker=9 if team==1 else 20
			game.ball.pending_kick=false; game.kick_lock=0; keeper.touch_cooldown=0
			check(keeper.can_save(hand),"High save requires physical glove proximity")
			game.goalkeeping.reads[team*11]={"kicker":game.last_kicker,"age":1.0,"delay":.2,"next_read":10.0,"set":keeper.position,"x":hand.x,"height":hand.y,"error":0.0,"height_error":0.0,"handling":1.0,"screened":false}
			game.goalkeeping.update(team*11,DT)
			check(game.ball.pending_kick and game.ball.held_by==null and game.saves[team]==1,"Actual "+kind+" contact deflects once without accidentally catching")
			check(game.ball.kick_velocity.y>4 and game.ball.kick_velocity.z*game.attack_sign(team)*(1 if kind=="punch" else -1)>0,"Punch clears forward; fingertips redirect up and behind")
			if team==0: await snapshot("keeper-"+kind,keeper)

func save_selection() -> void:
	for team in [0,1]:
		for kind in ["punch","tip"]:
			setup(); p.hide(); var keeper=game.players[team*11]; keeper.show()
			var forward: float=game.attack_sign(team)
			keeper.position=Vector3(0,0,-forward*47); keeper.facing=Vector3(0,0,forward)
			keeper.rig.rotation=Vector3(0,PI if forward>0 else 0,0)
			keeper.action_timer=0; keeper.tackle_cooldown=0
			for frame in range(8): keeper.step(DT); await physics_frame
			game.last_touch=1-team; game.last_kicker=9 if team==1 else 20; game.dribbler=-1
			if kind=="punch":
				game.ball.position=keeper.position+Vector3(-2,2.4,0); game.ball.linear_velocity=Vector3.RIGHT*10
				var attacker=game.players[game.last_kicker]; attacker.show(); attacker.position=keeper.position+Vector3(.6,0,0)
			else:
				game.ball.position=keeper.position+keeper.facing*7+Vector3.UP*2.3; game.ball.linear_velocity=-keeper.facing*24
				game.goalkeeping.reads[team*11]={"kicker":game.last_kicker,"age":1.0,"delay":.2,"next_read":10.0,"set":keeper.position,"x":0.0,"height":2.25,"error":0.0,"height_error":0.0,"handling":1.0,"screened":false}
			game.goalkeeping.update(team*11,DT)
			check(keeper.keeper_motion.special(keeper) and keeper.keeper_motion.kind==kind,"Live trajectory automatically chooses "+kind+" for team "+str(team))

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-context-animations.cfg"; p=game.players[9]
	if visual:
		game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1280,800))
	await pass_variants(); await receptions(); await blocks(); await hurdles(); await marking(); await high_saves(); await save_selection()
	setup(); p.contextual_motion.block="body"; p.contextual_motion.block_age=.1
	game.state="paused"; game.simulate_match(.2)
	check(p.contextual_motion.block_age==.1,"Pause preserves and freezes contextual animation state")
	game.state="playing"; game.reset_practice()
	check(not p.contextual_motion.active(),"Restart clears every contextual pose")
	print("CONTEXTUAL ANIMATION CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
