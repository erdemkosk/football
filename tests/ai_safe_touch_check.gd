extends "res://tests/ai_attack_check.gd"

func offers_push() -> bool:
	for option in game.ai_attack.options(20):
		if option.kind=="push": return true
	return false

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	setup()
	check(not offers_push() and game.ai_attack.decide(20).is_empty() and not game.ai_attack.act(20) and not game.ball.pending_kick,"Standing AI carries instead of knocking the ball away in empty space")
	var p=game.players[20]
	p.velocity=Vector3.BACK*4; p.desired=Vector3.BACK
	game.ball.linear_velocity=p.velocity
	check(offers_push(),"An established forward run still allows an open-space knock-on")
	p.desired=Vector3.LEFT
	check(not offers_push(),"Turning AI keeps the ball close")
	p.desired=Vector3.BACK; p.velocity=Vector3.FORWARD*4
	check(not offers_push(),"A player moving against the intended exit cannot knock ahead")
	p.velocity=Vector3.BACK*4; game.ball.linear_velocity=p.velocity
	p.receive_timer=.2
	check(not offers_push(),"First touch settles before a long touch is attempted")
	check(game.ai_attack.skill_choice(20,{"gap":2.0,"closing":2.0}).is_empty(),"AI does not interrupt reception with a skill")
	p.receive_timer=0; game.ball.linear_velocity=Vector3.BACK*8
	check(not offers_push(),"An escaping ball is recovered before another opening touch")
	game.ball.linear_velocity=p.velocity; p.energy=.2
	check(not offers_push(),"Tired AI does not open a ball it cannot chase")
	setup(); player(4,Vector3(0,0,2))
	var choice: Dictionary=game.ai_attack.skill_choice(20,game.ai_attack.pressure_read(20))
	check(not choice.is_empty() and choice.kind!="knock_around","Stationary one-on-one can use a close skill without a long knock-around")
	print("AI SAFE TOUCH CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
