extends "res://tests/career_flow_check.gd"
const World=preload("res://scripts/career_world.gd")

func capture(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	game.update_camera(0); game.hud.queue_redraw()
	for i in range(80): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-trophy-"+label+".png")

func stage_final(away: bool=false) -> Dictionary:
	var c=game.career
	c.detach(); c.new_career("c00",1)
	c.world.cup_fixtures=c.world.cup_fixtures.filter(func(f): return f.competition=="domestic")
	c.world.cups.champions.stage=3
	var f: Dictionary=c.cups.fixture(c.world,"champions","tr00" if away else "c00","c00" if away else "tr00",3,World.day(2026,8,1))
	c.world.date=f.day
	game.career_screen.open_hub()
	return f

func play_final() -> void:
	game.career_screen.play(); game.frontend.confirm(); game.ceremony.finish(true)
	game.ball.freeze=true

func advance_to(age: float) -> void:
	while game.finale.age<age: game.finale.update(minf(1.0/120,age-game.finale.age))
	game.update_camera(0)

func grip_error() -> float:
	var f=game.finale; var p=f.shooter
	return maxf(p.left_hand.global_position.distance_to(f.trophy.to_global(Vector3(-.32,.13,0))),p.right_hand.global_position.distance_to(f.trophy.to_global(Vector3(.32,.13,0))))

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.match_menu.config_path="/tmp/sefc-trophy-settings.cfg"
	var c=game.career; var ui=game.career_screen; var finale=game.finale
	c.save_root="/tmp/sefc-trophy-career"; DirAccess.make_dir_recursive_absolute(c.save_root)
	var f:=stage_final(true)
	check(finale.award_for(f).is_empty(),"An unplayed final never starts a celebration")
	play_final()
	var captain=game.players[7]
	for p in game.players: p.set_captain(p==captain)
	var transform: Transform3D=captain.transform
	var mask: int=captain.collision_mask; var layer: int=captain.collision_layer
	game.score=[2,0]; game.state="finished"; game._process(0)
	check(f.played and f.score==[0,2] and c.world.cups.champions.champion=="c00","An away victory awards the correct club through the real match completion path")
	check(game.state=="trophy" and finale.shooter==captain and finale.champion==0,"The actual captain leads the winners even when neither the first player nor the striker")
	check(finale.medals.size()==18 and not game.ball.visible and game.referees.actors.all(func(p): return not p.visible),"The winning squad and bench receive medals and match props leave the podium")
	check(not finale.confetti.visible and finale.phase=="presentation","The opening presentation precedes the confetti burst")
	var cash: int=c.club().cash; var budget: int=c.club().budget; var ledger: int=c.world.ledger.size()
	var fitness: float=c.player(captain.career_id).fitness
	var initial_height: float=finale.trophy.global_position.y
	ui.open_hub()
	check(not ui.visible and game.state=="trophy","Returning from a finished match cannot cover the newly started ceremony")
	await capture("presentation")
	advance_to(2.4)
	check(finale.phase=="receive" and grip_error()<.06,"Both hands grip the cup handles while the captain receives it")
	advance_to(4.4)
	check(finale.phase=="lift" and grip_error()<.06 and not finale.confetti.visible,"The lifting animation preserves hand contact before the celebration")
	await capture("lift")
	advance_to(6)
	check(finale.phase=="celebrate" and finale.confetti.visible and finale.presentation.burst,"Confetti and team celebration begin at the completed lift")
	check(finale.trophy.global_position.y>initial_height+.6 and finale.trophy.to_global(Vector3(0,.815,0)).y>captain.head_joint.to_global(Vector3(0,.36,0)).y and grip_error()<.06,"The captain holds the cup above his head without losing either handle")
	check(finale.trophy.global_position.y>captain.head_joint.to_global(Vector3(0,.20,0)).y,"The raised cup's base clears the captain's eyes instead of covering his face")
	check(c.player(captain.career_id).fitness==fitness,"Celebrating does not spend the player's saved fitness")
	await capture("celebration")
	finale.toggle_pause()
	var paused_age: float=finale.age; var cup_pose: Transform3D=finale.trophy.global_transform
	var paper_pose: Transform3D=finale.confetti.multimesh.get_instance_transform(0)
	finale.update(3); finale.finish_ceremony()
	check(game.state=="trophy" and finale.age==paused_age and finale.trophy.global_transform==cup_pose and finale.confetti.multimesh.get_instance_transform(0)==paper_pose,"Pause freezes players, cup and confetti and prevents accidental skipping")
	finale.toggle_pause()
	check(game.ball.freeze,"Resuming the trophy scene keeps the hidden match ball frozen")
	tap(JOY_BUTTON_A)
	check(game.state=="finished" and finale.stage==null and finale.medals.is_empty() and game.ball.visible,"Controller confirmation cleans up the ceremony and returns to full time")
	check(captain.transform==transform and captain.collision_mask==mask and captain.collision_layer==layer and game.referees.actors.all(func(p): return p.visible),"Exiting restores the players' transforms, collisions and match officials")
	check(c.club().cash==cash and c.club().budget==budget and c.world.ledger.size()==ledger,"The presentation never pays a second championship reward")
	ui.open_hub()
	check(c.save() and c.load_slot(1),"The awarded final survives saving and reloading")
	ui.go("league"); ui.division=World.LEAGUES.size()+1; ui.build(); game.controller.menus.sync()
	check(named("TÖRENİ İZLE")!=null and go(named("TÖRENİ İZLE")),"A saved championship exposes a controller-reachable replay in Lig & Kupalar")
	await capture("replay-button")
	game.players[0].dismissed=true; game.players[0].hide(); game.players[1].rig.hide()
	tap(JOY_BUTTON_A)
	check(game.state=="trophy" and finale.return_to_hub and not ui.visible and finale.medals.size()==18,"Replaying a saved trophy rebuilds the complete winning side after an unrelated dismissal")
	check(game.camera.cull_mask!=0 and game.players[1].rig.visible,"Menu replays restore the stadium and player rendering")
	advance_to(23.1)
	check(game.state=="career" and ui.visible and ui.page=="hub" and game.clubs.career_clubs.is_empty(),"The complete ceremony automatically returns to the career hub")
	check(c.club().cash==cash and c.club().budget==budget and c.world.ledger.size()==ledger,"Reloading and replaying preserve the single prize payment")
	# A losing final shows the opponent's captain, never the user's celebrations.
	f=stage_final(); play_final()
	var keeper=game.players[11]
	for p in game.players: p.set_captain(p==keeper)
	game.score=[0,3]; game.state="finished"; game._process(0)
	check(finale.champion==1 and finale.shooter==keeper and keeper.keeper,"An opposing goalkeeper captain can lift the trophy after the user loses")
	advance_to(6)
	check(grip_error()<.06,"A goalkeeper captain also holds both handles throughout the lift")
	finale.finish_ceremony(); ui.open_hub()
	check(finale.award_for_division(World.LEAGUES.size()+1).is_empty(),"A lost final cannot be replayed as the user's title")
	# A dismissed captain stays out; another eligible winner receives the trophy.
	f=stage_final(); play_final()
	captain=game.players[6]
	for p in game.players: p.set_captain(p==captain)
	captain.dismissed=true; captain.hide()
	game.score=[1,0]; game.state="finished"; game._process(0)
	check(finale.shooter!=captain and finale.shooter.team==0 and finale.medals.size()==17 and not captain.visible,"A missing captain falls back to an eligible teammate without reviving a dismissed actor")
	advance_to(2); finale.finish_ceremony(); ui.open_hub()
	# Use the real simulation button; fix abilities and RNG to make its winner deterministic.
	f=stage_final()
	for id in [f.home,f.away]:
		for pid in c.world.clubs[id].roster:
			for key in c.player(pid).attributes:
				if key not in ["archetype","weak_foot","preferred_foot"]: c.player(pid).attributes[key]=95 if id==c.world.user else 35
	c.rng.seed=17; c.world.rng=c.rng.state
	ui.simulate_match()
	check(f.played and f.winner==c.world.user and game.state=="trophy" and finale.return_to_hub,"Winning through MAÇI SİMÜLE ET opens the same trophy ceremony")
	cash=c.club().cash; budget=c.club().budget; ledger=c.world.ledger.size()
	advance_to(2)
	var enter:=InputEventKey.new(); enter.keycode=KEY_ENTER; enter.pressed=true; game._input(enter)
	check(game.state=="career" and ui.visible and not c.in_match and c.club().cash==cash and c.club().budget==budget and c.world.ledger.size()==ledger,"Keyboard confirmation returns a simulated winner to the hub without altering results or money")
	# League titles share the presentation and replay path, including the separate Turkish league.
	c.detach(); c.new_career("tr00",1)
	for item in c.world.fixtures:
		if item.league==9: item.played=true
	c.world.table.tr00.pts=100
	check(c.settle_league_prizes(9),"A completed league records its actual champion")
	var award: Dictionary=finale.award_for_division(9)
	check(award.get("club","")=="tr00" and award.title==World.LEAGUES[9] and award.prize==6000000,"League replay uses the correct national title and championship prize")
	check(finale.show_award(award) and finale.title==World.LEAGUES[9],"A league championship also opens the captain's trophy presentation")
	advance_to(2); finale.finish_ceremony()
	print("TROPHY PRESENTATION CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
