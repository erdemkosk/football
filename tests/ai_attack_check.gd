extends SceneTree
const DT := 1.0/120
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func player(index: int,at: Vector3,velocity: Vector3=Vector3.ZERO) -> void:
	var p=game.players[index]
	p.visible=true; p.position=at; p.velocity=velocity; p.desired=Vector3.ZERO
	p.facing=Vector3(0,0,game.attack_sign(p.team)); p.ai_think=3
	p.action_timer=0; p.touch_cooldown=0; p.kick_timer=0
func possession(index: int) -> void:
	game.ball.position=game.players[index].position+Vector3(0,.23,game.attack_sign(game.players[index].team)*.65)
	game.ball.pending_reset=false; game.ball.pending_kick=false; game.ball.pending_touch=false
	game.ball.linear_velocity=Vector3.ZERO; game.kick_lock=0
	game.dribbler=index; game.carrier=index; game.last_touch=game.players[index].team
	game.players[index].ai_think=3; game.players[index].touch_cooldown=0; game.players[index].kick_timer=0
func setup(at: Vector3=Vector3.ZERO) -> void:
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.ball.freeze=true; game.management.difficulty=2
	game.rng.seed=541; game.controller.held.clear(); game.controller.stick=Vector2.ZERO
	for p in game.players:
		p.visible=false; p.collision_layer=0; p.collision_mask=1
		p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	# A real second-last defender keeps intended attacking receivers onside.
	player(0,Vector3(0,0,49)); player(2,Vector3(-27,0,48))
	player(20,at); possession(20)
func kind(index: int=20) -> String:
	return game.ai_attack.decide(index).get("kind","")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-ai-attack-test.cfg"
	setup(Vector3(0,0,33))
	check(kind()=="shot" and game.ai_attack.act(20) and game.shots[1]==1 and game.ball.pending_kick,"A clear scoring position produces a physical shot")
	setup(Vector3(13,0,33))
	check(kind()=="finesse" and absf(game.ai_attack.decide(20).curve)>0,"A wide scoring angle can use a curled shot")
	setup(Vector3(0,0,33)); game.players[0].position.z=41
	check(kind()=="chip" and game.ai_attack.act(20) and game.ball.kick_velocity.y>6,"An advancing goalkeeper invites a genuine lofted chip")
	setup(); player(18,Vector3(-6,0,12),Vector3(0,0,4))
	var route: Dictionary=game.ai_attack.decide(20)
	check(route.kind=="through" and route.route.target.z>game.players[18].position.z+4,"A teammate running forward receives a pass into the space ahead")
	check(game.ai_attack.act(20) and game.passes[1]==1 and game.ai_receivers[1]==18,"The through pass uses normal ball physics and receiver tracking")
	setup(); player(18,Vector3(-6,0,49),Vector3(0,0,4))
	check(not game.ai_attack.onside(18,1) and kind()!="through","An offside run is not selected for a through pass")
	setup(Vector3(4,0,0)); player(18,Vector3(-3,0,7)); player(4,Vector3(8,0,0))
	check(kind()=="one_two" and game.ai_attack.act(20),"Nearby pressure with a safe wall player triggers a one-two")
	check(game.support.runs.has(20) and game.support.runs[20].get("explicit",false) and game.support.runs[20].time<=3,"The AI passer starts the same bounded three-second run as the user")
	game.players[20].position=Vector3(1,0,12); game.players[20].action_timer=0
	possession(18)
	check(kind(18)=="return_pass" and game.ai_attack.act(18) and game.passes[1]==2 and not game.support.runs.has(20),"The wall player returns the ball and ends the original run")
	setup(Vector3(26,0,33)); player(18,Vector3(1,0,40))
	route=game.ai_attack.decide(20)
	check(route.kind=="cross" and route.route.target.y>1.7 and route.route.velocity.y>5,"A wide attack targets a teammate at head height with an aerial cross")
	check(game.ai_attack.act(20) and game.last_kicker==20 and game.ai_receivers[1]==18,"The cross is kicked by the winger with no ball teleport")
	setup(Vector3(23,0,44)); player(18,Vector3(4,0,38))
	check(kind()=="driven_cross" and game.ai_attack.act(20) and game.ball.kick_velocity.y<.2 and game.ball.kick_velocity.length()>27,"A clear byline cutback becomes a hard ground cross")
	setup(Vector3(20,0,4)); player(18,Vector3(-24,0,6)); player(4,Vector3(24,0,4))
	check(kind()=="switch" and game.ai_attack.act(20) and game.ball.kick_velocity.x< -10 and game.ball.kick_velocity.y>6,"Pressure on one wing prompts a lofted switch toward the free opposite wing")
	setup(); player(4,Vector3(1.8,0,0))
	game.charging=true; game.charge=.4
	var stamina: float=game.players[20].energy
	check(kind()=="feint" and game.ai_attack.act(20) and game.players[20].feint_time>0 and game.players[20].energy<stamina,"Close pressure and lateral space trigger a stamina-consuming body feint")
	check(game.charging and game.charge==.4 and not game.ai_attack.act(20),"An opponent feint does not cancel user input or repeat every simulation tick")
	setup()
	stamina=game.players[20].energy
	check(kind()=="push" and game.ai_attack.act(20) and game.ball.pending_kick and game.players[20].energy<stamina,"Open grass allows the AI to push the real ball ahead at a stamina cost")
	setup(); player(18,Vector3(10,0,-10)); game.ai_attack.skill_in[20]=2
	check(kind()=="pass" and game.ai_attack.act(20) and game.passes[1]==1,"The AI can recycle possession with an ordinary safe pass")
	setup(Vector3(0,0,-40)); player(4,Vector3(1.8,0,-40))
	check(kind()=="clearance" and game.ai_attack.act(20) and game.ball.kick_velocity.z>8,"A trapped defender with no safe outlet clears toward the flank")
	setup(); player(9,Vector3(0,0,-30)); possession(9)
	check(not game.ai_attack.act(9) and not game.ball.pending_kick and game.passes[0]==0 and game.shots[0]==0,"The user team never passes, shoots, or performs possession skills without permission")
	setup(Vector3(0,0,33)); game.ball.position.x=5
	check(not game.ai_attack.act(20) and not game.ball.pending_kick,"AI decisions cannot remotely kick a ball outside foot reach")
	# Exercise shared heading contact with a real flying RigidBody, no forced touch.
	for intent in ["shot","clearance","pass"]:
		setup(Vector3(0,0,40 if intent=="shot" else (-35 if intent=="clearance" else 0)))
		var p=game.players[20]
		if intent=="pass": player(18,Vector3(-7,0,5))
		p.body_language.enabled=false; p.rig.rotation=Vector3.ZERO
		p.head_joint.rotation=Vector3.ZERO; p.animate(1)
		for tick in range(5): p.step(DT); await physics_frame
		game.ball.freeze=false
		game.ball.place(p.position+Vector3(-4,2.85,.1),Vector3(11,0,0))
		await physics_frame; await physics_frame
		game.dribbler=-1; game.carrier=-1; game.last_kicker=-1
		check(game.ai_attack.try_header(20),"AI recognizes a reachable incoming ball for header "+intent)
		var contact := false
		var gap := INF
		for tick in range(95):
			game.kick_lock=maxf(0,game.kick_lock-DT)
			game.heading.prepare(DT); p.step(DT)
			var before: Vector3=game.ball.position
			game.heading.resolve()
			if game.last_kicker==20:
				contact=true; gap=game.heading.head_point(p).distance_to(game.ball.position)
				check(game.ball.position==before,"AI header "+intent+" changes velocity without moving the ball")
				break
			await physics_frame
		check(contact and gap<.54 and p.kick_timer==0,"AI header "+intent+" waits for actual animated head contact")
		check(game.shots[1]==(1 if intent=="shot" else 0) and game.passes[1]==(1 if intent=="pass" else 0),"Header "+intent+" records the appropriate match statistic")
		check(game.ball.kick_velocity.z>0,"Header "+intent+" sends the ball away from the AI's own goal")
	setup(); game.half=2; player(20,Vector3(0,0,-33)); possession(20)
	game.players[0].position.z=-49; game.players[2].position.z=-48
	check(game.ai_attack.act(20) and game.ball.kick_velocity.z<0,"AI attacking decisions reverse with second-half ends")
	print("AI ATTACK CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
