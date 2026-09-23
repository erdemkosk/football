extends "res://tests/attacking_combos_check.gd"
## Render the actual match HUD for visual review, without advancing the match.
func scene() -> void:
	setup()
	game.frontend.hide(); game.match_menu.hide(); game.controls_help.hide(); game.training_menu.hide()
	game.hud.sync_navigation(); game.hud.bug_age=2; game.toast_timer=0
	game.weather.select(0,true); game.stadium.light_rig.select(0)
	game.ball.position.y=game.ball.GROUND_HEIGHT
	game.ball.pending_reset=false
	game.controller.using_gamepad=true
	for p in game.players:
		if p.visible:
			p.facing=Vector3.FORWARD; p.animate(1)
	game.match_camera.select("sideline"); game.camera_focus=game.ball.position
	game.update_camera(1)

func photo(label: String) -> void:
	# Let a queued restart placement reach the rigid body before drawing once.
	for i in range(3): await physics_frame
	game.hud.queue_redraw()
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.save_png("res://tests/aim-style-"+label+".png")
	print("CAPTURE: ",label," ",frame.get_size())

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/aim-preview-settings.tmp"
	game.match_menu.display.set_fullscreen(false)
	game.match_menu.display.select_resolution(Vector2i(1440,900))
	scene(); game.begin_pass(); game.pass_power=.64; game.last_direction=Vector3(-.4,0,-1).normalized(); game.update_pass_preview()
	await photo("pass")
	game.pass_power=.12; game.update_pass_preview(); await photo("pass-low")
	scene(); game.begin_pass(true,true); game.pass_power=.78; game.update_pass_preview()
	await photo("loft")
	scene(); game.players[9].position=Vector3(7,0,-30); game.ball.position=Vector3(7,game.ball.GROUND_HEIGHT,-30.7)
	game.camera_focus=game.ball.position; game.update_camera(1)
	game.begin_shot(); game.charge=.71; game.shot_direction=Vector3(-.24,0,-1).normalized()
	game.players[9].facing=game.shot_direction; game.players[9].animate(1)
	await photo("shot")
	game.stadium.light_rig.select(1); game.weather.select(2,true); await photo("night-shot")
	game.weather.select(0,true); game.stadium.light_rig.select(0)
	game.shot_finesse=true; game.charge=.9; await photo("finesse")
	game.match_camera.select("pitch"); game.update_camera(1); await photo("top")
	scene(); game.begin_restart("SERBEST VURUŞ",0,Vector3(3,0,-27)); game.set_pieces.snap_ready(); game.state="set_piece"
	game.set_pieces.button=KEY_D; game.set_pieces.power=.66; game.set_pieces.preview()
	game.toast_timer=0; game.update_camera(1); await photo("free-kick")
	game.match_menu.display.set_process(false)
	root.size=Vector2i(1720,720)
	game.ui.refresh(); game.update_camera(1); await photo("wide")
	game.free(); quit(0)
