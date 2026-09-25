extends "res://tests/ai_attack_check.gd"

func fixture(team: int,half: int,depth: float,wide: float=0) -> void:
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.half=half
	game.management.apply_formation()
	for p in game.players:
		p.visible=true; p.dismissed=false; p.collision_layer=0; p.collision_mask=1
	game.restart_type="SERBEST VURUŞ"; game.restart_team=team
	game.restart_point=Vector3(wide,0,game.attack_sign(team)*depth)
	game.set_pieces.prepare(); game.set_pieces.snap_ready(); game.state="set_piece"
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false
	game.ball.position=game.restart_point+Vector3.UP*game.ball.GROUND_HEIGHT
	game.ball.linear_velocity=Vector3.ZERO; game.dribbler=-1; game.carrier=-1
	game.controller.stick=Vector2.ZERO; game.controller.held.clear()
	game.kick_lock=0

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/free-kick-support-settings.tmp"
	for team in [0,1]:
		for half in [1,2]:
			fixture(team,half,4,14)
			var sp=game.set_pieces
			var forward: float=game.attack_sign(team)
			var in_box := 0
			var cover := 0
			for i in sp.targets:
				var p=game.players[i]
				if p.team!=team or p.keeper or i==sp.taker: continue
				if absf(p.position.x)<16 and p.position.z*forward>33.5: in_box+=1
				if p.position.z*forward<game.restart_point.z*forward-5: cover+=1
			check(in_box>=3 and cover>=2,"A distant free kick offers box receivers and counter cover, team=%d half=%d" % [team,half])
			check(sp.wall.is_empty() and sp.routines.selected==-1,"A distant delivery needs neither a wall nor a manually selected routine")
			sp.button=KEY_A; sp.power=.9
			sp.direction=(Vector3(0,0,forward*41)-game.restart_point).normalized(); sp.preview()
			check(sp.target.z*forward>36,"A charged distant delivery can actually reach the box receivers")
			if "--visual" in OS.get_cmdline_user_args() and team==0 and half==1:
				game.match_menu.display.set_fullscreen(false)
				game.match_menu.display.select_resolution(Vector2i(1440,900))
				game.frontend.hide(); game.match_menu.hide(); game.controls_help.hide()
				game.hud.sync_navigation(); game.toast_timer=0
				game.camera.position=Vector3(25,51,9); game.camera.look_at(Vector3(0,0,-26)); game.camera.size=64
				game.hud.queue_redraw()
				for frame in range(4): await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://tests/free-kick-box-support-verified.png")
			sp.commit(); sp.launch()
			check(game.state=="playing" and game.support.runs.size()>=3,"The default delivery commits attacking runs into open play")
			# Clear only the kick wind-up for this off-ball movement fixture.
			game.kick_contact.reset(); game.last_touch=team
			game.ball.position=Vector3(0,6,forward*43); game.ball.linear_velocity=Vector3(0,-2,forward*8)
			var starts: Dictionary={}
			for i in game.support.runs: starts[i]=game.players[i].position
			for tick in range(60):
				game.ai_attack.update(DT); game.update_ai(DT)
				for i in starts:
					if not game.is_user_player(i): game.players[i].step(DT)
				await physics_frame
			var moved := 0
			for i in starts:
				if (game.players[i].position-starts[i]).z*forward>.5: moved+=1
			check(moved>=2,"At least two receivers physically continue toward the delivery after release")
	fixture(0,1,-25)
	check(game.set_pieces.routines.runs.is_empty(),"A deep own-half free kick retains build-up instead of sending the team into the far box")
	fixture(0,1,4)
	var sp=game.set_pieces
	sp.routines.select(sp,0)
	check(sp.routines.runs.values().any(func(point): return point.z*game.attack_sign(0)>40),"A selected near-post routine from distance still attacks the box")
	fixture(0,1,4)
	sp=game.set_pieces
	sp.button=KEY_S; sp.power=.4; sp.preview(); sp.commit(); sp.launch()
	check(game.support.runs.is_empty(),"Choosing the short ground pass keeps the default delivery runs uncommitted")
	if "--full-flow" in OS.get_cmdline_user_args():
		game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
		game.begin_restart("SERBEST VURUŞ",0,Vector3(14,0,-4))
		for tick in range(7200):
			game._physics_process(DT); await physics_frame
			if game.state=="set_piece": break
		var receivers := 0
		for i in range(1,11):
			if i!=game.set_pieces.taker and game.players[i].position.z< -33.5 and absf(game.players[i].position.x)<16: receivers+=1
		print("DISTANT FLOW state=",game.state," phase=",game.set_pieces.recovery.phase," receivers=",receivers)
		check(game.state=="set_piece" and receivers>=3,"The complete distant-restart recovery brings real receivers into the box before the whistle")
	print("FREE KICK SUPPORT CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
