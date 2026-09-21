extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func capture(name: String,actor) -> void:
	game.camera.size=6.8
	game.camera.position=actor.position+Vector3(4,3.5,-5)
	game.camera.look_at(actor.position+Vector3.UP*1.3)
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/referee-"+name+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	game.hud.visible=false
	var main=game.referees.actors[0]
	main.position=Vector3(0,0,-15)
	main.facing=Vector3.FORWARD
	main.rig.rotation.y=0
	for pose in ["whistle","point","yellow","red","indirect"]:
		main.signal_pose(pose)
		main.animate(0.2)
		await capture(pose,main)
	var assistant=game.referees.actors[1]
	assistant.position=Vector3(-33.2,0,-15)
	assistant.rig.rotation.y=0
	for pose in ["flag_up","offside_zone"]:
		assistant.signal_pose(pose)
		assistant.zone=1
		assistant.animate(0.2)
		await capture(pose,assistant)
	game.free()
	quit()
