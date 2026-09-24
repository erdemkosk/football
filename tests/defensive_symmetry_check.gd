extends "res://tests/ai_attack_check.gd"
## Both teams read runners, cover and through-ball threats with the same
## duties; the user's controlled player is never given an AI duty.

func plan(owner: int) -> void:
	game.state="playing"
	game.team_tactics.age=0; game.team_tactics.observed_owner=-2
	game.team_tactics.update(DT)

func scene(defending: int,runner_depth: float,controlled: int=-1) -> Dictionary:
	setup()
	for p in game.players: p.visible=false
	var attack: int=1-defending
	var toward: float=game.attack_sign(attack)
	# Our goal is where the attackers head; depth is measured from halfway.
	var carrier: int=attack*11+8
	var runner: int=attack*11+9
	player(defending*11,Vector3(0,0,toward*48))
	player(defending*11+2,Vector3(-8,0,toward*28)); player(defending*11+3,Vector3(8,0,toward*28))
	player(defending*11+6,Vector3(0,0,toward*12))
	# Midfielders nearer the pressing point take the cover job.
	player(defending*11+5,Vector3(-7,0,toward*15)); player(defending*11+7,Vector3(7,0,toward*15))
	player(carrier,Vector3(2,0,toward*4)); game.players[carrier].facing=Vector3(0,0,toward)
	player(runner,Vector3(-6,0,toward*runner_depth),Vector3(0,0,toward*7))
	possession(carrier)
	# The human controls a player of team 0 away from the move unless told otherwise.
	if controlled<0:
		controlled=10 if attack==1 else 1
		player(controlled,Vector3(26,0,-toward*20))
	game.controlled=controlled
	plan(carrier)
	return {"carrier":carrier,"runner":runner,"centre_backs":[defending*11+2,defending*11+3]}

func tracked(info: Dictionary) -> int:
	for i in info.centre_backs:
		if game.team_tactics.roles.get(i,"") in ["track","recover"]: return i
	return -1

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-defensive-symmetry.cfg"
	for defending in [0,1]:
		var info := scene(defending,22)
		check(tracked(info)>=0,"A centre back picks up the runner goal-side, defending team %d" % defending)
	# The user's own back line no longer leaves runners to the human alone.
	var info := scene(0,22,2)
	var tracker := tracked(info)
	check(tracker==3,"With the user on one centre back, the other AI centre back takes the runner")
	check(game.team_tactics.roles.get(2,"") not in ["track","recover","press_support"],"The controlled player is never assigned an AI marking duty")
	# The marking slider moves the depth at which runners are picked up.
	game.sliders.reset()
	game.sliders.set_value(0,"marking",0.0)
	info=scene(0,20)
	var loose := tracked(info)
	game.sliders.set_value(0,"marking",1.0)
	info=scene(0,20)
	var tight := tracked(info)
	check(loose<0 and tight>=0,"Tight marking tracks a runner earlier than loose marking")
	game.sliders.reset(); game.sliders.apply()
	# Through-ball threat drops the line for an unpressured carrier facing goal.
	info=scene(0,10)
	var threat: float=game.team_tactics.through_ball_threat(0,info.carrier)
	var line_free: float=game.team_tactics.targets[2].z*game.attack_sign(0)
	var pressure_at: Vector3=game.players[info.carrier].position+Vector3(0,0,game.attack_sign(1)*1.4)
	player(6,pressure_at); plan(info.carrier)
	var pressed_threat: float=game.team_tactics.through_ball_threat(0,info.carrier)
	var line_pressed: float=game.team_tactics.targets[2].z*game.attack_sign(0)
	check(threat>.9 and pressed_threat<.1,"Pressure on the ball removes the through-ball threat")
	check(line_free<line_pressed-2.5,"An unpressured carrier facing goal pushes the back line deeper: %.1f vs %.1f" % [line_free,line_pressed])
	print("DEFENSIVE SYMMETRY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
