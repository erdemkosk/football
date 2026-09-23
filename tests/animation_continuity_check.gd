extends "res://tests/volley_check.gd"

func keeper_delivery(team: int,backpass: bool=false) -> void:
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.goalkeeping.variation.seed=520; game.weather.select(0,true)
	var index := 0 if team==0 else 11
	var keeper=game.players[index]
	var forward: float=game.attack_sign(team)
	for q in game.players:
		q.visible=q==keeper; q.collision_layer=2 if q==keeper else 0
		q.velocity=Vector3.ZERO; q.desired=Vector3.ZERO
	keeper.position=Vector3(0,0,-forward*47.5); keeper.facing=Vector3(0,0,forward)
	keeper.body_language.enabled=false; keeper.animate(1)
	for frame in range(5): keeper.step(DT); await physics_frame
	game.ball.freeze=false
	game.ball.place(keeper.position+Vector3(0,1.1,forward*3.2),Vector3(0,3.0,-forward*8))
	await physics_frame; await physics_frame
	game.kick_lock=0; game.dribbler=-1; game.carrier=-1
	game.last_touch=team if backpass else 1-team; game.last_kicker=6 if backpass else 20
	var hands := false
	var held := false
	for frame in range(100):
		var target: Vector3=game.goalkeeping.update(index,DT)
		keeper.desired=((target-keeper.position)*Vector3(1,0,1)).limit_length(1)
		keeper.step(DT)
		hands=hands or keeper.keeper_motion.kind=="catch"
		held=held or game.ball.held_by==keeper
		await physics_frame
		if held or game.saves[team]>0: break
	print("HAND DELIVERY ",team," backpass=",backpass," hands=",hands," held=",held," saves=",game.saves[team])
	check(not held if backpass else (hands and held),"Keeper %d respects hand contact and back-pass rules (%s)" % [team,str(backpass)])

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	p=game.players[9]
	var fresh=load("res://scripts/footballer.gd").new()
	fresh.shirt_number=24; game.add_child(fresh)
	check(fresh.left_elbow.rotation.length()>.05 and fresh.right_elbow.rotation.length()>.05,"New players have a live stance before the first physics tick")
	fresh.left_elbow.rotation=Vector3(1,1.2,-.8); fresh.right_elbow.rotation=Vector3(1,-1.2,.8)
	fresh.animate(.2)
	check(absf(fresh.left_elbow.rotation.y)+absf(fresh.left_elbow.rotation.z)+absf(fresh.right_elbow.rotation.y)+absf(fresh.right_elbow.rotation.z)<.001,"A completed hand gesture cannot leave twisted elbow axes in the next animation")
	fresh.free()
	var reserve=game.stadium.sidelines.actors.filter(func(actor): return actor.role=="substitute")[0]
	check(absf(reserve.legs[0].rotation.x)>1 and reserve.elbows[0].rotation.length()>.1,"Reserves start seated with bent arms instead of an authored rest pose")
	var before: Quaternion=reserve.spine.quaternion
	for frame in range(40): reserve.animate_actor(DT,frame*DT+3,Vector3.ZERO,"watch",0)
	check(before.angle_to(reserve.spine.quaternion)>.001,"Waiting substitutes retain breathing and small independent movement")
	await reset(Vector3(0,8,-.5),Vector3(0,2,-4))
	p.desired=Vector3.RIGHT; p.velocity=Vector3.RIGHT*3
	game.begin_shot()
	check(not game.charging and not game.aerial_shot_active(9) and p.action_timer==0,"An unreachable high ball does not start a futile shot animation")
	var start: Vector3=p.position
	for frame in range(12): p.step(DT); await physics_frame
	check(p.position.x>start.x+.2,"Rejected aerial input leaves the runner moving")
	await reset(Vector3(-2.8,1.1,-.55),Vector3(11,0,0))
	key(true); key(false)
	var launched := false
	for frame in range(35):
		await tick()
		if p.pose=="volley" and p.action_timer>0: launched=true; break
	check(launched,"Reachable aerial shot enters a real volley preparation")
	game.ball.place(p.position+Vector3(6,2,0),Vector3(8,2,0))
	await physics_frame; await physics_frame
	p.desired=Vector3.RIGHT; p.velocity=Vector3.RIGHT*3
	game.volleys.prepare(DT)
	check(not game.volleys.active(9) and p.action_timer==0 and not p.volley_motion.hit,"A deflection out of reach cancels the unfinished kick")
	start=p.position
	for frame in range(12): p.step(DT); await physics_frame
	check(p.position.x>start.x+.2 and game.shots[0]==0,"Cancelled volley keeps movement and records no phantom shot")
	for team in [0,1]:
		await keeper_delivery(team)
		await keeper_delivery(team,true)
	print("ANIMATION CONTINUITY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
