extends "res://tests/keeper_handling_check.gd"

func wear_checks() -> void:
	await setup_keeper()
	game.state="playing"; game.menu_match.running=false
	var w=game.weather
	w.reset_match(); w.select(0,true)
	var p=game.players[9]; p.show(); p.position=Vector3(4,0,8)
	p.surface=w; p.action_timer=0; p.pose="run"; p.set_piece_pose=""; p.desired=Vector3.RIGHT
	for i in range(150): p.step(DT); w.update(DT); await physics_frame
	check(w.wear.contacts>3,"Real dry footsteps write match-long turf wear")
	var old: int=w.wear.contacts
	p.desired=Vector3.ZERO; p.velocity=Vector3.ZERO
	for i in range(80): p.step(DT); await physics_frame
	check(w.wear.contacts==old,"A stationary player cannot churn the turf each frame")
	var at:=Vector3(0,0,47)
	var original_grip: float=w.grip_at(at)
	for i in range(8): w.foot_contact(p,at)
	var dry: Vector2=w.wear.sample(at)
	check(dry.x>0 and w.wear.sample(at+Vector3(4,0,0))==Vector2.ZERO,"Traffic accumulates at the contacted goalmouth, not across untouched grass")
	w.reset_match(); w.select(2,true)
	for i in range(8): w.foot_contact(p,at)
	var wet: Vector2=w.wear.sample(at)
	check(wet.x>dry.x,"The same number of contacts leaves stronger wear in rain")
	w.select(0,true)
	check(w.wear.sample(at)==wet and is_equal_approx(w.grip_at(at),original_grip),"Drying preserves wear and visual scarring does not alter traction")
	for i in range(w.MARK_LIMIT+4): w.stamp(Vector3(10,0,10),Vector3.FORWARD,Vector2(.2,.4),Color.BROWN)
	w.update(240)
	check(w.wear.sample(at)==wet,"Old wear survives both tread lifetime and mark-pool recycling")
	check(w.mark_count==w.MARK_LIMIT and w.wear.image.get_size()==w.wear.SIZE,"Long matches retain fixed mark and texture budgets")
	p.position=Vector3(-3,0,47); p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO; p.facing=Vector3.RIGHT
	w.foot_state.clear(); old=w.wear.contacts
	p.start_slide(Vector3.RIGHT)
	for i in range(120): p.step(DT); w.update(DT); await physics_frame
	check(w.wear.contacts>old+3 and w.wear.sample(Vector3(-1.5,0,47)).y>0,"A physical slide leaves torn sod along its actual path")
	old=w.wear.contacts; game.state="replay"
	p.position+=Vector3.RIGHT; w.player_step(p,DT); w.foot_contact(p,p.position)
	check(w.wear.contacts==old,"Replay poses cannot write fresh pitch damage")
	game.state="paused"; var clock: float=w.clock
	game._physics_process(DT)
	check(w.clock==clock and w.wear.contacts==old,"Pausing freezes surface events")
	game.start_match(false,false)
	check(w.wear.contacts==0 and w.wear.sample(at)==Vector2.ZERO,"A new match restores the surface memory")

func recover_dive(team: int,side: float,wet: int) -> void:
	var p=await setup_keeper(team,wet)
	game.state="playing"; game.menu_match.running=false
	game.weather.reset_match(); game.weather.select(wet,true)
	p.start_dive(side*2.8,.6,.40)
	var brace_seen:=false; var min_palm:=INF; var slide_start:=Vector3.INF
	var slide_distance:=0.0; var worst_grip:=0.0; var caught:=false; var lowest:=INF
	for i in range(210):
		p.desired=Vector3.ZERO; p.step(DT)
		if not caught and i==42:
			game.ball.freeze=false; game.ball.place(p.hand_center())
			await physics_frame; await physics_frame
			game.ball.hold(p); p.keeper_motion.saved(p); p.keeper_motion.secured=true; p.keeper_motion.target=game.ball.position
			caught=true
		if caught: game.ball.hold_target=p.keeper_motion.grip_target(p)
		await physics_frame
		if "--trace" in OS.get_cmdline_user_args() and i%12==0: print("TRACE i=",i," pos=",p.position," vel=",p.velocity," landed=",p.keeper_motion.landed_at," age=",p.motion_clock," brace=",p.keeper_motion.brace_weight)
		if caught and i>65: worst_grip=maxf(worst_grip,game.ball.position.distance_to(p.keeper_motion.grip_target(p)))
		if p.keeper_motion.landed_at>=0:
			if not slide_start.is_finite(): slide_start=p.position
			slide_distance=maxf(slide_distance,game.flat_distance(p.position,slide_start))
		if p.keeper_motion.brace_weight>.85:
			brace_seen=true
			var hand: Vector3=p.left_hand.global_position if p.keeper_motion.brace_left else p.right_hand.global_position
			min_palm=minf(min_palm,hand.y)
			lowest=minf(lowest,p.spine.to_global(Vector3(0,.45,0)).y)
	print("RECOVERY team=",team," side=",side," wet=",wet," slide=",slide_distance," palm=",min_palm," grip=",worst_grip," shoulder=",lowest)
	check(slide_start.is_finite() and slide_distance>.025 and slide_distance<.80,"Dive landing has a short physical slide on team %d / side %s" % [team,side])
	check(brace_seen and min_palm<.20 and min_palm>-.08 and lowest>.18,"A recovery palm reaches the turf while the torso remains above it")
	check(worst_grip<.55 and game.ball.held_by==p,"The secured ball stays at the chest while the free hand braces")
	check(p.action_timer==0 and p.pose=="run" and p.keeper_motion.brace_weight==0,"The keeper completes the rise and returns to a responsive stance")
	game.keeper_distribution.drop(team*11)
	check(game.ball.held_by==null and not p.keeper_motion.secured,"Deliberate distribution releases the new grip normally")

func directing() -> void:
	var p=await setup_keeper(0)
	game.state="playing"; game.menu_match.running=false
	var mate=game.players[3]; mate.show(); mate.position=p.position+Vector3(7,0,-16)
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.position=p.position+Vector3(4,0,-25); game.ball.linear_velocity=Vector3.ZERO
	p.keeper_motion.reset()
	game.goalkeeping.update(0,DT); p.motion_clock+=.30; p.animate(DT)
	check(p.keeper_motion.command_weight(p)>.9 and p.keeper_motion.command_target==mate.position,"A safe phase prompts a gesture toward an actual defender")
	var old: float=p.keeper_motion.command_at
	game.goalkeeping.update(0,DT)
	check(p.keeper_motion.command_at==old,"Repeated AI frames do not restart the directing gesture")
	game.ball.position=p.position+Vector3(0,.3,-8)
	game.goalkeeping.update(0,DT)
	check(p.keeper_motion.command_weight(p)==0,"An approaching ball cancels the gesture immediately")
	game.goalkeeping.reset()
	check(p.keeper_motion.brace_weight==0 and p.keeper_motion.command_at<0 and not p.keeper_motion.secured,"A whistle clears recovery and directing state")

func low_recovery(team: int) -> void:
	var p=await setup_keeper(team)
	game.state="playing"; game.menu_match.running=false
	p.keeper_motion.start(p,"smother",p.position+p.facing*.35+Vector3.UP*.28)
	var palm:=INF; var highest_gap:=0.0
	for i in range(150):
		p.step(DT); await physics_frame
		if i==18: p.keeper_motion.saved(p); p.keeper_motion.secured=true
		if p.keeper_motion.brace_weight>.9:
			var hand: Vector3=p.left_hand.global_position if p.keeper_motion.brace_left else p.right_hand.global_position
			palm=minf(palm,hand.y)
			if "--low-trace" in OS.get_cmdline_user_args() and i%3==0: print("LOW TRACE ",i," rig=",p.rig.position," root=",p.position," spine=",p.spine.global_position," shoulder=",p.left_arm.global_position if p.keeper_motion.brace_left else p.right_arm.global_position," hand=",hand," goal=",p.keeper_motion.brace_point," weight=",p.keeper_motion.brace_weight)
		if i>60 and p.keeper_motion.brace_weight<.1:
			highest_gap=maxf(highest_gap,p.hand_center().distance_to(p.keeper_motion.grip_target(p)))
	print("LOW RECOVERY team=",team," palm=",palm," grip_gap=",highest_gap)
	check(palm<.20 and palm>-.08,"A low scoop also places its recovery hand on the ground, team %d" % team)
	check(highest_gap<.12,"Both gloves return around the held ball after a low recovery")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	if "--low-trace" in OS.get_cmdline_user_args():
		await low_recovery(0); game.free(); quit(); return
	if "--trace" in OS.get_cmdline_user_args():
		await recover_dive(1,1,2); game.free(); quit(); return
	await wear_checks()
	for team in [0,1]:
		for side in [-1.0,1.0]: await recover_dive(team,side,2 if side>0 else 0)
		await low_recovery(team)
	await directing()
	print("TURF KEEPER CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
