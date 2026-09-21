extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/"+name+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	game.camera_focus=Vector3(0,0,30)
	game.update_camera(1)
	await capture("weather-clear")
	game.weather.select(2,true)
	for i in range(600):
		for index in [7,9,10]:
			var p=game.players[index]
			if i==0:
				p.position=Vector3(-5+(index-7)*1.5,0,45+(index%3))
				p.velocity=Vector3.ZERO
			p.desired=Vector3.RIGHT if i<220 else Vector3.FORWARD
			if i==240 and index==9: p.start_slide(Vector3.FORWARD)
			p.step(1.0/120)
		game.weather.update(1.0/120)
		await physics_frame
	game.hud.queue_redraw()
	await capture("weather-rain")
	game.hud.visible=false
	game.camera.size=18
	game.camera.position=Vector3(10,16,59)
	game.camera.look_at(Vector3(1,0,45))
	await capture("weather-mud-close")
	game.free()
	quit()
