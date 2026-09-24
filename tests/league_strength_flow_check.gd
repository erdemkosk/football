extends "res://tests/ai_attack_check.gd"
const World=preload("res://scripts/career_world.gd")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-league-strength-flow.cfg"
	# Every revised league exposes its real lineup through the same quick-match UI.
	for entry in [[3,"c54",79],[4,"c61",82],[5,"c66",81],[6,"c72",76],[7,"c79",83],[8,"c86",79]]:
		game.clubs.set_league(0,entry[0])
		game.clubs.choose(0,game.clubs.league_ids(entry[0]).find(entry[1]))
		check(game.frontend.team_ovr(0)==entry[2],"Quick-match card uses the revised lineup: "+game.clubs.data(0).name)
	game.clubs.set_league(0,7); game.clubs.set_league(1,7)
	game.clubs.choose(0,game.clubs.league_ids(7).find("c79"))
	game.clubs.choose(1,game.clubs.league_ids(7).find("c84"))
	var regional_attributes: Array=[]
	for side in range(2):
		for slot in range(11): regional_attributes.append(game.clubs.member(side,slot).attributes.duplicate())
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	var regional_ok:=true
	for i in range(22): regional_ok=regional_ok and game.players[i].attributes==regional_attributes[i]
	check(regional_ok and game.frontend.team_ovr(0)==83,"Rebalanced English players carry the displayed attributes into the actual match")
	game.return_menu()
	game.clubs.set_league(0,2); game.clubs.set_league(1,2)
	var ids: Array=game.clubs.league_ids(2)
	game.clubs.choose(0,ids.find("c36")); game.clubs.choose(1,ids.find("c53"))
	var madrid: int=game.frontend.team_ovr(0)
	var vigo: int=game.frontend.team_ovr(1)
	print("QUICK MATCH RATINGS: Madrid=",madrid," Vigo=",vigo)
	check(madrid>=83 and vigo<=71 and madrid-vigo>=13,"Quick-match team cards expose the actual league strength gap")
	var selected: Array=[]
	for side in range(2):
		for slot in range(11): selected.append(game.clubs.member(side,slot).attributes.duplicate())
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	var match_ok:=true
	for i in range(22): match_ok=match_ok and game.players[i].attributes==selected[i]
	check(match_ok,"All 22 on-pitch players carry the exact attributes shown during team selection")
	check(game.management.identity.team_quality(0)>game.management.identity.team_quality(1)+.2,"The stronger lineup materially improves the live team's reading of play")
	game.clubs.choose(0,ids.find("c37"))
	check(game.frontend.team_ovr(0)>=82,"Barcelona remains a second strong selectable Spanish team")
	game.clubs.choose(0,ids.find("c36"))
	check(game.frontend.team_ovr(0)==madrid,"Switching clubs cannot stack or reroll ratings")
	game.career.save_root="/tmp/sefc-league-strength-flow"
	DirAccess.make_dir_recursive_absolute(game.career.save_root)
	check(game.career.new_career("c36",1),"A strong Spanish club starts a real saved career")
	game.career.world.date=game.career.next_fixture().day
	check(game.career.prepare_match(),"The career opens its actual scheduled match")
	var career_ok:=true
	for q in game.players:
		career_ok=career_ok and q.attributes==game.career.player(q.career_id).attributes
	check(game.career.in_match and career_ok and game.frontend.team_ovr(0)>=83,"Career selection and physical players use the same strong squad")
	print("LEAGUE STRENGTH FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
