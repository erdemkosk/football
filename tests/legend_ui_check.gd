extends "res://tests/career_flow_check.gd"
## Real controller navigation and renderable captures; all saves stay in /tmp.

func named(title: String) -> Control:
	for child in game.legend_screen.controls.get_children():
		if child is Button and child.text==title: return child
	return null

func capture(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw(); game.legend_screen.queue_redraw()
	for i in range(30): await process_frame
	RenderingServer.force_draw(false)
	var suffix:="-compact" if "--compact" in OS.get_cmdline_user_args() else ""
	root.get_texture().get_image().save_png("/tmp/sefc-legend-"+label+suffix+".png")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-legend-ui-settings.cfg"
	if "--visual" in OS.get_cmdline_user_args():
		game.match_menu.display.fullscreen=false
		game.match_menu.display.resolution=Vector2i(1120,760) if "--compact" in OS.get_cmdline_user_args() else Vector2i(1440,900)
		game.match_menu.display.apply(); await create_timer(1.5).timeout
		game.match_menu.display.apply(); await create_timer(.5).timeout
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.ball.freeze=true
	var l=game.legend; var ui=game.legend_screen
	l.career.save_root="/tmp/sefc-legend-ui-"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(l.career.save_root)
	game.hud.sync_navigation(); await capture("home")
	check(go(game.hud.nav_buttons[6]),"Efsane is reachable from the home screen with the controller")
	tap(JOY_BUTTON_A); await capture("entry")
	check(ui.visible and ui.page=="entry","Controller opens the three personal save slots")
	check(go(named("YENİ EFSANE")),"New player creation is reachable")
	tap(JOY_BUTTON_A); await capture("create")
	for child in ui.controls.get_children():
		if child is BaseButton and not child.disabled: check(go(child),"Creation option reachable: "+str(child.position))
	var position: OptionButton=ui.controls.get_child(1)
	check(go(position),"Position can be selected with the controller")
	tap(JOY_BUTTON_A); tap(JOY_BUTTON_DPAD_UP); tap(JOY_BUTTON_A)
	check(ui.config.position==8,"Popup selects right wing without triggering another menu action")
	ui.config.name="Deniz Efsane"; ui.config.foot=0; ui.config.height=176; ui.config.weight=67
	check(go(named("İLK SÖZLEŞMENİ İMZALA")),"The first contract can be signed with the controller")
	tap(JOY_BUTTON_A)
	check(l.active() and ui.page=="hub" and l.player().name=="DENİZ EFSANE","Creation opens the personal career hub")
	for page in ["hub","training","positions","league"]:
		ui.go(page); game.controller.menus.sync()
		var contained:=true; var reachable:=true
		for child in ui.controls.get_children():
			if child is BaseButton:
				contained=contained and Rect2(0,0,1440,900).encloses(Rect2(child.position,child.size))
				if not child.disabled: reachable=go(child) and reachable
		check(contained and reachable,"Every control fits and is reachable: "+page)
		await capture(page)
	ui.go("hub"); var f: Dictionary=l.career.next_fixture(); l.career.world.date=f.day
	l.play(); game.state="playing"; game.update_camera(0); game.hud.sync_navigation(); game.controller.menus.sync()
	await capture("bench")
	check(go(game.hud.nav_buttons[0]),"The bench skip is controller-accessible")
	tap(JOY_BUTTON_A); game.pace.substitutions_ready()
	for n in range(240):
		game.management.update_substitutions(1.0/60)
		if l.on_pitch(): break
	check(l.on_pitch(),"Controller advances the bench period and enters the created player")
	game.state="playing"; game.ball.freeze=true; game.update_camera(0); game.hud.sync_navigation()
	await capture("playing")
	game.before_pause=game.state; game.state="paused"; game.hud.sync_navigation(); await capture("pause")
	check(go(game.hud.nav_buttons[1]),"Player controls replace manager tactics in the pause menu")
	tap(JOY_BUTTON_A)
	check(game.controls_help.visible,"Personal pause action opens a usable control guide")
	print("LEGEND UI CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
