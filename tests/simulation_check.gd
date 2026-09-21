extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match()
	var restarts=0
	var goals=0
	var previous="playing"
	var restart_frames=0
	# Allow time for goals and set pieces, which pause the match clock.
	for frame in range(int((game.LENGTH+600)*Engine.physics_ticks_per_second)):
		await physics_frame
		restart_frames=restart_frames+1 if game.state=="restart" else 0
		if restart_frames>7200:
			var setup=game.set_pieces
			print("STALLED RESTART kind=%s phase=%s point=%s taker=%s ball=%s held=%s rest_age=%s" % [game.restart_type,setup.recovery.phase,game.restart_point,setup.taker,game.ball.position,game.ball.held_by,setup.recovery.rest_age])
			for i in setup.targets:
				print("PLAYER %d position=%s target=%s action=%s" % [i,game.players[i].position,setup.targets[i],game.players[i].action_timer])
			break
		if game.state=="set_piece" and game.restart_team==0 and game.set_pieces.runup<0:
			game.set_pieces.button=KEY_D if game.restart_type=="PENALTI" else (KEY_A if game.restart_type=="KORNER" else KEY_S)
			game.set_pieces.power=0.5
			game.set_pieces.commit()
		# Exercise real keyboard movement, passing and shooting while opponents play.
		if frame%720==0:
			Input.parse_input_event(key(KEY_UP,true))
		if frame%720==210:
			Input.parse_input_event(key(KEY_UP,false))
			game.pass_ball(false)
		if frame%720==400 and game.can_touch(game.controlled,1.8):
			game.charge=0.7
			game.shoot()
		if previous!=game.state:
			if game.state=="restart": restarts+=1
			if game.state=="goal": goals+=1
			previous=game.state
		if frame%7200==0: print("At tick %d: state=%s, time=%.1f, score=%s, shots=%s, passes=%s, ball=%s" % [frame,game.state,game.match_time,game.score,game.shots,game.passes,game.ball.position])
		if game.state=="finished": break
	Input.parse_input_event(key(KEY_UP,false))
	print("SIMULATION COMPLETE: state=%s score=%s shots=%s passes=%s saves=%s restarts=%d goals=%d" % [game.state,game.score,game.shots,game.passes,game.saves,restarts,goals])
	var ok=game.state=="finished" and game.shots[0]+game.shots[1]>0 and game.passes[0]+game.passes[1]>0
	game.free()
	quit(0 if ok else 1)
func key(code: int,pressed: bool) -> InputEventKey:
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	return event
