extends "res://tests/net_check.gd"
var impacts: Array[Dictionary]=[]

func on_impact(point: Vector3,direction: Vector3,strength: float) -> void:
	impacts.append({"point":point,"direction":direction,"strength":strength})

func scored_shot(speed: float) -> Dictionary:
	game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	game.replay.enabled=false
	game.feedback.reset()
	for net in game.stadium.nets: net.reset()
	for p in game.players: p.collision_layer=0
	game.players[9].position=Vector3(1,0,-43)
	game.last_kicker=9; game.last_touch=0; game.boundary_grace=0
	game.previous_ball=Vector3(0.8,1.1,-49)
	game.ball.place(game.previous_ball,Vector3(0,1,-speed))
	game.camera_focus=Vector3(0,0,-35)
	game.match_camera.snap=true
	game.update_camera(0)
	impacts.clear()
	var peak := 0.0
	var onset := -1
	var counted_goal := false
	var before_touch := false
	var look_z := 0.0
	for i in range(190):
		await physics_frame
		game.feedback.update(1.0/120)
		game.audio.update_atmosphere(1.0/120,game.state)
		if game.state=="playing":
			game.check_boundaries()
			game.previous_ball=game.ball.position
		if game.state=="goal" and not counted_goal:
			counted_goal=true
			before_touch=game.feedback.event_count==0 and not game.audio.net_impact.playing
		game.update_camera(1.0/120)
		peak=maxf(peak,game.feedback.amplitude)
		if impacts.size()>0 and onset<0: onset=i
		if i==120: look_z=game.camera_focus.z
		if visual and speed>25 and i in [25,45,95]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/goal-feel-%03d.png" % i)
	return {"peak":peak,"impacts":impacts.duplicate(true),"onset":onset,"before_touch":before_touch,"goal":counted_goal,"look_z":look_z}

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await frames(3)
	game.set_process(false); game.set_physics_process(false)
	for net in game.stadium.nets: net.struck.connect(on_impact)
	check(not game.audio.net_impact.playing,"Menu starts without a net sound")
	var weak: Dictionary=await scored_shot(8)
	var strong: Dictionary=await scored_shot(32)
	check(weak.goal and strong.goal and game.score==[1,0],"Both slow and hard real shots score exactly once")
	check(weak.before_touch and strong.before_touch,"Crossing the goal line does not fake a net sound or camera impact")
	check(strong.onset>0 and not strong.impacts.is_empty(),"The live ball contact emits the net cue")
	check(strong.impacts.size()<=2 and weak.impacts.size()<=2,"Dozens of physics contact steps cannot become an audio buzz")
	check(strong.impacts[0].strength>weak.impacts[0].strength*1.5,"Net sound and haptics scale with the actual incoming speed")
	check(strong.peak>weak.peak*1.4 and strong.peak<=0.22,"Hard goals have stronger but bounded camera feedback")
	check(strong.impacts[0].direction.z< -0.9 and strong.impacts[0].point.z< -51,"Cue location and direction come from the contacted net")
	check(strong.look_z< -48,"Goal camera follows the ball into the net before celebration")
	check(not game.camera.is_position_behind(game.ball.position),"Live net impact stays in front of the goal camera")
	game.before_pause="goal"; game.state="paused"; game.ball.freeze=true
	game._physics_process(1.0/120)
	var frozen: Dictionary=game.stadium.nets[0].capture_physics()
	await frames(30)
	check(game.stadium.nets[0].capture_physics()==frozen,"Pause preserves net deformation, velocities and contact cooldown")
	game.resume(); game._physics_process(1.0/120)
	check(not game.stadium.nets[0].simulation_paused,"Resuming releases the physical net")
	game.feedback.update(1)
	check(game.feedback.offset()==Vector3.ZERO,"Camera impact fully settles")
	check(game.audio.cheer_kind=="goal" and game.audio.cheering.playing,"Supplied goal applause remains layered over the net impact")
	game.audio.net_contact(1,true)
	var loud: float=game.audio.net_impact.volume_db
	game.audio.play("shot")
	check(game.audio.net_impact.playing and game.audio.effects.playing,"Net sound cannot cut off the shot channel")
	game.audio.net_contact(0.2,false)
	check(game.audio.net_impact.volume_db<loud-6,"Soft outside-net contact is audibly lighter than a hard goal")
	game.audio.update_atmosphere(0.1,"paused")
	check(game.audio.net_impact.stream_paused,"Pause freezes the net sound")
	game.audio.net_impact.stop(); game.audio.net_contact(1,true)
	check(not game.audio.net_impact.playing,"Paused contact cannot start new sound")
	var count: int=game.feedback.event_count
	for state in ["paused","replay","menu","career"]:
		game.state=state
		game.feedback.net_contact(Vector3(0,1,-52),Vector3.FORWARD,1)
	check(game.feedback.event_count==count,"Pause, replay and menus never replay live contact feedback")
	game.audio.update_atmosphere(0.1,"goal")
	game.audio.toggle(); game.audio.net_contact(1,true)
	check(not game.audio.net_impact.playing,"Mute suppresses the net channel")
	game.audio.toggle(); game.audio.background=true; game.audio.net_contact(1,true)
	check(not game.audio.net_impact.playing,"Main-menu background matches stay silent")
	game.audio.background=false; game.audio.net_contact(1,true)
	game.audio.stop_atmosphere()
	check(not game.audio.net_impact.playing,"Leaving a match clears its net sound")
	var wav: AudioStreamWAV=game.audio.clips.net
	var peak_sample := 0
	var biggest_step := 0
	var previous := 0
	for i in range(wav.data.size()/2):
		var sample: int=wav.data.decode_s16(i*2)
		peak_sample=maxi(peak_sample,absi(sample))
		biggest_step=maxi(biggest_step,absi(sample-previous))
		previous=sample
	check(wav.data.decode_s16(0)==0 and absi(previous)<2 and peak_sample<28000,"Net sample fades from and to silence without digital clipping")
	check(peak_sample>4000 and biggest_step<12000 and wav.loop_mode==AudioStreamWAV.LOOP_DISABLED,"Filtered fabric transient is audible without a harsh jump or repeating buzz")
	print("GOAL FEEL CHECK: %d failures" % failures)
	game.free(); quit(0 if failures==0 else 1)
