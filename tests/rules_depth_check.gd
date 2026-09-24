extends SceneTree
## Handball (natural vs unnatural arm, penalty area, goalkeeper) and in-match
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
	game.rules.handball_age=5.0; game.foul_cooldown=0

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
		game.rules.check_handball(DT)
		if game.state!="playing": return game.restart_type
		await physics_frame
	return ""

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-rules-depth.cfg"
	var forward: float=game.attack_sign(0)
	# An arm held out away from the body is punished.
	scene()
	var hand: Node3D=await pose(9,Vector3(0,0,-forward*5),true)
	var awarded: String=await throw_at(hand.global_position)
	check(awarded=="SERBEST VURUŞ" and game.restart_team==1,"A ball striking an extended arm is a free kick to the other team")
	# The same ball against an arm by the side is play on.
	scene()
	hand=await pose(9,Vector3(0,0,-forward*5),false)
	check(await throw_at(hand.global_position)=="","A natural arm by the side is not an offence")
	# Inside the own penalty area it is a penalty.
	scene()
	hand=await pose(9,Vector3(4,0,-forward*40),true)
	check(await throw_at(hand.global_position)=="PENALTI" and game.restart_team==1,"Handball inside the own area gives a penalty")
	# The goalkeeper may handle inside his own area.
	scene()
	var keeper=game.players[0]
	hand=await pose(0,Vector3(0,0,-forward*44),true)
	check(await throw_at(hand.global_position)=="","The goalkeeper handling inside his area is legal")
	keeper.visible=false
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
