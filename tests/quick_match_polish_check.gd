extends "res://tests/tactics_navigation_check.gd"

func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	front.enter_age=1
	for i in range(160):
		await process_frame
		if front.portraits.pending.is_empty() and front.portraits.studio==null and i>30: break
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/quick-match-"+label+".png")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.controller.using_gamepad=true
	game.match_menu.config_path="res://tests/quick-polish-settings.tmp"
	if DisplayServer.get_name()!="headless":
		game.match_menu.display.set_fullscreen(false)
		game.match_menu.display.select_resolution(Vector2i(1440,900))
	front=game.frontend; front.open_selection()
	check(focus()==front.team_select[0],"Selection opens on the active team's clear confirmation button")
	check(front.team_select[1].disabled and front.go_button.disabled,"Opponent and continue are gated until the required selection")
	await capture("teams")
	front.weather_button.grab_focus()
	var weather: int=game.weather.preset
	tap(JOY_BUTTON_A)
	check(game.weather.preset==(weather+1)%3 and not front.picked[0] and focus()==front.weather_button,"A on weather changes weather and preserves focus without selecting a team")
	var selected: Array=game.clubs.selected.duplicate()
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(game.clubs.selected==selected and focus()==front.difficulty_button,"Footer navigation moves focus instead of cycling a team")
	var level: int=game.management.level
	tap(JOY_BUTTON_A)
	check(game.management.level==(level+1)%game.MatchSettings.LEVELS.size() and not front.picked[0],"Difficulty has its own A action")
	front.kit_buttons[0].grab_focus()
	var alternate: bool=game.clubs.alternate[0]
	tap(JOY_BUTTON_A)
	check(game.clubs.alternate[0]!=alternate and not front.picked[0],"A on a kit changes only the kit")
	front.league_buttons[0].grab_focus()
	var league: int=game.clubs.league[0]
	tap(JOY_BUTTON_A)
	check(game.clubs.league[0]!=league and not front.picked[0],"League selection is accessible with the controller")
	front.focus_pick(); selected=game.clubs.selected.duplicate()
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(game.clubs.selected[0]!=selected[0] and focus()==front.team_select[0],"Team carousel changes only the active side and retains confirmation focus")
	tap(JOY_BUTTON_A); front._process(.33)
	check(front.picked[0] and front.pick_step==1 and focus()==front.team_select[1],"Confirming home moves directly to the opponent without a long wait")
	tap(JOY_BUTTON_A); front._process(.33)
	check(front.picked==[true,true] and focus()==front.go_button and not front.go_button.disabled,"Both selections put focus on squad and tactics")
	await capture("ready")
	tap(JOY_BUTTON_A)
	check(front.stage=="tactics" and focus()==front.first_focus and front.swap_stage=="browse","Prematch tactics opens focused on Maça Başla, with no player swap armed")
	var lineup: Array=game.clubs.lineups[0].duplicate()
	check(front.first_focus.text.contains("MAÇA BAŞLA"),"The primary button names the next action clearly")
	await capture("tactics")
	tap(JOY_BUTTON_DPAD_UP)
	check(focus() in front.reserve_buttons and game.clubs.lineups[0]==lineup,"Up from Maça Başla reaches squad editing without changing players")
	front.first_focus.grab_focus(); tap(JOY_BUTTON_BACK); tap(JOY_BUTTON_B)
	check(focus()==front.first_focus and front.stage=="tactics","Returning from settings restores Maça Başla focus")
	tap(JOY_BUTTON_A)
	check(not front.visible and game.state=="ceremony","A single A press starts the match from the default tactics focus")
	check(not game.pass_charging and not game.ball.pending_kick,"The menu confirmation release does not become an in-game pass")
	game.ceremony.finish(true); game.controlled=9; front.open_tactics(false)
	check(focus()==front.slot_buttons[9],"Live squad management still opens on the controlled player")
	print("QUICK MATCH POLISH: %d checks, %d failures" % [checks,failures])
	DirAccess.remove_absolute(game.match_menu.config_path)
	game.free(); quit(1 if failures else 0)
