extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/impact-"+name+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(true)
	game.set_physics_process(false)
	game.set_process(false)
	game.hud.visible=false
	game.camera.size=8
	game.camera.position=Vector3(5,4,-19)
	game.camera.look_at(Vector3(0,1,-25))
	await physics_frame
	game.begin_shot()
	game.update_control(0.9)
	game.players[9].animate(1.0/120)
	await capture("windup")
	game.shoot()
	for i in range(8):
		game.players[9].step(1.0/120)
		await physics_frame
	await capture("follow-through")
	game.players[12].visible=true
	game.players[12].position=Vector3(0,0,-24.4)
	game.players[9].position=Vector3(0,0,-25.2)
	game.rules.start_tackle(12,Vector3.FORWARD)
	game.tackle_impact(12,9)
	for i in range(33):
		game.players[9].step(1.0/120)
		game.players[12].step(1.0/120)
		await physics_frame
	await capture("tackle")
	game.free()
	quit()
