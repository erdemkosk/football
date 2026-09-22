extends "res://tests/career_flow_check.gd"
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.controller.using_gamepad=true; game.ball.freeze=true
	var c=game.career; var ui=game.career_screen
	c.save_root="/tmp/sefc-turkey-flow"; DirAccess.make_dir_recursive_absolute(c.save_root)
	ui.open_entry(); ui.choose(1); game.controller.menus.sync()
	var selector: OptionButton=ui.controls.get_child(0)
	check(go(selector),"League selection is reachable with the controller")
	for i in range(9): tap(JOY_BUTTON_DPAD_RIGHT)
	check(ui.division==9 and ui.choose_ids().size()==18,"Controller selects Turkey separately from the SEFC leagues")
	check(go(named("BURSA İPEK")),"A distinctly named Turkish club card is reachable")
	tap(JOY_BUTTON_A)
	check(ui.selected_club=="tr04","The chosen Turkish club retains its separate identity")
	await capture("turkey-choose")
	check(go(named("BU KULÜPLE BAŞLA")),"Start-career button is reachable from Turkish clubs")
	tap(JOY_BUTTON_A)
	if ui.overwrite: tap(JOY_BUTTON_A)
	check(ui.page=="hub" and c.world.user=="tr04" and c.club().league==9,"The Turkish career starts through the actual controller flow")
	await capture("turkey-hub")
	ui.go("squad"); game.controller.menus.sync()
	check(ui.list_ids.any(func(id): return c.player(id).nationality=="TR") and ui.list_ids.any(func(id): return c.player(id).nationality!="TR"),"The real squad screen contains both Turkish and foreign players")
	var foreign: String=ui.list_ids.filter(func(id): return c.player(id).nationality!="TR")[0]
	var card: Control
	for control in ui.controls.get_children():
		if control.get_meta("focus_key","")=="player:"+foreign: card=control
	check(go(card),"A foreign player's portrait card can be selected with the pad")
	tap(JOY_BUTTON_A)
	check(ui.selected==foreign,"The actual foreign identity populates the player detail")
	await capture("turkey-squad")
	ui.go("league"); game.controller.menus.sync()
	check(ui.division==9 and c.standings(9).size()==18,"The league screen opens Turkey's independent standings")
	await capture("turkey-table")
	ui.go("hub"); c.world.date=c.next_fixture().day
	ui.build(); game.controller.menus.sync()
	check(go(named("KADROYU HAZIRLA & MAÇA ÇIK")),"Match preparation is reachable from the Turkish career")
	tap(JOY_BUTTON_A)
	check(c.in_match and game.frontend.visible and game.clubs.career_clubs.size()==2,"A Turkish fixture opens the real pre-match game")
	check(game.players.filter(func(p): return p.team==0).all(func(p): return c.player(p.career_id).club=="tr04"),"The actual match uses the chosen Turkish squad and saved player identities")
	await capture("turkey-prematch")
	print("TURKISH LEAGUE FLOW CHECK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
