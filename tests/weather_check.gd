extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func roll(mode: int,point: Vector3) -> float:
	game.weather.select(mode,true)
	game.ball.place(point+Vector3.UP*0.23,Vector3(4,0,0))
	await frames(3)
	var start: Vector3=game.ball.position
	await frames(100)
	return game.flat_distance(start,game.ball.position)
func bounce(mode: int) -> float:
	game.weather.select(mode,true)
	game.ball.place(Vector3(0,3,47))
	await frames(3)
	var hit := false
	var peak := 0.0
	for i in range(180):
		await physics_frame
		if game.ball.position.y<0.3: hit=true
		if hit: peak=maxf(peak,game.ball.position.y)
	return peak
func accelerate(mode: int) -> float:
	game.weather.select(mode,true)
	var p=game.players[9]
	p.position=Vector3(0,0,47)
	p.velocity=Vector3.ZERO
	p.reset_stamina()
	p.desired=Vector3.RIGHT
	for i in range(12):
		p.step(1.0/120)
		await physics_frame
	return p.velocity.x
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_match(false,false)
	game.set_physics_process(false)
	for p in game.players: p.position=Vector3(30,0,-30); p.collision_layer=0
	var dry=await roll(0,Vector3(15,0,0))
	var wet=await roll(2,Vector3(15,0,0))
	var mud=await roll(2,Vector3(0,0,47))
	print("ROLL distance dry=%.3f wet=%.3f mud=%.3f" % [dry,wet,mud])
	check(wet>dry+0.04,"A physical ball skids farther on wet intact grass")
	check(mud<dry-0.2,"Mud slows the same physical pass more than dry grass")
	var dry_bounce=await bounce(0)
	var mud_bounce=await bounce(2)
	print("BOUNCE dry=%.3f mud=%.3f" % [dry_bounce,mud_bounce])
	check(mud_bounce<dry_bounce*0.75,"A dropped ball rebounds lower on the soft wet goalmouth")
	game.ball.place(Vector3(0,10,54),Vector3(0,0,18))
	await frames(3)
	var rebound_speed := 0.0
	var furthest := 0.0
	for i in range(160):
		await physics_frame
		furthest=maxf(furthest,game.ball.position.z)
		if game.ball.linear_velocity.z<0: rebound_speed=maxf(rebound_speed,-game.ball.linear_velocity.z)
	check(furthest<55.7 and rebound_speed>0 and rebound_speed<18,"A high wet ball rebounds inside the stadium without gaining energy or escaping")
	var dry_acceleration=await accelerate(0)
	var wet_acceleration=await accelerate(2)
	check(wet_acceleration<dry_acceleration*0.85,"Actual player acceleration loses traction in mud")
	game.weather.reset_match()
	game.weather.select(2,true)
	game.ball.place(Vector3(25,0.23,-25))
	var player=game.players[9]
	player.position=Vector3(-3,0,47)
	player.velocity=Vector3.ZERO
	player.desired=Vector3.RIGHT
	player.facing=Vector3.RIGHT
	for i in range(150):
		player.step(1.0/120)
		game.weather.update(1.0/120)
		await physics_frame
	check(game.weather.mark_count>=3,"Actual grounded footsteps leave persistent marks")
	var count: int=game.weather.mark_count
	game.weather.update(12)
	check(game.weather.mark_count==count and game.weather.marks.multimesh.visible_instance_count==count,"Marks remain after twelve seconds without allocating extra nodes")
	game.weather.select(0)
	game.weather.update(1)
	check(game.weather.wetness>0.9 and game.weather.mark_count==count,"Stopping rain does not instantly dry the pitch or erase footprints")
	var old_clock: float=game.weather.clock
	game.before_pause="playing"
	game.state="paused"
	for i in range(30): game._physics_process(1.0/120)
	check(game.weather.clock==old_clock and game.weather.sound.stream_paused,"Pause freezes weather, mark aging and rain audio")
	game.state="playing"
	game.weather.select(2,true)
	player.position=Vector3(-2,0,47)
	player.velocity=Vector3.ZERO
	game.weather.foot_state.clear()
	player.start_slide(Vector3.RIGHT)
	for i in range(90):
		player.step(1.0/120)
		game.weather.update(1.0/120)
		await physics_frame
	check(game.weather.mark_count>count+4,"A physical slide carves a continuous muddy track")
	check(game.weather.grip_at(Vector3(0,0,47))<game.weather.grip_at(Vector3(15,0,0)),"Player acceleration uses the same localized mud map as the ball")
	for i in range(3100): game.weather.stamp(Vector3.ZERO,Vector3.FORWARD,Vector2(0.2,0.4),Color.BROWN)
	check(game.weather.mark_count==game.weather.MARK_LIMIT,"Trace storage stays bounded during a long wet match")
	game.start_match(false,false)
	check(game.weather.mark_count==0 and game.weather.foot_state.is_empty(),"A new match clears the old pitch marks")
	check(game.weather.preset==2 and game.weather.wetness==1,"A new match preserves the selected weather")
	var event := InputEventKey.new()
	event.keycode=KEY_H
	event.pressed=true
	game._input(event)
	check(game.weather.preset==0 and game.weather.wetness==1,"H cycles weather during play while retaining the wet surface")
	game.audio.toggle()
	game.weather.update(1.0/120)
	check(game.weather.sound.volume_db<=-79,"M also silences the separate rain ambience")
	game.free()
	print("WEATHER CHECK: %d failures" % failures)
	quit(0 if failures==0 else 1)
