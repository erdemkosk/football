extends "res://tests/ai_match_flow_check.gd"
## Same user club, difficulty, weather and random seed; three distinct opponent
## squads must both play coherent football with their real tactical presets.
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-identity-flow-settings.cfg"
	for club in [1,4,6]:
		game.clubs.selected[1]=club; game.clubs.apply()
		print("OPPONENT ",game.clubs.data(1).name," rating=",game.frontend.team_ovr(1)," plan=",game.clubs.tactical_plan(1))
		await exhibition(1,541)
		print("ACTION MIX ",game.ai_attack.uses)
	print("TEAM IDENTITY FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
