extends "res://tests/career_flow_check.gd"
const World=preload("res://scripts/career_world.gd")
func option_at_point(point: Vector2) -> OptionButton:
	for control in game.career_screen.controls.get_children():
		if control is OptionButton and control.position==point: return control
	return null

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.ball.freeze=true
	game.match_menu.config_path="/tmp/sefc-career-cups-flow-settings.cfg"
	var c=game.career; var ui=game.career_screen
	c.save_root="/tmp/sefc-career-cups-flow"; DirAccess.make_dir_recursive_absolute(c.save_root)
	c.new_career("c00",1); ui.open_hub()
	check(c.next_fixture().competition=="super","The career hub schedules the Super Cup before the first league fixture")
	await capture("cups-hub")
	check(go(named("LİG & KUPALAR")),"The competitions tab is reachable with a controller")
	tap(JOY_BUTTON_A)
	check(go(option_at_point(Vector2(54,177))),"The competition selector is reachable")
	for n in range(World.LEAGUES.size()): tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.division==World.LEAGUES.size(),"Controller navigation opens the domestic cup")
	await capture("cups-domestic")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.division==World.LEAGUES.size()+1 and option_at_point(Vector2(536,177))!=null,"The Champions Cup exposes its group selector")
	check(go(option_at_point(Vector2(536,177))),"The group selector is reachable by controller")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.cup_group==1,"The controller can inspect another Champions Cup group")
	await capture("cups-groups")
	check(go(named("SONUÇLAR")),"Cup result filters are reachable")
	tap(JOY_BUTTON_A)
	check(ui.mode==1,"The cup result filter opens an empty-results view without errors")
	check(go(named("GOL KRALI")),"The independent cup scoring chart is reachable")
	tap(JOY_BUTTON_A)
	check(ui.mode==2,"The cup scoring chart supports an empty competition")
	ui.go("market"); game.controller.menus.sync()
	check(go(option_at_point(Vector2(694,173))),"The nationality filter is reachable by controller")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.nation_filter=="*" and not ui.list_ids.is_empty() and ui.list_ids.all(func(pid): return c.player(pid).nationality!="TR"),"The foreign-player filter includes only non-Turkish player identities")
	await capture("foreign-market")
	tap(JOY_BUTTON_DPAD_RIGHT); tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.nation_filter=="ES" and ui.list_ids.all(func(pid): return c.player(pid).nationality=="ES"),"A specific nationality filters the full international player market")
	var target: String=ui.list_ids[0]; var identity: Dictionary=c.player(target).duplicate(true)
	c.club().cash=90000000; c.club().budget=60000000; ui.selected=target; ui.negotiate(false)
	ui.fee=World.value(c.player(target))*2; ui.submit_offer(); ui.wage=40000; ui.promised=2; ui.submit_offer()
	check(c.deal.stage=="sign" and c.sign_deal() and c.player(target).nationality==identity.nationality,"An international transfer preserves the player's nationality")
	# Play a cup final through the actual 90/105/120-minute clock transitions.
	ui.open_hub(); var f: Dictionary=c.next_fixture(); c.world.date=f.day
	ui.play(); game.frontend.confirm(); game.ceremony.finish(true)
	check(c.in_match and game.players.any(func(p): return p.career_id!=""),"Cup fixtures enter the same playable 3D match as league fixtures")
	var table: Dictionary=c.world.table.duplicate(true)
	game.score=[0,0]; game.state="playing"; game.half=2; game.management.added[1]=0
	game.match_time=game.LENGTH+.01; game.players[9].energy=.51; game.players[9].yellow_cards=1
	game._physics_process(.01)
	check(c.cups.extra_phase==1 and game.state=="restart" and f.extra_time and not f.played,"A tied final enters playable first-half extra time instead of finishing")
	check(is_equal_approx(game.players[9].energy,.51) and game.players[9].yellow_cards==1,"Extra time preserves fatigue and discipline")
	game.state="playing"; game.match_time=game.LENGTH*7.0/6.0+.01
	game._physics_process(.01)
	check(c.cups.extra_phase==2 and game.half==2 and game.state=="restart","At 105 minutes the extra-time second half changes ends")
	await capture("cups-extra-time")
	game.state="playing"; game.match_time=game.LENGTH*4.0/3.0+.01
	game._physics_process(.01)
	check(game.state=="shootout","A tied cup final enters a playable shootout after 120 minutes")
	game.finale.attempts=[[true,true,true],[false,false,false]]; game.finale.totals=[3,0]; game.finale.phase="result"; game.finale.age=3
	game.finale.update(.01)
	game._process(0)
	check(not c.in_match and f.played and not f.penalties.is_empty() and game.score==[0,0],"Full time records the played shootout and preserves the actual match score")
	check(game.ending_reason.contains("PENALTILAR") and game.ending_reason.contains("KUPAYI KAZANDI"),"The result screen names the shootout winner and trophy")
	check(c.world.table==table,"Playing a cup final does not change domestic league points")
	await capture("cups-final")
	game.finale.age=3; game.finale.finish_ceremony()
	ui.open_hub(); ui.go("league"); ui.division=World.LEAGUES.size()+2; ui.mode=1; ui.build()
	await capture("cups-trophy")
	check(c.world.cup_history.size()==1 and c.world.cups.super.champion==f.winner,"The cup page shows the same winner stored in the trophy archive")
	# The next league fixture still ends in a draw at regulation time.
	ui.open_hub(); f=c.next_fixture(); c.world.date=f.day; ui.play(); game.frontend.confirm(); game.ceremony.finish(true)
	game.score=[1,1]; game.state="playing"; game.half=2; game.management.added[1]=0; game.match_time=game.LENGTH+.01
	game._physics_process(.01)
	check(game.state=="finished" and c.cups.extra_phase==0 and not f.has("competition"),"A drawn league match still ends after regulation without extra time")
	game._process(0)
	check(f.played and c.world.table.c00.pts==1,"The real league draw awards one league point")
	check(c.save() and c.load_slot(1),"The career reloads after live cup and league matches")
	print("CAREER CUPS FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
