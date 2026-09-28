extends "res://tests/duel_balance_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	# The opponent is closer to the ball, but has not made a challenge.
	for owner in [9,17]:
		await arrange(Vector3(.65,0,-.75),Vector3(0,.23,-.65))
		var challenger: int=17 if owner==9 else 9
		game.players[owner].position=Vector3(.95,0,-.75)
		game.players[challenger].position=Vector3.ZERO
		game.dribbler=owner; game.carrier=owner
		game.kick_lock=0
		game.update_contacts(1.0/60.0)
		check(game.dribbler==owner,"Nearer opponent cannot silently take controlled possession: "+str(owner))
		check(not game.ball.pending_kick,"Proximity does not manufacture a tackle")
	# The existing visible challenge must still free the ball.
	await arrange(Vector3(.65,0,-.75),Vector3(0,.23,-.65))
	poke()
	check(game.ball.pending_kick and game.last_kicker==9 and game.dribbler<0,"Real boot challenge releases a loose ball before collection")
	# Removing proximity steals must not prevent collecting a free ball.
	await arrange(Vector3(5,0,5),Vector3(0,.23,-.5))
	game.dribbler=-1; game.carrier=-1
	game.update_contacts(1.0/60.0)
	check(game.dribbler==9,"Uncontested loose ball remains collectable")
	print("READABLE POSSESSION CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
