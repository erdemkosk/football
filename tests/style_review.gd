extends SceneTree
var game
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	await save("menu-v3")
	game.start_match(false,false)
	await create_timer(0.4).timeout
	game.set_physics_process(false)
	game.ball.freeze = true
	game.toast_timer = 0
	await save("match-v3")
	game.start_match(true)
	game.ball.freeze = false
	await physics_frame
	await physics_frame
	game.ball.freeze = true
	game.camera_focus = Vector3(0,0,-31)
	await create_timer(0.5).timeout
	await save("practice-v3")
	game.start_match(false,false)
	game.ball.freeze = false
	game.set_physics_process(true)
	for p in game.players:
		p.position.z = clampf(p.home.z-27,-45,45)
	game.players[9].position = Vector3(-4,0,-31)
	game.players[11].position = Vector3(0,0,-47.5)
	game.ball.place(Vector3(-4,0.23,-32))
	game.camera_focus = Vector3(0,0,-34)
	game.match_time = 86
	await create_timer(0.05).timeout
	game.charge = 0.65
	game.shoot()
	await create_timer(0.25).timeout
	game.set_physics_process(false)
	game.ball.freeze = true
	game.toast_timer = 0
	await create_timer(0.3).timeout
	await save("gameplay-v3")
	game.tactical = true
	await create_timer(1.0).timeout
	await save("stadium-v3")
	game.set_process(false)
	game.hud.visible = false
	game.camera.size = 18
	game.camera.position = Vector3(25,17,-26)
	game.camera.look_at(Vector3(44,3.8,-29))
	await create_timer(0.2).timeout
	await save("crowd-v3")
	print("VISUAL REVIEW: %d FPS; stadium nodes=%d" % [Engine.get_frames_per_second(),game.stadium.get_child_count()])
	game.free()
	quit()
func save(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path = "res://tests/"+filename+".png"
	root.get_texture().get_image().save_png(path)
	print("Saved "+path)
