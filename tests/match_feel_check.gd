extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/feel-"+label+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.start_match(false,false)
	game.set_process(false); game.set_physics_process(false)
	game.controller.set_process(false)
	game.frontend.hide(); game.match_menu.hide()
	game.ball.freeze=true; game.ball.pending_reset=false
	var p=game.players[6]
	p.velocity=Vector3.ZERO; p.position=Vector3(0,0,0); p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO
	p.begin_receive("foot",Vector3(.18,.22,-.5),Vector3(0,0,3),0)
	check(p.ball_actions.receive_contact=="sole","Slow grounded delivery selects a sole trap")
	p.begin_receive("foot",Vector3(.18,.22,-.5),Vector3(0,0,16),0)
	check(p.ball_actions.receive_contact=="inside","Firm delivery selects an inside-foot cushion")
	p.begin_receive("chest",Vector3(0,1.3,-.2),Vector3(0,-2,9),0)
	check(p.receive_style=="chest","High delivery retains chest control")
	game.team_control.select(6,true)
	check(game.team_control.selection_age==0,"Changing controlled player starts the selection pulse")
	game.team_control.selection_age=.3; game.team_control.select(6,true)
	check(game.team_control.selection_age==.3,"Selecting the same player does not restart the pulse")
	game.dribbler=-1; game.ball.linear_velocity=Vector3(0,0,-20)
	game.match_camera.reset(); game.match_camera.select("sideline")
	for i in range(120): game.match_camera.apply(Vector3.ZERO,70,1.0/120)
	var lead: Vector3=game.match_camera.attack_lead
	check(lead.z< -2 and lead.length()<4,"Sustained attack creates bounded camera lead")
	game.ball.linear_velocity=Vector3(0,0,20)
	game.match_camera.apply(Vector3.ZERO,70,1.0/120)
	check(game.match_camera.attack_lead.distance_to(lead)<.2,"A deflection cannot abruptly reverse camera lead")
	game.match_camera.reset()
	check(game.match_camera.attack_lead==Vector3.ZERO and game.match_camera.attack_width==0,"New match clears camera anticipation")
	var forward: float=game.attack_sign(0)
	game.ball.position=Vector3(0,.3,forward*45)
	game.reactions.kicked(6,"shot")
	check(game.reactions.save_on_target(11,Vector3(0,0,forward*15)),"A saved goal-bound shot qualifies as on target")
	check(not game.reactions.save_on_target(11,Vector3(20,0,forward*15)),"A wide shot stopped by the keeper is not on target")
	game.reactions.saved(11,true); game.reactions.on_target(0)
	check(game.shots_on_target[0]==1,"Parry followed by goal cannot count the same shot twice")
	game.reactions.kicked(6,"kick"); game.reactions.saved(11,true)
	check(game.shots_on_target[0]==1,"A gathered cross does not become an on-target shot")
	game.state="playing"; game.ball.linear_velocity=Vector3.ZERO
	game.ball.position=p.position+Vector3(.3,.22,-.6)
	p.receive_timer=0; p.ball_actions.receive_feedback_time=1.2; p.ball_actions.receive_reason="SERT GELEN TOP"
	game.hud.bug_age=2; game.team_control.selection_age=.1
	game.hud.sync_navigation()
	game.update_camera(1)
	await capture("match")
	game.state="finished"; game.score=[2,1]; game.shots=[8,5]; game.passes=[31,24]; game.saves=[2,3]
	game.shots_on_target=[5,3]; game.possession=[130,110]; game.match_time=game.LENGTH
	game.hud.sync_navigation()
	await capture("result")
	var names := [game.team_name(0),game.team_name(1)]
	game.hud.rematch()
	check(game.state=="playing" and game.score==[0,0] and game.shots_on_target==[0,0],"Rematch starts directly with clean score and shot statistics")
	check(names==[game.team_name(0),game.team_name(1)],"Rematch preserves the selected clubs")
	print("MATCH FEEL CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
