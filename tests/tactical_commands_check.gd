extends "res://tests/pass_skill_check.gd"
var checks := 0

func check(ok: bool,label: String) -> void:
	checks+=1; super.check(ok,label)

func tick(count: int) -> void:
	for i in range(count):
		game.simulate_match(DT)
		await physics_frame

func cancel_checks() -> void:
	for code in [KEY_D,KEY_Y,KEY_A]:
		for pad in [false,true]:
			setup()
			var binding: int=game.controller.button_for(code)
			if pad: button(binding)
			else: key(code)
			hold(.3); game.controller.combos.update(.3)
			var position: Vector3=game.ball.position
			var velocity: Vector3=game.ball.linear_velocity
			if pad:
				button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_RIGHT_SHOULDER)
			else: key(KEY_B)
			check(not game.action_control.pending(9),"Cancel clears charged action %d pad=%s" % [code,pad])
			if pad:
				button(binding,false); button(JOY_BUTTON_RIGHT_SHOULDER,false); button(JOY_BUTTON_LEFT_SHOULDER,false)
			else: key(code,false)
			check(not game.ball.pending_kick and game.kick_contact.pending.is_empty() and game.ball.position==position and game.ball.linear_velocity==velocity,"Releasing cancelled action neither kicks nor moves the ball")
			check(game.controlled==9 and game.players[9].shot_preparation==0,"Cancel leaves the carrier selected without a stuck preparation")
	setup(); key(KEY_S)
	check(game.passes[0]==1 and not game.kick_contact.pending.is_empty(),"Normal pass waits for its boot contact")
	key(KEY_B); key(KEY_S,false); contact()
	check(game.kick_contact.pending.is_empty() and game.passes[0]==0 and game.ai_receivers[0]<0 and not game.ball.pending_kick,"Cancelling an instant pass retracts its pending contact, count and receiver")
	setup(); button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_A)
	check(game.controlled!=9 and game.kick_contact.pending.get("index",-1)==9,"One-two can switch control before contact")
	key(KEY_B); contact()
	check(game.controlled==9 and not game.ball.pending_kick and game.passes[0]==0,"Cancel recalls the unstruck one-two without leaving an orphan kick")
	setup(); key(KEY_D); hold(.3); key(KEY_D,false)
	var shot: Vector3=game.ball.kick_velocity
	key(KEY_B)
	check(game.ball.pending_kick and game.ball.kick_velocity==shot and game.shots[0]==1,"Cancel cannot recall an already struck shot")
	incoming(); key(KEY_S); game.ball.position=Vector3(0,game.ball.GROUND_HEIGHT,-.4); key(KEY_B)
	check(game.pass_buffer.pending.is_empty() and game.dribbler==-1,"Cancel clears the early pass buffer without claiming an unreceived ball")
	setup(); game.finishing.queue(9,Vector3.FORWARD,.7,"power")
	key(KEY_B)
	check(game.finishing.pending.is_empty() and game.players[9].action_timer==0 and not game.ball.pending_kick,"Cancel stops a special finish before contact")
	setup(); game.ball.position=Vector3(0,1.9,-.5); game.ball.linear_velocity=Vector3(0,-1,1)
	game.dribbler=-1; game.last_kicker=6
	key(KEY_D)
	check(game.aerial_shot_active(9),"Incoming high ball arms a real aerial request")
	key(KEY_B); key(KEY_D,false)
	check(not game.aerial_shot_active(9) and not game.charging and not game.ball.pending_kick,"Cancel clears aerial contact intent without changing the incoming ball")
	setup(); game.skills.start(9,"roll",1); key(KEY_B)
	check(not game.skills.active.has(9),"Ground trick can be abandoned before its first contact")

func runner_checks() -> void:
	for half in [1,2]:
		setup(); game.half=half
		var forward: float=game.attack_sign(0)
		game.players[9].position=Vector3(0,0,-forward*.8); game.players[9].facing=Vector3(0,0,forward)
		game.players[6].position=Vector3(1,0,forward*8); game.players[7].position=Vector3(8,0,forward*6)
		game.players[14].position=Vector3(12,0,forward*25); game.players[11].position.z=forward*48
		key(KEY_N); game.support.update(DT)
		check(game.support.roles.get(6)=="directed_run" and game.controlled==9,"Forward command chooses the aimed teammate and keeps ball control, half=%d" % half)
		var before: Vector3=game.players[6].position
		game.ball.freeze=false; game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,0),Vector3.ZERO)
		await tick(36)
		check((game.players[6].position-before).z*forward>.1,"Requested runner physically advances")
		check(game.support.targets.get(6,Vector3.ZERO).z*forward<=game.rules.offside_line(0),"Forward run respects the current offside line")
		game.begin_pass(true); game.pass_power=.4; game.pass_direction=Vector3.RIGHT; game.update_pass_preview()
		check(absf(game.pass_preview.velocity.z)<.001 and game.pass_preview.velocity.x>0,"A run command cannot pull the free through-pass aim")
		game.cancel_pass(); game.dribbler=9; game.carrier=9
		game.controller.using_gamepad=true; game.controller.stick=Vector2((game.players[6].position-game.players[9].position).x,(game.players[6].position-game.players[9].position).z).normalized()
		button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_LEFT_STICK)
		button(JOY_BUTTON_LEFT_STICK,false); button(JOY_BUTTON_LEFT_SHOULDER,false)
		game.support.update(.11)
		check(game.support.roles.get(6)=="come_short" and game.controlled==9,"LB + L3 calls the same teammate short without switching or toggling timed finishing")
		check(game.flat_distance(game.support.targets[6],game.players[9].position)<6,"Short option stays at a playable passing distance")
		game.last_touch=1; game.dribbler=14; game.support.update(DT)
		check(game.support.runs.is_empty(),"Turnover clears explicit attacking requests")
	setup(); game.players[6].position=Vector3(8,0,0); game.players[7].visible=false
	check(game.support.command()==-1 and game.support.runs.is_empty(),"An empty looking direction does not select a sideways player")
	setup(); button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_RIGHT_STICK)
	button(JOY_BUTTON_RIGHT_STICK,false); button(JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.support.runs.get(6,{}).get("command","")=="directed_run" and game.controlled==9 and not game.ball.pending_kick,"LB + R3 requests a run without pushing the ball or switching players")
	setup(); key(KEY_I); game.support.update(DT)
	game.players[6].position=game.support.targets[6]; game.support.update(.11)
	check(game.support.roles.get(6)=="come_short","A called teammate briefly holds the short option after arriving")

func fake_checks() -> void:
	for code in [KEY_D,KEY_Y,KEY_A]:
		setup(); game.ball.freeze=false; game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,0),Vector3.ZERO)
		await physics_frame; await physics_frame
		key(code); hold(.2); game.controller.combos.update(.2)
		game.controller.stick=Vector2.RIGHT
		var before: Vector3=game.ball.position
		key(KEY_S)
		check(game.skills.active.get(9,{}).get("kind","")==("fake_shot" if code==KEY_D else "fake_pass"),"Prepared action becomes the matching fake, action=%d" % code)
		check(game.ball.position==before and not game.ball.pending_kick,"Fake begins with a pose, without teleporting or shooting the ball")
		key(code,false); key(KEY_S,false)
		var state: Dictionary=game.skills.active.get(9,{})
		await tick(40)
		check(state.get("contacts",0)==1 and state.get("hit_gap",9)<.35,"Fake redirects the ball at one measured boot contact")
		check(game.shots[0]==0 and game.passes[0]==0 and game.ball.position.x>.05,"Fake exits to the chosen side without counting a shot/pass")
	setup(); key(KEY_S); key(KEY_Z)
	check(game.skills.active.get(9,{}).get("kind","")=="fake_pass" and game.passes[0]==0,"Pending instant pass can become a pass fake")
	for b in [JOY_BUTTON_X,JOY_BUTTON_B,JOY_BUTTON_Y]:
		setup(); button(b); hold(.2); game.controller.combos.update(.2)
		button(JOY_BUTTON_A); button(b,false); button(JOY_BUTTON_A,false)
		check(game.skills.active.get(9,{}).get("kind","")==("fake_shot" if b==JOY_BUTTON_X else "fake_pass") and not game.ball.pending_kick,"Face-button fake consumes both releases without a second action: %d" % b)

func restart_checks() -> void:
	for half in [1,2]:
		for kind in ["KORNER","SERBEST VURUŞ"]:
			setup(); game.half=half
			for p in game.players: p.visible=true
			var forward: float=game.attack_sign(0)
			game.players[11].position.z=forward*49; game.players[14].position.z=forward*47
			game.restart_team=0; game.restart_type=kind
			game.restart_point=Vector3(32 if kind=="KORNER" else -8,0,forward*(49 if kind=="KORNER" else 25))
			game.set_pieces.prepare(); game.set_pieces.snap_ready(); game.state="set_piece"
			# This synchronous fixture does not advance the physics frame that
			# normally applies snap_ready's queued stationary-ball placement.
			game.ball.position=game.restart_point+Vector3.UP*game.ball.GROUND_HEIGHT
			game.ball.pending_reset=false; game.ball.linear_velocity=Vector3.ZERO
			var sp=game.set_pieces
			for choice in range(4):
				sp.button=KEY_A; sp.power=.6; sp.preview()
				var aim: Vector3=sp.direction
				var velocity: Vector3=sp.pending_velocity
				key(KEY_1+choice)
				check(sp.routines.selected==choice and sp.routines.runs.size()==4,"Four distinct runners assigned to routine %d, %s half=%d" % [choice,kind,half])
				check(sp.direction==aim and sp.pending_velocity==velocity and sp.power==.6,"Routine selection preserves exact aim, trajectory and power")
				var legal := true
				for i in sp.routines.runs:
					for w in sp.wall:
						if game.flat_distance(sp.targets[i],sp.targets[w])<1.65: legal=false
				check(legal,"Routine staging keeps the free-kick wall clear")
			sp.commit(); sp.update(.1); key(KEY_B); key(KEY_A,false)
			check(sp.runup<0 and sp.button==0 and game.state=="set_piece" and game.kick_contact.pending.is_empty(),"Cancel abandons a restart run-up and release cannot restart it")
			sp.button=KEY_A; sp.power=.6; sp.commit(); sp.launch()
			check(game.support.runs.size()==4,"Restart assignments survive the transition into open play")
			game.ai_receivers[0]=-1; game.ai_pass_time[0]=0; game.dribbler=-1
			var ball_position: Vector3=game.ball.position
			game.ball.position=Vector3(0,8,0)
			for p in game.players: p.position.z+=10
			game.support.update(DT)
			check(game.support.roles.values().has("set_piece_run"),"Restart runs continue in flight without an automatically selected receiver")
			game.ball.position=ball_position
			key(KEY_B)
			check(game.state=="set_piece" and not game.ball.pending_kick and game.passes[0]==0,"Cancel during final restart backswing restores the untaken restart")
	setup(); game.state="set_piece"; game.restart_type="PENALTI"
	check(not game.set_pieces.routines.select(game.set_pieces,0),"Routines cannot alter a penalty or kickoff")
	game.restart_type="KORNER"; game.restart_team=0; game.restart_point=Vector3(32,0,-49)
	game.set_pieces.prepare(); game.state="set_piece"
	var aim: Vector3=game.set_pieces.direction
	button(JOY_BUTTON_LEFT_SHOULDER); button(JOY_BUTTON_DPAD_LEFT)
	button(JOY_BUTTON_DPAD_LEFT,false); button(JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.set_pieces.routines.selected==3 and game.set_pieces.direction==aim and game.controller.aim_buttons.is_empty(),"LB + D-pad selects a routine without leaking into the aim input")

func adaptive_checks() -> void:
	setup(); game.management.difficulty=2
	var brain=game.opponent_coach
	game.ball.position=Vector3(24,game.ball.GROUND_HEIGHT,-22)
	var attributes: Dictionary=game.players[17].attributes.duplicate()
	for attack in range(3):
		game.dribbler=9; brain.update(4.0)
		game.dribbler=14; brain.update(1.0)
	brain.review()
	check(brain.wing_entries[1]>2 and brain.wing_bias>.8,"Repeated visible wing entries build a directional defensive response")
	for i in range(12,22):
		game.players[i].visible=true; game.players[i].position=Vector3((i-17)*3,0,-25)
		game.team_tactics.targets[i]=game.players[i].position; game.team_tactics.roles[i]="block"
	var targets: Dictionary=game.team_tactics.targets.duplicate()
	game.team_tactics.adapt_wing(12,13,false)
	var changed := 0
	for i in targets:
		if targets[i]!=game.team_tactics.targets[i]: changed+=1
	check(changed==1 and game.team_tactics.roles.values().has("wing_cover"),"One midfielder leaves his old lane to cover the repeated wing")
	check(game.players[17].attributes==attributes,"Adaptation never changes opponent attributes")
	game.dribbler=-1; game.carrier=-1; brain.update(180); brain.review()
	check(absf(brain.wing_bias)<.1,"Unused attack habits decay instead of permanently locking the defence")

func rebound_checks() -> void:
	for team in [0,1]:
		setup(); game.dribbler=-1; game.carrier=-1; game.ai_pass_time=[0.0,0.0]
		for p in game.players: p.visible=false
		game.ball.position=Vector3(0,1.1,0); game.ball.linear_velocity=Vector3(1,-1,-3)
		for i in [6,7,8,17,18,19]:
			game.players[i].visible=true; game.players[i].position=Vector3((i%3-1)*4,0,3 if i<11 else -5)
		game.second_balls.alert("save",team); game.second_balls.update(DT)
		check(game.second_balls.targets.size()==6,"Both teams assign a contest and two complementary second-ball positions")
		var first: int=game.second_balls.jobs[team][0]
		var separated := true
		for a in game.second_balls.jobs[team]:
			for b in game.second_balls.jobs[team]:
				if a!=b and game.flat_distance(game.second_balls.targets[a],game.second_balls.targets[b])<3: separated=false
		check(separated and game.second_balls.roles.values().has("finish") and game.second_balls.roles.values().has("protect_goal"),"Finisher, collector and goal cover occupy different reachable areas")
		game.ball.position.x+=.03; game.second_balls.update(.13)
		check(game.second_balls.jobs[team][0]==first,"Tiny landing changes keep the same first challenger")
		var target: Vector3=game.second_balls.targets[first]
		game.update_ai(DT)
		check(game.players[first].desired.dot(target-game.players[first].position)>0,"The assigned first challenger actually runs toward the predicted landing")
		game.dribbler=first; game.second_balls.update(DT)
		check(game.second_balls.targets.is_empty(),"Secured possession ends the second-ball scramble")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-tactical-commands.cfg"
	cancel_checks()
	await runner_checks()
	await fake_checks()
	restart_checks()
	adaptive_checks()
	rebound_checks()
	print("TACTICAL COMMANDS COMPLETE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
