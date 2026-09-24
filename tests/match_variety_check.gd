extends "res://tests/ai_attack_check.gd"

func style_setup(style: String,half: int=1) -> void:
	# Equal people, seed and initial positions isolate decisions and runs.
	game.clubs.career_clubs=[game.clubs.CLUBS[0].duplicate(true),game.clubs.CLUBS[0].duplicate(true)]
	game.clubs.career_clubs[1].style=style
	game.clubs.career_clubs[1].plan={"formation":0}
	setup(); game.half=half; game.match_time=30; game.management.apply_formation()
	game.management.difficulty=1; game.rng.seed=541; game.weather.select(0,true)
	game.playtest.enabled=false
	for i in range(22):
		var q=game.players[i]
		var point: Vector2=game.management.SHAPES[0][i%11]
		player(i,Vector3(point.x*game.P.WIDTH_RATIO,0,point.y)*-game.attack_sign(q.team))
		q.collision_layer=2; q.collision_mask=3; q.body_language.enabled=false
		for stat in ["pace","acceleration","control","balance","heading","finishing","passing","defending","strength","stamina","positioning"]: q.attributes[stat]=78
	game.opponent_coach.reset(); game.opponent_coach.review()
	game.ball.freeze=false

func tick() -> void:
	game.kick_lock=maxf(0,game.kick_lock-DT)
	game.ai_attack.update(DT); game.update_ai(DT)
	game.skills.update(DT); game.physical_contests.update(DT); game.kick_contact.prepare(DT)
	for q in game.players:
		if q.visible: q.step(DT)
	game.skills.resolve(); game.duels.resolve(DT); game.rules.resolve_tackles()
	game.defending.resolve(); game.kick_contact.resolve(); game.update_contacts(DT)
	await physics_frame

func attack_layout(style: String,half: int,margin: int=0,regain: bool=false) -> Dictionary:
	style_setup(style,half)
	var forward: float=game.attack_sign(1)
	for i in range(11): game.players[i].position=Vector3((i-5)*5,0,45*forward)
	for entry in [[16,-7,-6],[17,9,4],[18,-23,2],[19,18,-7],[20,0,0],[21,6,11]]:
		player(entry[0],Vector3(entry[1],0,entry[2])*forward)
	game.controlled=20; possession(20)
	game.ball.place(Vector3(0,game.ball.GROUND_HEIGHT,.65*forward))
	await physics_frame; await physics_frame
	if margin!=0:
		game.match_time=game.LENGTH*.85; game.score=[1,1+margin]
		game.opponent_coach.review()
	if regain: game.team_tactics.possession_team=0
	for frame in range(360): await tick()
	var nearby := 0
	var ahead := 0
	var fullback_progress := 0.0
	var progress := 0.0
	var close_outlets := 0
	var outlet_sides: Array[float]=[]
	for i in range(12,22):
		if i==20: continue
		var q=game.players[i]
		if game.management.slot_role(i)>=2 and game.flat_distance(q.position,game.players[20].position)<13: nearby+=1
		if q.position.z*forward>8: ahead+=1
		if game.management.wide_defender(i): fullback_progress+=q.position.z*forward
		if i>=16: progress+=q.position.z*forward/5
		if game.support.roles.get(i,"") in ["short_outlet","link_outlet"]:
			if game.flat_distance(q.position,game.players[20].position)<13: close_outlets+=1
			outlet_sides.append(q.position.x)
	var split_outlets: bool=outlet_sides.size()==2 and outlet_sides[0]*outlet_sides[1]<0
	var result := {"nearby":nearby,"ahead":ahead,"progress":progress,"close_outlets":close_outlets,"split_outlets":split_outlets,"fullbacks":fullback_progress/2,"owner":game.dribbler,"passes":game.passes[1],"roles":game.support.roles.duplicate()}
	print("ATTACK LAYOUT ",style," half=",half," margin=",margin," regain=",regain," ",result)
	return result

func defend_build_up(style: String,half: int) -> Dictionary:
	style_setup(style,half)
	var forward: float=game.attack_sign(1)
	# An opponent building from its own half, with no runner pinning our line.
	for i in range(11): player(i,Vector3((i-5)*5,0,40*forward))
	for i in range(12,16): game.players[i].position.z=-18*forward
	player(9,Vector3(0,0,10*forward)); game.controlled=9; possession(9)
	game.ball.place(game.players[9].position+Vector3(0,game.ball.GROUND_HEIGHT,-.65*forward))
	await physics_frame; await physics_frame
	var pressure_time := INF
	var defending_line := 0.0
	for frame in range(360):
		await tick()
		# Compare physical lines at the same early time, while both teams are
		# defending. A successful high-press tackle can switch the later layout
		# into possession/cover; that is no longer a defensive-block comparison.
		if frame==120:
			for i in range(12,16): defending_line+=game.players[i].position.z*forward/4
		for i in range(12,22):
			if game.flat_distance(game.players[i].position,game.players[9].position)<4: pressure_time=minf(pressure_time,frame*DT)
	var result := {"pressure":pressure_time,"line":defending_line}
	print("DEFEND BUILD UP ",style," half=",half," ",result)
	return result

func compact_lanes(half: int) -> void:
	style_setup("KOMPAKT BLOK",half)
	var forward: float=game.attack_sign(1)
	for i in range(11): player(i,Vector3((i-5)*5,0,40*forward))
	player(8,Vector3(-24,0,-8*forward)); player(10,Vector3(24,0,-8*forward))
	player(9,Vector3.ZERO); game.controlled=9; possession(9)
	player(20,Vector3(0,0,-4*forward)); player(21,Vector3(5,0,-8*forward))
	game.team_tactics.update(.1)
	var span := 0.0
	for i in range(16,20): span=maxf(span,absf(game.team_tactics.targets[i].x))
	check(span<16,"A central low block leaves harmless wide outlets outside its midfield instead of opening the middle")
	# The same outlets become dangerous when they reach the penalty area.
	game.players[8].position.z=-32*forward; game.players[10].position.z=-32*forward
	game.team_tactics.age=0; game.team_tactics.update(.1)
	var covered := 0
	for receiver in [8,10]:
		for i in range(12,16):
			var target: Vector3=game.team_tactics.targets[i]
			if absf(target.x-game.players[receiver].position.x)<2 and target.z*forward< -32:
				covered+=1; break
	check(covered==2,"The compact block still tracks both dangerous wide runners on the goal side")
	# Moving the ball wide must also release the central-only restraint.
	player(8,Vector3(-24,0,-8*forward)); player(10,Vector3(24,0,-8*forward))
	player(9,Vector3(18,0,0)); possession(9); player(20,Vector3(18,0,-4*forward))
	game.team_tactics.age=0; game.team_tactics.update(.1)
	check("screen" in game.team_tactics.roles.values(),"Moving possession to the wing makes the block screen wide passing routes again")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/football-match-variety.cfg"
	for half in [1,2]:
		var patient: Dictionary=await attack_layout("SABIRLI PAS OYUNU",half)
		# A live instruction replaces held jobs before their usual 2.4 s expiry.
		game.clubs.career_clubs[1].plan.merge({"runs":2,"width":0},true)
		game.support.update(.1)
		check(not game.support.shape.jobs.has("link_outlet") and not game.support.shape.jobs.has("wide_outlet") and game.support.shape.jobs.has("channel_run"),"A live narrow, forward-running plan replaces the old passing triangle without stale duties")
		var direct: Dictionary=await attack_layout("ÖN ALAN BASKISI",half)
		check(patient.close_outlets==2 and patient.split_outlets and direct.ahead>patient.ahead,"Identical players offer two nearby passing angles for patient build-up and more depth for direct play, half %d" % half)
		check(patient.owner==20 and direct.owner==20 and patient.passes==0 and direct.passes==0,"Off-ball identity leaves the controlled player's possession and kick choice intact")
		var counter: Dictionary=await attack_layout("HIZLI GEÇİŞLER",half,0,true)
		var settled: Dictionary=await attack_layout("HIZLI GEÇİŞLER",half)
		check(counter.progress>settled.progress+3 and counter.roles.values().count("counter_run")>=2,"A genuine regain sends the counter team's runners forward through normal movement")
		var leading: Dictionary=await attack_layout("SABIRLI PAS OYUNU",half,1)
		var chasing: Dictionary=await attack_layout("SABIRLI PAS OYUNU",half,-1)
		check(chasing.fullbacks>leading.fullbacks+4,"The same opponent leaves more space behind its fullbacks when chasing a late goal")
		var pressing: Dictionary=await defend_build_up("ÖN ALAN BASKISI",half)
		var block: Dictionary=await defend_build_up("KOMPAKT BLOK",half)
		check(pressing.pressure<block.pressure and pressing.line>block.line+1,"The high press closes earlier and advances its physical line farther during the first second, half %d" % half)
		compact_lanes(half)
	print("MATCH VARIETY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
