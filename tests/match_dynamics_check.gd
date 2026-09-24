extends "res://tests/ai_attack_check.gd"

func squad(team: int=1,half: int=1) -> void:
	setup(); game.half=half; game.management.apply_formation()
	for i in range(22): player(i,game.players[i].home)
	player(team*11+9,Vector3.ZERO); possession(team*11+9)

func advance_energy(p,seconds: float,rate: int=120) -> void:
	for tick in range(roundi(seconds*rate)): p.update_stamina(1.0/rate)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-match-dynamics.cfg"
	# Identity changes defensive reach and genuine regain runs on the same pitch.
	for club in [1,3,0]:
		game.clubs.selected[1]=club; game.clubs.apply(); squad()
		game.opponent_coach.review(); game.opponent_coach.transition=2
		check(game.opponent_coach.press_level()==[2,0,1][[1,3,0].find(club)],"Press / counter / wing clubs retain distinct pressure after losing the ball")
		possession(9); game.team_tactics.update(.1)
		possession(20); game.team_tactics.update(.1); game.support.update(.1)
		var counters: int=game.support.roles.values().count("counter_run")
		check((counters>=2)==(club==3),"Only the counter plan launches its front players after a real regain, club %d" % club)
		if club==0:
			var wide := false
			for i in game.support.roles:
				if game.support.roles[i]=="wing_outlet" and absf(game.support.targets[i].x)>game.P.HALF_WIDTH-9: wide=true
			check(wide,"Wing play keeps an outlet near the touchline before the ball goes wide")
		if club==3:
			game.team_tactics.update(6); game.support.update(.2)
			check(not "counter_run" in game.support.roles.values(),"Regain urgency expires instead of becoming a permanent all-out attack")
		game.begin_restart("TAÇ",0,Vector3.ZERO)
		check(game.team_tactics.counter_time==[0.0,0.0],"A stoppage clears the previous transition")
	# Compare actual runner destinations, including the reversed second half.
	for half in [1,2]:
		for team in [0,1]:
			squad(team,half); game.match_time=game.LENGTH*.86
			game.score[team]=0; game.score[1-team]=1
			game.support.update(.2)
			var attacking: Dictionary=game.support.targets.duplicate()
			check(game.support.roles.values().count("commit")>=3,"Trailing team %d commits more runners in half %d" % [team,half])
			game.score[team]=2; game.support.update(.2)
			var dropped := 0
			for i in attacking:
				if game.management.wide_defender(i) and (attacking[i].z-game.support.targets[i].z)*game.attack_sign(team)>15: dropped+=1
			check(dropped==2,"Both fullbacks leave counter space when chasing and drop when protecting, team %d / half %d" % [team,half])
			check(game.support.roles.values().count("cover_attack")>=5,"A leading team keeps midfield cover behind possession")
			game.score=[1,1]
			check(game.team_tactics.score_intent(team)==0,"An equalizer removes the score-driven instruction")
	squad(0); game.match_time=game.LENGTH*.9; game.score=[0,1]
	game.management.live_plan(0)
	check(game.team_tactics.plan_for(0)==0 and game.team_tactics.score_intent(0)==0,"An explicit touchline plan remains authoritative over automatic score response")
	game.support.update(.2)
	var cautious: float=game.support.targets[2].z*game.attack_sign(0)
	game.management.live_plan(2); game.support.update(.2)
	check(game.support.targets[2].z*game.attack_sign(0)>cautious+5,"Explicit attacking instructions still advance the supporting defensive line")
	# Sprint fatigue survives recovery, while rest does not keep accumulating it.
	squad(); var p=game.players[20]
	p.attributes.stamina=72; p.attributes.pace=86
	p.desired=Vector3.BACK; p.sprinting=true; p.update_stamina(0)
	var fresh_speed: float=p.movement_speed()
	for cycle in range(4):
		p.sprinting=true; p.desired=Vector3.BACK; advance_energy(p,20)
		p.sprinting=false; p.desired=Vector3.ZERO; advance_energy(p,12)
	var fatigue: float=p.match_fatigue
	check(fatigue>.24 and p.energy<.76,"Repeated sprint bursts lower the recoverable energy ceiling")
	advance_energy(p,20)
	check(p.match_fatigue==fatigue and is_equal_approx(p.energy,p.stamina_capacity()),"Standing restores short-term energy without erasing match fatigue")
	p.sprinting=true; p.desired=Vector3.BACK; p.update_stamina(0)
	check(p.movement_speed()<fresh_speed*.92,"A tired winger loses actual sprint pace even after catching his breath")
	p.stamina_free_movement=true; advance_energy(p,5)
	check(p.match_fatigue==fatigue,"Substitution and interval walks cannot add match fatigue")
	p.stamina_free_movement=false
	game.state="paused"; game.simulate_match(2)
	check(p.match_fatigue==fatigue,"Pause cannot age the player's legs")
	game.state="halftime"; game.interval.finish()
	check(p.match_fatigue==fatigue and p.energy<=p.stamina_capacity(),"Halftime recovery respects the accumulated fatigue ceiling")
	game.reset_positions(0)
	check(p.match_fatigue==fatigue,"A goal kickoff cannot refresh tired legs")
	p.reset_stamina(); p.desired=Vector3.BACK; p.sprinting=true; advance_energy(p,10,30)
	var fatigue30: float=p.match_fatigue
	p.reset_stamina(); p.desired=Vector3.BACK; p.sprinting=true; advance_energy(p,10,120)
	check(absf(p.match_fatigue-fatigue30)<.0001,"Fatigue is independent of simulation rate")
	p.reset_stamina(); p.attributes.stamina=90; p.desired=Vector3.BACK; p.sprinting=true; advance_energy(p,10)
	check(p.match_fatigue<fatigue30,"Endurance attributes reduce the cost of repeated sprinting")
	game.start_match(false,false)
	check(p.match_fatigue==0 and p.energy==1,"A new match resets fatigue")
	# A mistimed poke must recover even when it hits neither ball nor body.
	squad(); player(14,Vector3.ZERO); player(9,Vector3(3,0,-2)); possession(9)
	var defender=game.players[14]
	game.duels.standing_tackle(14); defender.step(.13); game.duels.resolve(.13)
	check(defender.tackle_recovery>.5 and game.last_kicker!=14,"An early poke into empty space leaves the defender committed")
	defender.action_timer=0; defender.sprinting=true; defender.desired=Vector3.BACK; defender.update_stamina(0)
	var committed_speed: float=defender.movement_speed()
	defender.tackle_recovery=0
	check(defender.movement_speed()>committed_speed*1.5,"Recovery has a physical movement cost, not just a button cooldown")
	# Fitness and pace influence the actual reserve selected to chase a goal.
	game.clubs.selected[1]=0; game.clubs.apply(); squad()
	game.match_time=game.LENGTH*.85; game.score=[1,0]; game.opponent_coach.review()
	var wing := 19
	game.players[wing].match_fatigue=.30; game.players[wing].energy=.68
	var role: int=game.management.slot_role(wing)
	for i in range(1,7):
		game.management.bench[1][i].role=role
		game.management.bench[1][i].attributes.pace=62
		game.management.bench[1][i].attributes.acceleration=62
	game.management.bench[1][5].attributes.pace=94; game.management.bench[1][5].attributes.acceleration=94
	var choice: Dictionary=game.opponent_coach.substitution()
	check(choice.get("slot",-1)==wing and choice.get("reserve",-1)==5,"A chasing coach chooses the fresh fast winger for the tired wide slot")
	game.management.bench[1][5].fitness=.35
	check(game.opponent_coach.substitution().get("reserve",-1)!=5,"An unfit fast reserve is not treated as a fresh replacement")
	# A live second leg may have the opposite leader to the scoreboard.
	game.career.in_match=true; game.career.fixture_id="return"
	game.career.world={"user":"home","cup_fixtures":[
		{"id":"first","played":true,"score":[0,3]},
		{"id":"return","home":"home","away":"away","leg":2,"tie":"first"}]}
	game.team_tactics.reset(); game.management.manual_plan=false
	game.score=[0,1]
	check(game.team_tactics.score_intent(0)==-1 and game.team_tactics.score_intent(1)==1,"A team losing tonight but leading on aggregate protects its qualification")
	game.career.world.user="away"; game.team_tactics.reset()
	check(game.team_tactics.score_intent(0)==1,"Aggregate orientation also works when the user's club is away")
	game.career.in_match=false
	print("MATCH DYNAMICS CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
