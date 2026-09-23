extends "res://tests/ai_match_flow_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	await exhibition(2,983)
	print("HARD MATCH PACE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
