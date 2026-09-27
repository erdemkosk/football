extends SceneTree
## Hand/arm contacts never award handball; normal fouls, keeper handling and
## injuries (pace, sprint, readiness, substitution priority, slider).
const DT := 1.0/120
var game
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func scene() -> void:
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.state="playing"; game.menu_match.running=false; game.hud.hide()
	for p in game.players:
		p.visible=false; p.collision_layer=0; p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	game.dribbler=-1; game.carrier=-1; game.last_touch=1; game.last_kicker=20; game.kick_lock=0
	game.foul_cooldown=0

func pose(index: int,at: Vector3,extended: bool) -> Node3D:
	var p=game.players[index]
	p.visible=true; p.position=at; p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO
	p.jockeying=extended; p.protecting=false; p.pose="run"; p.action_timer=0
	for n in range(50):
		p.desired=Vector3.ZERO; p.jockeying=extended; p.step(DT)
		await physics_frame
	return p.right_hand

func throw_at(point: Vector3) -> String:
	# A flat 9 m/s ball from 3 m, lifted just enough to meet the arm.
	var start: Vector3=point+Vector3(3,0,0)
	var launch := Vector3(-9,4.905*(3.0/9.0),0)
	game.ball.place(start,launch); await physics_frame
	game.ball.position=start; game.ball.linear_velocity=launch
	for n in range(60):
		game.rules.update(DT)
		if game.state!="playing": return game.restart_type
		await physics_frame
	return ""

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-rules-depth.cfg"
	# Both teams and both halves: even a shot meeting an extended hand plays on.
	for half in [1,2]:
		for team in [0,1]:
			for depth in [5,40]:
				scene(); game.half=half
				var index: int=9+team*11; var p=game.players[index]
				var hand: Node3D=await pose(index,Vector3(4,0,-game.attack_sign(team)*depth),true)
				game.reactions.shooter=20 if team==0 else 9
				var awarded: String=await throw_at(hand.global_position)
				check(awarded=="" and game.state=="playing" and p.fouls_committed==0 and p.yellow_cards==0 and not p.dismissed,"Extended hand contact keeps play running without free kick, penalty or card: team %d, half %d, depth %d" % [team,half,depth])
				check(game.rules.allows_goal(1-team),"Hand contact does not disallow the following goal")
	scene()
	var hand: Node3D=await pose(9,Vector3(0,0,-game.attack_sign(0)*5),false)
	check(await throw_at(hand.global_position)=="","A natural arm by the side also keeps play running")
	scene()
	hand=await pose(0,Vector3(0,0,-game.attack_sign(0)*44),true)
	check(await throw_at(hand.global_position)=="","Goalkeeper hand contact in his area does not stop play")
	# Removing handball must not remove fouls or penalties from actual challenges.
	for depth in [5,40]:
		scene()
		for index in [9,20]:
			game.players[index].visible=true; game.players[index].position=Vector3(4,0,-game.attack_sign(0)*depth)
		game.rules.foul(9,20,true)
		check(game.restart_type==("PENALTI" if depth==40 else "SERBEST VURUŞ") and game.restart_team==1 and game.players[9].yellow_cards==1,"A reckless foul still awards its restart and card: depth %d" % depth)
	# Injuries: heavy challenges can leave a knock with real consequences.
	scene()
	var p=game.players[7]
	p.visible=true; p.position=Vector3(0,0,0); p.energy=1; p.match_fatigue=0
	game.sliders.reset(); game.sliders.set_value(0,"injuries",1.0)
	var fit_speed: float=p.movement_speed()
	var fit_ready: float=p.readiness()
	var hit := false
	for n in range(60):
		if game.injuries.impact(7,1.0,true): hit=true; break
	check(hit and p.injury_level>0,"A maximal injury slider lets a heavy foul cause a knock")
	check(p.movement_speed()<fit_speed and p.readiness()<fit_ready,"A knock reduces pace and readiness")
	p.injury_level=2
	p.sprinting=true; p.desired=Vector3.FORWARD; p.update_stamina(DT)
	check(not p.active_sprint,"An injured player cannot sprint")
	for i in range(1,11): game.players[i].visible=true; game.players[i].energy=1; game.players[i].match_fatigue=0
	game.players[7].energy=1
	var proposal: Dictionary=game.management.suggestion(0,.40)
	check(not proposal.is_empty() and proposal.slot==7,"The bench suggestion replaces the injured player first")
	var data: Dictionary=game.players[7].identity()
	game.players[7].apply_identity(data)
	check(game.players[7].injury_level==0,"A player arriving on the pitch starts fit")
	game.sliders.set_value(0,"injuries",0.0)
	var none := true
	for n in range(80):
		if game.injuries.impact(6,1.0,true): none=false
	check(none,"The injury slider at zero disables knocks")
	game.sliders.reset(); game.sliders.apply()
	print("RULES DEPTH CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
