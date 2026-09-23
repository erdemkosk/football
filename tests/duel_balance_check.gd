extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func arrange(victim: Vector3,ball: Vector3,facing: Vector3=Vector3.FORWARD) -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	game.controlled=9
	for i in range(22):
		var p=game.players[i]
		p.position=Vector3(-28+i*2.4,0,30)
		p.velocity=Vector3.ZERO
	game.players[9].position=Vector3.ZERO
	game.players[9].facing=Vector3.FORWARD
	game.players[17].position=victim
	game.players[17].facing=facing
	game.ball.place(ball)
	for i in range(3): await physics_frame
	game.dribbler=17
	game.carrier=17
	game.last_kicker=-1
func poke() -> void:
	game.duels.standing_tackle(9)
	poke_pose()
	game.duels.resolve(.13)
func poke_pose() -> void:
	game.players[9].step(.13)
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	await arrange(Vector3(.38,0,-.8),Vector3(0,.23,-1.5))
	poke()
	check(game.state=="playing" and game.players[9].fouls_committed==0,"A missed poke brushing the carrier's side keeps play live")
	check(game.players[17].pose!="fall" and game.players[17].action_timer==0,"Light duels do not knock the carrier down or lock their controls")
	await arrange(Vector3(.0,0,-.8),Vector3(0,.23,-1.65))
	check(not game.duels.ai_can_challenge(9,17) and not game.duels.ai_can_challenge(9,17,true),"AI does not lunge through a carrier's legs from behind")
	poke()
	check(game.state=="restart" and game.restart_team==1,"A deliberate rear trip still awards a free kick")
	await arrange(Vector3(0,0,-.8),Vector3(0,.23,-2.4),Vector3.BACK)
	poke()
	check(game.state=="restart","A late standing lunge into the legs is still a foul")
	await arrange(Vector3(.65,0,-.75),Vector3(0,.23,-.65))
	poke()
	check(game.state=="playing" and game.last_kicker==9 and game.ball.pending_kick,"A well timed foot challenge wins the real ball")
	await arrange(Vector3(.59,0,-.8),Vector3(0,.23,-2.5))
	game.rules.start_tackle(9,Vector3.FORWARD); game.rules.resolve_tackles()
	check(game.state=="playing","A slide passing beside a player is not an imaginary foul")
	await arrange(Vector3(0,0,-.72),Vector3(0,.23,-.78))
	game.rules.start_tackle(9,Vector3.FORWARD); game.rules.resolve_tackles()
	check(game.state=="playing" and game.ball.pending_kick,"Near simultaneous ball-first contact has a small natural tolerance")
	await arrange(Vector3(0,0,-.8),Vector3(0,.23,-2.0))
	game.rules.start_tackle(9,Vector3.FORWARD); game.rules.resolve_tackles()
	check(game.state=="restart" and game.restart_team==1,"A slide through the opponent before the ball remains a foul")
	await arrange(Vector3(.8,0,-.8),Vector3(0,.23,-1.65))
	game.players[17].active_sprint=true
	check(game.duels.ai_can_challenge(9,17,true),"AI may still tackle a genuinely exposed ball from a clear angle")
	game.players[17].active_sprint=false
	game.players[17].position=Vector3(0,0,-1.0)
	game.players[17].protecting=true
	check(not game.duels.ai_can_challenge(9,17),"Shielding invites jockeying instead of repeated automatic fouls")
	print("DUEL BALANCE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
