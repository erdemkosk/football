extends "res://tests/career_flow_check.gd"
## Exercise the user-facing route; optional render captures stay in /tmp.

func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	game.hud.queue_redraw(); game.frontend.queue_redraw(); game.career_screen.queue_redraw()
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/sefc-derby-"+label+".png")

func put_derby_next(c,home: String,away: String) -> Dictionary:
	var f: Dictionary=c.world.fixtures.filter(func(fixture): return fixture.home==home and fixture.away==away)[0]
	for fixture in c.cups.all_fixtures():
		if fixture.day<f.day and c.world.user in [fixture.home,fixture.away]: fixture.played=true; fixture.score=[0,0]
	c.world.date=f.day
	return f

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-derby-ui-settings.cfg"
	if "--visual" in OS.get_cmdline_user_args():
		game.match_menu.display.fullscreen=false; game.match_menu.display.resolution=Vector2i(1440,900)
		game.match_menu.display.apply(); await create_timer(1.5).timeout
		game.match_menu.display.apply(); await create_timer(.5).timeout
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.controller.device=0; game.controller.using_gamepad=true; game.ball.freeze=true
	game.experience.short_presentation=false; game.experience.reduce_motion=false
	game.clubs.league=[0,0]; game.clubs.selected=[0,1]
	var front=game.frontend; front.open_selection()
	check(front.rival_button.disabled,"Choose a home club before requesting its rival")
	tap(JOY_BUTTON_A); front._process(.33)
	check(go(front.rival_button),"The rival shortcut is reachable through controller navigation")
	tap(JOY_BUTTON_A)
	check(game.clubs.match_id(1)=="c06" and focus()==front.team_select[1] and not front.picked[1],"The shortcut shows the rival and leaves its confirmation under player control")
	await capture("selection")
	tap(JOY_BUTTON_A); front._process(.33); tap(JOY_BUTTON_A)
	check(front.stage=="tactics","The chosen derby proceeds through normal squad preparation")
	tap(JOY_BUTTON_A)
	game.stadium.supporters.set_process(false); game.stadium.supporters._process(1.6)
	game.ceremony.update_camera(0)
	check(game.state=="ceremony" and game.clubs.rivalry.active and game.stadium.supporters.visible,"Starting through the UI opens the derby ceremony and club cloth display")
	# MultiMesh instance reads require a real renderer; the headless dummy has no transforms.
	if DisplayServer.get_name()!="headless":
		var props: Array=game.stadium.supporters.covered_props
		check(not props.is_empty() and props.all(func(prop): return is_zero_approx(prop.mesh.get_instance_transform(prop.index).basis.determinant())),"Real renderer lowers the small flags so they cannot pierce the fabric")
	await capture("opening")
	game.ceremony.finish(true); game.state="playing"; game.update_camera(0); game.hud.bug_age=1
	check(game.half==1 and game.match_time==0 and game.ball.visible,"Skipping the derby entrance preserves a clean opening kickoff")
	await capture("kickoff")
	game.return_menu(); var c=game.career
	if DisplayServer.get_name()!="headless":
		check(game.stadium.supporters.covered_props.all(func(prop): return prop.mesh.get_instance_transform(prop.index).is_equal_approx(prop.transform)),"Returning to the menu restores every original supporter flag transform")
	c.save_root="/tmp/sefc-derby-ui-"+str(OS.get_process_id()); DirAccess.make_dir_recursive_absolute(c.save_root)
	c.new_career("tr00")
	var f:=put_derby_next(c,"tr01","tr00")
	game.career_screen.open_hub()
	check(c.next_fixture().id==f.id and c.cups.fixture_label(f).begins_with("DERBİ"),"An upcoming away derby is visible from the actual career hub")
	await capture("career")
	game.career_screen.play(); game.frontend.confirm()
	game.stadium.supporters._process(1.6); game.ceremony.update_camera(0)
	check(game.clubs.rivalry.active and game.clubs.rivalry.home_team==1,"The career match launch preserves actual home support when the user travels away")
	await capture("away-opening")
	game.return_menu()
	game.legend.career.save_root=c.save_root
	game.legend.create("tr00",2,game.legend_screen.config)
	c=game.legend.career
	put_derby_next(c,"tr00","tr01"); game.legend_screen.open_hub()
	check(game.legend.active() and not c.World.Rivalries.fixture(c.next_fixture()).is_empty(),"The personal career also recognizes its upcoming derby")
	await capture("legend")
	print("DERBY UI CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
