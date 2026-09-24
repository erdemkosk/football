extends "res://tests/presentation_depth_check.gd"

class TestCommentary:
	extends "res://scripts/commentary.gd"
	var busy := false
	func speaking() -> bool: return busy
	func available() -> bool: return false
	func stop() -> void:
		busy=false
		super.stop()

var c

func quiet_fixture(team: int=0,half: int=1,depth: float=0,x: float=0) -> void:
	game.state="playing"; game.training=false; game.menu_match.running=false
	game.score=[0,0]; game.match_time=20; game.half=half
	game.weather.rain=0; game.team_tactics.counter_time=[0.0,0.0]
	game.ball.freeze=true; game.ball.release_hold()
	game.ball.pending_kick=false; game.ball.pending_reset=false
	game.ball.linear_velocity=Vector3.ZERO
	for p in game.players:
		p.visible=false; p.dismissed=false; p.velocity=Vector3.ZERO; p.energy=1
	var owner := team*11+9
	var p=game.players[owner]
	p.visible=true; p.position=Vector3(x,0,depth*game.attack_sign(team))
	game.ball.position=p.position+Vector3(0,.23,game.attack_sign(team)*.5)
	game.dribbler=owner; game.carrier=owner
	c.enabled=true; c.busy=false; c.reset(); c.variation.seed=736

func tick(seconds: float) -> void:
	for n in range(int(seconds*2)): c.update(.5)

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-commentary-variety.cfg"
	live_match()
	c=TestCommentary.new(); c.game=game; game.commentary=c
	quiet_fixture()
	var line_count := 0
	var no_repeats := true
	for kind in c.LINES:
		var seen: Array=[]
		for n in range(c.LINES[kind].size()):
			var line: String=c.choose(kind)
			no_repeats=no_repeats and line not in seen
			seen.append(line); line_count+=1
		no_repeats=no_repeats and c.choose(kind)!=seen.back()
	check(line_count>=180 and no_repeats,"Every phrase is used before repeating, including across shuffle cycles (%d lines)" % line_count)
	for row in [[0,1,.3,"goal_level"],[0,0,.3,"goal_lead"],[2,0,.3,"goal_extend"],[0,3,.3,"goal_reply"],[0,0,.9,"goal_late_lead"],[0,1,.9,"goal_late_level"]]:
		quiet_fixture(); game.score=[row[0],row[1]]; game.match_time=game.LENGTH*row[2]
		check(c.line_key("goal",{"team":0})==row[3] and c.event("goal",{"team":0,"name":"Deniz"}) and "Deniz" in c.history.back(),"Score-aware goal call: "+row[3])
	quiet_fixture(); game.score=[0,1]; game.last_kicker=9
	game.goal(0)
	check(game.score==[1,1] and c.spoken_at.has("goal") and ("eşit" in c.history.back() or "beraber" in c.history.back() or "denge" in c.history.back()),"The actual goal hook describes the new score, not the pre-goal score")
	quiet_fixture()
	check(c.event("cross") and c.event("save") and c.event("goal",{"team":0,"name":"Deniz"}),"A save interrupts the build-up and a goal interrupts the save")
	var before: int=c.history.size()
	check(not c.event("corner") and not c.event("great_save") and not c.event("goal",{"team":0}),"Minor calls and duplicate contact notifications cannot crowd out a goal")
	c.update(10)
	check(c.history.size()==before,"Dropped calls are never spoken late from a backlog")
	quiet_fixture(); c.event("corner"); c.busy=true; c.update(20)
	check(not c.event("skill") and not c.event("free_kick"),"A slow speech voice cannot accumulate ordinary calls behind an unfinished line")
	check(c.event("goal",{"team":0,"name":"Deniz"}),"An important goal can interrupt an actually busy speech engine")
	quiet_fixture(); c.event("substitution",{"out":"Deniz","incoming":"Efe","team":0})
	check("Deniz" in c.history.back() and "Efe" in c.history.back() and "{" not in c.history.back(),"Substitution commentary identifies both real players")
	# Busy play keeps the action calls but still leaves deliberate silence.
	quiet_fixture(); game.carrier=-1; game.dribbler=-1
	var calls := 0
	for step in range(240):
		c.update(.5)
		if step%12==0: calls+=int(c.event("save",{"name":"Efe"}))
		if step%8==0: calls+=int(c.event("corner"))
		if step%2==0: calls+=int(c.event("shot",{"name":"Deniz"}))
		calls+=int(c.event("skill",{"name":"Deniz"}))
	print("BUSY COMMENTARY: ",calls," calls in 120 seconds")
	check(calls>=8 and calls<=20,"Frequent shots, corners and skills do not turn into nonstop commentary")
	for team in [0,1]:
		for half in [1,2]:
			quiet_fixture(team,half,20,24); c.context_in=0
			tick(2)
			check(c.history.is_empty(),"A momentary wide position is not announced as a sustained wing attack")
			tick(1)
			check(c.spoken_at.has("wing_attack"),"Actual wing play is recognized for team=%d half=%d" % [team,half])
			quiet_fixture(team,half,5); c.context_in=0
			game.team_tactics.counter_time[team]=4
			game.players[team*11+9].velocity=Vector3(0,0,game.attack_sign(team)*4)
			c.update(.5)
			check(c.spoken_at.has("counter"),"A real forward transition is recognized for team=%d half=%d" % [team,half])
	quiet_fixture(0,1,30); c.context_in=0
	for i in [6,7]:
		game.players[i].visible=true; game.players[i].position=Vector3(i,0,-30)
	tick(3)
	check(c.spoken_at.has("pressure"),"Sustained numbers around the penalty area produce a pressure remark")
	for margin in [-1,0,1]:
		quiet_fixture(); c.context_in=0; game.match_time=game.LENGTH*.9
		game.score=[maxi(0,margin),maxi(0,-margin)]
		tick(2)
		var key: String={-1:"late_chase",0:"late_level",1:"late_protect"}[margin]
		check(c.spoken_at.has(key),"Late-match remarks agree with the actual score: "+key)
	quiet_fixture(); c.context_in=0; game.match_time=game.LENGTH*.9; game.score=[0,3]
	tick(3)
	check(not c.spoken_at.has("late_chase"),"A three-goal deficit is never described as needing one equalizer")
	quiet_fixture(); c.context_in=0; game.weather.rain=.8
	tick(3)
	check(c.spoken_at.has("rain"),"Wet-pitch advice is tied to current rain")
	quiet_fixture(); c.context_in=0
	for i in range(1,11): game.players[i].visible=true; game.players[i].energy=.2
	c.update(.5)
	check(c.spoken_at.has("fatigue"),"Fatigue commentary requires the team's actual low energy")
	quiet_fixture(0,1,20,24); tick(120)
	check(c.history.size()>=2 and c.history.size()<=6,"A quiet passage gets occasional contextual remarks with long gaps")
	quiet_fixture(0,1,20,24); game.ball.position=Vector3(0,.23,0)
	tick(30)
	check(c.history.is_empty(),"A stale carrier far from the ball cannot generate invented attacks")
	for mode in ["disabled","paused","replay","training","menu"]:
		quiet_fixture(); c.event("shot"); c.busy=true
		if mode=="disabled": c.enabled=false
		elif mode=="training": game.training=true
		elif mode=="menu": game.menu_match.running=true
		else: game.state=mode
		before=c.history.size(); c.update(20)
		check(not c.event("goal",{"team":0}) and c.history.size()==before and not c.busy and c.subtitle=="","No stale voice or subtitle in "+mode)
	quiet_fixture(); var random_state: int=game.rng.state
	c.event("shot"); tick(30)
	check(game.rng.state==random_state,"Commentary randomness does not change gameplay outcomes")
	# New action calls belong to the committed strike, never the button press.
	for row in [["shot","shot"],["cross","cross"],["volley","volley"]]:
		live_match(); quiet_fixture(0,1,35)
		game.players[9].action_timer=0; game.kick_lock=0
		game.last_kicker=9; game.last_touch=0
		if row[0]=="shot":
			game.strike(9,Vector3(0,3,-20),0,false,"shot")
			check(c.history.is_empty(),"Preparing a shot does not announce a strike that might still be cancelled")
			game.kick_contact.reset()
		var committed: bool=game.commit_strike(9,Vector3(0,3,-20),0,false,row[0],true)
		check(committed and c.spoken_at.has(row[1]),"The real committed action produces its commentary: "+row[0])
	print("COMMENTARY VARIETY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
