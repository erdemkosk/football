extends "res://tests/ai_attack_check.gd"

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	setup(); player(17,Vector3(25,0,-25))
	var budget=game.work_budget; budget.game=game
	var nearest: Array=[2,20]
	var p=game.players[17]
	check(p.can_defer_running_pose(),"The distant test player has no active contact or turn")
	var updates:=0; var elapsed:=0.0
	for tick in range(120):
		var dt: float=budget.decision_delta(17,DT,nearest)
		if dt>0: updates+=1; elapsed+=dt
	check(updates>=10 and updates<=22,"Distant routine decisions run at 12–20 Hz instead of 120 Hz")
	check(absf(elapsed+budget.entries[17].elapsed-1.0)<.00001,"Skipped decision time is preserved for positional timers")
	game.ball.position=p.position+Vector3(0,.23,1)
	check(budget.decision_delta(17,DT,nearest)>0 and not budget.entries.has(17),"A nearby ball bypasses the budget on the same physics tick")
	possession(20); budget.decision_delta(17,DT,nearest)
	game.ai_receivers[1]=17
	check(budget.decision_delta(17,DT,nearest)>0 and not budget.entries.has(17),"A newly selected pass receiver reacts immediately at any distance")
	game.ai_receivers[1]=-1; budget.decision_delta(17,DT,nearest)
	game.team_tactics.roles[17]="press"
	check(budget.decision_delta(17,DT,nearest)>0 and not budget.entries.has(17),"Pressing assignments keep full-rate decisions")
	game.team_tactics.roles.clear(); budget.decision_delta(17,DT,nearest)
	p.ball_actions.contact_pending=true
	check(budget.decision_delta(17,DT,nearest)>0,"A committed boot contact never waits for the distant timer")
	p.ball_actions.contact_pending=false; budget.decision_delta(17,DT,nearest)
	game.carrier=18
	check(budget.decision_delta(17,DT,nearest)>0,"Possession changes invalidate distant decisions immediately")
	budget.reset(); budget.decision_delta(17,DT,nearest)
	game.support.targets[17]=p.position+Vector3(5,0,0)
	check(budget.decision_delta(17,DT,nearest)>0,"A large target change bypasses the timer")
	p.pending_pose_delta=DT; p.running_pose_interval=1.0/30.0; p.defer_running_pose=true
	game._process(0)
	check(is_equal_approx(p.pending_pose_delta,DT),"A far running pose can wait between rendered frames")
	p.pending_pose_delta=1.0/30.0; game._process(0)
	check(p.pending_pose_delta==0,"A distant running pose flushes at its 30 Hz deadline")
	p.pending_pose_delta=DT; p.protecting=true; game._process(0)
	check(p.pending_pose_delta==0,"Protection cancels visual deferral immediately")
	p.protecting=false; p.pending_pose_delta=DT
	game.replay.snapshot()
	check(p.pending_pose_delta==0,"Replay snapshots flush pending poses before recording")
	var crowd=game.stadium.crowd
	crowd.reset(); crowd.react("goal",1,Vector3.ZERO)
	var matching:=true
	for mat in [crowd.material,crowd.cloth_material]+crowd.prop_materials:
		matching=matching and mat.get_shader_parameter("event_team")==1.0 and mat.get_shader_parameter("event_age")==0.0
	check(matching,"Goals reach every crowd material immediately, outside the staggered uploads")
	crowd.update(DT,Vector3(0,0,30),Vector3.ZERO,1,true,false)
	check(is_equal_approx(crowd.cloth_material.get_shader_parameter("crowd_time"),DT),"Crowd animation clocks advance every frame")
	budget.reset(); check(budget.entries.is_empty(),"Reset removes all delayed work")
	print("MATCH WORK BUDGET: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
