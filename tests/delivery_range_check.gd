extends "res://tests/pass_skill_check.gd"
const Guide=preload("res://scripts/shot_guide.gd")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	setup()
	game.ball.position=Vector3(27,game.ball.GROUND_HEIGHT,-10)
	game.players[6].position=Vector3(20,0,-10)
	var previous := 0.0
	for power in [0.0,.25,.5,.75,1.0]:
		var route: Dictionary=game.cross_plan(Vector3.LEFT,false,power)
		var distance: float=game.flat_distance(game.ball.position,route.target)
		check(distance>previous,"More cross charge always adds distance: "+str(power))
		check(absf(distance-lerpf(3,58,power))<.01,"Nearby teammate cannot shorten charged crossing range")
		var flight: Dictionary=Guide.predict(game.ball.position,route.velocity,0,INF,game.weather,Vector3.INF,true,4)
		check(game.flat_distance(flight.target,route.target)<1.0,"Cross trajectory reaches its charged landing point: "+str(power))
		previous=distance
	check(previous>50,"Full crossing power can reach beyond the far post from the wing")
	for pad in [false,true]:
		setup()
		if pad: button(JOY_BUTTON_B)
		else: key(KEY_A)
		check(game.kick_contact.pending.is_empty() and game.controller.combos.cross_player==9,"Holding starts at short range without kicking: "+str(pad))
		game.controller.combos.update(.95)
		check(is_equal_approx(game.controller.combos.cross_power,1),"Holding reaches full crossing power")
		if pad: button(JOY_BUTTON_B,false)
		else: key(KEY_A,false)
		check(not game.kick_contact.pending.is_empty() and game.controller.combos.cross_player<0,"Release queues one physical cross: "+str(pad))
	setup()
	game.state="set_piece"; game.restart_type="TAÇ"; game.restart_team=0
	game.restart_point=Vector3(33,0,0); game.ball.position=Vector3(33,1.6,0)
	var sp=game.set_pieces
	sp.taker=9; sp.button=KEY_S; sp.direction=Vector3.LEFT
	previous=0
	for power in [0.0,.25,.5,.75,1.0]:
		sp.power=power; sp.preview()
		var distance: float=game.flat_distance(game.restart_point,sp.target)
		check(distance>previous and absf(distance-lerpf(2.5,36,power))<.01,"Throw charge grows from a nearby receiver to long range: "+str(power))
		var flight: Dictionary=Guide.predict(game.ball.position,sp.pending_velocity,0,INF,game.weather,Vector3.INF,true,4)
		check(game.flat_distance(flight.target,sp.target)<1,"Throw trajectory reaches the selected distance: "+str(power))
		previous=distance
	game.restart_type="KORNER"; game.restart_point=Vector3(33,0,-49)
	game.ball.position=game.restart_point+Vector3.UP*game.ball.GROUND_HEIGHT
	sp.button=KEY_A; sp.power=1; sp.direction=Vector3(-1,0,.2).normalized(); sp.preview()
	check(game.flat_distance(game.restart_point,sp.target)>50,"Corners also retain enough charge for a far-post delivery")
	print("DELIVERY RANGE CHECK: failures=",failures)
	game.free(); quit(1 if failures else 0)
