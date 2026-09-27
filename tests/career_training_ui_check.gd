extends "res://tests/career_flow_check.gd"
const Catalog=preload("res://scripts/training_catalog.gd")

func capture(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw()
	for i in range(25): await process_frame
	RenderingServer.force_draw(false)
	var suffix: String="-compact" if "--compact" in OS.get_cmdline_user_args() else ""
	if label=="entry": print("VISUAL OUTPUT: ",root.size," / mode ",root.mode," / buffer ",root.get_texture().get_image().get_size())
	root.get_texture().get_image().save_png("/tmp/sefc-ui-"+label+suffix+".png")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	if "--visual" in OS.get_cmdline_user_args():
		game.match_menu.display.fullscreen=false
		game.match_menu.display.resolution=Vector2i(1120,760) if "--compact" in OS.get_cmdline_user_args() else Vector2i(1440,900)
		game.match_menu.display.apply()
		await create_timer(1.5).timeout
		game.match_menu.display.apply()
		await create_timer(.5).timeout
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.ball.freeze=true
	game.match_menu.config_path="/tmp/sefc-ui-check-settings.cfg"
	var c=game.career; var ui=game.career_screen; var menu=game.training_menu
	c.save_root="/tmp/sefc-ui-check-career"; DirAccess.make_dir_recursive_absolute(c.save_root)
	c.new_career("c00",1); ui.open_entry(); await capture("entry")
	ui.open_hub(); await capture("hub")
	for page in ["squad","market","finance","development","academy","training"]:
		ui.go(page); game.controller.using_gamepad=true; game.controller.menus.sync()
		var reachable:=true; var contained:=true
		for control in ui.controls.get_children():
			if control is BaseButton and not control.disabled: reachable=go(control) and reachable
			if control is BaseButton: contained=Rect2(0,0,1440,900).encloses(Rect2(control.position,control.size)) and contained
		check(reachable,"Controller reaches every enabled control: "+page)
		check(contained,"Career controls fit the canvas: "+page)
		await capture(page)
	ui.go("training"); game.controller.menus.sync()
	var third: Control
	for control in ui.controls.get_children():
		if control.get_meta("focus_key","")=="session:2": third=control
	check(third!=null and go(third),"A weekly session is reachable by controller")
	tap(JOY_BUTTON_A)
	check(ui.training_ui.selected==2,"Selecting a session opens that session's details")
	var row: Dictionary=c.training.data().slots[2]
	var chosen_id: String=row.player
	check(go(named("SİMÜLE ET")),"The selected session's simulation is reachable")
	tap(JOY_BUTTON_A)
	check(row.done and row.player==chosen_id and c.training.data().slots.filter(func(r): return r.done).size()==1,"Simulate completes only the selected weekly session")
	check(named("OYNA").disabled and named("SİMÜLE ET").disabled,"Completed weekly sessions cannot award twice")
	ui.status="Çalışma tamamlandı. Gelişim puanı kaydedildi."; ui.queue_redraw()
	check(not ui.art.notice_rect(ui).intersects(Rect2(327,826,260,44)) and not ui.art.notice_rect(ui).intersects(Rect2(1102,826,294,44)),"Status messages stay clear of training footer actions")
	await capture("training-complete")
	ui.close(); game.return_menu(); menu.open_menu(); game.controller.menus.sync()
	check(menu.cards.filter(func(card): return card.visible).size()==4,"Practice starts with four unlimited workshops")
	await capture("workshops")
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(menu.visible and menu.group==1 and menu.cards.filter(func(card): return card.visible).size()==8,"Shoulder button opens all eight scored exercises without starting one")
	for index in menu.visible_indices():
		check(go(menu.cards[index]),"Scored exercise reachable: "+Catalog.MODES[index])
	menu.choose(Catalog.MODES.find("crossing")); menu.cards[menu.selected].grab_focus()
	await capture("scored")
	tap(JOY_BUTTON_A)
	check(game.training and game.training_drills.mode=="crossing" and not menu.visible,"Controller confirmation starts the selected scored exercise")
	var challenge=game.training_drills.challenges
	for value in [100,0,65,80,90,55]:
		challenge.record(value,"DENEME")
		if challenge.completed<6: challenge.setup()
	challenge.finish()
	check(menu.result.attempts==[100,0,65,80,90,55] and menu.result.score==65,"Result displays actual six attempts and their average")
	await capture("result")
	menu.close_menu(); menu.select_group(1); menu.choose(Catalog.MODES.find("control"))
	game.controller.using_gamepad=false
	await capture("keyboard")
	menu.close_menu(); game.start_match(true,false,false,"passing")
	for i in range(3): await physics_frame
	game.update_camera(0); await capture("exercise")
	game.reset_practice()
	check(challenge.attempt_scores==[0] and challenge.completed==1 and challenge.points==0,"Retry records exactly one zero without adding earned points")
	print("CAREER TRAINING UI CHECKS: ",checks," / FAILURES: ",failures)
	quit(1 if failures else 0)
