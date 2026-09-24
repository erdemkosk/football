extends "res://tests/strike_quality_check.gd"

func shooter(index: int,finishing: int) -> Vector3:
	p=game.players[index]; p.visible=true; game.controlled=index
	for q in game.players:
		if q!=p: q.visible=false; q.position=Vector3(30,0,0)
	var aim := place(50,0,72,3,true)
	# Change only the visible ŞUT attribute, not strength, identity or charge.
	p.attributes.finishing=finishing; p.appearance_id=777
	p.action_timer=0; p.pose=""; p.touch_cooldown=0
	Attributes.refresh(p)
	game.dribbler=index; game.carrier=index; game.state="playing"
	return aim

func flat_speed(velocity: Vector3) -> float:
	return (velocity*Vector3(1,0,1)).length()

func launch(index: int,finishing: int,kind: String,power: float=.8) -> Vector3:
	var aim := shooter(index,finishing)
	match kind:
		"normal": return game.shot_velocity(aim,power,false,false,index)
		"finesse": return game.shot_velocity(aim,power,true,false,index)
		"chip": return game.shot_velocity(aim,power,false,true,index)
		"volley": return game.volleys.launch_velocity(index,aim,power)
		"SERBEST VURUŞ","PENALTI":
			game.restart_type=kind; game.restart_point=game.ball.position
			var sp=game.set_pieces
			sp.taker=index; sp.direction=aim; sp.power=power; sp.button=KEY_D
			sp.preview(); return sp.pending_velocity
	return game.finishing.velocity(index,aim,power,kind)

func flight(index: int,finishing: int,kind: String) -> Dictionary:
	game.rules.reset(); game.ball.freeze=false
	var velocity := launch(index,finishing,kind)
	await physics_frame; await physics_frame
	p.strike_effort=.8
	check(game.commit_strike(index,velocity,0,false,"finish" if kind=="power" else "shot"),"Physical release accepted: team %d, %d ŞUT, %s" % [p.team,finishing,kind])
	var pending_speed := flat_speed(game.ball.kick_velocity)
	var start: Vector3=game.ball.position
	for frame in range(48): await physics_frame
	return {"speed":pending_speed,"distance":game.flat_distance(start,game.ball.position),"expected":flat_speed(velocity)}

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-shot-pace.cfg"
	game.start_match(true); game.set_process(false); game.set_physics_process(false)
	game.weather.select(0,true); game.hud.hide(); game.ball.freeze=true
	for q in game.players: q.visible=false; q.position=Vector3(30,0,0)
	for index in [9,20]:
		for kind in ["normal","finesse","chip","power","low","outside","timed","volley","SERBEST VURUŞ","PENALTI"]:
			var weak := flat_speed(launch(index,50,kind))
			var strong := flat_speed(launch(index,90,kind))
			check(strong>weak*1.4,"Visible ŞUT rating makes a clear speed difference: team %d, %s (%.1f → %.1f m/s)" % [p.team,kind,weak,strong])
		for charge in [.2,.6,1.0]:
			var previous := 0.0; var increasing := true
			for rating_value in [35,45,55,65,72,85,95]:
				var speed := flat_speed(launch(index,rating_value,"normal",charge))
				increasing=increasing and speed>previous; previous=speed
			check(increasing,"Shot speed increases smoothly across ratings at charge %.1f, team %d" % [charge,p.team])
	var medium := flat_speed(launch(9,72,"normal",1.0))
	var elite := flat_speed(launch(9,95,"normal",1.0))
	check(medium>31 and medium<33 and elite<39,"Average shots retain their existing pace and elite shots remain bounded")
	var lightly := flat_speed(launch(9,50,"normal",.2))
	check(flat_speed(launch(9,50,"normal",1.0))>lightly*1.4,"Charging still gives a weaker shooter meaningful extra power")
	shooter(9,50); p.attributes.strength=95; p.attributes.shot_power=95; Attributes.refresh(p)
	var muscular: float=Attributes.kick_factor(p,game.ball.position)
	shooter(9,90); p.attributes.strength=50; p.attributes.shot_power=50; Attributes.refresh(p)
	check(Attributes.kick_factor(p,game.ball.position)>muscular*1.2,"Physical strength cannot erase a poor finishing rating")
	shooter(9,90)
	var strong_foot: float=Attributes.kick_factor(p,game.ball.position)
	p.attributes.preferred_foot=1-p.attributes.preferred_foot; p.attributes.weak_foot=1
	check(Attributes.kick_factor(p,game.ball.position)<strong_foot*.9,"Weak-foot contact still reduces the actual launch pace")
	shooter(9,50)
	var pass_velocity := Vector3(0,.14,-14)
	check(game.strike_quality.assess(9,pass_velocity,"kick").velocity==pass_velocity,"Low shooting does not slow a clean ordinary pass")
	var aim := shooter(9,50)
	var old_power: float=float(p.attributes.finishing)*.55+Attributes.value(p,"shot_power")*.45
	var old_factor: float=Attributes.multiplier(old_power,.13)*(1.04 if Attributes.has_style(p,"power_shot") else 1.0)
	check(is_equal_approx(flat_speed(game.finishing.velocity(9,aim,.8,"punt")),lerpf(24,36,.8)*old_factor),"Keeper punts retain their established distribution power")
	for index in [9,20]:
		for kind in ["normal","power"]:
			var weak := await flight(index,50,kind)
			var strong := await flight(index,90,kind)
			check(is_equal_approx(weak.speed,weak.expected) and is_equal_approx(strong.speed,strong.expected),"The physical shot launches at the preview's attribute-aware speed: team %d, %s" % [p.team,kind])
			check(strong.speed>weak.speed*1.4 and strong.distance>weak.distance*1.3,"The stronger shot really travels farther in the same flight time: team %d, %s" % [p.team,kind])
	print("SHOT PACE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
