extends "res://tests/menu_controller_check.gd"

func screenshot(label: String) -> void:
	if DisplayServer.get_name()=="headless" or "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw(); game.career_screen.queue_redraw(); game.match_menu.queue_redraw()
	for i in range(12): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-ui-"+label+".png")

func career_control(key: String) -> Control:
	for node in game.career_screen.controls.get_children():
		if node.get_meta("focus_key","")==key: return node
	return null

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.audio.muted=true; game.playtest.enabled=false
	var menu=game.match_menu; var exp=game.experience
	menu.config_path="/tmp/sefc-ui-upgrade-%d.cfg" % OS.get_process_id()
	menu.display.set_fullscreen(false); menu.display.select_resolution(Vector2i(1440,900))
	root.size=Vector2i(1440,900)
	var c=game.career; var ui=game.career_screen
	c.save_root="/tmp/sefc-ui-upgrade-%d" % OS.get_process_id(); DirAccess.make_dir_recursive_absolute(c.save_root)
	await settle(); await screenshot("home")
	var cfg:=ConfigFile.new()
	exp.reduce_motion=true; exp.ui_sounds=false; exp.score_scale=.8; exp.player_scale=1.1; exp.map_scale=.9
	exp.save(cfg); exp.load_config(ConfigFile.new())
	check(not exp.reduce_motion and exp.ui_sounds and exp.score_scale==1,"Old settings get usable UI defaults")
	exp.load_config(cfg)
	check(exp.reduce_motion and not exp.ui_sounds and is_equal_approx(exp.map_scale,.9),"Motion, sounds and independent HUD sizes round-trip")
	exp.text_size=2
	check(exp.hud_scale("score")<exp.hud_scale("player") and exp.hud_scale("player")<=1.5,"Global readability preserves independent bounded HUD sizes")
	exp.text_size=0; exp.reduce_motion=false
	menu.open_menu(); menu.show_page(3); await settle()
	var camera_before: Transform3D=game.camera.transform; var current: Camera3D=root.get_camera_3d()
	game.match_camera.set_distance(1.1); menu.inspector._process(.2)
	check(menu.inspector.framing.id()==game.match_camera.preferred,"Preview uses the selected profile even when the menu backdrop uses another camera")
	check(game.camera.transform==camera_before and root.get_camera_3d()==current,"Preview owns a separate camera and never moves or replaces the match camera")
	menu.fields[7][0].grab_focus(); await settle(); await screenshot("camera")
	menu.show_page(2); await settle(); menu.fields[2][1].grab_focus(); await settle()
	var action: int=menu.ACTIONS[2]; game.controller.rebind(action,JOY_BUTTON_A)
	check(menu.fields[2][1].get_meta("binding_action")==game.controller.label_for(action),"Controller diagram follows live remapping")
	await screenshot("controls")
	go(menu.fields[10][1]); await settle()
	check(menu.scroll.scroll_vertical>0 and menu.scroll.get_global_rect().encloses(focus().get_global_rect()),"Binding list keeps the focused control entirely inside its scroll viewport")
	menu.show_page(3); await settle()
	check(focus()==menu.fields[7][0],"Returning to a settings tab restores the selected field")
	menu.show_page(4); exp.text_size=2; menu.apply_readability(); await settle(); await screenshot("accessibility")
	menu.close_menu(); exp.text_size=0; game.controller.reset_bindings()
	check(c.new_career("c00",1),"Create an isolated career for UI and report checks")
	ui.open_hub(); await settle(); await screenshot("career")
	var hero: String=ui.showcase.hero(ui)
	var captain: String=c.club().lineup[0]
	for id in c.club().lineup:
		if c.player(id).shirt==6: captain=id; break
	check(hero==captain and ui.showcase.hero_label=="KAPTAN","Career showcase uses the match captain selection rule")
	c.world.offers=[{"closed":true,"expires":c.world.date+1},{"closed":false,"expires":c.world.date-1},{"closed":false,"expires":c.world.date+1}]
	check(ui.pending_offers()==1,"Only open, unexpired transfer offers count as pending decisions")
	c.world.offers.clear()
	ui.go("squad"); ui.list_view=true; ui.player_sort=1; ui.build(); await settle()
	var sorted:=true
	for i in range(1,ui.list_ids.size()): sorted=sorted and c.player(ui.list_ids[i-1]).attributes.pace>=c.player(ui.list_ids[i]).attributes.pace
	check(sorted,"List view sorts by actual pace values")
	var pid: String=ui.list_ids[2]
	go(career_control("player_row:"+pid)); tap(JOY_BUTTON_A); await settle()
	check(ui.selected==pid and str(focus().get_meta("focus_key")).ends_with(pid),"Selecting a list row retains the player and controller focus")
	await screenshot("squad")
	ui.go("league"); ui.go("squad"); await settle()
	check(ui.list_view and ui.player_sort==1 and ui.selected==pid,"Career tab return restores view, sorting and selected player")
	var sort: OptionButton=career_control("player_sort"); sort.item_selected.emit(4); await settle()
	check(ui.selected==pid,"Resorting keeps the selected player on its new page")
	ui.go("market"); ui.list_view=true; ui.build(); await settle(); await screenshot("market")
	ui.go("squad"); ui.list_view=false; ui.build(); await settle(); await screenshot("cards")
	ui.close(); game.return_menu(); game.set_physics_process(false)
	game.training_menu.open_menu(); game.training_menu.choose(8); game.training_menu.cards[8].grab_focus(); await settle()
	var training=game.training_menu
	var clock_before: float=training.demo.elapsed; training.demo.update(training,.3)
	check(training.demo.elapsed>clock_before,"Selected exercise has an animated demonstration")
	exp.reduce_motion=true; clock_before=training.demo.elapsed; training.demo.update(training,1)
	check(training.demo.elapsed==clock_before,"Reduced motion freezes automatic exercise demonstrations")
	training.demo.toggle(training)
	check(training.demo.elapsed!=clock_before,"Reduced-motion users can advance demonstration steps explicitly")
	go(training.demo_button); await screenshot("training")
	training.close_menu(); exp.reduce_motion=false
	game.start_match(false,false); game.set_physics_process(false); game.ball.freeze=true
	var r=game.match_report
	check(r.active and not game.playtest.active,"On-screen match report works with local recording disabled")
	game.match_time=game.LENGTH*.5; r.sync()
	var old_id: String=r.key(game.players[9]); var outgoing: Dictionary=game.players[9].identity()
	r.strike(9,"shot",false); r.saved(11); game.last_kicker=11; game.score=[1,0]; r.goal(0)
	check(r.rows[old_id].goals==1 and r.rows[r.key(game.players[11])].own_goals==0,"A goal after a goalkeeper parry remains credited to the shooter")
	game.last_kicker=9
	r.saved(11)
	var replacement: Dictionary=game.management.bench[0][1].duplicate(true)
	r.substitution(game.players[9],replacement); game.players[9].apply_identity(replacement)
	var new_id: String=r.key(game.players[9]); game.match_time=game.LENGTH; r.sync()
	r.strike(9,"shot",false); game.score=[2,0]; r.goal(0)
	check(r.rows[old_id].goals==1 and r.rows[new_id].goals==1 and r.rows[old_id].minutes==45 and r.rows[new_id].minutes==45,"Substitution retains separate identities, goals and accurate minutes")
	check(r.participants().size()==23,"Only starters and used substitutes enter the report")
	game.players[1].yellow_cards=2; game.players[1].dismissed=true; r.sync(); r.sync()
	check(r.events.filter(func(e): return e.kind=="KIRMIZI KART").size()==1,"Card events are recorded once")
	game.state="playing"; game.rules.card_time=0; game.broadcast.reset()
	game.broadcast.debut_card={"name":"İLK MAÇ","shirt":19,"team":0,"detail":"HIZ 82 · TEKNİK 75"}; game.broadcast.debut_age=1
	game.broadcast.substitution(outgoing,replacement,0); game.broadcast.update_substitution(.1); game.broadcast.update_debut(1)
	check(game.broadcast.notification_owner()=="substitution" and game.broadcast.debut_age==1,"Substitution pauses the debut notification without consuming its display time")
	game.state="goal"; var sub_age: float=game.broadcast.substitution_age; game.broadcast.update_substitution(2)
	check(game.broadcast.notification_owner()=="goal" and game.broadcast.substitution_age==sub_age,"Goal presentation interrupts and preserves queued substitution graphics")
	game.state="playing"; game.broadcast.reset(); game.announce("Birinci bildirim"); game.announce("İkinci bildirim")
	check(game.toast=="Birinci bildirim" and game.toast_queue==["İkinci bildirim"],"Live messages queue instead of overwriting each other")
	exp.score_scale=1.15; exp.player_scale=1.15; exp.map_scale=1.15; exp.text_size=2
	game.hud.bug_age=2; game.half=2; game.hud.sync_navigation(); game.update_camera(1); await screenshot("hud-large")
	exp.text_size=0; game.state="finished"; r.finish(); game.hud.sync_navigation(); await settle()
	check(r.complete and not r.active and r.best().goals>0,"Full-time freezes the report and chooses its player from recorded contributions")
	var final_rows: Dictionary=r.rows.duplicate(true); r.strike(9,"shot",false); r.saved(11); r.finish()
	check(r.rows==final_rows,"Finished report cannot be changed by later celebration contacts")
	await screenshot("report")
	for page in [1,2,0]:
		go(game.hud.nav_buttons[2+page]); tap(JOY_BUTTON_A); await settle()
		check(r.page==page,"Controller opens match report tab %d" % page)
		await screenshot("report-%d" % page)
	# Exercise the real result path and confirm that the UI never applies it twice.
	game.return_menu(); game.set_physics_process(false); ui.open_hub()
	var fixture: Dictionary=c.next_fixture(); c.world.date=fixture.day
	check(c.prepare_match(),"Prepare an actual career fixture")
	ui.hide(); game.frontend.confirm(); game.set_physics_process(false); game.camera.cull_mask=ui.world_mask
	game.ceremony.clear(); game.state="playing"; game.match_time=game.LENGTH; game.score=[2,1]
	r.sync(); game.state="finished"; game._process(0)
	check(not c.in_match and not r.consequences.is_empty(),"Career outcome appears after the normal result is applied")
	var cash: int=c.club().cash; var points: int=c.world.table[c.world.user].pts
	game._process(0); game.hud.sync_navigation(); await settle()
	check(c.club().cash==cash and c.world.table[c.world.user].pts==points,"Viewing the report cannot apply rewards or league points twice")
	if game.state=="trophy":
		game.finale.age=20; game.finale.finish_ceremony(); game.hud.sync_navigation(); await settle()
	check(game.state=="finished" and r.complete and not r.consequences.is_empty(),"Trophy presentation returns to the same completed career report")
	await screenshot("career-report")
	print("UI UPGRADE CHECK: %d checks, %d failures" % [assertions,failures])
	game.free(); quit(1 if failures else 0)
