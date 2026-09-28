extends "res://tests/match_identity_gallery.gd"
const Pitch=preload("res://scripts/pitch_dimensions.gd")

func prep() -> void:
	await scene("")
	game.club_entrance.set_process(false)
	game.hud.replay_frame.set_process(false)
	game.stadium.supporters.set_process(false)
	game.stadium.supporters.hide(); game.stadium.supporters.cover_props(false)
	game.replay.enabled=true
	game.experience.short_presentation=false

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(); return
	visual=true; output="res://artifacts/match-character"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DirAccess.make_dir_recursive_absolute("/tmp/sefc-match-character/frames")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-match-character/gallery.cfg"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	var layer:=CanvasLayer.new(); layer.layer=20; root.add_child(layer)
	var panel:=ColorRect.new(); panel.color=Color("10272d",.92); panel.position=Vector2(30,100); panel.size=Vector2(585,82); layer.add_child(panel)
	heading=Label.new(); heading.position=Vector2(47,107); heading.add_theme_font_size_override("font_size",24); heading.add_theme_color_override("font_color",Color("fff5dc")); layer.add_child(heading)
	subtitle=Label.new(); subtitle.position=Vector2(48,147); subtitle.add_theme_font_size_override("font_size",14); subtitle.add_theme_color_override("font_color",Color("64ecd8")); layer.add_child(subtitle)
	await prep()
	title_line("01 / OYUNCU İMZALARI","Dört farklı kol duruşu, koşu karakteri ve şut hazırlığı")
	game.ball.hide()
	for i in range(4):
		var q=game.players[6+i]; q.show(); q.marker.hide(); q.call_label.hide()
		q.appearance.movement=i; q.apply_build(); q.position=Vector3((i-1.5)*2.2,0,0)
		q.facing=Vector3.FORWARD; q.rig.rotation=Vector3.ZERO
		q.shot_preparation=.85; q.velocity=Vector3.FORWARD*3; q.run_phase=.7; q.animate(.3)
	camera_at(Vector3(0,.9,0),Vector3(1,2.8,-10))
	await still("signatures")
	for kind in ["roulette","elastico"]:
		await prep()
		title_line("02 / "+kind.to_upper(),"Gerçek ayak temasından sonra çıkan kısa çalım izi")
		game.skills.start(9,kind)
		for i in range(36):
			await fly(1)
			if game.visual_identity.event_counts.get("skill",0)>0: break
		await fly(7)
		camera_at(p.position+Vector3.UP*.55,Vector3(2.5,3.3,5))
		await still(kind)
	await prep()
	title_line("03 / DİREK TEMASI","Kısa beyaz parıltı · fizik çarpışması değişmeden görsel titreşim")
	p.hide(); var hit:=Vector3(3.66,1.15,-50)
	game.ball.place(hit+Vector3(.18,0,.12)); await physics_frame; await physics_frame
	game.ball.freeze=true
	game.feedback.woodwork(hit,Vector3.RIGHT,.95); game.visual_identity._process(.035)
	camera_at(hit,Vector3(4,2.0,5.5)); await still("woodwork")
	await prep()
	title_line("04 / BİRLİKTE SEVİNÇ","Takım arkadaşıyla buluşma, el çakışma ve kişisel sevinç")
	game.training=false; game.replay.enabled=false
	p.position=Vector3(-22,0,-35)
	var teammate=game.players[8]; teammate.show(); teammate.position=p.position+Vector3.RIGHT
	game.last_kicker=9; game.goal(0)
	for i in game.celebration.targets:
		game.players[i].position=game.celebration.targets[i]; game.players[i].velocity=Vector3.ZERO
	game.ball.place(Vector3(0,.23,-51)); await physics_frame
	var captured:=false
	for frame in range(84):
		game.celebration.update(DT*2); await physics_frame
		var focus: Vector3=(p.position+teammate.position)*.5+Vector3.UP*.85
		camera_at(focus,Vector3(5,2.4,2))
		if not captured and game.celebration.greeting_age>.35:
			await still("high-five"); captured=true
		if frame%2==0: await frame_image("/tmp/sefc-match-character/frames/celebration-%03d.png" % (frame/2))
	await prep()
	title_line("05 / TAKIM ARKADAŞI TEPKİSİ","Kaçan şutta hayal kırıklığı ve arkadaşına destek işareti")
	p.position=Vector3.ZERO; p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO
	teammate=game.players[8]; teammate.show(); teammate.position=Vector3(1.5,0,0)
	teammate.facing=Vector3.FORWARD; teammate.rig.rotation=Vector3.ZERO
	game.state="restart"; game.reactions.update(0)
	game.reactions.kicked(9,"shot"); game.reactions.out(1)
	game.ball.place(Vector3(0,.23,-45)); await physics_frame
	for i in range(25):
		for q in [p,teammate]: q.reaction.update(q,.016); q.animate(.016)
	camera_at(Vector3(.65,.85,0),Vector3(2,2,-6)); await still("reactions")
	await prep()
	title_line("06 / KULÜP RENKLERİYLE GİRİŞ","İki tünel şeridi, takım ışıkları ve canlı maç sunumu")
	game.start_match(false,true); game.set_process(false); game.set_physics_process(false)
	game.frontend.hide(); game.match_menu.hide(); game.hud.show()
	game.club_entrance._process(0)
	camera_at(Vector3(41+Pitch.SIDE_SHIFT,1.5,0),Vector3(-13,2.1,-5))
	await still("entrance")
	title_line("07 / OYUNCU TANITIMI","Kulüp rengi, oyuncu adı ve kendine özgü selamlama")
	game.ceremony.phase="presentation"; game.ceremony.age=1.1
	for i in range(22):
		var q=game.players[i]; q.position=game.ceremony.lineup[i]; q.velocity=Vector3.ZERO
		q.facing=Vector3.RIGHT; q.rig.rotation.y=-PI/2
		q.saluting=i==game.ceremony.featured_player(); q.animate(.25)
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	for i in range(100): game.ceremony.update_camera(.016)
	await still("introduction")
	title_line("08 / TRİBÜN PANKARTI","Her maç girişinde kulübe ait büyük renkli koreografi")
	game.stadium.supporters._process(3); game.hud.hide()
	var focus: Vector3=game.stadium.supporters.displays[0].root.global_position
	camera_at(focus,Vector3(24,9,6))
	await still("club-banner")
	game.stadium.supporters.hide(); game.stadium.supporters.cover_props(false)
	title_line("09 / KRİTİK POZİSYON","Tehlikeli hücumda bölge bölge ayağa kalkan taraftarlar")
	game.state="playing"; game.stadium.crowd.reset()
	for i in range(50): game.stadium.crowd.update(.016,Vector3(0,.23,-44),Vector3(0,0,-12),0,true,false)
	camera_at(Vector3(-48,4,-31),Vector3(17,6,9))
	await still("crowd-danger")
	title_line("10 / KAÇAN FIRSAT","Atak yapan tribünde eller başa, omuzlar aşağı")
	game.stadium.crowd.react("miss",0,Vector3(0,0,-50))
	for i in range(80): game.stadium.crowd.update(.016,Vector3(0,.23,-51),Vector3.ZERO,0,false,false)
	await still("crowd-miss")
	# Record a real physical strike crossing the goal line for the finish card.
	await prep(); game.training=false; game.replay.reset(); game.replay.enabled=true
	title_line("11 / GOLÜN İMZA KARESİ","Gerçek vuruş hızı ve mesafesi · çizgide kısa duraklama")
	p.position=Vector3(0,0,-36); p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO
	p.attributes.finishing=99; p.attributes.composure=99; p.attributes.weak_foot=5
	game.ball.place(p.position+Vector3(0,.23,-.65)); await physics_frame; await physics_frame
	game.ball.freeze=false; game.boundary_grace=0
	for i in range(30): game.replay.capture(.05)
	game.commit_strike(9,Vector3(0,3,-29),0,false,"shot")
	var goal_frames:=0
	for i in range(260):
		game.previous_ball=game.ball.position
		await tick()
		game.replay.capture(DT)
		if game.state=="playing": game.check_boundaries()
		if game.state=="goal":
			goal_frames+=1
			if goal_frames>45: break
	game.replay.goal_tail=0
	if game.state!="goal": push_error("Gallery strike did not score"); game.free(); layer.free(); quit(1); return
	game.replay.begin(); game.hud.show()
	for i in range(1200):
		game.replay.update(DT)
		if game.replay.freeze_left>0: break
	game.hud.replay_frame.sync()
	await frame_image(output+"/finish-card.png")
	game.replay.finish()
	print("MATCH CHARACTER GALLERY: 12 stills and 42 celebration frames saved")
	game.free(); layer.free(); quit()
