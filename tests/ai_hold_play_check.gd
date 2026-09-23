extends "res://tests/ai_attack_check.gd"
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	setup(); player(4,Vector3(0,0,-2)); player(18,Vector3(-7,0,6),Vector3(-6,0,0)); player(5,Vector3(-7,0,6))
	var option: Dictionary=game.ai_attack.hold_choice(20,game.ai_attack.pressure_read(20))
	check(option.get("kind","")=="shield","A carrier with rear pressure sees a moving outlet and can shield")
	player(4,Vector3(0,0,2))
	check(game.ai_attack.hold_choice(20,game.ai_attack.pressure_read(20)).get("kind","")=="invite","Facing pressure can be invited while a teammate opens an outlet")
	player(4,Vector3(0,0,-2)); game.ai_attack.decisions.game=game
	check(game.ai_attack.act(20) and game.ai_attack.holds.has(20),"AI chooses to protect a ball while the immediate passing outlet is marked")
	check(game.players[20].protecting and not game.players[20].sprinting and game.players[20].facing.z>0,"Holding keeps the body between rear pressure and the ball")
	# The receiver opens and the attacker must reassess a real passing lane.
	player(18,Vector3(-10,0,12)); game.ai_attack.update(.7)
	check(not game.ai_attack.holding_action(20),"Holding has a bounded duration rather than trapping the AI in an animation")
	check(game.ai_attack.hold_choice(20,game.ai_attack.pressure_read(20)).is_empty(),"Cooldown prevents repetitive stop-and-hold loops")
	check(kind() in ["pass","through","driven_pass","one_two"],"The opened outlet becomes a pass after drawing pressure")
	check(act_and_contact(20) and game.passes[1]>0,"The release pass is completed through the ordinary boot-contact system")
	setup(); player(4,Vector3(0,0,-2)); player(18,Vector3(-7,0,6),Vector3(-6,0,0))
	game.ai_attack.holds[20]={"age":.1,"kind":"shield"}
	player(5,Vector3(1,0,0))
	check(not game.ai_attack.holding_action(20),"A second presser immediately ends the invitation")
	setup(); player(4,Vector3(0,0,-2)); player(18,Vector3(-7,0,6))
	check(game.ai_attack.hold_choice(20,game.ai_attack.pressure_read(20)).is_empty(),"No moving outlet means no purposeless invitation")
	setup(); player(4,Vector3(0,0,-2)); player(18,Vector3(-7,0,6),Vector3(-6,0,0))
	game.ai_attack.holds[20]={"age":.1,"kind":"shield"}; game.dribbler=4
	game.ai_attack.update(.02)
	check(game.ai_attack.holds.is_empty(),"Lost possession clears the hold without protecting the ball from the opponent")
	print("AI HOLD PLAY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
