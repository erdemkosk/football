extends "res://tests/attack_decisions_check.gd"

func scoring_scene(half: int,side: float) -> void:
	setup(); game.half=half
	var f: float=game.attack_sign(1)
	player(20,Vector3(side*13,0,f*33)); possession(20)
	player(18,Vector3(0,0,f*40))
	player(0,Vector3(0,0,f*49)); player(2,Vector3(-27,0,f*48))

func scoring_choices() -> void:
	for half in [1,2]:
		for side in [-1.0,1.0]:
			scoring_scene(half,side)
			var choice: Dictionary=game.ai_attack.decide(20)
			check(choice.get("receiver",-1)==18 and choice.kind=="square","A safe central layoff beats the narrow-angle shot, half=%d side=%s" % [half,side])
			check(act_and_contact(20) and game.passes[1]==1 and game.shots[1]==0,"The selected layoff completes through actual boot contact")
			scoring_scene(half,side)
			player(4,game.players[20].position.lerp(game.players[18].position,.5))
			player(5,game.players[18].position+Vector3(.5,0,0))
			check(game.ai_attack.decide(20).get("receiver",-1)!=18,"A blocked layoff does not receive a forced scoring bonus")
			scoring_scene(half,side)
			game.players[18].position.z=game.attack_sign(1)*49
			check(game.ai_attack.decide(20).get("receiver",-1)!=18,"The better finishing position must still be onside")
	setup(Vector3(0,0,33)); player(18,Vector3(-8,0,25))
	check(kind()=="shot","A clear central shot is retained instead of an unnecessary backward pass")

func deceptive_scene(half: int) -> Dictionary:
	team_shape(half)
	var shape=game.support.shape
	var runner: int=shape.jobs.channel_run
	var decoy: int=shape.jobs.short_outlet
	var f: float=game.attack_sign(1)
	player(runner,Vector3(3,0,f*7))
	player(decoy,Vector3(-4,0,f*4))
	player(4,game.players[runner].position+Vector3(.6,0,f*1.8))
	player(5,game.players[decoy].position+Vector3(.3,0,f*1.5))
	game.support.plan_age=0
	game.support.update(.1)
	game.ai_attack.think_in[20]=10
	return {"runner":runner,"decoy":decoy,"forward":f}

func deceptive_runs() -> void:
	for half in [1,2]:
		var info := deceptive_scene(half)
		var runner=game.players[info.runner]
		var moves=game.support.movements
		check(not moves.active.is_empty() and game.support.roles[info.runner]=="check_run","A marked channel runner offers a short option before breaking, half=%d" % half)
		if moves.active.is_empty(): continue
		var check_target: Vector3=game.support.targets[info.runner]
		check(check_target.distance_to(game.players[20].position)<runner.position.distance_to(game.players[20].position),"The initial target actually moves toward the ball")
		check(moves.active.decoy==info.decoy and game.support.roles[info.decoy]=="decoy_run","A second marked outlet draws outward on a separate route")
		var marker_position: Vector3=game.players[4].position
		var origin: Vector3=runner.position
		var decoy_origin: Vector3=game.players[info.decoy].position
		for tick in range(24):
			game.update_ai(DT); runner.step(DT); game.players[info.decoy].step(DT); await physics_frame
		check(runner.position.distance_to(game.players[20].position)<origin.distance_to(game.players[20].position)-.1,"The check uses real running steps")
		if half==1: await capture("check",Vector3(0,0,6))
		for tick in range(72):
			game.update_ai(DT); runner.step(DT); game.players[info.decoy].step(DT); await physics_frame
		check(not moves.active.is_empty() and moves.active.phase=="burst" and runner.sprinting,"The runner turns and accelerates into the channel")
		check(game.players[info.decoy].position.distance_to(decoy_origin)>.7,"The companion's decoy route also moves a real player")
		if half==1: await capture("burst",Vector3(0,0,6))
		check(game.players[4].position==marker_position,"A decoy never moves or stuns the defender")
		game.players[2].position.z=info.forward*8
		game.support.update(DT)
		check(game.support.targets[info.runner].z*info.forward<=maxf(0,game.rules.offside_line(1)-.8),"The run reacts immediately to a higher offside line")
		game.support.assign_run(info.runner,runner.position+Vector3(-5,0,0),"come_short",2)
		game.support.runs[info.runner].owner=20
		game.support.update(DT)
		check(moves.active.is_empty() and game.support.roles[info.runner]=="come_short","An explicit run command cancels the automatic feint")
	var info := deceptive_scene(1)
	game.ai_receivers[1]=info.runner; game.ai_pass_time[1]=2
	game.support.update(DT)
	check(game.support.movements.active.is_empty(),"An actual pass receiver leaves the deceptive movement immediately")
	info=deceptive_scene(1)
	game.state="restart"; game.support.update(.1)
	check(game.support.movements.active.is_empty(),"A whistle cancels the attacking movement")
	info=deceptive_scene(1)
	player(9,Vector3.ZERO); possession(9); game.support.update(.1)
	check(game.support.movements.active.is_empty() or game.support.movements.active.team==0,"Possession loss cancels the old team's movement")
	team_shape(); game.support.update(.5)
	check(game.support.movements.active.is_empty(),"An unmarked runner attacks open space without a needless check")
	info=deceptive_scene(1)
	game.support.update(2.5); game.support.update(.11)
	check(game.support.movements.active.is_empty(),"A finished feint has a cooldown before another attempt")
	info=deceptive_scene(1)
	game.controlled=info.runner; game.support.update(DT)
	check(game.support.movements.active.is_empty(),"Taking control of the runner ends the automatic movement")
	info=deceptive_scene(1)
	game.players[info.runner].energy=.1; game.support.update(.11)
	check(game.support.movements.active.is_empty(),"A tired runner leaves the demanding deceptive movement")

func duel_styles() -> void:
	setup(); player(9,Vector3(.98,0,0),Vector3.BACK*2.5)
	var p=game.players[9]
	game.players[20].velocity=Vector3.BACK*2.5
	game.ball.linear_velocity=Vector3.BACK*6
	p.attributes.strength=92; p.attributes.agility=48
	p.attributes.tackling=80; p.attributes.reactions=80; p.Attributes.refresh(p)
	var strong: Vector3=game.duels.pressure_target(9,20)
	check(game.duels.prefers_shoulder(9,20),"A strong marker uses safe side pressure while the ball is not ready for a poke")
	p.attributes.strength=48; p.attributes.agility=92; p.Attributes.refresh(p)
	var agile: Vector3=game.duels.pressure_target(9,20)
	check(absf(strong.x)<absf(agile.x) and agile.z>strong.z,"A strong player closes the body gap; a nimble player gets level with the foot opening")
	check(not game.duels.prefers_shoulder(9,20),"A nimble marker does not repeatedly shove a close-control runner")
	game.players[20].active_sprint=true
	check(game.duels.prefers_shoulder(9,20),"An exposed sprint still permits a nimble player's legal shoulder challenge")
	game.players[20].active_sprint=false
	p.position=Vector3.ZERO; p.velocity=Vector3.ZERO
	game.ball.position=Vector3(0,.155,.84); game.ball.linear_velocity=Vector3(3.2,0,0)
	p.attributes.reactions=35; p.Attributes.refresh(p)
	var slow: float=game.duels.reaction_time(9)
	var reach: float=game.duels.poke_reach(20)*game.duels.tackle_reach(p)
	check(game.duels.ai_poke_window(9,20),"A less perceptive marker stabs early at a ball cutting across him")
	p.attributes.reactions=95; p.Attributes.refresh(p)
	check(game.duels.reaction_time(9)<slow and not game.duels.ai_poke_window(9,20),"A better reader reacts sooner but waits when the cut will escape his boot")
	check(is_equal_approx(reach,game.duels.poke_reach(20)*game.duels.tackle_reach(p)),"Reading skill changes timing without extending the physical boot")

func follow_up() -> void:
	setup()
	for p in game.players: p.visible=false; p.collision_layer=0
	player(9,Vector3.ZERO); player(20,Vector3(.65,0,-.75))
	for i in [9,20]: game.players[i].collision_layer=2; game.players[i].collision_mask=3
	game.players[9].facing=Vector3.FORWARD
	game.controlled=0; game.foul_cooldown=0
	game.ball.freeze=false; game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,-.65))
	await physics_frame; await physics_frame
	game.dribbler=20; game.carrier=20; game.last_touch=1; game.kick_lock=0
	game.duels.standing_tackle(9); game.players[9].step(.13); game.duels.resolve(.13)
	check(game.last_kicker==9 and game.second_balls.source=="tackle" and game.second_balls.duelists==[9,20],"A real clean tackle starts a follow-up for both original participants")
	var recovery: float=game.players[9].action_timer
	game.second_balls.update(DT)
	check(game.second_balls.targets.size()==2 and game.second_balls.targets.has(9) and game.second_balls.targets.has(20),"One player from each team contests the loose tackle ball")
	check(game.dribbler==-1 and game.players[9].action_timer==recovery and recovery>0,"The follow-up grants neither possession nor instant recovery")
	game.controlled=9; game.players[9].desired=Vector3.LEFT
	game.update_ai(DT)
	check(game.players[9].desired==Vector3.LEFT,"A follow-up target never overrides human movement")
	game.controlled=0
	# The carrier's last dribble touch is still recovering as the ball is
	# poked free. This leaves a real chase after the winner's planting step.
	game.players[20].touch_cooldown=.35
	var followed := false
	var recovered := false
	for tick in range(180):
		game.simulate_match(DT); await physics_frame
		if game.players[9].action_timer<=0 and game.players[9].desired.dot(game.ball.position-game.players[9].position)>.1: followed=true
		if game.dribbler in [9,20]: recovered=true; break
	print("FOLLOW-UP ",{"followed":followed,"recovered":recovered,"owner":game.dribbler,"state":game.state})
	check(followed and recovered,"After planting, a real chase reaches and controls the loose ball")
	game.second_balls.update(DT)
	check(game.second_balls.targets.is_empty(),"Securing the ball ends the follow-up")
	game.second_balls.challenged(9,20)
	check(game.commit_strike(9,Vector3.RIGHT*8,0,false,"kick",true) and game.second_balls.remaining==0,"The next controlled pass cancels the old tackle chase")
	game.dribbler=-1; game.second_balls.challenged(9,20)
	game.state="restart"; game.second_balls.update(DT)
	check(game.second_balls.remaining==0 and game.second_balls.duelists.is_empty(),"A whistle clears the tackle follow-up")

func capture(label: String,centre: Vector3) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	game.hud.hide()
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=44
	game.camera.position=centre+Vector3(14,17,-19)
	game.camera.look_at(centre)
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-attacking-"+label+".png")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-attacking-flow.cfg"
	scoring_choices()
	await deceptive_runs()
	duel_styles()
	await follow_up()
	print("ATTACKING FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
