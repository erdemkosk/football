extends "res://tests/career_flow_check.gd"
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.ball.freeze=true; game.match_menu.config_path="/tmp/sefc-director-flow.cfg"
	var c=game.career; var ui=game.career_screen
	c.save_root="/tmp/sefc-director-flow"; DirAccess.make_dir_recursive_absolute(c.save_root); c.new_career("c00")
	ui.open_hub(); game.controller.menus.sync()
	check(go(named("TEKNİK DİREKTÖR MERKEZİ")),"Manager hub is reachable from career home with a controller")
	tap(JOY_BUTTON_A)
	check(ui.page=="board","The controller opens the manager's board review")
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(ui.page=="jobs","Shoulder buttons switch the manager centre tabs")
	for page in ui.director_ui.PAGES:
		ui.page=page; ui.build(); game.controller.menus.sync()
		var reachable:=true
		for control in ui.controls.get_children():
			if control is BaseButton and not control.disabled: reachable=go(control) and reachable
		check(reachable,"All manager actions are controller reachable: "+page)
		await capture("director-"+page)
	ui.page="development"; ui.build(); game.controller.menus.sync()
	var plan: OptionButton
	for control in ui.controls.get_children():
		if control is OptionButton and control.position.y==359: plan=control
	check(go(plan),"The individual development-plan selector is reachable")
	var pid: String=ui.selected; var previous: int=c.player(pid).development.plan
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(c.player(pid).development.plan==(previous+1)%6,"Controller changes the saved individual development plan")
	ui.page="academy"; ui.build(); game.controller.menus.sync()
	check(go(named("GÖZLEMCİ GÖNDER")),"Country scouting can be launched by controller")
	tap(JOY_BUTTON_A); c.world.date+=30; c.director.daily(); ui.build()
	check(c.world.academy.c00.size()==3,"Calendar progression delivers reports to the academy screen")
	await capture("director-academy-report")
	ui.go("market"); ui.selected="p0033"; ui.negotiate(false); game.controller.menus.sync()
	check(go(named("PRİMLER & SÖZLEŞME DETAYLARI")),"Advanced contract terms are reachable from the meeting room")
	tap(JOY_BUTTON_A)
	check(ui.page=="terms","The controller opens detailed contract clauses")
	await capture("director-contract-terms")
	check(go(named("ŞARTLARI KAYDET & GÖRÜŞMEYE DÖN")),"The terms panel has a controller return path")
	tap(JOY_BUTTON_A)
	check(ui.page=="talks" and ui.office!=null,"Returning from terms restores the animated negotiation room")
	# Real penalty motion and input, including goalkeeper control.
	ui.open_hub(); var f: Dictionary=c.next_fixture(); c.world.date=f.day; ui.play(); game.frontend.confirm(); game.ceremony.finish(true)
	c.cups.extra_phase=2; game.score=[0,0]; game.match_time=game.LENGTH*4/3.0
	check(c.cups.period_end() and game.state=="shootout","A drawn extra-time decider starts the actual shootout")
	var finale=game.finale
	game.controller.family="playstation"; game.controller.using_gamepad=true; game.update_camera(0)
	await capture("director-penalty-ready")
	var aim_press:=InputEventJoypadButton.new(); aim_press.device=0; aim_press.button_index=JOY_BUTTON_DPAD_RIGHT; aim_press.pressed=true
	game._input(aim_press); finale.update(.2); aim_press.pressed=false; game._input(aim_press)
	check(finale.aim.x<0,"Screen-right aiming follows the penalty camera rather than world X")
	finale.aim=Vector2(.7,.35); finale.keeper.position.x=-3; finale.keeper_jumped=true
	var press:=InputEventJoypadButton.new(); press.device=0; press.button_index=JOY_BUTTON_X; press.pressed=true
	game._input(press); finale.update(.70)
	check(finale.charging and finale.power>.4,"Holding the pad shoot button charges the penalty")
	press.pressed=false; game._input(press)
	check(finale.phase=="flight" and game.ball.pending_kick,"Releasing shoot launches the physical ball")
	for n in range(150):
		await physics_frame
		finale.update(1.0/60); game.update_camera(0)
		if finale.phase=="result": break
	check(finale.attempts[0].size()==1 and game.score==[0,0],"A real shot resolves separately from the match score")
	check(finale.totals[0]==1,"An aimed on-target penalty past a misplaced keeper scores")
	await capture("director-penalty-goal")
	finale.age=3; finale.update(.01)
	check(finale.side==1 and finale.phase=="ready","The opposing kick hands control to the user's keeper")
	var direction:=InputEventJoypadButton.new(); direction.device=0; direction.button_index=JOY_BUTTON_DPAD_LEFT; direction.pressed=true; game._input(direction)
	press.pressed=true; game._input(press)
	check(finale.keeper_jumped and finale.keeper.pose=="dive" and finale.keeper.dive_direction>0,"Direction plus the shoot button starts the user's keeper dive")
	direction.pressed=false; game._input(direction)
	finale.toggle_pause(); var old_age: float=finale.age; finale.update(2)
	check(finale.age==old_age and game.ball.freeze,"Pausing a shootout freezes both timing and ball physics")
	finale.toggle_pause()
	finale.attempts=[[true,true,true],[false,false,false]]; finale.totals=[3,0]
	check(finale.shootout_winner()==0,"An unreachable five-kick deficit ends the series early")
	finale.attempts=[[true,true,true,true,true,true],[true,true,true,true,true]]; finale.totals=[6,5]
	check(finale.shootout_winner()==-1,"Sudden death gives the second team its matching attempt")
	finale.attempts[1].append(false)
	check(finale.shootout_winner()==0,"A complete sudden-death pair determines the winner")
	finale.phase="result"; finale.age=3; finale.update(.01); game._process(0)
	check(f.played and f.live_penalties and f.penalties==[6,5],"The played shootout result is persisted without re-simulation")
	check(game.state=="trophy" and is_instance_valid(finale.trophy) and finale.medals.size()==11,"Winning the cup enters a 3D trophy and medal ceremony")
	finale.update(4); game.update_camera(0)
	await capture("director-trophy-lift")
	var cash: int=c.club().cash; tap(JOY_BUTTON_A)
	check(game.state=="finished" and c.club().cash==cash and not c.in_match,"The skippable ceremony returns to full time without awarding the prize twice")
	check(c.save() and c.load_slot(1) and c.world.cups.super.champion=="c00","The awarded trophy and played shootout survive a save/reload")
	print("CAREER DIRECTOR FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
