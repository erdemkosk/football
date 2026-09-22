extends "res://tests/team_control_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-player-authority.cfg"
	for depth in [-32.0,0.0]:
		setup()
		game.players[9].position=Vector3(20,0,20)
		game.players[6].position=Vector3(0,0,depth)
		game.players[7].position=Vector3(4,0,depth-9)
		game.ball.position=Vector3(0,0.23,depth-0.7)
		game.dribbler=6; game.carrier=6; game.last_touch=0
		game.team_control.manual_hold=1.4
		game.players[6].ai_think=20
		for frame in range(120): game.update_ai(1.0/120)
		check(game.shots[0]==0 and game.passes[0]==0 and not game.ball.pending_kick,"An unselected teammate never shoots or passes without input at z=%.0f" % depth)
		check(game.players[7].desired.length()>0,"Off-ball teammates still move into supporting space")
		game.player_lock=true
		game.update_ai(0.2)
		check(game.shots[0]==0 and game.passes[0]==0,"Locking selection does not re-enable automatic possession decisions")
	setup()
	game.players[9].position=Vector3(20,0,20)
	game.players[6].position=Vector3(0,0,0.7)
	game.players[7].position=Vector3(0,0,-14)
	game.controlled=7
	game.dribbler=6; game.carrier=6; game.last_touch=0
	game.call_for_pass(false)
	game.update_pass_request(0.3); game.update_ai(0.01)
	contact()
	check(game.passes[0]==1 and game.last_kicker==6,"An explicit user pass request still authorizes the teammate's pass")
	setup()
	game.players[14].position=Vector3(0,0,33)
	game.ball.position=Vector3(0,0.23,33.7)
	game.players[14].ai_think=20
	game.dribbler=14; game.carrier=14; game.last_touch=1
	game.update_ai(0.1)
	contact()
	check(game.shots[1]==1 and game.last_kicker==14,"Opponent AI retains its own shooting decisions")
	setup()
	game.players[9].position=Vector3(20,0,20)
	game.players[6].position=Vector3(0,0,-32)
	game.ball.position=Vector3(0,0.23,-32.7)
	game.players[6].ai_think=20
	game.menu_match.running=true
	game.update_ai(0.1)
	contact()
	check(game.shots[0]==1,"The main-menu exhibition still lets both teams play")
	game.menu_match.running=false
	setup()
	var keeper=game.players[0]
	keeper.visible=true; keeper.position=Vector3(0,0,45)
	keeper.facing=Vector3.FORWARD; keeper.animate(1)
	game.players[6].position=Vector3(3,0,34)
	game.ball.position=keeper.hand_center()
	game.ball.hold(keeper)
	game.goalkeeping.holding=0
	game.team_control.update(0.1)
	check(game.controlled==0 and game.has_ball_control(0),"A keeper holding the ball becomes controllable for distribution")
	game.goalkeeping.update(0,3.0)
	check(game.ball.held_by==keeper and game.passes[0]==0 and not game.ball.pending_kick,"The user's keeper waits for a command instead of automatically distributing")
	game.last_direction=Vector3.FORWARD
	button(JOY_BUTTON_A); button(JOY_BUTTON_A,false)
	# Distribution releases at the animated hand contact, not the button event.
	for frame in range(40):
		game.keeper_distribution.update(1.0/120)
		keeper.step(1.0/120)
		game.keeper_distribution.resolve()
	check(game.ball.held_by==null and game.ball.pending_kick and game.passes[0]==1 and game.goalkeeping.holding==-1,"User A releases the held ball as a real pass and clears the hand constraint")
	print("PLAYER AUTHORITY CHECK: %d failures" % failures)
	game.free(); quit(0 if failures==0 else 1)
