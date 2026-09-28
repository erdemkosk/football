extends "res://tests/ai_attack_check.gd"
const Clock = preload("res://scripts/match_clock.gd")

func scene(team: int=0,half: int=2,depth: float=32) -> int:
	game.career.in_match=false; game.career.cups.extra_phase=0
	setup(); game.half=half; game.controlled=9
	game.opponent_coach.next_sub=INF
	for p in game.players: p.visible=false; p.collision_layer=0; p.action_timer=0
	var index := team*11+9
	var f: float=game.attack_sign(team)
	player(index,Vector3(0,0,f*depth),Vector3(0,0,f*3))
	possession(index)
	game.management.added[half-1]=0
	game.match_time=game.management.half_end()+.01
	game.referee_flow.sync_period()
	game.boundary_grace=0; game.foul_cooldown=0
	return index

func end_state(half: int) -> String:
	return "halftime" if half==1 else "finished"

func final_attacks() -> void:
	for half in [1,2]:
		for team in [0,1]:
			var i := scene(team,half)
			game.score=[0,3] if team==0 else [3,0]
			game.referee_flow.update(DT)
			check(game.state=="playing","The losing side's live attack survives expiry, team=%d half=%d" % [team,half])
			var other: int=(1-team)*11+9
			player(other,game.ball.position*Vector3(1,0,1)); game.dribbler=other
			game.referee_flow.update(DT)
			check(game.state==end_state(half),"Real opponent control ends that last attack")
			i=scene(team,half); game.score=[3,0] if team==0 else [0,3]
			game.referee_flow.update(DT)
			check(game.state=="playing","The leading side gets the same last-attack treatment")
			game.ball.held_by=game.players[(1-team)*11]
			game.referee_flow.update(DT)
			check(game.state==end_state(half),"A keeper's secure catch ends the period")
			i=scene(team,half,40); game.players[i].velocity=Vector3.ZERO
			game.referee_flow.update(game.referee_flow.ATTACK_WINDOW+.1)
			check(game.state==end_state(half),"Standing in the box cannot extend play forever")
			i=scene(team,half,5); game.players[i].velocity=Vector3.ZERO
			game.referee_flow.update(DT)
			check(game.state==end_state(half),"Neutral midfield possession does not invent a last attack")
			i=scene(team,half)
			game.referee_flow.update(DT)
			game.players[i].position.z=game.attack_sign(team)*12; possession(i)
			game.referee_flow.update(DT)
			check(game.state==end_state(half),"Recycling out of the attacking third ends the phase")
			i=scene(team,half,40)
			game.commit_strike(i,Vector3(0,1,game.attack_sign(team)*25),0,false,"shot",true)
			game.dribbler=-1; game.last_touch=1-team
			game.referee_flow.update(DT)
			check(game.state=="playing","A loose defender deflection cannot cut off an on-target shot at expiry")
			game.begin_restart("KORNER",team,Vector3(game.P.HALF_WIDTH,0,game.attack_sign(team)*49))
			game.referee_flow.update(DT)
			check(game.state==end_state(half),"A completed attack does not chain corners into endless added time")
			i=scene(team,half)
			game.state="paused"; game.referee_flow.update(20)
			check(game.state=="paused" and game.referee_flow.late_age==0,"A pause cannot consume the referee's decision window")
	scene(); game.training=true; game.referee_flow.update(20)
	check(game.state=="playing","Practice has no final whistle")

func stoppage_time() -> void:
	scene(); game.half=1; game.management.added[0]=-1
	game.match_time=game.LENGTH*.5-5
	game.management.lost_time[0]=game.LENGTH/90*2.2
	game.management.update_clock(DT)
	var announced: float=game.management.added[0]
	var end: float=game.management.half_end()
	check(is_equal_approx(announced,game.LENGTH/90*3),"The board announces whole minutes as a minimum")
	game.match_time=game.LENGTH*.5+announced*.5
	game.state="restart"; game.management.update_clock(10)
	check(game.management.added[0]==announced and game.management.half_end()>end+.79,"A later stoppage extends the deadline without rewriting the announced minimum")
	end=game.management.half_end()
	game.state="paused"; game.management.update_clock(30)
	game.state="replay"; game.management.update_clock(30)
	check(game.management.half_end()==end,"Pause and replay do not create extra minutes")
	game.half=2
	check(game.management.added[1]==0 and game.management.after_announcement[1]==0,"Second-half allowance is independent of the first half")
	game.match_time=game.LENGTH*.5; game.state="restart"; game.management.update_clock(30)
	check(game.management.lost_time[1]==0,"Waiting for the second-half kickoff is not lost playing time")
	# The clock uses independent allowances for 105 and 120 as well.
	game.career.in_match=true; game.career.cups.extra_phase=1
	game.match_time=game.LENGTH*7/6-1; game.state="playing"
	game.management.lost_time[2]=game.LENGTH/90*1.2
	game.management.update_clock(DT)
	check(game.management.period_index()==2 and is_equal_approx(game.management.half_end(),game.LENGTH*7/6+game.LENGTH/90*2),"First extra-time period receives its own lost-time allowance")
	game.career.cups.extra_phase=2
	check(game.management.period_index()==3 and game.management.added[3]<0,"Second extra-time allowance starts independently")
	game.match_time=game.LENGTH*7/6; game.state="set_piece"; game.management.update_clock(30)
	check(game.management.lost_time[3]==0,"Waiting for an extra-time kickoff cannot create its own allowance")
	check(Clock.text(game.LENGTH*7/6+game.LENGTH/90,game.LENGTH,1,true)=="105+1" and Clock.text(game.LENGTH*4/3+game.LENGTH/90,game.LENGTH,2,true)=="120+1","Extra-time displays show their added minutes")
	for duration in [240.0,480.0,720.0,1200.0]:
		check(Clock.text(duration*7/6+duration/90,duration,1,true)=="105+1" and Clock.text(duration*4/3+duration/90,duration,2,true)=="120+1","Added-time rounding is stable at a %d-second match length" % duration)
	game.career.in_match=false; game.career.cups.extra_phase=0

func foul_scene(late: bool=false) -> Dictionary:
	var i := scene(0,2,24)
	if not late: game.match_time=20
	var f: float=game.attack_sign(0)
	player(12,game.players[i].position-Vector3(0,0,f*1.1))
	return {"victim":i,"offender":12,"point":game.players[i].position,"forward":f}

func advantages() -> void:
	var data := foul_scene()
	game.rules.foul(12,9)
	check(not game.rules.advantage.is_empty() and game.state=="playing","The fouled player can retain advantage while upright and moving into space")
	game.state="paused"; game.rules.update_advantage(5)
	check(game.rules.advantage.age==0,"Paused advantage does not expire")
	game.state="playing"; game.dribbler=-1
	game.players[12].position=game.ball.position*Vector3(1,0,1)
	game.ball.linear_velocity=Vector3(0,0,data.forward*20)
	game.rules.update_advantage(.2)
	check(not game.rules.advantage.is_empty(),"A defender merely near a fast passing ball does not cancel advantage")
	game.ball.linear_velocity=Vector3.ZERO; game.dribbler=12
	game.rules.update_advantage(.1)
	check(game.state=="restart" and game.restart_team==0 and game.restart_point.distance_to(data.point)<.01,"Real lost possession returns to the original foul")
	data=foul_scene(); game.rules.foul(12,9,true)
	check(12 in game.rules.deferred_cards and game.players[12].yellow_cards==0,"Advantage defers a first reckless caution")
	game.players[9].position.z+=data.forward*6; possession(9)
	game.rules.update_advantage(.3)
	check(game.rules.advantage.is_empty() and game.state=="playing","Controlled forward progress consumes the advantage")
	game.begin_restart("TAÇ",0,Vector3(game.P.HALF_WIDTH,0,0))
	check(game.players[12].yellow_cards==1 and game.rules.deferred_cards.is_empty(),"The deferred caution is shown once at the next stoppage")
	data=foul_scene(); game.rules.foul(12,9)
	game.rules.update_advantage(3.01)
	check(game.state=="restart" and game.restart_point.distance_to(data.point)<.01,"Possession without a useful continuation returns to the foul within three seconds")
	data=foul_scene(); game.rules.foul(12,9)
	game.begin_restart("TAÇ",0,Vector3(game.P.HALF_WIDTH,0,data.point.z))
	check(game.restart_type=="SERBEST VURUŞ" and game.restart_point.distance_to(data.point)<.01,"An unfulfilled advantage is recalled even if the awarded throw belongs to the fouled team")
	data=foul_scene(); game.rules.foul(12,9)
	game.begin_restart("PENALTI",0,Vector3(0,0,data.forward*39))
	check(game.restart_type=="PENALTI","A subsequent penalty is kept instead of recalling a worse free kick")
	data=foul_scene(); game.rules.foul(12,9)
	game.commit_strike(9,Vector3(0,2,data.forward*25),0,false,"shot",true)
	check(game.rules.advantage.is_empty() and game.ball.pending_kick,"Taking the real shooting chance consumes advantage")
	game.ball.pending_kick=false; game.dribbler=12; game.rules.update_advantage(.1)
	check(game.state=="playing","A missed or saved opportunity cannot be pulled back for a second chance")
	data=foul_scene(); game.rules.foul(12,9,true,true)
	check(game.state=="restart" and game.players[12].dismissed,"A severe challenge stops play immediately")
	data=foul_scene(); game.players[12].yellow_cards=1; game.rules.foul(12,9,true)
	check(game.state=="restart" and game.players[12].dismissed,"A second-yellow challenge is not left running as ordinary advantage")
	data=foul_scene(true); game.rules.foul(12,9)
	game.referee_flow.update(DT)
	check(game.state=="playing","Expiry waits for an unresolved advantage")
	game.players[12].position=game.ball.position*Vector3(1,0,1); game.dribbler=12
	game.rules.update_advantage(.1); game.referee_flow.update(DT)
	check(game.state=="restart" and game.referee_flow.protected_restart==0,"A recalled last-second foul can actually be taken before the whistle")
	game.state="playing"; game.commit_strike(9,Vector3(0,2,data.forward*24),0,false,"shot",true)
	game.referee_flow.update(DT)
	check(game.state=="playing" and game.referee_flow.protected_restart<0,"The recalled free kick becomes a live final shot")
	data=foul_scene(true); game.players[9].position.z=data.forward*30; possession(9)
	game.players[9].action_timer=.4
	game.rules.foul(12,9); game.referee_flow.update(DT)
	check(game.state=="restart" and game.referee_flow.protected_restart==0,"A direct foul during the final dangerous attack cannot buy the defender an immediate whistle")
	data=foul_scene(); game.rules.foul(12,9)
	check(not game.rules.allows_goal(1) and game.state=="restart" and game.restart_team==0,"An opponent goal cannot stand while the original foul is still awaiting advantage")
	data=foul_scene(); game.rules.foul(12,9,true)
	game.goal(0)
	check(game.score[0]==1 and game.rules.advantage.is_empty(),"A goal fulfills advantage and cannot be recalled at the ensuing kickoff")

func penalties() -> void:
	for half in [1,2]:
		var i := scene(0,half,39)
		game.begin_restart("PENALTI",0,game.players[i].position)
		game.referee_flow.update(20)
		check(game.state=="restart","The period waits for its awarded penalty, half=%d" % half)
		game.state="playing"; game.rules.restart_taken("PENALTI",0,i)
		var f: float=game.attack_sign(0)
		game.commit_strike(i,Vector3(0,1,f*24),0,false,"shot",true)
		game.referee_flow.update(DT)
		check(game.state=="playing" and game.referee_flow.penalty_kicked,"The penalty waits for real flight after boot contact")
		check(game.rules.before_touch(11,false),"A goalkeeper's deflection does not end an extended penalty")
		check(not game.rules.before_touch(10) and game.state==end_state(half),"An outfielder cannot take a rebound during an extended penalty")
		i=scene(0,half,39)
		game.referee_flow.taking("PENALTI",0,i); game.referee_flow.kicked(i)
		game.ball.pending_kick=false; game.ball.linear_velocity=Vector3.ZERO
		game.referee_flow.update(DT)
		check(game.state==end_state(half),"A stopped penalty ball completes the period")
		i=scene(0,half,39)
		game.referee_flow.taking("PENALTI",0,i); game.referee_flow.kicked(i)
		game.begin_restart("PENALTI",0,game.players[i].position)
		game.referee_flow.update(DT)
		check(game.state=="restart" and not game.referee_flow.penalty_kicked,"An awarded penalty retake remains available at expiry")

func live_goal(penalty: bool=false) -> void:
	for half in [1,2]:
		var i := scene(0,half,40)
		game.match_time=game.management.half_end()+(.02 if penalty else -.02)
		game.ball.freeze=false
		var f: float=game.attack_sign(0)
		game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,f*40.6))
		await physics_frame; await physics_frame
		game.dribbler=i; game.last_touch=0
		if penalty: game.rules.restart_taken("PENALTI",0,i)
		game.strike_quality.shot_error_scale[0]=0
		game.commit_strike(i,Vector3(0,1.6,f*28),0,false,"shot",true)
		var cut_off := false
		for tick in range(180):
			game.simulate_match(DT); await physics_frame
			if game.state in ["finished","halftime"]: cut_off=true; break
			if game.score[0]==1: break
		check(not cut_off and game.score[0]==1,"A real last-second shot crosses the goal line before the final decision, half=%d penalty=%s" % [half,penalty])
		check(game.referee_flow.period_complete,"The expired period is marked complete after the goal")
		var deadline: float=game.management.half_end()
		game.management.update_clock(30)
		check(game.management.half_end()==deadline,"Celebrating the final goal cannot create another allowance")
		game.skip_sequence(); game.referee_flow.update(DT)
		if game.state=="goal": game.celebration.skip(); game.referee_flow.update(DT)
		check(game.state==end_state(half),"The final goal needs no kickoff after its celebration")
		check(absf(game.ball.position.z)>45,"Finishing the final celebration cannot teleport the ball to a needless kickoff")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-referee-flow.cfg"
	final_attacks()
	stoppage_time()
	advantages()
	penalties()
	await live_goal()
	await live_goal(true)
	print("REFEREE FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
