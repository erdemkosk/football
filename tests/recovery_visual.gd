extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(false,false)
	game.set_physics_process(false)
	game.set_process(false)
	game.hud.visible=false
	game.players[8].position=Vector3(28,0,8)
	game.ball.place(Vector3(32.5,3,10),Vector3(6,2,3))
	await physics_frame
	await physics_frame
	game.begin_restart("TAÇ",0,Vector3(32,0,10))
	var saved: Array[String]=[]
	for frame in range(4000):
		game._physics_process(1.0/120)
		await physics_frame
		var recovery=game.set_pieces.recovery
		if recovery.phase in ["retrieve","pickup","carry","raise"] and recovery.age>0.3 and not recovery.phase in saved:
			var player=game.players[game.set_pieces.taker]
			game.camera.size=7
			game.camera.position=player.position+Vector3(-4,3,4)
			game.camera.look_at(player.position+Vector3.UP*0.8)
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://tests/recovery-close-"+recovery.phase+".png")
			print("Captured "+recovery.phase)
			saved.append(recovery.phase)
		if game.state=="set_piece": break
	print("RECOVERY VISUAL: %d stages" % saved.size())
	game.free()
	quit(0 if saved.size()==4 else 1)
