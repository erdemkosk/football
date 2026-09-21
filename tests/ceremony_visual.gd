extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/ceremony-"+name+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match()
	game.set_physics_process(false)
	game.set_process(false)
	var captured: Array[String]=[]
	for frame in range(12000):
		game._physics_process(1.0/120)
		game._process(1.0/120)
		await physics_frame
		var phase: String=game.ceremony.phase
		if phase!="" and not phase in captured and game.ceremony.age>(2.8 if phase=="presentation" else 2.0):
			await capture(phase)
			captured.append(phase)
		if game.state=="playing": break
	print("CEREMONY VISUAL: %s" % [captured])
	game.free()
	quit(0 if captured.size()==3 else 1)
