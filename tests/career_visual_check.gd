extends "res://tests/career_flow_check.gd"
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.controller.using_gamepad=true; game.ball.freeze=true
	var c=game.career; var ui=game.career_screen
	c.save_root="res://tests/career-visual.tmp"; DirAccess.make_dir_recursive_absolute(c.save_root)
	c.new_career("c00",1); ui.open_entry(); await capture("new-entry")
	ui.choose(1); await capture("new-choose")
	ui.open_hub(); await capture("new-hub")
	for page in ["squad","market","tactics","league","finance","development","academy","relations","board","jobs"]:
		ui.go(page); game.controller.menus.sync()
		var accessible:=true
		for control in ui.controls.get_children():
			if control is BaseButton and not control.disabled: accessible=go(control) and accessible
		check(accessible,"Every controller action reachable: "+page)
		await capture("new-"+page)
	ui.go("squad"); game.controller.menus.sync()
	var chosen: String=ui.list_ids[4]
	var target: Control
	for control in ui.controls.get_children():
		if control.get_meta("focus_key","")=="player:"+chosen: target=control
	check(go(target),"A portrait card is reachable without a mouse")
	tap(JOY_BUTTON_A)
	check(ui.selected==chosen,"Confirming a card changes the detailed player and actions")
	tap(JOY_BUTTON_RIGHT_SHOULDER); tap(JOY_BUTTON_LEFT_SHOULDER)
	check(ui.selected==chosen and focus().get_meta("focus_key","")=="player:"+chosen,"Returning from a tab restores player identity and controller focus")
	motion(JOY_AXIS_TRIGGER_RIGHT,1.0); ui._process(.016)
	check(ui.list_page==1 and focus().get_meta("card_cell",-1)==4 and ui.selected==str(ui.list_ids[13]),"RT advances the roster while retaining the grid column and row")
	for i in range(20): ui._process(.016)
	check(ui.list_page==1,"Holding a trigger does not skip several roster pages")
	motion(JOY_AXIS_TRIGGER_RIGHT,0.0); ui._process(.016)
	motion(JOY_AXIS_TRIGGER_LEFT,1.0); ui._process(.016)
	check(ui.list_page==0,"LT returns to the previous roster page")
	motion(JOY_AXIS_TRIGGER_LEFT,0.0); ui._process(.016)
	var selector: OptionButton
	for control in ui.controls.get_children():
		if control is OptionButton: selector=control; break
	check(go(selector),"Roster filtering remains reachable from the card grid")
	tap(JOY_BUTTON_A)
	motion(JOY_AXIS_TRIGGER_RIGHT,1.0); ui._process(.016)
	check(ui.list_page==0 and selector.get_popup().visible,"Paging cannot replace controls underneath an open filter")
	motion(JOY_AXIS_TRIGGER_RIGHT,0.0); ui._process(.016); tap(JOY_BUTTON_B)
	for family in ["xbox","playstation"]:
		game.controller.family=family
		ui.go("market"); game.controller.menus.sync()
		check(go(named("SONRAKİ →")),family+" can page through the transfer catalogue")
		var before_page: int=ui.list_page
		tap(JOY_BUTTON_A)
		check(ui.list_page==before_page+1,family+" confirms the next player-card page")
		await capture("new-market-"+family)
	ui.showcase._process(.016)
	check(ui.showcase.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"The 3D hero stops rendering outside the hub")
	ui.go("hub"); ui.showcase._process(.016)
	check(ui.showcase.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"The 3D hero resumes only on the hub")
	await capture("new-hub-final")
	ui.close(); ui.showcase._process(.016)
	check(ui.showcase.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"The 3D hero stops when returning to gameplay")
	print("CAREER VISUAL CHECKS: ",checks," / FAILURES: ",failures)
	quit(1 if failures else 0)

func motion(axis: int,value: float) -> void:
	var e:=InputEventJoypadMotion.new(); e.device=0; e.axis=axis; e.axis_value=value
	Input.parse_input_event(e); Input.flush_buffered_events()
