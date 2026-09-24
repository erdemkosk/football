extends "res://tests/ai_attack_check.gd"

func stats(index: int,value: int) -> void:
	for key in ["pace","acceleration","control","balance","heading","finishing","passing","defending","strength","stamina","reflexes","handling","positioning"]:
		game.players[index].attributes[key]=value
	game.players[index].energy=1

func club_scene(club: int,at: Vector3=Vector3.ZERO) -> void:
	game.clubs.career_clubs.clear(); game.clubs.career_rosters.clear()
	game.clubs.selected[1]=club; game.clubs.apply()
	setup(at)

func style_choice(style: String) -> Dictionary:
	setup()
	# Identical people and positions: only the tactical style changes.
	game.clubs.career_clubs=[game.clubs.data(0).duplicate(true),game.clubs.data(1).duplicate(true)]
	game.clubs.career_clubs[1].style=style
	game.clubs.career_clubs[1].erase("plan")
	player(18,Vector3(22,0,12)); player(17,Vector3(7,0,8))
	game.ai_attack.skill_in[20]=10
	var choice: Dictionary=game.ai_attack.decide(20)
	print("STYLE ",style," => ",choice.get("kind","carry")," receiver=",choice.get("receiver",-1))
	game.clubs.career_clubs.clear()
	return choice

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/identity-settings.tmp"
	var ratings: Array=[]
	var shapes: Array=[]
	for club in range(8):
		club_scene(club)
		ratings.append(game.frontend.team_ovr(1))
		shapes.append(game.management.opponent_formation)
		var plan: Dictionary=game.clubs.tactical_plan(1)
		check(game.management.opponent_formation==int(plan.formation) and game.management.detail(1,"tempo")==int(plan.tempo),"Quick-match club %d starts with its real formation and tempo" % club)
	print("SQUAD RATINGS: ",ratings," FORMATIONS: ",shapes)
	check(ratings[1]-ratings[6]>=12,"Strong and weak local squads show a meaningful difference in their actual lineup ratings")
	check(shapes.has(0) and shapes.has(1) and shapes.has(2),"Local opponents use all three formations")
	club_scene(1,Vector3(0,0,33)); game.management.difficulty=1
	stats(20,60); game.players[20].ai_think=.95
	var weak_reaction: float=game.management.reaction(1,20)
	var hurried := Vector3(0,.1,-22)
	game.players[20].velocity=Vector3(6,0,0)
	var weak_error: float=game.strike_quality.assess(20,hurried,"kick").limit
	check(not game.ai_attack.act(20) and game.kick_contact.pending.is_empty(),"A limited player still needs time to read an otherwise clear shot")
	stats(20,90)
	var strong_error: float=game.strike_quality.assess(20,hurried,"kick").limit
	game.players[20].velocity=Vector3.ZERO
	check(game.management.reaction(1,20)<weak_reaction*.8 and strong_error<weak_error*.65,"At fixed difficulty, passing quality changes reaction and execution precision")
	check(act_and_contact(20) and game.ball.pending_kick and game.shots[1]==1,"The elite player recognizes and physically strikes the same chance earlier")
	setup(Vector3(0,0,33)); stats(20,60)
	var aim := Vector3(0,0,1)
	var weak_shot: Vector3=game.shot_velocity(aim,.65,false,false,20)
	stats(20,90)
	var strong_shot: Vector3=game.shot_velocity(aim,.65,false,false,20)
	check(strong_shot.length()>weak_shot.length()*1.10,"Finishing affects real shot velocity in exhibition as well as career")
	setup(); stats(20,60)
	var p=game.players[20]
	p.sprinting=true; p.desired=Vector3.FORWARD; p.velocity=Vector3.ZERO
	p.update_stamina(0)
	var slow: float=p.movement_speed()
	stats(20,90)
	check(p.movement_speed()>slow*1.14,"Pace differences remain visible in quick-match sprinting")
	var normal: float=p.movement_speed()
	game.management.difficulty=0
	check(is_equal_approx(normal,p.movement_speed()),"Changing difficulty never grants hidden running speed")
	var fresh: float=game.management.reaction(1,20)
	p.energy=.12
	check(game.management.reaction(1,20)>fresh,"Tired players read play more slowly")
	club_scene(6)
	for i in range(12,22): game.players[i].visible=true; stats(i,60)
	var team_before: float=game.management.identity.team_quality(1)
	# Apply the same identity operation used when the replacement enters.
	var replacement: Dictionary=game.players[18].identity()
	for key in replacement.attributes:
		if key not in ["archetype","preferred_foot","weak_foot"]: replacement.attributes[key]=92
	game.players[18].apply_identity(replacement)
	check(game.management.identity.team_quality(1)>team_before+.04,"A stronger substitute improves live team reading without changing the badge")
	var wing := style_choice("KANATLARDAN OYUN")
	var patient := style_choice("SABIRLI PAS OYUNU")
	check(wing.get("receiver",-1)==18 and patient.get("receiver",-1)==17,"The same open pitch produces a wide outlet for wing play and a short combination for possession play")
	# Safety must beat style: a club preference cannot authorize a blocked pass.
	setup(); player(18,Vector3(22,0,12)); player(4,Vector3(11,0,6))
	game.ai_attack.skill_in[20]=10
	var blocked: Dictionary=game.ai_attack.decide(20)
	check(blocked.get("receiver",-1)!=18,"A blocked preferred lane still loses to a safer action")
	for half in [1,2]:
		for formation in range(3):
			setup(); game.half=half; game.management.formation=formation
			game.management.fullbacks=2; game.management.runs=1; game.management.tempo=1
			game.management.apply_formation()
			for i in range(1,11): player(i,game.players[i].home)
			var forward: float=game.attack_sign(0)
			player(11,Vector3(0,0,forward*49)); player(13,Vector3(-25,0,forward*48))
			game.players[9].position=Vector3(25,0,forward*20); possession(9)
			game.career.in_match=false; game.support.update(.3)
			var defenders := 0; var forwards := 0; var wide_backs := 0
			for i in range(1,11):
				defenders+=int(game.management.slot_role(i)==1)
				forwards+=int(game.management.slot_role(i)==3)
				if game.management.wide_defender(i):
					wide_backs+=1
					if signf(game.players[i].home.x)>0:
						check(game.support.roles.get(i,"")=="overlap" and game.support.targets[i].z*forward>game.ball.position.z*forward,"Formation %d sends its actual wide defender forward in half %d" % [formation,half])
			check(defenders==[4,4,3][formation] and forwards==[2,3,2][formation] and wide_backs==2,"Formation %d preserves its distinct lines in half %d" % [formation,half])
	# Defence has better spacing and updates sooner with stronger defenders,
	# while the same one-presser/cover rules continue to apply.
	club_scene(2); player(9,Vector3(0,0,-15)); possession(9)
	var gaps: Array=[]; var delays: Array=[]
	for value in [58,90]:
		for i in range(12,22): player(i,Vector3(0,0,35)); stats(i,value)
		game.team_tactics.age=0; game.team_tactics.update(.01)
		gaps.append(absf(game.team_tactics.targets[17].z-game.team_tactics.targets[13].z))
		delays.append(game.team_tactics.age)
		check(game.team_tactics.roles.values().count("press")<=1 and game.team_tactics.roles.values().count("press_support")<=1,"Defensive quality %d never creates an unlimited swarm" % value)
	check(gaps[1]<gaps[0]-1.5 and delays[1]<delays[0]*.85,"Better defenders hold closer lines and collectively react earlier")
	# A saved career plan wins over a style preset; arbitrary catalog indices
	# (including large international leagues) never index the eight local clubs.
	game.clubs.career_clubs=[game.clubs.data(0).duplicate(true),game.clubs.data(1).duplicate(true)]
	game.clubs.career_clubs[1].plan={"formation":2,"mentality":1,"pressing":0,"line_height":0,"width":2,"tempo":0,"runs":2,"fullbacks":0,"anchor":true}
	game.clubs.selected[1]=23; game.match_time=0; game.opponent_coach.reset(); game.opponent_coach.review()
	check(game.management.opponent_formation==2 and game.management.detail(1,"width")==2 and game.opponent_coach.pressing==0,"Saved tactics remain authoritative outside the eight-club catalog")
	print("TEAM IDENTITY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
