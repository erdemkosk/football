extends "res://tests/keeper_balance_check.gd"
## A reproducible sensitivity report, not a claim about full human matches.
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	var rows: Array=[]
	for rain in [0,2]:
		for energy in [1.0,.35]:
			for group in [["central",20.0,16.0,0.0,.9],["placed",20.0,24.0,3.15,.9],["close",8.0,28.0,2.4,.7]]:
				var goals := 0; var saves := 0
				for offset in [-8.0,0.0,8.0]:
					for side in [-1,1]:
						var result: Dictionary=await shot(group[1],group[2],group[3]*side,group[4],offset,731+side*41,1,rain,energy)
						goals+=int(result.goal); saves+=int(result.saved)
						rows.append({"group":group[0],"rain":rain,"keeper_energy":energy,"offset":offset,"corner":group[3]*side,"goal":result.goal,"saved":result.saved})
				print("BALANCE rain=%d energy=%.2f %s goals=%d saves=%d shots=6" % [rain,energy,group[0],goals,saves])
	check(rows.size()==72,"Seventy-two releases cover both corners, three approach angles, rain and tired keepers")
	var dry_central := rows.filter(func(r): return r.rain==0 and r.keeper_energy==1.0 and r.group=="central" and r.saved)
	var dry_close := rows.filter(func(r): return r.rain==0 and r.keeper_energy==1.0 and r.group=="close" and r.goal)
	check(dry_central.size()>=4,"Fresh dry keeper saves ordinary shots from several angles")
	check(not dry_close.is_empty(),"Close finishes still have a path past a fresh keeper")
	var file := FileAccess.open("/tmp/football-experience-balance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":"automated_release_fixture","shots":rows,"note":"72 controlled releases; not human match win rates or an exploit guarantee."},"\t")); file.close()
	print("EXPERIENCE BALANCE: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
