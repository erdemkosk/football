extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	game.hud.queue_redraw()
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/match-day-"+label+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	game.ball.freeze=true
	game.hud.visible=false
	game.camera.size=21
	game.camera.position=Vector3(23,14,-24)
	game.camera.look_at(Vector3(44,3.8,-24))
	game.stadium.crowd.reset()
	await capture("calm-crowd")
	game.stadium.react("shot",0,Vector3(0,1,-28))
	for i in range(100): game.stadium.crowd.update(1.0/120,Vector3.ZERO,Vector3.ZERO,0,false,false)
	await capture("shot-crowd")
	game.stadium.react("goal",0,Vector3(0,1,-50))
	for i in range(100): game.stadium.crowd.update(1.0/120,Vector3.ZERO,Vector3.ZERO,0,false,false)
	await capture("goal-crowd")
	game.ball.freeze=false
	for i in range(1,11): game.players[i].position=Vector3(12+(i%3)*3,0,-30-(i/3)*3)
	game.last_kicker=9
	game.players[9].position=Vector3(18,0,-39)
	game.ball.place(Vector3(0,0.3,-51))
	await physics_frame
	await physics_frame
	game.goal(0)
	for i in range(850):
		game._physics_process(1.0/120)
		game._process(1.0/120)
		await physics_frame
	game.camera.size=15
	game.camera.position=game.celebration.gathering+Vector3(-11,10,13)
	game.camera.look_at(game.celebration.gathering+Vector3.UP)
	game.hud.visible=true
	await capture("team-celebration")
	print("MATCH DAY VISUAL COMPLETE")
	game.free()
	quit()
