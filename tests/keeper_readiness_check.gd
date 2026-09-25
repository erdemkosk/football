extends "res://tests/keeper_balance_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/keeper-readiness-settings.tmp"
	for team in [0,1]:
		reading(team)
		var index: int=team*11
		var keeper=game.players[index]
		var forward: float=game.attack_sign(team)
		game.ball.position=Vector3(0,1,-forward*25)
		game.ball.linear_velocity=Vector3(2,0,-forward*22)
		game.goalkeeping.reset(); game.goalkeeping.variation.seed=127
		var waiting: Vector3=game.goalkeeping.update(index,.01)
		check(waiting.is_equal_approx(keeper.position),"The keeper still observes a newly struck long shot before moving, team %d" % team)
		var moving: Vector3=game.goalkeeping.update(index,.4)
		check(moving.x>keeper.position.x+.5,"After reading the flight, the keeper adjusts laterally before the ball reaches the box, team %d" % team)
	var saves := 0
	for team in [0,1]:
		for attempt in range(4):
			var result: Dictionary=await shot(22,22,0,2.05,0,910+attempt,team)
			saves+=int(result.saved)
	print("HIGH CENTRAL SHOTS: ",saves," saves / 8 shots")
	check(saves>=6,"A reachable high central shot prompts a real raised-glove save instead of watching it pass")
	print("KEEPER READINESS CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
