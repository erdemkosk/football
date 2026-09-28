extends "res://tests/power_shot_trail_check.gd"
## Render real match objects and event handlers into reviewable stills/frames.
var output:="res://artifacts/match-identity"
var heading: Label
var subtitle: Label

func title_line(title: String,detail: String) -> void:
	heading.text=title; subtitle.text=detail

func frame_image(path: String) -> void:
	game.hud.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var capture:=root.get_texture().get_image()
	if capture.get_size()!=Vector2i(1440,900): capture.resize(1440,900,Image.INTERPOLATE_LANCZOS)
	capture.save_png(path)

func still(name: String) -> void:
	var velocity: Vector3=game.ball.linear_velocity
	game.ball.freeze=true
	await frame_image(output+"/"+name+".png")
	game.ball.freeze=false; game.ball.linear_velocity=velocity

func camera_at(focus: Vector3,distance: Vector3=Vector3(3.5,6.5,10)) -> void:
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=43; game.camera.position=focus+distance; game.camera.look_at(focus)

func scene(kind: String="power") -> void:
	await trail_fixture(kind)
	game.experience.reduce_motion=false
	game.visual_identity.set_process(false); game.visual_identity.reset()
	game.controller.set_process(false); game.hud.set_process(false)
	game.frontend.hide(); game.match_menu.hide(); game.controls_help.hide()
	game.hud.help_launcher.hide(); game.hud.hide(); game.toast_timer=0
	game.weather.select(0,true); game.stadium.light_rig.select(0)
	game.ball.reset_physics_interpolation()
	p.animate(1); p.marker.hide(); p.call_label.hide()
	for official in game.referees.actors: official.hide()
	camera_at(p.position+p.facing*2)

func fly(frames: int) -> void:
	for i in range(frames):
		await tick()
		game.ball.reset_physics_interpolation()
		game.ball.power_trail.update(DT)
		game.visual_identity._process(DT)

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(); return
	visual=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DirAccess.make_dir_recursive_absolute("/tmp/sefc-match-identity/frames")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-match-identity/gallery.cfg"
	game.match_menu.display.set_fullscreen(false)
	game.match_menu.display.select_resolution(Vector2i(1440,900))
	await create_timer(.3).timeout
	var layer:=CanvasLayer.new(); layer.layer=20; root.add_child(layer)
	var panel:=ColorRect.new(); panel.color=Color("10272d",.92); panel.position=Vector2(30,112); panel.size=Vector2(530,82); layer.add_child(panel)
	heading=Label.new(); heading.position=Vector2(47,119); heading.add_theme_font_size_override("font_size",24); heading.add_theme_color_override("font_color",Color("fff5dc")); layer.add_child(heading)
	subtitle=Label.new(); subtitle.position=Vector2(48,159); subtitle.add_theme_font_size_override("font_size",14); subtitle.add_theme_color_override("font_color",Color("64ecd8")); layer.add_child(subtitle)
	await scene()
	title_line("01 / POWER SHOT","Krampon ışığı · temas parlaması · sıcak renkli iz")
	game.charging=true; game.charge=.85; game.finishing.style="power"
	game.shot_direction=p.facing; game.hud.show(); game.hud.bug_age=1
	game.visual_identity._process(0)
	await still("power-windup")
	game.charging=false; game.hud.hide()
	game.finishing.release_charged(9,p.facing,.75)
	await fly(24); camera_at(game.ball.position-p.facing*2.7)
	game.ball.power_trail.draw()
	await still("power-shot")
	await scene("")
	title_line("02 / PLASE","Topun gerçek kavisini izleyen iki turkuaz şerit")
	game.commit_strike(9,p.facing*26+Vector3.UP*3.5,4,false,"shot")
	await fly(30); camera_at(game.ball.position-p.facing*2.3)
	game.ball.power_trail.draw(); await still("finesse")
	await scene("timed")
	title_line("03 / KUSURSUZ ZAMANLAMA","Yalnızca başarılı vuruşta açılan altın halka")
	p.strike_timing=1.08
	game.commit_strike(9,p.facing*25+Vector3.UP*2.2,0,false,"finish")
	game.visual_identity._process(.15)
	camera_at(game.ball.position+Vector3.UP*.15,Vector3(2,3.2,5.8))
	await still("perfect-timing")
	await scene("")
	title_line("04 / İLK ADIM","Krampon hizasında hız çizgileri ve çim parçaları")
	p.velocity=Vector3.ZERO; game.visual_identity.acceleration(9,DT)
	p.velocity=p.facing*7; p.run_phase=1.2; p.animate(.016)
	game.visual_identity.acceleration(9,DT); game.visual_identity._process(.035)
	camera_at(p.position+Vector3.UP*.45,Vector3(3,2.9,5.5))
	await still("acceleration")
	await scene("")
	title_line("05 / KALECİ TEMASI","Beyaz temas darbesi · yağmurda su damlaları")
	p.hide(); var keeper=game.players[0]; keeper.show(); keeper.position=p.position
	keeper.set_piece_pose=""; keeper.start_claim(); keeper.action_timer=.51; keeper.animate(.1)
	keeper.marker.hide(); keeper.call_label.hide()
	game.weather.select(2,true)
	var palm: Vector3=keeper.right_hand.global_position
	game.ball.place(palm+Vector3(0,0,-.09)); await physics_frame; await physics_frame
	game.ball.freeze=true
	game.feedback.contact("glove",0,palm,Vector3(0,1,-1),.9)
	game.visual_identity._process(.065)
	camera_at(keeper.position+Vector3.UP*1.5,Vector3(2,2,5.4))
	await still("keeper-save")
	await scene("")
	title_line("06 / GOL KİMLİĞİ","Takım renkli LED panoları ve ortak eğimli grafikler")
	game.training=false; game.last_kicker=9; game.goal(0); game.replay.goal_tail=0
	game.visual_identity._process(.7)
	p.position=Vector3(-26,0,-17); p.celebration="fist"; p.animate(1)
	game.ball.place(p.position+Vector3(.8,.23,0)); await physics_frame
	game.hud.show(); game.hud.bug_age=1
	camera_at(p.position+Vector3(0,1,0),Vector3(7,3.7,6))
	await still("goal")
	# A short moving example from actual physics, with the camera following it.
	await scene("power")
	title_line("POWER SHOT / HAREKETLİ ÖRNEK","Gerçek oyun görüntüsü · vuruş, iz ve doğal sönme")
	game.finishing.release_charged(9,p.facing,.72)
	for i in range(54):
		await fly(3)
		camera_at(game.ball.position-p.facing*2.0,Vector3(3.0,5.5,8.5))
		game.ball.power_trail.draw()
		var velocity: Vector3=game.ball.linear_velocity; game.ball.freeze=true
		await frame_image("/tmp/sefc-match-identity/frames/power-%03d.png" % i)
		game.ball.freeze=false; game.ball.linear_velocity=velocity
	print("MATCH IDENTITY GALLERY: 7 stills and 54 motion frames saved")
	game.free(); layer.free(); quit()
