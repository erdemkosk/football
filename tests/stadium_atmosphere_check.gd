extends SceneTree
var game
var checks := 0
var failures := 0
const Clock = preload("res://scripts/match_clock.gd")

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func settle() -> void:
	for i in range(8): await process_frame
func capture(label: String) -> Image:
	if "--visual" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return Image.new()
	game.hud.queue_redraw(); await settle(); RenderingServer.force_draw(false)
	var frame := root.get_texture().get_image()
	check(not frame.is_empty() and frame.save_png("res://tests/atmosphere-"+label+".png")==OK,"Rendered "+label)
	return frame
func point_camera(eye: Vector3,at: Vector3,fov: float=55) -> void:
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=fov; game.camera.position=eye; game.camera.look_at(at)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	game.controller.set_process(false); game.ball.freeze=true
	game.frontend.hide(); game.match_menu.hide(); game.hud.hide()
	game.state="playing"; game.menu_match.running=false
	var rig=game.stadium.light_rig
	check(game.stadium.env.background_mode==Environment.BG_SKY and rig.sky_material.get_shader_parameter("cloud_noise")!=null,"A procedural sky replaces the solid background")
	rig.set_process(false)
	rig.sky_tick=0; rig._process(.5)
	var stamp: float=rig.sky_material.get_shader_parameter("cloud_clock")
	rig._process(.6)
	check(rig.sky_material.get_shader_parameter("cloud_clock")>stamp,"Cloud decks advance on a bounded update cadence")
	var palettes: Array[Color]=[]
	point_camera(Vector3(14,2,-27),Vector3(-12,20,64),62)
	for period in [0,2,1]:
		rig.select(period); game.weather.select(0,true)
		palettes.append(rig.sky_material.get_shader_parameter("horizon"))
		check(game.stadium.env.glow_enabled==(period==1),"Bloom follows the selected time of day: "+str(period))
		await capture(["sky-noon","sky-night","sky-evening"][period])
	check(palettes[0]!=palettes[1] and palettes[1]!=palettes[2],"All three skies use distinct palettes")
	game.weather.select(2,true)
	check(rig.sky_material.get_shader_parameter("coverage")>.9 and rig.period==1,"Rain increases cloud coverage without resetting the night palette")
	check(game.stadium.env.glow_bloom==0.0 and game.stadium.env.glow_hdr_threshold>1.0,"Night glow preserves dark scene detail and excludes ordinary pixels")
	point_camera(Vector3(30,1.4,-24),Vector3(-13,1,12),62)
	await capture("wet-floodlight")
	game.weather.select(0,true); rig.select(0)
	check(game.stadium.grass.get_shader_parameter("flood_glint")==0.0,"Daytime removes floodlight reflection highlights")
	var props=game.stadium.sidelines.get_node("MatchDayEquipment")
	check(props.items.size()==14 and props.items.filter(func(p): return p.kind=="spare_ball").size()==6,"Two equipment stations and six spare balls furnish the touchline")
	check(props.items.all(func(p): return absf(p.position.x)>game.P.HALF_WIDTH+3),"Every prop stays outside the pitch and technical-area walking lane")
	check(props.find_children("*","CollisionObject3D",true,false).is_empty(),"Decorative equipment cannot deflect the live ball or trap actors")
	check(props.batch_stats.batches<=20 and props.batch_stats.sources>100,"Equipment geometry shares a small static render budget")
	point_camera(Vector3(game.P.HALF_WIDTH-.5,2.3,-2.2),Vector3(game.P.HALF_WIDTH+5,.7,-7),47)
	await capture("equipment")
	point_camera(Vector3(game.P.HALF_WIDTH+3.0,1.3,-5.4),Vector3(game.P.HALF_WIDTH+4.75,.52,-6.2),48)
	await capture("equipment-towel")
	point_camera(Vector3(game.P.HALF_WIDTH+2.8,1.6,-15.6),Vector3(game.P.HALF_WIDTH+5.16,.86,-16.8),48)
	await capture("equipment-bib")
	var architecture=game.stadium.architecture
	game.half=1; game.match_time=game.LENGTH*.25; game.score=[2,1]; game.update_stadium_score()
	check(architecture.clock_labels.all(func(label): return label.text=="22:30") and architecture.score_labels.all(func(label): return label.text=="2   :   1"),"Both stadium displays show the live score and clock")
	game.match_time+=game.LENGTH/5400.0; game.update_stadium_score()
	check(architecture.clock_labels[0].text=="22:31","The physical clock visibly advances by one match second")
	check(Clock.text(121,240,1)=="45+1" and Clock.text(243,240,2)=="90+2","Both halves display added time instead of freezing at 90 minutes")
	check(Clock.text(280,240,2,true)=="105:00" and Clock.text(320,240,2,true)=="120:00","Extra-time clocks retain correct minutes and seconds")
	game.state="halftime"; game.match_time=game.LENGTH*.5; game.update_stadium_score()
	check(architecture.phase_labels.all(func(label): return label.text=="DEVRE"),"Half-time status appears on the physical boards")
	game.state="playing"; game.half=2; game.match_time=game.LENGTH*.72; game.update_stadium_score()
	point_camera(Vector3(0,12,40),Vector3(0,12.4,64.6),40)
	await capture("scoreboard")
	game.replay.frames.clear(); game.replay.sample_age=0
	game.match_time=100; game.score=[0,0]; game.half=1
	for i in range(30):
		game.match_time+=.05
		game.ball.position=Vector3(2,.3,-35-i*.3)
		game.replay.capture(.05)
	game.match_time+=.05; game.score=[1,0]; game.ball.position=Vector3(2,.4,-48)
	var live_time: float=game.match_time
	check(game.replay.begin(),"A recorded goal starts a real replay")
	game.hud.show(); game.replay.update(.15); game.update_stadium_score()
	check(architecture.score_labels[0].text=="0   :   0" and game.score==[1,0] and game.match_time==live_time,"Replay boards show the recorded pre-goal score without mutating live match data")
	check(architecture.clock_labels[0].text==Clock.text(game.replay.display_seconds,game.LENGTH,1),"Replay boards follow the recorded clock")
	game.hud.replay_frame.sync()
	check(game.hud.replay_frame.visible and game.hud.replay_frame.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Replay treatment is visible and cannot intercept input")
	check(Rect2(game.hud.replay_frame.position,game.hud.replay_frame.size)==game.ui.bounds(),"Letterbox and grain cover the complete output aspect")
	await capture("replay")
	game.before_pause="replay"; game.state="paused"; game.hud.replay_frame.sync(); game.update_stadium_score()
	check(not game.hud.replay_frame.visible and architecture.score_labels[0].text=="0   :   0","Pause hides the treatment while preserving the replay board state")
	game.resume(); game.replay.finish(); game.hud.replay_frame.sync()
	check(game.hud.replay_frame.visible and game.replay.transition_alpha()>.99,"Replay exit covers the return to live action with a short fade")
	game.replay.update_outro(.3); game.hud.replay_frame.sync()
	check(not game.hud.replay_frame.visible and architecture.score_labels[0].text=="1   :   0" and game.match_time==live_time,"Skipping or finishing replay removes treatment and restores the live scoreboard")
	if "--visual" in OS.get_cmdline_user_args():
		game.hud.hide()
		game.match_menu.display.set_fullscreen(false)
		for dimensions in [Vector2i(1200,900),Vector2i(1720,720)]:
			root.size=dimensions; await settle()
			game.state="replay"; game.hud.show(); game.hud.replay_frame.sync()
			game.hud.sync_navigation()
			check(game.hud.nav_buttons[0].position==Vector2(game.ui.bounds().end.x-225,game.ui.bounds().position.y+8),"Replay skip target follows the resized caption: "+str(dimensions))
			check(Rect2(game.hud.replay_frame.position,game.hud.replay_frame.size)==game.ui.bounds(),"Resized replay covers "+str(dimensions))
			var frame: Image=await capture("replay-"+str(dimensions.x))
			if not frame.is_empty():
				check(frame.get_pixel(4,4).get_luminance()<.06 and frame.get_pixel(frame.get_width()-5,frame.get_height()-5).get_luminance()<.06,"Letterbox reaches all corners at "+str(dimensions))
		# Start a second real replay and exercise its visible mouse skip target.
		game.state="goal"
		for i in range(25): game.replay.capture(.05)
		game.replay.begin(); game.hud.sync_navigation(); await settle()
		var at: Vector2=game.hud.nav_buttons[0].get_global_transform_with_canvas()*(game.hud.nav_buttons[0].size*.5)
		for pressed in [true,false]:
			var event := InputEventMouseButton.new(); event.position=at; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
			root.push_input(event,true)
		await settle()
		game.replay.update_outro(.3); game.hud.replay_frame.sync()
		check(game.state=="goal" and not game.hud.replay_frame.visible,"Mouse skip ends replay and clears the overlay after a wide-screen resize")
	game.free()
	print("STADIUM ATMOSPHERE CHECK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
