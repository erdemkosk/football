extends "res://tests/career_flow_check.gd"
const World=preload("res://scripts/career_world.gd")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.controller.using_gamepad=true; game.ball.freeze=true
	game.match_menu.config_path="/tmp/sefc-prizes-flow-settings.cfg"
	var c=game.career; var ui=game.career_screen
	c.save_root="/tmp/sefc-prizes-flow"; DirAccess.make_dir_recursive_absolute(c.save_root)
	c.new_career("c00",1); ui.choose(1); ui.division=9; ui.selected_club="tr00"; ui.build()
	await capture("prizes-choose-turkey")
	ui.open_hub(); ui.go("league"); ui.division=9; ui.build(); game.controller.menus.sync()
	check(go(named("SONRAKİ →")),"The full eighteen-club table keeps controller paging reachable alongside prize information")
	await capture("prizes-turkish-league")
	ui.division=0; ui.build()
	await capture("prizes-league-estimate")
	ui.division=World.LEAGUES.size()+1; ui.build(); game.controller.menus.sync()
	check(go(named("SONUÇLAR")),"Champions Cup results remain controller accessible alongside the €25M preview")
	await capture("prizes-champions-preview")
	# Stage the final before the league calendar, then use the real match-to-career path.
	c.world.cup_fixtures=c.world.cup_fixtures.filter(func(f): return f.competition=="domestic")
	c.world.cups.champions.stage=3
	var f: Dictionary=c.cups.fixture(c.world,"champions","c00","tr00",3,World.day(2026,8,1))
	c.world.date=f.day
	var budget: int=c.club().budget
	ui.open_hub(); ui.play(); game.frontend.confirm(); game.ceremony.finish(true)
	check(c.in_match and c.fixture_id==f.id,"The staged Champions final opens as a playable career match")
	game.score=[2,0]; game.state="playing"; game.half=2
	game.management.added[1]=0; game.match_time=game.LENGTH+.01
	game._physics_process(.01); game._process(0)
	check(f.played and not c.in_match and c.world.cups.champions.champion==c.world.user,"Winning the played final records the user's trophy")
	check(c.club().budget==budget+25000000 and game.state=="trophy" and game.finale.prize_amount==25000000,"The trophy ceremony shows the same €25M already available for transfers")
	for i in range(30): game.finale.update(.1)
	game.update_camera(0)
	await capture("prizes-champions-ceremony")
	game.finale.finish_ceremony(); ui.open_hub(); ui.go("league")
	ui.division=World.LEAGUES.size()+1; ui.build()
	await capture("prizes-champions-paid")
	ui.go("finance"); ui.mode=1; ui.list_page=0; ui.build(); game.controller.menus.sync()
	check(ui.finance_entries().any(func(item): return item.amount==25000000 and item.label.contains("şampiyonluk")),"The financial ledger exposes the real final prize transaction")
	check(go(named("SONRAKİ →")),"Controller navigation remains usable in the prize ledger")
	await capture("prizes-finance")
	print("CAREER PRIZES FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
