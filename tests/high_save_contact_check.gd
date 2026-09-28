extends "res://tests/keeper_handling_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	for team in [0,1]:
		for side in [-1.0,1.0]:
			var keeper=await setup_keeper(team)
			var index: int=team*11
			var attacker=game.players[9 if team==1 else 20]
			attacker.show(); attacker.position=keeper.position+Vector3(side*.6,0,.25)
			attacker.collision_layer=0
			game.ball.freeze=false; game.ball.place(keeper.position+Vector3(side*6,3.5,0),Vector3(-side*12,0,0))
			await physics_frame; await physics_frame
			var punching := false
			var glove_gap := INF
			for frame in range(180):
				game.kick_lock=maxf(0,game.kick_lock-DT)
				var before: int=game.saves[team]
				var move: Vector3=(game.goalkeeping.update(index,DT)-keeper.position)*Vector3(1,0,1)
				punching=punching or keeper.keeper_motion.special(keeper) and keeper.keeper_motion.kind=="punch"
				if game.saves[team]>before:
					glove_gap=minf(keeper.left_hand.global_position.distance_to(game.ball.position),keeper.right_hand.global_position.distance_to(game.ball.position))
					break
				keeper.desired=move.normalized()*clampf(move.length()/1.4,0,1)
				keeper.step(DT); await physics_frame
			print("CROSS team=",team," side=",side," punch=",punching," saves=",game.saves[team]," glove_gap=",glove_gap)
			check(punching and game.saves[team]==1 and glove_gap<.40,"A real crowded cross reaches the punching gloves on team %d / side %s" % [team,side])
			check(game.ball.held_by==null and game.ball.kick_velocity.z*game.attack_sign(team)>8,"The contacted cross is cleared forward without a grip or teleport")
	print("HIGH SAVE CONTACT CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
