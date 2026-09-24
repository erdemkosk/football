extends "res://tests/ai_attack_check.gd"

func restart(half: int=1,depth: float=27,rain: bool=false) -> void:
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.half=half; game.management.apply_formation(); game.rng.seed=541
	game.weather.select(2 if rain else 0,true)
	game.begin_restart("SERBEST VURUŞ",1,Vector3(3,0,depth*game.attack_sign(1)))
	game.set_pieces.snap_ready(); game.state="set_piece"
	for frame in range(3): await physics_frame
	game.set_pieces.ready_age=1.2

func queue_restart() -> void:
	var sp=game.set_pieces
	check(sp.plan_ai(),"The opponent has a real restart plan")
	var p=game.players[sp.taker]
	p.position=game.restart_point-sp.direction*.48
	p.velocity=Vector3.ZERO; p.facing=sp.direction
	p.rig.rotation.y=atan2(-p.facing.x,-p.facing.z); p.animate(1)
	sp.launch()
	check(game.kick_contact.pending.has("restart"),"The run-up queues a physical restart contact")

func protected_restart(label: String) -> void:
	check(game.state=="set_piece" and game.restart_team==1 and game.kick_contact.pending.is_empty(),"An unstruck free kick remains the opponent's protected restart: "+label)
	check(game.shots[1]==0 and game.passes[1]==0 and game.ball.linear_velocity.length()<.5 and not game.ball.pending_kick,"An unstruck restart neither registers a kick nor donates a moving ball: "+label)
	check(game.support.runs.is_empty() and game.ai_receivers[1]==-1 and game.set_pieces.runup<0,"Cancelled contact clears the old run-up and receiving jobs: "+label)

func complete_restart(label: String) -> void:
	var before: int=game.kick_contact.contacts
	var taker: int=game.set_pieces.taker
	var donated := false
	for frame in range(600):
		game._physics_process(DT)
		await physics_frame
		if game.kick_contact.contacts>before: break
		if game.state=="playing" and game.kick_contact.pending.is_empty(): donated=true; break
	check(not donated and game.kick_contact.contacts==before+1 and game.last_kicker==taker,"The AI retries and makes actual boot contact before leaving the ball: "+label)
	check(game.state=="playing" and game.ball.linear_velocity.length()>6 and game.shots[1]+game.passes[1]==1,"One successful restart launches the ball and counts exactly once: "+label)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-restart-contact.cfg"
	# A recovery pose can reject queue(); launch must not fall through to play.
	await restart(); game.set_pieces.plan_ai()
	game.players[game.set_pieces.taker].action_timer=.3
	game.set_pieces.launch()
	protected_restart("preparation rejected")
	await complete_restart("preparation rejected")
	# Preparation can also be interrupted after launch accepted the request.
	await restart(2); queue_restart()
	game.players[game.set_pieces.taker].action_timer=.3
	game.kick_contact.prepare(DT)
	protected_restart("interrupted backswing")
	await complete_restart("interrupted backswing")
	# A short swing that fails to reach the actual ball must be retried.
	await restart(1,27,true); queue_restart()
	game.players[game.set_pieces.taker].position.x+=2
	game.kick_contact.pending.age=.2
	game.kick_contact.resolve()
	protected_restart("missed boot contact")
	await complete_restart("missed boot contact")
	# A deep free kick is a pass; cancel safely if its route closes at contact.
	await restart(2,-24); queue_restart()
	var delivery: Dictionary=game.kick_contact.pending.restart.choice
	check(delivery.has("route") and delivery.kind!="clearance","The deep free kick selects a teammate")
	if delivery.has("route"):
		game.players[9].position=delivery.route.target*Vector3(1,0,1)
		for frame in range(30):
			if game.kick_contact.pending.is_empty(): break
			game.kick_contact.prepare(DT)
			game.players[game.set_pieces.taker].step(DT)
			game.kick_contact.resolve()
		protected_restart("passing lane closed")
		await complete_restart("passing lane closed")
	# Already recorded statistics survive a rejected queue (no false rollback).
	await restart(); game.shots[1]=3; game.passes[1]=4
	game.set_pieces.plan_ai(); game.players[game.set_pieces.taker].action_timer=.3
	game.set_pieces.launch()
	check(game.shots[1]==3 and game.passes[1]==4,"Rejecting an uncounted preparation preserves previous match statistics")
	await restart(); queue_restart()
	game.ball.position.x+=1.5
	var displaced: Vector3=game.ball.position
	game.kick_contact.pending.age=.2
	game.kick_contact.resolve()
	check(game.state=="restart" and game.restart_team==1 and game.restart_type=="SERBEST VURUŞ" and game.shots[1]==0,"A displaced, unstruck ball returns to protected free-kick retrieval")
	check(game.ball.position==displaced and game.set_pieces.recovery.phase=="watch","Recovering a displaced ball uses the real retrieval sequence without teleporting it")
	# A real new whistle supersedes the old kick instead of restoring it.
	await restart(); queue_restart()
	game.state="restart"; game.restart_team=0
	game.kick_contact.prepare(DT)
	check(game.state=="restart" and game.restart_team==0 and game.kick_contact.pending.is_empty(),"A new restart keeps its team and state when an old backswing is discarded")
	for half in [1,2]:
		for depth in [27.0,-24.0]:
			await restart(half,depth)
			await complete_restart("normal half=%d depth=%.0f" % [half,depth])
	print("RESTART CONTACT CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
