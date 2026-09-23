extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func officials_step(count: int) -> void:
	for i in range(count):
		game.referees.update(1.0/120)
		await physics_frame
func arrange() -> void:
	game.start_match(false,false)
	game.set_physics_process(false)
	for i in range(22): game.players[i].position=Vector3(-28+i*2.3,0,12 if i<11 else -12)
	game.players[9].position=Vector3(0,0,-20)
	game.players[10].position=Vector3(-20,0,-40)
	game.players[11].position=Vector3(0,0,-49)
	game.players[12].position=Vector3(8,0,-30)
	game.ball.place(Vector3(0,0.23,-20))
	await frames(3)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	await arrange()
	var refs=game.referees
	check(game.players.size()==22 and refs.actors.size()==3,"One referee and two assistants are separate from the 22 footballers")
	check(refs.actors[0].visible and refs.actors[1].flag!=null and refs.actors[2].flag!=null,"All match officials persist with two assistant flags")
	var excluded := true
	for ref in refs.actors: excluded=excluded and (ref.collision_layer & game.ball.collision_mask)==0 and (ref.collision_mask & game.ball.collision_layer)==0
	check(excluded,"Ball and official collision masks exclude each other in both directions")
	var before: Vector3=refs.actors[0].position
	await officials_step(180)
	check(refs.actors[0].position.distance_to(before)>2 and absf(refs.actors[0].position.x)<32,"The main referee runs inside the pitch to follow play")
	check(absf(refs.targets[1].z+30)<0.01 and refs.targets[1].x< -32,"North assistant follows the second-last defender outside the touchline")
	game.ball.place(Vector3(0,0.23,-42))
	await frames(3)
	await officials_step(1)
	check(absf(refs.targets[1].z+42)<0.01,"An advanced ball takes precedence over the defensive offside line")
	game.players[0].position=Vector3(0,0,49)
	game.players[1].position=Vector3(-8,0,32)
	await officials_step(1)
	check(absf(refs.targets[2].z-32)<0.01 and refs.targets[2].x>32,"South assistant mirrors the second-last-defender logic")
	# Compare a real moving ball through an official with a vacant lane.
	var results: Array[Vector3]=[]
	for occupied in [false,true]:
		refs.actors[0].position=Vector3(0 if occupied else 10,0,0)
		game.ball.place(Vector3(0,0.7,3),Vector3(0,0,-10))
		await frames(3)
		await frames(70)
		results.append(game.ball.position)
	check(results[0].distance_to(results[1])<0.005 and results[1].z< -1,"The real ball passes through the referee without deflecting or losing speed")
	await arrange()
	# Offside candidates are recorded at contact, not when a swing is queued.
	game.commit_strike(9,Vector3(0,0,-15))
	check(10 in game.rules.candidates and refs.actors[1].gesture!="flag_up","An uninvolved offside-position player does not cause a false flag")
	check(not game.rules.before_touch(10),"Actual involvement produces the existing offside decision")
	await officials_step(20)
	check(refs.actors[1].gesture=="flag_up" and game.restart_team==1,"The correct assistant raises a flag when offside is awarded")
	await officials_step(120)
	check(refs.actors[1].gesture=="offside_zone" and refs.actors[1].zone==0,"After acknowledgement the flag indicates the near-side infringement")
	check(refs.actors[0].gesture=="indirect","The referee raises an arm for the indirect free kick")
	refs.ball_in_play("ENDİREKT VURUŞ",12)
	refs.touch(12)
	check(refs.indirect_pending,"The indirect signal stays up for the first kick")
	refs.touch(13)
	check(not refs.indirect_pending,"Another player's touch releases the indirect signal")
	await arrange()
	refs.actors[0].position=game.players[12].position+Vector3(2.2,0,1.2)
	game.rules.foul(12,9,true)
	check(not refs.ready_for_restart(),"Play waits while the referee presents a booking")
	await officials_step(15)
	check(refs.actors[0].gesture=="yellow" and refs.actors[0].card.visible,"A real caution raises a visible yellow card")
	await officials_step(220)
	check(refs.ready_for_restart(),"The booking sequence releases restart preparation")
	game.rules.foul(12,9,true)
	var saw_yellow := false
	var saw_red := false
	for i in range(500):
		await officials_step(1)
		saw_yellow=saw_yellow or refs.actors[0].gesture=="yellow"
		saw_red=saw_red or refs.actors[0].gesture=="red"
	check(saw_yellow and saw_red and game.players[12].dismissed,"A second caution shows yellow then red in the referee's hand")
	await arrange()
	game.begin_restart("TAÇ",0,Vector3(-32,0,-15))
	await officials_step(100)
	check(refs.actors[1].gesture=="flag_direction" and refs.actors[0].gesture=="point","Throw-in decisions have matching assistant and referee direction signals")
	var clock: float=refs.clock
	var position: Vector3=refs.actors[0].position
	game.state="paused"
	game._physics_process(0.5)
	check(refs.clock==clock and refs.actors[0].position==position,"Pause freezes referee movement and decision animation")
	game.start_match()
	var identity: int=refs.actors[0].get_instance_id()
	game.ceremony.finish(true)
	check(refs.actors[0].visible and refs.actors[0].get_instance_id()==identity and game.ceremony.officials[0]==refs.actors[0],"The same ceremony officials take their match duties after skipping")
	game.goal(0)
	game.reset_positions(1)
	check(refs.decision=="" and refs.actors[0].visible,"Kickoff clears old goal signals without removing officials")
	game.start_match(true)
	check(not refs.actors[0].visible and not refs.actors[1].visible,"Practice does not add match officials")
	game.free()
	print("REFEREE CHECK: %d failures" % failures)
	quit(0 if failures==0 else 1)
