extends "res://tests/advanced_play_check.gd"

func record_finish() -> void:
	game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	game.frontend.hide(); game.match_menu.hide()
	game.ball.position=Vector3(0,.23,-24)
	game.commit_strike(9,Vector3(0,3,-30),0,false,"shot")
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false
	for i in range(101):
		var t:=minf(1,i/80.0)
		game.ball.position=Vector3(1.4*sin(t*PI),.23+sin(t*PI)*1.3,-24-t*28)
		game.players[9].position=Vector3(0,0,-24)
		game.replay.capture(.05)
	game.last_kicker=9; game.goal(0); game.replay.goal_tail=0

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-match-character/test.cfg"
	game.controller.set_process(false); game.visual_identity.set_process(false)
	game.club_entrance.set_process(false); game.hud.replay_frame.set_process(false)
	game.experience.reduce_motion=false; game.experience.short_presentation=false
	await reset()
	var gait_signatures: Array=[]; var ready_signatures: Array=[]
	var base: Dictionary=p.appearance.duplicate()
	for style in range(4):
		p.appearance.movement=style; p.apply_build()
		gait_signatures.append(Vector3(p.gait_arm_swing,p.gait_elbow,p.gait_posture))
		p.velocity=Vector3.FORWARD*4; p.shot_preparation=.8; p.animate(.2)
		ready_signatures.append(p.right_arm.rotation)
	check(gait_signatures[0]!=gait_signatures[1] and gait_signatures[1]!=gait_signatures[2] and gait_signatures[2]!=gait_signatures[3],"Four persistent running signatures have distinct arm carriage and posture")
	check(ready_signatures[0].distance_to(ready_signatures[1])>.05,"Shot preparation preserves each player's shoulder signature")
	var at: Vector3=p.position; var velocity: Vector3=p.velocity
	p.SignatureMotion.apply(p)
	check(p.position==at and p.velocity==velocity,"Signature poses cannot move or accelerate the player")
	p.appearance=base; p.apply_build()
	for kind in ["roulette","elastico","roll","scoop"]:
		await reset()
		check(game.skills.start(9,kind),"Real skill starts: "+kind)
		check(game.visual_identity.event_counts.get("skill",0)==0,"Preparing a skill emits no premature arc: "+kind)
		for frame in range(95): await tick()
		check(game.visual_identity.event_counts.get("skill",0)==1,"Only a physical skill contact emits one signature: "+kind)
	await reset(); game.ball.position.y=2
	check(not game.skills.start(9,"roulette") and game.visual_identity.event_counts.get("skill",0)==0,"Rejected skill attempts produce no effect")
	await reset()
	var vfx=game.visual_identity
	var collision_poses: Array=[]
	for body in game.stadium.get_children():
		if body is StaticBody3D: collision_poses.append([body,body.transform])
	var ball_transform: Transform3D=game.ball.transform
	game.feedback.woodwork(Vector3(3.66,1.2,-50),Vector3.RIGHT,1)
	vfx._process(.02)
	check(vfx.post_index>=0 and game.stadium.goal_posts[vfx.post_index].transform!=vfx.post_rest[vfx.post_index],"Woodwork contact visibly vibrates its own post")
	var unchanged: bool=game.ball.transform==ball_transform
	for item in collision_poses: unchanged=unchanged and item[0].transform==item[1]
	check(unchanged,"Post vibration never changes the goal collider or the ball")
	vfx._process(.5)
	var restored:=true
	for i in range(vfx.post_rest.size()): restored=restored and game.stadium.goal_posts[i].transform==vfx.post_rest[i]
	check(restored,"The goal frame settles exactly back into place")
	game.experience.reduce_motion=true
	game.feedback.woodwork(Vector3(3.66,1.2,-50),Vector3.RIGHT,1)
	check(vfx.post_index<0,"Reduced-motion mode suppresses post vibration")
	game.experience.reduce_motion=false
	await reset()
	var receiver=game.players[8]; receiver.show(); receiver.position=p.position+Vector3.RIGHT*12
	game.ball.position=receiver.position+Vector3.UP*.23
	game.reactions.kicked(9,"kick"); game.reactions.received(8)
	check(p.reaction.kind=="acknowledge" and receiver.reaction.kind=="","A completed teammate pass acknowledges its receiver without interrupting first touch")
	game.reactions.update(.1); p.reaction.update(p,.15); p.animate(.1)
	check(p.reaction.weight>0,"A distant passer can perform the acknowledgement")
	p.chosen=true; p.desired=Vector3.FORWARD
	p.reaction.update(p,.3)
	check(p.reaction.kind=="","Fresh movement input releases the social gesture immediately")
	game.reactions.reset(); game.reactions.kicked(9,"shot"); game.reactions.out(1)
	check(p.reaction.kind=="miss" and receiver.reaction.kind=="encourage","A missed shot gives the shooter and a nearby teammate different reactions")
	game.reactions.reset(); game.reactions.kicked(9,"kick"); game.reactions.received(12)
	check(p.reaction.kind=="sorry","An interception does not produce a successful-pass acknowledgement")
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	game.replay.enabled=false; game.last_kicker=9; game.goal(0)
	var celebration=game.celebration
	for i in celebration.targets:
		game.players[i].position=celebration.targets[i]; game.players[i].velocity=Vector3.ZERO
	var saw_pair:=false
	for frame in range(160):
		celebration.update(DT)
		saw_pair=saw_pair or game.players[9].celebration=="high_five"
		await physics_frame
	check(saw_pair and celebration.greeting_done,"Teammates physically meet, exchange a high five, then resume their celebration")
	celebration.skip()
	check(celebration.partner<0 and game.players[9].celebration=="","Skipping a goal clears the paired gesture")
	game.start_match(false,true); game.set_physics_process(false); game.set_process(false)
	game.club_entrance._process(0)
	check(game.club_entrance.visible and game.club_entrance.materials[0].albedo_color!=game.club_entrance.materials[1].albedo_color,"The two tunnel lanes take the actual clubs' different colours")
	game.stadium.supporters.heat=0; game.stadium.supporters._process(2)
	check(game.stadium.supporters.visible,"Ordinary matches also unfurl their opening club displays")
	game.ceremony.phase="presentation"; game.ceremony.age=1
	var first: int=game.ceremony.featured_player(); game.ceremony.age=4
	check(first!=game.ceremony.featured_player(),"The presentation introduces a different player from each team")
	game.ceremony.finish(true); game.club_entrance._process(0)
	check(not game.club_entrance.visible and game.ceremony.featured_player()<0,"Skipping the walkout disables tunnel lights and introduction cards")
	var crowd=game.stadium.crowd
	crowd.reset(); crowd.update(.2,Vector3(0,.23,-42),Vector3(0,0,-12),0,true,false)
	check(crowd.section_age>=0 and is_equal_approx(crowd.section_origin,.75),"A dangerous attack starts a section reaction at the ball's end")
	crowd.react("miss",0,Vector3(0,0,-50))
	check(crowd.cloth_material.get_shader_parameter("event_style")==3 and is_equal_approx(crowd.cloth_material.get_shader_parameter("event_origin"),.75),"A miss propagates the disappointment event to every crowd material")
	game.replay.enabled=true; record_finish()
	var replay=game.replay; var live_transform: Transform3D=game.ball.transform
	var live_velocity: Vector3=game.ball.linear_velocity
	var speed: float=replay.shot_record.speed
	check(replay.goal_record.name==game.players[9].display_name and speed>0 and absf(replay.goal_record.distance-26)<.01,"Goal-card data is captured from the real shot")
	check(replay.begin(),"A recorded goal starts its replay")
	for i in range(1800):
		replay.update(DT)
		if replay.freeze_left>0: break
	check(replay.freeze_left>0 and replay.show_finish_card(),"Crossing the line triggers the finish card and one short hold")
	check(absf(game.ball.position.z*replay.goal_end-50-game.ball.RADIUS)<.005,"The hold is at the whole-ball crossing, interpolated between recorded frames")
	var held_age: float=replay.age; var held_pose: Transform3D=game.ball.transform
	replay.update(.2)
	check(replay.age==held_age and game.ball.transform==held_pose,"The finish hold freezes only the recorded timeline")
	game.state="paused"; var hold: float=replay.freeze_left; replay.update(.2)
	check(replay.freeze_left==hold,"Pause also freezes the replay finish hold")
	game.state="replay"
	for i in range(1800):
		replay.update(DT)
		if game.state!="replay": break
	check(game.state=="goal" and game.ball.transform==live_transform and game.ball.linear_velocity==live_velocity and game.score==[1,0],"After the hold, playback completes and restores the entire live ball state")
	replay.reset()
	check(replay.freeze_left==0 and replay.goal_record.is_empty(),"A new match cannot inherit a stale finish card")
	print("MATCH CHARACTER CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
