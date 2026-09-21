extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if value: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func key(code: int) -> void:
	var e := InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.pressed=true
	game._input(e)
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw()
	game.frontend.queue_redraw()
	game.match_menu.queue_redraw()
	for i in range(8): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/prematch-"+label+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	game.match_menu.config_path="/tmp/football-new-settings-test.cfg"
	await capture("menu")
	key(KEY_ENTER)
	check(game.frontend.visible and game.frontend.stage=="teams" and game.state=="setup","Quick match opens team selection before kickoff")
	await capture("teams-default")
	game.frontend.cycle_team(0,2)
	game.frontend.cycle_team(1,2)
	check(game.team_name(0)=="DEMİRSPOR" and game.team_name(1)=="GÜNEŞ FK","Home and opponent are chosen independently")
	var home_color: Color=game.players[9].kit_materials.jersey.albedo_color
	check(home_color==Color("2463a3") and game.players[20].kit_materials.jersey.albedo_color==Color("f2be49"),"Both selections update actual 3D match kits")
	check(game.players[9].display_name=="TOLGA" and game.players[20].display_name=="YAMAN","Selected clubs have different named squads")
	game.frontend.toggle_kit(0)
	check(game.players[9].kit_materials.jersey.albedo_color!=home_color,"Alternate strip updates preview and players")
	game.frontend.toggle_kit(0)
	await capture("teams")
	game.frontend.open_tactics(true)
	check(game.frontend.stage=="tactics" and game.state=="setup" and game.match_time==0,"Tactical preparation happens before any match time")
	await capture("lineup")
	game.frontend.select_slot(9)
	var incoming: String=game.management.bench[0][1].name
	game.frontend.select_reserve(1)
	check(game.players[9].display_name==incoming and game.management.used[0]==0,"Pre-match roster swap costs no in-match substitution")
	check(not game.clubs.swap_starter(0,2),"Outfield players cannot replace the goalkeeper in the lineup")
	game.frontend.set_pane(1)
	game.frontend.set_tactic("formation",1)
	game.frontend.set_tactic("pressing",2)
	await capture("tactics")
	check(game.management.formation==1 and game.players[8].home.x< -20,"Formation changes the pitch diagram and real team positions")
	game.match_menu.open_menu()
	check(game.match_menu.visible and game.frontend.visible and game.state=="paused","Settings can open above pre-match without losing selections")
	for i in range(4):
		game.match_menu.show_page(i)
		await capture("settings-"+str(i))
	var labels := ""
	for button in game.match_menu.navigation: labels+=button.text
	check(not labels.contains("KADRO") and not labels.contains("TAKTİK"),"Settings has no roster or tactics tabs")
	game.match_menu.close_menu()
	check(game.state=="setup" and game.frontend.stage=="tactics","Closing settings restores pre-match preparation")
	game.frontend.confirm()
	check(game.state=="ceremony" and not game.frontend.visible,"Prepared match starts with the ceremony")
	check(game.players[9].display_name==incoming and game.players[9].shirt_number==13 and game.management.used[0]==0,"Starting lineup survives the start-match reset")
	check(game.management.formation==1 and game.management.pressing==2,"Chosen tactics survive kickoff")
	game.ceremony.finish(true)
	check(game.state=="playing" and game.team_name(1)=="GÜNEŞ FK","Selected opponent survives the ceremony")
	await capture("playing")
	key(KEY_K)
	check(game.frontend.visible and not game.frontend.prematch and game.state=="paused","K opens separate in-match team management")
	game.match_menu.open_menu()
	game.match_menu.close_menu()
	check(game.state=="paused" and game.ball.freeze and game.frontend.visible,"Closing settings over in-match tactics keeps the match paused")
	game.frontend.select_reserve(2)
	check(game.management.pending.size()==1,"In-match roster changes still queue substitutions")
	game.frontend.confirm()
	check(game.state=="playing" and not game.ball.freeze,"Closing tactics resumes the live match")
	game.return_menu()
	game.frontend.open_selection()
	check(game.management.pending.is_empty() and game.management.used==[0,0],"A new quick match resets previous substitutions before roster selection")
	game.clubs.choose(0,game.clubs.selected[1])
	check(game.clubs.selected[0]!=game.clubs.selected[1],"Team cycling avoids accidentally selecting identical opponents")
	game.frontend.back()
	check(game.state=="menu" and not game.frontend.visible,"Back from quick match returns to the main menu")
	print("PREMATCH CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
