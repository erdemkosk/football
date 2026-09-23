extends "res://tests/body_language_check.gd"
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.start_match(true); game.set_process(false); game.set_physics_process(false); game.hud.hide()
	player=game.players[9]; await reset()
	var opponent=game.players[20]
	opponent.show(); opponent.position=player.position+Vector3(.65,0,0)
	game.ball.position=player.position+Vector3(0,.13,-.6)
	game.dribbler=9
	await tick(24)
	check(player.body_language.contest_weight>.95 and opponent.body_language.contest_weight>.95,"Both nearby rivals participate in the duel")
	check(player.body_language.contest_shoulder and opponent.body_language.contest_shoulder,"Parallel players use shoulder bracing")
	check(player.spine.rotation.z*opponent.spine.rotation.z<0,"The two torsos lean toward opposing contact directions")
	check(player.right_elbow.rotation.x>.9 and opponent.left_elbow.rotation.x>.9,"The inside arms bend naturally against the opponent")
	await capture("shoulder-duel")
	player.desired=Vector3.FORWARD; opponent.desired=Vector3.FORWARD
	for frame in range(40):
		game.ball.position=player.position+Vector3(0,.13,-.6)
		game.physical_contests.update(DT); await tick()
	check(not game.physical_contests.pairs.is_empty() and player.body_language.contest_weight>.5 and opponent.body_language.contest_weight>.5,"Live shoulder physics and the paired visual brace remain active while running")
	await capture("running-duel")
	player.desired=Vector3.ZERO; opponent.desired=Vector3.ZERO
	opponent.position=player.position+Vector3(0,0,-.7); opponent.facing=Vector3.BACK; opponent.rig.rotation.y=PI
	player.velocity=Vector3.ZERO; opponent.velocity=Vector3.ZERO
	await tick(24)
	check(not player.body_language.contest_shoulder,"Face-to-face contact uses an arm brace instead of a side shoulder")
	await capture("arm-duel")
	opponent.position+=Vector3.RIGHT*4; await tick(35)
	check(player.body_language.contest_weight==0 and opponent.body_language.contest_weight==0,"Separating releases both contest poses")
	opponent.position=player.position+Vector3(.65,0,0); opponent.team=player.team; await tick(25)
	check(player.body_language.contest_weight==0,"Teammates do not visually grapple")
	opponent.team=1; game.ball.position=player.position+Vector3(10,.13,0); await tick(25)
	check(player.body_language.contest_weight==0,"Players away from the ball keep their ordinary motion")
	game.ball.position=player.position+Vector3(0,.13,-.6); player.kick_timer=.3
	player.body_language.observe(game,9); player.body_language.update(player,.2)
	check(not player.body_language.can_balance(player),"A shot retains priority over the contest overlay")
	print("DUEL ANIMATION: %d checks, %d failures" % [assertions,failures])
	game.free(); quit(1 if failures else 0)
