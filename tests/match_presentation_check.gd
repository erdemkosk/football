extends SceneTree
var game
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func settle() -> void:
	for i in range(5): await process_frame
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	game.weather.presence.update_visuals(); game.hud.queue_redraw()
	await settle(); RenderingServer.force_draw(false)
	var frame := root.get_texture().get_image()
	check(not frame.is_empty(),"Rendered presentation: "+label)
	check(frame.save_png("res://tests/presentation-"+label+".png")==OK,"Saved visual review: "+label)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	game.controller.set_process(false); game.ball.freeze=true
	game.frontend.hide(); game.match_menu.hide(); game.hud.hide()
	game.state="playing"; game.menu_match.running=false
	var clubs=game.clubs
	var valid := true
	for home in range(8):
		for away in range(8):
			if home==away: continue
			clubs.selected=[home,away]
			for alternate in [[false,false],[true,false],[false,true],[true,true]]:
				clubs.alternate=alternate.duplicate(); clubs.contrast_kits()
				valid=valid and clubs.separation(clubs.kit(0).primary,clubs.kit(1).primary)>=.26
	check(valid,"224 club/kit pairings retain light/dark separation")
	clubs.selected=[0,1]; clubs.alternate=[false,false]; clubs.contrast_kits(); clubs.apply()
	var p=game.players[5]
	check(p.captain and p.captain_band.visible,"The starting captain wears a real upper-arm band")
	game.management.swap_positions(5,9)
	check(p.captain and not game.players[9].captain,"Captaincy follows player identity during tactical swaps")
	game.management.swap_positions(5,9)
	p.dismissed=true; game.management.refresh_captains()
	check(not p.captain and game.players.filter(func(actor): return actor.team==0 and actor.captain).size()==1,"Dismissal transfers the armband to one remaining player")
	p.dismissed=false; game.management.reset()
	check(game.players[0].gloves.size()==2 and game.players[11].gloves.size()==2,"Both keepers have shaped gloves and contrasting wrist cuffs")
	var ink: Texture2D=p.kit_materials.printed.albedo_texture
	var identity: Dictionary=p.identity(); var renamed := identity.duplicate(); renamed.name="ŞENER"
	p.apply_identity(renamed)
	check(ink!=p.kit_materials.printed.albedo_texture,"A name change changes the baked jersey print")
	p.apply_identity(identity)
	check(ink==p.kit_materials.printed.albedo_texture,"Returning to the same identity reuses its print atlas")
	check(p.jersey_body.mesh.get_aabb().size.x>.62 and p.jersey_body.mesh.get_aabb().size.z<.51,"Shoulders are broader than the front-to-back torso silhouette")
	var presence=game.weather.presence
	game.ball.position=Vector3(2,.2,0); presence.update_visuals()
	var grounded: Transform3D=presence.shadows.multimesh.get_instance_transform(0)
	var dark: float=presence.shadows.multimesh.get_instance_color(0).a
	game.ball.position=Vector3(2,7,0); presence.update_visuals()
	var airborne: Transform3D=presence.shadows.multimesh.get_instance_transform(0)
	check(airborne.origin.is_equal_approx(grounded.origin),"A high ball's shadow remains directly on its ground position")
	check(airborne.basis.x.length()>grounded.basis.x.length() and presence.shadows.multimesh.get_instance_color(0).a<dark,"Ball altitude softens and enlarges the shadow without losing it")
	game.weather.select(0,true); presence.update_visuals()
	check(not presence.reflections.visible,"Dry turf has no player reflections")
	game.weather.select(2,true); presence.update_visuals()
	check(presence.reflections.visible and presence.reflections.multimesh.visible_instance_count==200,"Wet turf reflects articulated players and officials in one bounded batch")
	game.ball.hide(); game.players[2].hide(); presence.update_visuals()
	check(presence.reflections.multimesh.visible_instance_count==192 and presence.shadows.multimesh.visible_instance_count==72,"Hidden actors and the hidden ball leave no ghost reflections or shadows")
	game.ball.show(); game.players[2].show()
	p.apply_kit(clubs.kit(0)); game.weather.select(0,true); p.velocity=Vector3(6,0,0)
	p.position=Vector3(0,0,0); p.action_timer=0; p.stain(30)
	var early: float=p.kit_soil
	p.stain(240)
	check(early<.10 and p.kit_soil>early+.30 and p.kit_soil<.82,"Running dirt grows across the match instead of saturating in its opening seconds")
	check(p.kit_materials.socks.get_shader_parameter("soil")>p.kit_materials.printed.get_shader_parameter("soil"),"Socks accumulate more dirt than the upper shirt")
	var before: float=p.kit_soil
	p.pose="slide"; p.action_timer=.7; p.stain(.6)
	check(p.kit_soil>before+.05,"A ground slide adds localized dirt immediately")
	game.state="paused"; before=p.kit_soil; p.stain(120)
	check(p.kit_soil==before,"Pausing never ages the player's clothes")
	game.state="playing"; p.pose="run"; p.action_timer=0; p.velocity=Vector3.ZERO
	p.apply_kit(clubs.kit(0))
	check(p.kit_soil==0 and p.kit_materials.socks.get_shader_parameter("soil")==0,"A fresh kit resets every dirt layer")
	p.kit_soil=.7; p.update_soil(.8); p.dismissed=true
	game.management.reset()
	check(p.kit_soil==0 and p.captain,"Starting another match restores a clean kit and the original captain")
	p.dismissed=false
	var cursor: int=game.weather.spray_cursor
	game.weather.kick_turf(p,Vector3(0,3,0),Vector3(0,5,24))
	check(cursor==game.weather.spray_cursor,"An airborne strike never sprays dirt from the turf")
	game.weather.kick_turf(p,Vector3(0,.2,0),Vector3(0,5,24))
	check(cursor!=game.weather.spray_cursor,"A ground strike emits a short dry-grass burst")
	var crowd=game.stadium.crowd
	check(crowd.cloth_material.get_shader_parameter("home_color")==clubs.kit(0).badge_primary and crowd.cloth_material.get_shader_parameter("away_color")==clubs.kit(1).badge_primary,"Home blocks and away corner receive the selected club colours")
	crowd.react("goal",1,Vector3.ZERO); crowd.update(.1,Vector3.ZERO,Vector3.ZERO,1,false,false)
	check(crowd.cloth_material.get_shader_parameter("event_team")==1.0,"Recoloured fans retain the correct team's goal reaction")
	var burst=game.stadium.pitch_burst
	burst.reset()
	burst.begin(0,Vector3(0,1,-50))
	var paper := 0
	var from_stand := 0
	var from_net := 0
	for flake in burst.flakes:
		if flake.life<=0: continue
		paper+=1
		if absf(flake.position.z)>54.0 or absf(flake.position.x)>48.0: from_stand+=1
		if flake.position.distance_to(Vector3(0,2,-50))<12.0: from_net+=1
	check(paper>=40 and from_stand>paper*0.7 and from_net==0,"Goal paper is thrown from the stands, not the net")
	var flare_live := 0
	for flare in burst.flares:
		if flare.life>0: flare_live+=1
	check(flare_live>=8,"Scoring supporters light terrace flares")
	var open := 0
	for banner in burst.banners:
		if banner.node.visible: open+=1
	check(open>=2,"Supporters unfurl terrace banners after a goal")
	burst.update(1.2)
	check(burst.banners[0].node.scale.y>0.7,"A terrace banner opens rather than appearing fully formed")
	burst.reset()
	burst.begin(1,Vector3(0,1,50))
	var away_ok := true
	for flare in burst.flares:
		if flare.life>0 and not (flare.position.x>35.0 and flare.position.z>22.0): away_ok=false
	check(away_ok,"Away flares stay in the visiting section")
	burst.reset()
	check(burst.banners.all(func(banner): return not banner.node.visible) and burst.flares.all(func(flare): return flare.life<=0),"A new match clears stand celebrations")
	var fourth=game.stadium.sidelines.actors.filter(func(actor): return actor.role=="fourth")[0]
	game.state="restart"
	game.broadcast.substitution(game.players[9].identity(),game.management.bench[0][2],0)
	game.broadcast.update(.01)
	check(fourth.substitution_board.visible and fourth.substitution_board.outgoing==10 and fourth.substitution_board.incoming==14,"Fourth official displays the actual outgoing and incoming shirt numbers")
	check(not game.broadcast.substitution_card.is_empty(),"The substitution has a broadcast strip without opening any menu")
	game.broadcast.update(1); fourth.animate_actor(1,0,Vector3.ZERO,"watch",0)
	game.hud.show(); game.hud.bug_age=1
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=38
	game.camera.position=fourth.position+Vector3(-5,1.8,2.0); game.camera.look_at(fourth.position+Vector3(0,1.2,0))
	await capture("substitution")
	game.broadcast.update(6)
	check(game.broadcast.substitution_card.is_empty() and not fourth.substitution_board.visible,"The strip and raised board clear after the announcement")
	game.hud.hide(); game.state="playing"
	game.weather.select(0,true)
	for actor in game.players+game.referees.actors: actor.hide()
	for index in [0,5,9,14]:
		var actor=game.players[index]; actor.show(); actor.position=Vector3(-3.0+[0,5,9,14].find(index)*2,0,0)
		actor.rig.rotation=Vector3.ZERO; actor.velocity=Vector3.ZERO; actor.animate(0)
	game.players[9].rig.rotation.y=PI
	game.players[14].kit_soil=.75; game.players[14].update_soil(.8)
	game.camera.position=Vector3(1.5,2.6,-8.5); game.camera.look_at(Vector3(0,1,0))
	game.ball.position=Vector3(-.4,.2,-.5)
	await capture("players")
	game.players[9].rig.rotation.y=0
	game.weather.select(2,true)
	game.camera.position=Vector3(3,2.7,-9); game.camera.look_at(Vector3(0,.8,0))
	await capture("wet-contact")
	game.weather.select(0,true)
	for index in [0,5,9,14]: game.players[index].position.z+=45
	game.ball.position=Vector3(-2,4,44)
	game.camera.position=Vector3(12,8,33); game.camera.look_at(Vector3(0,1,48))
	var sun_angles: Array[Vector3]=[]
	for period in [0,2,1]:
		game.stadium.light_rig.select(period)
		sun_angles.append(game.stadium.sun.rotation_degrees)
		await capture(["noon","night","evening"][period])
	check(sun_angles[0].x<sun_angles[1].x and not game.stadium.sun.visible,"Noon has a high sun, evening a low sun, and night uses floodlights")
	game.stadium.light_rig.select(2); game.weather.select(2,true); game.weather.update(.1)
	check(game.stadium.light_rig.period==2 and game.stadium.sun.visible,"Rain retains the selected evening palette")
	game.stadium.light_rig.select(0); game.weather.select(0,true)
	game.camera.position=Vector3(28,28,14); game.camera.look_at(Vector3(42,5,42)); game.camera.fov=63
	await capture("supporters-led")
	game.broadcast.reset()
	check(game.broadcast.substitution_queue.is_empty(),"A match reset clears pending substitution graphics")
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.menu_match.running=true; game.hud.show(); game.ball.freeze=false
	game.weather.select(2,true)
	for frame in range(360):
		game._physics_process(1.0/60); game._process(1.0/60)
		await physics_frame
	game.hud.bug_age=1; game.update_camera(1)
	await capture("live-match")
	check(game.players.all(func(actor): return actor.position.is_finite()) and game.ball.position.is_finite(),"Live wet match keeps physics and presentation finite")
	check(game.weather.presence.shadows.multimesh.visible_instance_count<=96 and game.weather.presence.reflections.multimesh.visible_instance_count<=256,"Live effects stay inside their fixed render budgets")
	print("MATCH PRESENTATION CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
