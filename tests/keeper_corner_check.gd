extends "res://tests/keeper_balance_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	var results := {}
	for group in [["routine_corner",24.0,23.0,2.65,0.7],["firm_corner",20.0,28.0,2.8,1.0],["box_corner",15.0,26.0,2.75,1.0],["low_corner",20.0,25.0,2.8,0.25],["high_corner",20.0,25.0,2.8,1.9],["hard_corner",14.0,30.0,3.05,1.5],["close",8.0,28.0,2.4,0.7]]:
		var goals := 0; var saves := 0; var count := 0
		for side in [-1,1]:
			for seed_index in range(6):
				var offset: float=[-4.0,0.0,4.0][seed_index%3]
				var result := await shot(group[1],group[2],group[3]*side,group[4],offset,710+seed_index,seed_index%2)
				goals+=int(result.goal); saves+=int(result.saved); count+=1
		results[group[0]]={"goals":goals,"saves":saves,"shots":count}
		print("CORNER GROUP ",group[0],": ",JSON.stringify(results[group[0]]))
	if "--baseline" not in OS.get_cmdline_user_args():
		check(results.routine_corner.saves>=9,"Routine corner shots with ample flight time are usually stopped")
		check(results.firm_corner.saves>=5 and results.firm_corner.goals>=1,"Firm shots toward a corner produce both saves and goals")
		check(results.box_corner.saves>=3 and results.box_corner.goals>=2,"An ordinary box corner finish is not an automatic goal or save")
		check(results.low_corner.saves>=6,"Reachable low corners do not consistently pass under the gloves")
		check(results.high_corner.saves>=6 and results.high_corner.goals>=1,"High corners remain challenging but physically reachable")
		check(results.hard_corner.saves>=1 and results.hard_corner.goals>=3,"Hard close corner strikes can beat the keeper without every shot scoring")
		check(results.close.goals>=5,"Close one-on-ones still reward the attacker")
	print("KEEPER CORNER MATRIX: ",JSON.stringify(results))
	print("KEEPER CORNER CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
