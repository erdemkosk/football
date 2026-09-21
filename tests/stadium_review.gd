extends SceneTree
var game
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	await save("arena-menu")
	game.start_match(false,false)
	await create_timer(0.3).timeout
	game.set_physics_process(false)
	game.ball.freeze = true
	game.toast_timer = 0
	await save("arena-gameplay")
	game.tactical = true
	await create_timer(1.5).timeout
	await save("arena-tactical")
	game.set_process(false)
	game.hud.visible = false
	game.camera.far = 600
	game.camera.size = 210
	game.camera.position = Vector3(145,150,175)
	game.camera.look_at(Vector3(0,0,0))
	await save("arena-exterior")
	game.stadium.architecture.update_score([2,1],180,240)
	game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov = 65
	game.camera.position = Vector3(-19,6,20)
	game.camera.look_at(Vector3(7,9,-55))
	await save("arena-bowl")
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 24
	game.camera.position = Vector3(19,9,7)
	game.camera.look_at(Vector3(42,4,0))
	await save("arena-tunnel")
	print("STADIUM REVIEW COMPLETE; fans=%d; nodes=%d" % [game.stadium.crowd.fans.size(),game.stadium.get_child_count()])
	game.free()
	quit()
func save(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/"+filename+".png")
	print("Saved "+filename)
