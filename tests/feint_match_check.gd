extends "res://tests/space_skill_balance_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-feint-match.cfg"
	var straight: Dictionary=await skill_duel("",3.4,1,false,0,7)
	check(not straight.escaped,"A straight sprint is stopped by the committed defender")
	for kind in ["fake_shot","fake_pass"]:
		for team in [0,1]:
			var timely: Dictionary=await skill_duel(kind,3.4,1,false,team,7)
			check(timely.escaped and timely.kept,"A timed %s gives a real retained-ball exit, team=%d" % [kind,team])
			check(timely.physical and not timely.foul,"The fake preserves opponent collisions without relying on a foul")
		var late: Dictionary=await skill_duel(kind,1.05,1,false,0,7)
		check(not late.escaped,"A late %s can be intercepted before its contact" % kind)
		var covered: Dictionary=await skill_duel(kind,2.7,1,true,0,0)
		check(not covered.escaped,"A defender covering the exit can stop %s" % kind)
	print("FEINT MATCH COMPLETE: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
