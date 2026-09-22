extends SceneTree
var game
var failures := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func key(code: int,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func setup() -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	for p in game.players:
		p.visible=false
		p.collision_layer=0
		p.position=Vector3(25,0,25)
		p.velocity=Vector3.ZERO
	game.players[9].visible=true
	game.players[9].position=Vector3.ZERO
	game.players[9].facing=Vector3.FORWARD
	game.kick_lock=0
	game.ball.place(Vector3(0,0.23,-0.82))
	await physics_frame
	await physics_frame
func contact() -> void:
	for frame in range(20):
		if game.kick_contact.pending.is_empty(): return
		var actor=game.players[game.kick_contact.pending.index]
		game.kick_contact.prepare(1.0/120)
		actor.step(1.0/120)
		game.kick_contact.resolve()
		await physics_frame
func capture(label: String,focus: Vector3,size: float=7) -> void:
	if not visual: return
	game.hud.visible=false
	game.camera.size=size
	game.camera.position=focus+Vector3(4,3.5,5)
	game.camera.look_at(focus+Vector3.UP)
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/gameplay-"+label+".png")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await setup()
	for p in game.players:
		p.visible=true
		p.position=p.home
	game.players[11].position.z=-49
	game.players[12].position.z=-47
	game.players[8].position=Vector3(24,0,-33)
	game.ball.place(Vector3(24,0.23,-34))
	await physics_frame
	await physics_frame
	game.dribbler=8
	game.last_touch=0
	game.support.update(0.01)
	check(game.support.roles[4]=="overlap" and game.support.targets[4].x>23 and game.support.targets[4].z< -40,"The right back overlaps a right-wing attack")
	check(game.support.roles[9]=="box" and game.support.roles[10]=="box" and game.support.targets[9].distance_to(game.support.targets[10])>5,"Forwards occupy separate near/far-post receiving spaces")
	check(game.support.targets[7].z>game.support.targets[9].z+3,"A midfielder offers the cutback behind the forwards")
	var onside := true
	for i in game.support.targets: onside=onside and -game.support.targets[i].z<=game.rules.offside_line(0)+0.01
	check(onside,"Support runs stay behind the current offside line")
	game.deliver_pass(8,7,false)
	await contact()
	for frame in range(30): await physics_frame
	game.support.update(0.02)
	check(8 in game.support.runs and game.support.roles.get(8,"")=="give_go","A real pass starts a forward give-and-go run")
	game.last_touch=1
	game.support.update(0.1)
	check(game.support.runs.is_empty(),"Losing possession cancels attacking give-and-go runs")
	game.players[19].position=Vector3(-24,0,33)
	game.players[0].position.z=49
	game.players[1].position.z=47
	game.ball.place(Vector3(-24,0.23,34))
	await physics_frame
	await physics_frame
	game.dribbler=19
	game.support.update(0.01)
	check(game.support.roles.get(15,"")=="overlap" and game.support.targets[15].x< -23 and game.support.targets[15].z>40,"Away-team overlapping runs mirror the correct fullback and attacking end")
	await setup()
	game.players[9].position=Vector3(-6,0,-12)
	game.players[6].visible=true
	game.players[6].position=Vector3(0,0,-1)
	game.players[6].ai_think=0.8
	game.players[11].visible=true
	game.players[11].position=Vector3(0,0,-49)
	game.players[12].visible=true
	game.players[12].position=Vector3(12,0,-25)
	game.ball.place(Vector3(0,0.23,-2))
	await physics_frame
	await physics_frame
	game.dribbler=6
	game.support.passed(9,6)
	game.update_ai(1.0/120)
	check(game.passes[0]==0,"A teammate waits for the user before returning a give-and-go pass")
	game.call_for_pass(false)
	game.update_pass_request(0.3)
	game.update_ai(0.01)
	await contact()
	check(game.last_kicker==6 and game.ai_receivers[0]==9 and game.passes[0]==1,"The user's pass request returns an open give-and-go pass to the runner")
	game.support.passed(9,6)
	game.players[17].visible=true
	game.players[17].position=Vector3(-3,0,-7)
	check(game.support.return_option(6)==-1,"A defender blocking the lane prevents a forced one-two return")
	await setup()
	game.update_contacts(1.0/120)
	var energy: float=game.players[9].energy
	key(KEY_Z,true); key(KEY_Z,false)
	check(game.players[9].feint_time>0 and game.players[9].energy<energy,"Z starts a short skill move and spends stamina")
	var max_side := 0.0
	for frame in range(65):
		game.players[9].step(1.0/120)
		game.update_contacts(1.0/120)
		await physics_frame
		max_side=maxf(max_side,absf(game.ball.position.x))
		if frame==18: await capture("feint",game.players[9].position)
	check(max_side>0.15 and game.dribbler==9,"The feint moves the physical ball sideways without losing close control")
	var cooldown: float=game.players[9].skill_cooldown
	key(KEY_Z,true); key(KEY_Z,false)
	check(game.players[9].skill_cooldown==cooldown,"Skill cooldown prevents repeated input spam")
	for frame in range(60): game.players[9].step(1.0/120); await physics_frame
	key(KEY_V,true); key(KEY_V,false)
	check(game.dribbler==-1 and not game.kick_contact.pending.is_empty(),"V releases the ball for a push into space")
	await contact()
	for frame in range(35): await physics_frame
	check(game.flat_distance(game.ball.position,game.players[9].position)>2,"The pushed ball actually travels ahead of the player")
	await setup()
	game.players[17].visible=true
	game.players[17].position=Vector3(0,0,1.3)
	game.update_contacts(1.0/120)
	key(KEY_E,true)
	game.update_control(1.0/120)
	check(game.players[9].protecting and not game.players[9].sprinting,"Holding E engages ball protection")
	check(not game.duels.ball_exposed(17,9),"The protecting body blocks a reach from behind")
	game.players[9].step(1.0/120)
	await capture("shield",game.players[9].position)
	game.players[17].position=Vector3(0,0,-1.4)
	check(game.duels.ball_exposed(17,9),"A defender on the ball side can still challenge a shield")
	key(KEY_E,false)
	game.dribbler=-1
	game.ball.place(Vector3(2,0.23,-5))
	await physics_frame
	await physics_frame
	key(KEY_E,true); key(KEY_RIGHT,true)
	game.update_control(1.0/120)
	game.players[9].step(1.0/120)
	check(game.players[9].jockeying and game.players[9].desired.length()<0.7 and game.players[9].facing.z< -0.7,"E without possession jockeys sideways while facing the ball")
	key(KEY_E,false); key(KEY_RIGHT,false)
	await setup()
	game.last_touch=1
	key(KEY_G,true); key(KEY_G,false)
	var start: Vector3=game.ball.position
	for frame in range(30):
		game.players[9].step(1.0/120)
		game.duels.resolve(1.0/120)
		await physics_frame
		if frame==18: await capture("standing-tackle",game.players[9].position)
	check(game.players[9].pose=="poke" and game.last_kicker==9 and game.last_touch==0,"G makes a standing foot challenge win an exposed ball")
	check(game.ball.position.distance_to(start)>0.2,"Standing tackle changes the real ball's momentum")
	await setup()
	game.players[17].visible=true
	game.players[17].position=Vector3(0,0,-0.8)
	game.players[17].facing=Vector3.FORWARD
	game.ball.place(Vector3(0,0.23,-1.65))
	await physics_frame
	await physics_frame
	game.dribbler=17
	key(KEY_G,true); key(KEY_G,false)
	for frame in range(22):
		game.players[9].step(1.0/120)
		game.duels.resolve(1.0/120)
		await physics_frame
	check(game.state=="restart" and game.restart_team==1,"A body-first standing challenge from behind awards a foul")
	await setup()
	game.players[17].visible=true
	game.players[17].position=Vector3.ZERO
	game.players[17].facing=Vector3.FORWARD
	game.players[17].active_sprint=true
	game.players[17].sprinting=true
	game.ball.place(Vector3(0,0.23,-1.28))
	await physics_frame
	await physics_frame
	game.dribbler=17
	game.players[9].position=Vector3(0,0,-3.08)
	check(game.duels.ball_opened(17) and game.duels.poke_reach(17)>1.5,"A sprinting carrier opens the ball for a longer standing poke")
	key(KEY_G,true); key(KEY_G,false)
	for frame in range(22):
		game.players[9].step(1.0/120)
		game.duels.resolve(1.0/120)
		await physics_frame
	check(game.last_kicker==9 and game.last_touch==0 and game.state=="playing","G / Xbox X nicks a sprinting player's opened ball from a step away")
	await setup()
	game.players[17].visible=true
	game.players[17].position=Vector3.ZERO
	game.players[17].facing=Vector3.FORWARD
	game.players[17].active_sprint=false
	game.ball.place(Vector3(0,0.23,-0.82))
	await physics_frame
	await physics_frame
	game.dribbler=17
	game.players[9].position=Vector3(0,0,-3.08)
	check(not game.duels.ball_opened(17) and game.duels.poke_reach(17)<1.4,"A tucked jog keeps the short standing-tackle reach")
	key(KEY_G,true); key(KEY_G,false)
	for frame in range(22):
		game.players[9].step(1.0/120)
		game.duels.resolve(1.0/120)
		await physics_frame
	check(game.last_kicker!=9 and game.state=="playing","The same distant poke cannot steal a ball kept at the feet")
	await setup()
	game.players[1].visible=true
	game.players[2].visible=true
	game.players[1].position=Vector3(0,0,-2)
	game.players[2].position=Vector3(0,0,4)
	game.ball.place(Vector3(0,0.23,0),Vector3(0,0,12))
	await physics_frame
	await physics_frame
	game.last_touch=1
	key(KEY_Q,true); key(KEY_Q,false)
	check(game.controlled==2,"Q chooses the covering defender ahead of a dangerous moving ball")
	await setup()
	var keeper=game.players[11]
	keeper.visible=true
	keeper.position=Vector3(0,0,-47)
	keeper.facing=Vector3.BACK
	for frame in range(12): keeper.step(1.0/120); await physics_frame
	game.ball.place(Vector3(12,0.23,-35))
	await physics_frame
	await physics_frame
	game.last_touch=0
	var target: Vector3=game.goalkeeping.update(11,0.01)
	check(target.x>0.5 and target.z> -50,"Keeper shifts along the shooting angle")
	game.ball.place(Vector3(1,0.23,-41))
	await physics_frame
	await physics_frame
	target=game.goalkeeping.update(11,0.01)
	check(game.goalkeeping.modes[11]=="rush" and target.z> -43,"Keeper comes out to close an isolated attacker")
	game.ball.place(Vector3(24,0.23,-25))
	await physics_frame
	await physics_frame
	game.goalkeeping.update(11,0.01)
	check(game.goalkeeping.modes[11]=="angle","Keeper stays on the angle instead of chasing a ball outside the area")
	game.ball.place(Vector3(2.4,3.65,-47),Vector3(-6,0,0))
	await physics_frame
	await physics_frame
	game.goalkeeping.update(11,0.01)
	check(keeper.pose=="claim","A reachable cross triggers a two-handed aerial claim")
	var peak := 0.0
	var glove_peak := 0.0
	for frame in range(60):
		var claim_target: Vector3=game.goalkeeping.update(11,1.0/120)
		keeper.desired=((claim_target-keeper.position)*Vector3(1,0,1)).limit_length(1)
		keeper.step(1.0/120)
		await physics_frame
		peak=maxf(peak,keeper.position.y)
		glove_peak=maxf(glove_peak,keeper.left_hand.global_position.y)
		if frame==30: await capture("keeper-cross",keeper.position)
	check(peak>0.4 and glove_peak>2.3,"Cross claim physically jumps and raises the gloves")
	check(not keeper.can_save(keeper.position+Vector3(5,2,0)),"An aerial claim cannot save a distant cross")
	check(game.goalkeeping.holding==11,"The predicted cross is caught only when it reaches the airborne gloves")
	game.goalkeeping.reset()
	game.ball.release_hold()
	keeper.action_timer=0
	keeper.touch_cooldown=0; keeper.tackle_cooldown=0
	keeper.pose="run"
	keeper.position=Vector3(0,0,-47)
	keeper.velocity=Vector3.ZERO
	keeper.animate(1)
	game.ball.place(keeper.left_hand.global_position)
	await physics_frame
	await physics_frame
	game.last_touch=0
	game.goalkeeping.update(11,0.01)
	check(game.goalkeeping.holding==11 and game.ball.held_by==keeper,"A slow ball at the gloves can be caught")
	for frame in range(270):
		game.goalkeeping.update(11,1.0/120)
		game.keeper_distribution.update(1.0/120)
		game.ai_attack.finishing.game=game
		game.ai_attack.finishing.prepare(1.0/120)
		keeper.step(1.0/120)
		game.keeper_distribution.resolve()
		game.ai_attack.finishing.resolve()
		await physics_frame
	if game.goalkeeping.holding!=-1 or game.ball.held_by!=null or game.last_kicker!=11:
		print("DISTRIBUTION TRACE ",game.goalkeeping.holding," held=",game.ball.held_by," kicker=",game.last_kicker," pose=",keeper.pose," action=",keeper.action_timer," distribution=",game.keeper_distribution.pending," finishing=",game.ai_attack.finishing.pending," save_age=",keeper.motion_clock-keeper.keeper_motion.saved_at)
	check(game.goalkeeping.holding==-1 and game.ball.held_by==null and game.last_kicker==11,"Keeper releases a held ball through a real distribution")
	game.players[9].position=Vector3(-11,0,-43)
	game.ball.place(Vector3(0,1,-47),Vector3(0,0,-25))
	await physics_frame
	await physics_frame
	var parry: Vector3=game.goalkeeping.safe_parry(11)
	check(parry.x>0 and absf(parry.x)>absf(parry.z) and parry.z>0,"Parry chooses the unmarked side away from the central danger area")
	game.begin_restart("TAÇ",0,Vector3(32,0,0))
	check(game.support.runs.is_empty() and game.duels.attempts.is_empty() and game.goalkeeping.holding==-1,"A whistle clears all active skill, run and keeper decisions")
	print("GAMEPLAY DEPTH CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
