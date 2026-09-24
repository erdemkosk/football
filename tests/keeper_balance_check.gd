extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func shot(distance: float,speed: float,corner: float,height: float,offset: float,seed_value: int=-1,team: int=1,weather_preset: int=0,keeper_energy: float=1.0) -> Dictionary:
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	game.management.difficulty=1; game.weather.select(weather_preset,true)
	# The shooter's contact error is measured elsewhere; the keeper faces exact trajectories.
	game.strike_quality.shot_error_scale=[0.0,0.0]
	game.rng.seed=520+roundi(offset*10+corner*10)
	game.goalkeeping.variation.seed=520+roundi(offset*10+corner*10)
	if seed_value>=0: game.goalkeeping.variation.seed=seed_value
	for p in game.players: p.visible=false; p.collision_layer=0; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	var keeper_index := 11 if team==1 else 0
	var shooter_index := 9 if team==1 else 20
	var forward: float=game.attack_sign(team)
	var keeper=game.players[keeper_index]
	keeper.energy=keeper_energy
	keeper.visible=true; keeper.collision_layer=2; keeper.position=Vector3(0,0,-forward*47.5); keeper.facing=Vector3(0,0,forward)
	game.players[shooter_index].visible=true; game.players[shooter_index].position=Vector3(offset,0,forward*(-49+distance))
	game.ball.freeze=true
	for i in range(8): keeper.step(1.0/120); await physics_frame
	var origin := Vector3(offset,0.23,forward*(-50+distance))
	var target := Vector3(corner,height,-forward*50.4)
	var flight := Vector2(target.x-origin.x,target.z-origin.z).length()/speed
	var velocity: Vector3=game.Passing.Motion.lob_velocity(origin,target,flight,game.weather)
	game.ball.freeze=false; game.ball.place(origin)
	await physics_frame; await physics_frame
	game.kick_lock=0; game.last_touch=1-team
	# This fixture starts at ball release and only steps the keeper. Ordinary
	# shooter approach/contact is covered independently by motion_contact_check.
	game.commit_strike(shooter_index,velocity,0,false,"shot")
	var peak_x := 0.0
	var goal := false
	var closest := INF
	var nearest_frame: Dictionary={}
	for tick in range(360):
		game.kick_lock=maxf(0,game.kick_lock-1.0/120)
		var saved_before: int=game.saves[team]
		var move: Vector3=game.goalkeeping.update(keeper_index,1.0/120)-keeper.position
		var glove_distance: float=minf(keeper.left_hand.global_position.distance_to(game.ball.position),keeper.right_hand.global_position.distance_to(game.ball.position))
		if glove_distance<closest:
			closest=glove_distance
			nearest_frame={"at":tick/120.0,"ball":game.ball.position,"keeper":keeper.position,"glove":keeper.hand_center(),"pose":keeper.pose,"read":game.goalkeeping.reads.get(keeper_index,{}).duplicate()}
		if "--trace" in OS.get_cmdline_user_args() and game.saves[team]>saved_before:
			print("CONTACT dist=",distance," x=",corner," offset=",offset," at=",tick/120.0," ball=",game.ball.position," keeper=",keeper.position," pose=",keeper.pose)
		move.y=0; keeper.desired=move.normalized()*clampf(move.length()/1.4,0,1)
		keeper.step(1.0/120)
		await physics_frame
		peak_x=maxf(peak_x,absf(keeper.position.x))
		if game.ball.position.z*forward< -50.22:
			goal=absf(game.ball.position.x)<3.44 and game.ball.position.y<2.22
			break
		if game.ball.held_by==keeper: break
		if tick>120 and game.ball.linear_velocity.z*forward>3: break
	if "--trace" in OS.get_cmdline_user_args() and goal: print("MISSED dist=",distance," x=",corner," offset=",offset," closest=",closest," frame=",nearest_frame)
	return {"goal":goal,"saved":game.saves[team]>0,"peak_x":peak_x,"closest":closest}
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	var results := {}
	for group in [["central",20.0,16.0,0.0,0.9],["placed",20.0,24.0,3.15,0.9],["hard_corner",14.0,30.0,3.05,1.5],["close",8.0,28.0,2.4,0.7]]:
		var goals := 0; var saves := 0
		for side in [-1,1]:
			for offset in [-4.0,0.0,4.0]:
				# Several independent reads per trajectory: six lucky/unlucky reads
				# alone cannot establish whether a goalkeeper is invulnerable.
				for attempt in range(3):
					var seed_value: int=520+roundi(offset*10+group[3]*side*10)+attempt*997
					var outcome: Dictionary=await shot(group[1],group[2],group[3]*side,group[4],offset,seed_value)
					if outcome.goal: goals+=1
					if outcome.saved: saves+=1
		results[group[0]]={"goals":goals,"saves":saves,"shots":18}
	print("KEEPER SHOT MATRIX: ",JSON.stringify(results))
	if "--baseline" not in OS.get_cmdline_user_args():
		check(results.central.goals<=3 and results.central.saves>=12,"Routine shots at the keeper remain reliably stoppable")
		check(results.placed.goals>=1 and results.placed.saves>=9,"A precise twenty-metre corner shot can score while most remain saveable")
		check(results.hard_corner.goals>=9,"Hard corner finishes can beat the keeper's physical reach")
		check(results.close.goals>=9,"Close-range finishes can beat the keeper's reaction")
		await decisions()
	print("KEEPER BALANCE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)

func reading(team: int=1,difficulty: int=1,energy: float=1,rain: bool=false,screened: bool=false,step: float=0.01,pace: float=28) -> Dictionary:
	game.goalkeeping.reset(); game.goalkeeping.variation.seed=127
	game.management.difficulty=difficulty; game.weather.select(2 if rain else 0,true)
	for p in game.players: p.visible=false; p.collision_layer=0
	var index := 11 if team==1 else 0
	var p=game.players[index]; p.visible=true; p.energy=energy; p.velocity=Vector3.ZERO; p.action_timer=0; p.tackle_cooldown=0; p.touch_cooldown=0; p.pose="run"
	var forward: float=game.attack_sign(team)
	p.position=Vector3(0,0,-forward*47.5); p.facing=Vector3(0,0,forward); p.animate(1)
	game.ball.freeze=true; game.ball.release_hold(); game.ball.pending_reset=false; game.ball.pending_kick=false
	game.ball.position=Vector3(0,1,-forward*33); game.ball.linear_velocity=Vector3(3,0,-forward*pace)
	game.last_touch=1-team; game.kick_lock=0
	if screened:
		game.players[6].visible=true; game.players[6].position=Vector3(0,0,-forward*40)
	game.goalkeeping.update(index,step)
	return game.goalkeeping.reads[index].duplicate()

func decisions() -> void:
	var normal := reading()
	check(game.goalkeeping.modes[11]=="react" and game.players[11].pose!="dive","A newly struck ball first causes a human reaction delay")
	var repeat: Dictionary=game.goalkeeping.shot_read(11,0.01)
	check(repeat.delay==normal.delay and repeat.error==normal.error and repeat.handling==normal.handling,"Repeated frames cannot reroll the same shot into a guaranteed save or error")
	game.goalkeeping.reads[11].age=1.0; game.last_kicker=8 if game.last_kicker!=8 else 9
	var redirected: Dictionary=game.goalkeeping.shot_read(11,0.01)
	check(redirected.age<redirected.delay and redirected.kicker==game.last_kicker,"A new attacking touch requires a fresh read instead of inheriting an old instant reaction")
	var easy := reading(1,0); var hard := reading(1,2)
	check(easy.delay>normal.delay and normal.delay>hard.delay,"Opponent goalkeeper reactions scale with Easy, Normal and Hard")
	# Clubs now have distinct real attributes. Compare the same goalkeeper
	# quality on either side when checking for an artificial team advantage.
	var home_attributes: Dictionary=game.players[0].attributes.duplicate()
	game.players[0].attributes=game.players[11].attributes.duplicate()
	var home := reading(0)
	check(home.delay==normal.delay and home.error==normal.error,"Equal-quality goalkeepers use the same baseline balance on both teams")
	game.players[0].attributes=home_attributes
	var crowded := reading(1,1,0.25,true,true)
	check(crowded.delay>normal.delay and absf(crowded.error)>absf(normal.error),"Fatigue, rain and a screened view make reading the shot harder")
	var low_fps := reading(1,1,1,false,false,1.0/30)
	var high_fps := reading(1,1,1,false,false,1.0/120)
	check(low_fps.delay==high_fps.delay and low_fps.error==high_fps.error,"Reaction and error sampling do not depend on the frame rate")
	var soft_read := reading(1,1,1,false,false,0.01,18)
	var hard_read := reading(1,1,1,false,false,0.01,34)
	check(absf(hard_read.error)>absf(soft_read.error),"Faster shots are harder to judge without changing the contact radius")
	var keeper=game.players[11]
	keeper.pose="dive"; keeper.action_timer=keeper.dive_duration-0.3; keeper.animate(1)
	check(keeper.can_save(keeper.left_hand.global_position) and not keeper.can_save(keeper.left_hand.global_position+Vector3.UP*0.6),"A diving glove saves real contact but cannot grab a ball sixty centimetres away")
	keeper.action_timer=keeper.dive_duration-0.42; keeper.animate(1)
	check(keeper.can_save(keeper.hand_center()),"A ball at full extension cannot slip through an artificial gap between the gloves")
	keeper.pose="fall"; keeper.action_timer=0.5
	check(not keeper.can_save(keeper.position+Vector3.UP*0.4),"A fallen keeper cannot make an invisible standing save")
	reading(1,1,0.4,true)
	game.goalkeeping.reads[11].age=1.0; game.goalkeeping.reads[11].handling=0.0
	game.ball.position=keeper.left_hand.global_position; game.ball.linear_velocity=Vector3(0,0,-27)
	var at: Vector3=game.ball.position
	game.saves[1]=0
	game.goalkeeping.update(11,0.01)
	check(game.saves[1]==1 and game.ball.pending_kick and game.ball.held_by==null and game.ball.kick_velocity.z>3 and game.ball.kick_velocity.length()<9,"A pressured wet-glove error palms a hard shot into a reachable rebound")
	game.ball.freeze=false
	await physics_frame; await physics_frame; await physics_frame
	check(game.ball.position.distance_to(at)>0.03 and game.ball.linear_velocity.z>0,"The loose rebound travels as a live physical ball")
	game.begin_restart("TAÇ",0,Vector3(32,0,0))
	check(game.goalkeeping.reads.is_empty(),"A whistle clears old shot reactions before the next phase")
