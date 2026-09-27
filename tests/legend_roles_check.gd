extends "res://tests/legend_career_check.gd"

func ready_player(position: int) -> void:
	var l=game.legend
	l.create("c18",1,{"name":"Efsane Rol","position":position,"foot":1},{"half_minutes":1,"level":2})
	for key in World.Talent.STATS: l.player().attributes[key]=88
	l.data().games=8; l.data().trust=82; l.data().form=7.8
	l.coach_selection()
	var f: Dictionary=l.career.next_fixture(); l.career.world.date=f.day
	check(l.selection.starter and l.play(),"A developed player starts in his selected role: "+Progress.POSITIONS[position])
	game.ceremony.finish(true); game.state="playing"
	check(l.on_pitch() and game.is_user_player(l.live.index),"Starter control follows player identity: "+Progress.POSITIONS[position])

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.match_menu.config_path="/tmp/sefc-legend-roles.cfg"
	var l=game.legend
	l.career.save_root="/tmp/sefc-legend-roles-"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(l.career.save_root)
	ready_player(7)
	var hero: int=l.live.index
	check(hero==Progress.slot_for(7,int(l.career.club().plan.formation)),"The coach places the winger in the correct formation slot")
	game.reset_positions(0)
	check(game.controlled==hero,"Starting after a goal never selects another player")
	game.players[hero].dismissed=true; game.players[hero].visible=false
	l.live.enforce_control(); game.switch_player()
	check(not l.on_pitch() and not game.players.any(func(p): return game.is_user_player(game.players.find(p))),"A red card leaves the user watching, without taking over a teammate")
	var before: float=game.match_time; l.live.skip_bench()
	check(game.match_time==before,"A dismissed player cannot use bench skip to re-enter")
	game.return_menu()
	l.open(); l.career.world={}
	ready_player(0)
	check(game.controlled==0 and game.players[0].keeper,"Goalkeeper career controls the real goalkeeper")
	game.controller.device=0; game.controller.using_gamepad=true; game.controller.stick=Vector2(.8,0)
	game.update_control(.016)
	check(game.players[0].desired.length()>.5,"Goalkeeper positioning respects manual movement input")
	var keeper=game.players[0]
	game.controller.stick=Vector2.ZERO; keeper.desired=Vector3.RIGHT*.4
	game.ball.held_by=keeper; game.goalkeeping.holding=0; game.goalkeeping.hold_age=5
	game.goalkeeping.update(0,.016)
	check(game.ball.held_by==keeper and not game.keeper_distribution.active(0) and keeper.desired==Vector3.RIGHT*.4,"A player goalkeeper chooses when to distribute his held ball")
	game.ball.release_hold()
	game.finale.begin_shootout({"stage":1}); game.finale.side=1; game.finale.prepare()
	check(game.finale.user_keeper() and not game.finale.user_shooter(),"Goalkeeper penalty defence remains under human control")
	game.finale.reset(); game.return_menu(); l.open()
	check(not l.learn(9),"Goalkeeper careers cannot silently become outfield careers")
	check(l.train("distribution"),"Goalkeeper can train through a real scored distribution session")
	var reward: Dictionary=l.career.training.finish(90)
	check(reward.score==90 and l.data().xp.has("reflexes") and l.data().xp.has("handling"),"Goalkeeper training develops his own positional attributes")
	l.career.training.leave()
	# A completed new role becomes playable and survives the next match setup.
	l.create("c18",2,{"name":"Çok Yönlü","position":9},{"half_minutes":1,"level":2})
	for key in World.Talent.STATS: l.player().attributes[key]=85
	l.data().games=8; l.data().trust=90; l.data().form=8
	l.learn(5)
	for n in range(6): Progress.training(l.data(),l.player(),int(l.career.world.date)+(n/3)*7,100,["passing","control","stamina"],"passing")
	check(l.data().positions["5"]==100 and l.prefer(5),"Successful training unlocks selection of a second role")
	var f: Dictionary=l.career.next_fixture(); l.career.world.date=f.day
	check(l.play() and l.live.index==Progress.slot_for(5,int(l.career.club().plan.formation)),"A learned midfield role changes the actual match position")
	game.return_menu(); l.open()
	var id: String=l.player().id
	l.career.club().roster.erase(id); l.career.club().lineup.erase(id)
	l.player().retired=true; l.player().club=""
	l.coach_selection(); game.legend_screen.open_hub()
	check(l.career.valid(l.career.world) and l.career.save() and l.career.load_slot(2),"A completed football career remains a valid reloadable record")
	check(not l.selection.available and not l.train("passing"),"Retirement retains career statistics and closes further match and training entry")
	print("LEGEND ROLES CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
