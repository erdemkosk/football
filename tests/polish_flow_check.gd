extends "res://tests/trophy_presentation_check.gd"
const Contact=preload("res://scripts/contact_profile.gd")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.match_menu.config_path="/tmp/sefc-polish-settings.cfg"; game.controller.device=0
	game.career.save_root="/tmp/sefc-polish-career"; DirAccess.make_dir_recursive_absolute(game.career.save_root)
	game.start_match(false,false); game.ball.freeze=true; game.experience.short_presentation=false
	# Feedback is emitted once at contact and each surface has a distinct timbre/pulse.
	var soft:=Contact.read("kick",.4); var shot:=Contact.read("shot",.9)
	var glove:=Contact.read("glove",.9); var post:=Contact.read("woodwork",.9)
	check(soft.duration<shot.duration and soft.low<shot.low and post.high>post.low and glove.low>glove.high,"Pass, shot, woodwork and gloves have distinct, bounded haptic envelopes")
	check(game.audio.clips.glove.data!=game.audio.clips.kick.data and game.audio.clips.woodwork.data!=game.audio.clips.shot.data,"Gloves and posts use their own generated sound instead of a kick")
	game.audio.muted=false; game.audio.background=false; game.audio.paused=false
	var cursor: int=game.audio.contact_cursor
	game.feedback.woodwork(Vector3(3.66,1,-50),Vector3.LEFT,.8)
	check(game.audio.contacts[cursor].stream==game.audio.clips.woodwork,"A post impact dispatches its metallic sound on the impact frame")
	game.ball.pending_reset=false; game.ball.position=Vector3(0,.22,0)
	var p=game.players[6]; p.position=Vector3(0,0,.55); p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	p.pose="run"; p.action_timer=0; p.kick_timer=0; p.receive_timer=0; p.animate(.2)
	game.state="playing"; game.kick_lock=0; game.last_kicker=6; game.dribbler=6
	cursor=game.audio.contact_cursor
	check(game.kick_contact.queue(6,Vector3(0,0,-25),0,"shot") and game.audio.contact_cursor==cursor,"Preparing a shot makes no premature contact sound")
	game.kick_contact.reset(); p.ball_actions.finish_contact(p); p.ball_actions.release_age=.27; p.ball_actions.recovery_power=.9
	var velocity: Vector3=p.velocity; var request: Vector3=p.desired; var transform: Transform3D=p.transform
	p.spine.rotation=Vector3.ZERO; p.ball_actions.recover_weight(p)
	check(absf(p.spine.rotation.y)>.08 and p.transform==transform and p.velocity==velocity and p.desired==request,"Post-shot weight recovery moves the torso without delaying movement or changing physics")
	# Short presentation is persisted, but never changes the actual match clock.
	game.experience.short_presentation=true; game.match_menu.save_settings()
	game.experience.short_presentation=false; game.match_menu.load_settings()
	check(game.experience.short_presentation,"Short/full presentation preference survives settings reload")
	game.match_menu.show_page(3)
	var found:=false
	for field in game.match_menu.fields:
		if field[0] is OptionButton and field[0].item_count==2 and field[0].get_item_text(0).begins_with("Tam"): found=true
	check(found,"The presentation preference is available in the normal settings controls")
	game.match_menu.hide(); game.frontend.hide()
	game.state="restart"; game.restart_type="TAÇ"; game.restart_team=0
	game.management.queue_sub(9,1); game.management.prepare_substitutions()
	var incoming: String=game.management.bench[0][1].name
	var clock: float=game.match_time; var used: int=game.management.used[0]
	for i in range(28): game.management.update_substitutions(.1)
	check(game.pace.age>=0,"Short presentation schedules a covered substitution after a brief introduction")
	game.pace.update(.19)
	check(game.pace.alpha()>.99 and game.management.transit.is_empty() and game.players[9].display_name==incoming and game.management.used[0]==used+1,"The fade completes the real substitution once, including identity and substitution allowance")
	game.pace.update(.3)
	check(game.match_time==clock and game.pace.age<0,"Presentation cuts consume no match time and always release the fade")
	game.begin_restart("TAÇ",0,Vector3(preload("res://scripts/pitch_dimensions.gd").HALF_WIDTH,0,-5))
	game.pace.restart_ready()
	var taker=game.players[game.set_pieces.taker]
	check(game.state=="set_piece" and game.ball.held_by==taker and taker.set_piece_pose=="throw" and game.set_pieces.formation_ready(),"A shortened throw-in retains the raised ball, legal formation and taker's controls")
	game.ball.freeze=false; await physics_frame; await physics_frame
	check(game.ball.position.distance_to(taker.hand_center())<.15,"The first physics frames after a short cut keep the ball in the thrower's hands")
	game.state="restart"; game.pace.request(func(): game.state="set_piece")
	game.state="paused"; var age: float=game.pace.age; game.pace.update(1)
	check(game.pace.age==age,"Pause freezes a pending presentation cut")
	game.state="playing"; game.pace.update(.2)
	check(game.state=="playing" and game.pace.age<0,"An obsolete cut cannot overwrite live play after a manual transition")
	game.start_match(false,true)
	for i in range(600):
		game.simulate_match(1.0/120)
		await physics_frame
		if game.state=="set_piece" and game.pace.age<0: break
	check(game.state=="set_piece" and game.match_time==0,"Short opening presentation automatically reaches a legal kickoff without consuming match time")
	game.begin_restart("KORNER",0,Vector3(34,0,-50))
	for i in range(1200):
		game.simulate_match(1.0/120)
		await physics_frame
		if game.state=="set_piece" and game.pace.age<0: break
	check(game.state=="set_piece" and game.set_pieces.formation_ready(),"Normal restart recovery invokes the short cut and retains legal corner spacing")
	game.state="goal"; game.goal_team=1; game.score=[0,1]; game.last_kicker=20
	game.celebration.begin(1)
	for i in range(600):
		game.simulate_match(1.0/120); await physics_frame
		if game.state=="set_piece" and game.pace.age<0: break
	check(game.state=="set_piece" and game.restart_type=="SANTRA" and game.restart_team==0 and game.score==[0,1],"Short goal celebration returns to the correct kickoff and retains the goal")
	# Transfer comparison shows actual abilities and is reachable before signing.
	game.experience.short_presentation=false
	var c=game.career; var ui=game.career_screen
	c.new_career("c00",1); ui.open_hub(); ui.go("market"); ui.filter=c.player("p0033").name; ui.selected="p0033"; ui.build()
	game.controller.menus.sync()
	check(go(named("KADRONLA KARŞILAŞTIR")),"The transfer comparison action is controller reachable")
	tap(JOY_BUTTON_A)
	check(ui.page=="comparison" and ui.comparison.peer!="" and c.player(ui.comparison.peer).club==c.world.user,"Comparison opens alongside an appropriate existing squad member")
	var row: Dictionary=ui.comparison.rows(c)[0]
	check(row.a==c.player(ui.comparison.peer).attributes.pace and row.b==c.player("p0033").attributes.pace,"The comparison reports actual speed rather than inflated decorative ratings")
	await capture("polish-comparison")
	ui.back(); check(ui.page=="market" and ui.selected=="p0033","Backing out preserves the chosen transfer target")
	c.club().cash=80000000; c.club().budget=70000000
	check(c.transfer("p0033",c.world.user,1000000,15000,3,2,""),"A real signed transfer records the arriving player")
	var pid: String="p0033"; var member: Dictionary=c.player(pid)
	check(member.arrival.club==c.world.user and not member.arrival.debut and c.save() and c.load_slot(1),"First-appearance status survives saving and loading")
	# Put the transfer into the next match's selected eleven, independent of rating.
	member=c.player(pid)
	if pid not in c.club().lineup:
		for i in range(1,11):
			if c.player(c.club().lineup[i]).role==member.role: c.club().lineup[i]=pid; break
	var fixture: Dictionary=c.next_fixture(); c.world.date=fixture.day
	ui.play(); game.frontend.confirm(); game.ceremony.finish(true)
	check(game.broadcast.debut_queue.any(func(item): return item.id==pid),"The new signing is introduced in his first played match")
	game.state="playing"; game.broadcast.update(.25)
	check(game.broadcast.debut_card.id==pid and not c.player(pid).arrival.debut,"The first-match graphic does not prematurely consume the career appearance")
	game.broadcast.update(.25); game.update_camera(0); await capture("polish-debut")
	game.score=[1,0]; game.state="finished"; c.finish_match()
	check(c.player(pid).arrival.debut,"Only completing an appearance consumes the persisted debut")
	if game.state=="trophy": game.finale.age=2; game.finale.finish_ceremony()
	game.broadcast.reset(); c.in_match=true
	for actor in game.players:
		if actor.career_id==pid: game.broadcast.debut(actor)
	c.in_match=false
	check(game.broadcast.debut_queue.is_empty(),"A completed debut is never advertised as a new arrival twice")
	# Full trophy presentation includes the bench, coach, a shared cup and photo.
	stage_final(); play_final(); game.score=[2,0]; game.state="finished"; game._process(0)
	var f=game.finale; var presentation=f.presentation
	check(presentation.winners.size()==18 and presentation.guests.size()==8 and is_instance_valid(presentation.coach),"The winning eighteen and their coach attend the ceremony without adding gameplay slots")
	var money: int=c.club().cash; var appearances: int=c.player(c.club().lineup[0]).appearances
	advance_to(6); await capture("polish-lift")
	advance_to(11.2)
	var left: Vector3=f.trophy.to_global(Vector3(-.32,.13,0)); var right: Vector3=f.trophy.to_global(Vector3(.32,.13,0))
	check(f.phase=="share" and presentation.captain.right_hand.global_position.distance_to(left)<.08 and presentation.receiver.left_hand.global_position.distance_to(right)<.08,"Captain and teammate share physical handle contact during the handover")
	await capture("polish-handover")
	advance_to(14.8)
	check(presentation.receiver.left_hand.global_position.distance_to(f.trophy.to_global(Vector3(-.32,.13,0)))<.08 and presentation.receiver.right_hand.global_position.distance_to(f.trophy.to_global(Vector3(.32,.13,0)))<.08,"The teammate receives and lifts the cup with both hands")
	advance_to(19)
	check(f.phase=="photo" and presentation.winners.all(func(actor): return is_equal_approx(actor.position.y,.16)),"The celebration settles into a grounded team photo")
	await capture("polish-photo")
	var guests: Array=presentation.guests.duplicate()
	advance_to(23.1); await process_frame
	check(guests.all(func(actor): return not is_instance_valid(actor)) and game.players.size()==22,"Leaving the ceremony removes every presentation-only actor")
	check(c.club().cash==money and c.player(c.club().lineup[0]).appearances==appearances,"Bench celebration cannot alter money or career appearances")
	game.experience.short_presentation=true
	check(f.show_award(f.award_for_division(World.LEAGUES.size()+1)),"The earned cup can be replayed using short presentation")
	advance_to(9.5)
	check(f.phase=="photo","Short trophy presentation still includes the handover and team photo")
	advance_to(11.6)
	check(game.state!="trophy" and c.club().cash==money,"Short ceremony completes in half the time without duplicating its prize")
	print("POLISH FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
