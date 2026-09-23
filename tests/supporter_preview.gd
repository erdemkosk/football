extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(true)
	game.set_process(false)
	game.set_physics_process(false)
	game.ball.freeze=true
	game.hud.hide()
	game.frontend.hide()
	game.stadium.light_rig.select(1)
	var crowd=game.stadium.crowd
	var flags := 0
	var banners := 0
	for fan in crowd.prop_fans:
		if fan.kind=="flag": flags+=1
		else: banners+=1
	print("SUPPORTER PROPS: ",flags," flags, ",banners," banners / ",crowd.fans.size()," fans")
	assert(flags==banners and flags>0 and crowd.prop_fans.size()<=96)
	assert(game.stadium.find_children("Supporter_flare*","",false,false).is_empty())
	assert(game.stadium.find_children("Supporter_smoke*","",false,false).is_empty())
	for mat in crowd.prop_materials: assert(mat.get_shader_parameter("supporter_prop")==true)
	var holder: Transform3D=crowd.prop_fans[0].transform
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size=16
	game.camera.position=holder.origin+holder.basis*Vector3(0,4,-15)
	game.camera.look_at(holder.origin+Vector3(0,1.6,0))
	crowd.update(.5,Vector3.ZERO,Vector3.ZERO,0,false,false)
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/supporter-preview.png")
	# Capture a second simulation time to inspect waving fabric.
	for i in range(144): crowd.update(1.0/120.0,Vector3.ZERO,Vector3.ZERO,0,false,false)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/supporter-preview-moving.png")
	game.free()
	quit()
