extends "res://tests/fps_bottleneck.gd"
var skins: Array=[]
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="res://tests/performance-settings.tmp"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	prepare(); game.stadium.light_rig.select(1)
	for p in game.players+game.referees.actors:
		skins.append(p.render_batch)
	print("BATCH sources=",skins[0].sources.size()," draws=",skins[0].batches.size()," joints=",skins[0].joints.size())
	for trial in range(2):
		for enabled in ([false,true] if trial==0 else [true,false]):
			for skin in skins: skin.set_active(enabled)
			await measure("STATIC batch="+str(enabled)+" trial="+str(trial))
	game.set_process(true); game.set_physics_process(true); game.ball.freeze=false
	for trial in range(2):
		for enabled in ([false,true] if trial==0 else [true,false]):
			for skin in skins: skin.set_active(enabled)
			await measure("LIVE batch="+str(enabled)+" trial="+str(trial))
	game.set_process(false); game.set_physics_process(false); game.ball.freeze=true
	game.camera.position=Vector3(3,2,5); game.camera.look_at(game.players[20].position+Vector3.UP)
	for enabled in [false,true]:
		for skin in skins: skin.set_active(enabled)
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/batch-"+str(enabled)+".png")
	game.free(); quit()
