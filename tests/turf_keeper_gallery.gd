extends "res://tests/match_identity_gallery.gd"

func traffic() -> void:
	var rng:=RandomNumberGenerator.new(); rng.seed=591
	# Reproducible review traffic, using the same event handlers as live play.
	for route in range(65):
		var start:=Vector3(rng.randf_range(-4,4),0,rng.randf_range(-48,-44))
		var direction:=Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized()
		for step in range(16):
			var point:=start+direction*step*.20
			point.x=clampf(point.x,-5.2,5.2); point.z=clampf(point.z,-49,-42)
			game.weather.foot_contact(p,point)
	for route in range(6):
		var start:=Vector3(rng.randf_range(-3,2),0,rng.randf_range(-47,-43))
		var direction:=Vector3(rng.randf_range(.6,1),0,rng.randf_range(-.5,.5)).normalized()
		for step in range(rng.randi_range(8,17)):
			var a:=start+direction*step*.17
			game.weather.trail(a,a+direction*.18,.42,Color(.13,.10,.05,.32))
	game.weather.wear.update(.3)

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(); return
	visual=true; output="res://artifacts/turf-keeper"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DirAccess.make_dir_recursive_absolute("/tmp/sefc-turf-keeper/frames")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-turf-keeper/gallery.cfg"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	await create_timer(.3).timeout
	var layer:=CanvasLayer.new(); layer.layer=20; root.add_child(layer)
	var panel:=ColorRect.new(); panel.color=Color("10272d",.92); panel.position=Vector2(30,100); panel.size=Vector2(670,82); layer.add_child(panel)
	heading=Label.new(); heading.position=Vector2(47,107); heading.add_theme_font_size_override("font_size",24); heading.add_theme_color_override("font_color",Color("fff5dc")); layer.add_child(heading)
	subtitle=Label.new(); subtitle.position=Vector2(48,147); subtitle.add_theme_font_size_override("font_size",14); subtitle.add_theme_color_override("font_color",Color("64ecd8")); layer.add_child(subtitle)
	await scene(""); game.state="playing"; game.menu_match.running=false
	p.hide(); game.ball.hide(); game.weather.reset_match(); game.weather.select(0,true)
	camera_at(Vector3(0,0,-45.4),Vector3(6,6,8))
	title_line("01 / TAZE SAHA","Aynı kamera · maç başlamadan önce")
	await still("pitch-fresh")
	traffic()
	title_line("02 / BİRİKEN SAHA İZLERİ","Krampon basışları ve kaymalar · hazırlanmış trafik örneği")
	await still("pitch-worn")
	game.weather.select(2,true)
	title_line("03 / YAĞMURDA AŞINMA","Aynı izler ıslak zeminde daha koyu okunuyor")
	await still("pitch-wet")
	game.weather.clock=240; game.weather.apply_look()
	title_line("04 / SAHADA KALAN İZ","Taze krampon katmanı söndükten sonra da aşınma kalıyor")
	await still("pitch-persistent")
	await scene(""); game.state="playing"; game.menu_match.running=false
	p.hide(); game.ball.show(); game.weather.select(0,true)
	var keeper=game.players[0]; keeper.show(); keeper.position=Vector3(-2,0,-44)
	keeper.facing=Vector3.BACK; keeper.rig.rotation=Vector3(0,PI,0)
	keeper.action_timer=0; keeper.tackle_cooldown=0; keeper.touch_cooldown=0
	keeper.set_piece_pose=""; keeper.desired=Vector3.ZERO; keeper.velocity=Vector3.ZERO
	keeper.keeper_motion.reset(); keeper.marker.hide(); keeper.call_label.hide()
	for i in range(8): keeper.step(DT); await physics_frame
	keeper.start_dive(2.8,.6,.40)
	var acquired:=false; var brace_seen:=false
	title_line("05 / KURTARIŞTAN SONRA","İniş · kısa kayma · topu göğse çekme · el desteğiyle doğrulma")
	camera_at(Vector3(.4,.65,-44),Vector3(3.5,2.1,5.0))
	game.ball.freeze=true; game.ball.position=keeper.hand_center()
	for frame in range(60):
		for sub in range(4):
			keeper.step(DT)
			if not acquired and keeper.dive_duration-keeper.action_timer>.34:
				game.ball.freeze=false; game.ball.place(keeper.hand_center())
				await physics_frame; await physics_frame
				game.ball.hold(keeper); keeper.keeper_motion.saved(keeper)
				keeper.keeper_motion.secured=true; keeper.keeper_motion.target=game.ball.position; acquired=true
			if acquired: game.ball.hold_target=keeper.keeper_motion.grip_target(keeper)
			else: game.ball.position=keeper.hand_center()
			await physics_frame; game.weather.update(DT)
		keeper.reset_physics_interpolation(); game.ball.reset_physics_interpolation()
		if frame in [20,33,55]: print("GALLERY GRIP frame=",frame," ball=",game.ball.position," target=",keeper.keeper_motion.grip_target(keeper)," hands=",keeper.hand_center()," secured=",keeper.keeper_motion.secured," holder=",game.ball.held_by==keeper)
		if frame==20: await frame_image(output+"/keeper-gather.png")
		if not brace_seen and keeper.keeper_motion.brace_weight>.97:
			await frame_image(output+"/keeper-brace.png"); brace_seen=true
		if frame==55: await frame_image(output+"/keeper-upright.png")
		await frame_image("/tmp/sefc-turf-keeper/frames/recovery-%03d.png" % frame)
	game.ball.release_hold(); game.ball.hide(); keeper.keeper_motion.reset()
	keeper.position=Vector3(0,0,-44); keeper.facing=Vector3.BACK; keeper.rig.rotation.y=PI
	keeper.action_timer=0; keeper.set_piece_pose=""; keeper.velocity=Vector3.ZERO
	var mate=game.players[3]; mate.show(); mate.position=Vector3(-5,0,-35); mate.animate(1)
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.position=Vector3(-3,.23,-12); game.ball.linear_velocity=Vector3.ZERO
	game.goalkeeping.update(0,DT); keeper.motion_clock+=.3; keeper.animate(.1)
	camera_at(keeper.position+Vector3(0,1.0,0),Vector3(3.2,2.0,4.8))
	title_line("06 / SAVUNMAYI YÖNLENDİRME","Güvenli anda takım arkadaşına işaret · tehlikede hemen hazır duruş")
	await frame_image(output+"/keeper-direct.png")
	keeper.keeper_motion.reset(); keeper.tackle_cooldown=0; keeper.action_timer=0; keeper.set_piece_pose=""
	keeper.keeper_motion.start(keeper,"smother",keeper.position+keeper.facing*.4+Vector3.UP*.25)
	keeper.keeper_motion.saved(keeper); keeper.keeper_motion.secured=true
	keeper.motion_clock+=.5; keeper.action_timer=.31; keeper.animate(.1)
	game.ball.show(); game.ball.freeze=false; game.ball.place(keeper.keeper_motion.grip_target(keeper))
	await physics_frame; await physics_frame
	game.ball.hold(keeper); game.ball.hold_target=keeper.keeper_motion.grip_target(keeper)
	for i in range(20): await physics_frame
	title_line("07 / ALÇAK TOPTAN DOĞRULMA","Dizleri toplayıp avuçtan destek alma · topu vücut önünde koruma")
	await frame_image(output+"/keeper-low-brace.png")
	print("TURF KEEPER GALLERY: 9 stills and 60 recovery frames saved")
	game.free(); layer.free(); quit()
