extends SceneTree
var actors: Array=[]
var failures:=0
func _initialize() -> void: call_deferred("run")
func capture(enabled: bool,label: String) -> Image:
	for actor in actors: actor.render_batch.set_active(enabled)
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image()
	result.save_png("res://tests/batch-visual-"+label+"-"+("after" if enabled else "before")+".png")
	return result
func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720)); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world:=Node3D.new(); root.add_child(world)
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(.12,.16,.21)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=.4
	world.add_child(environment)
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-25,0); light.shadow_enabled=true; world.add_child(light)
	var floor_mesh:=PlaneMesh.new(); floor_mesh.size=Vector2(30,30)
	var floor:=MeshInstance3D.new(); floor.mesh=floor_mesh; floor.material_override=load("res://scripts/geometry.gd").material(Color(.08,.19,.10)); world.add_child(floor)
	for i in range(4):
		var player=load("res://scripts/footballer.gd").new()
		player.keeper=i==0; player.official=i==3; player.team=i%2; player.number=5+i
		world.add_child(player); player.marker.hide(); player.call_label.hide()
		player.position=Vector3(-2.7+i*1.8,0,0); player.height_cm=166+i*10; player.weight_kg=61+i*9; player.apply_build()
		player.run_phase=i*.7; player.velocity=Vector3(3,0,2); player.animate(.02)
		player.rig.rotation.y=-.3+i*.2; player.set_captain(i==1); actors.append(player)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(3,2.5,-7); camera.look_at(Vector3(0,1,0)); camera.fov=48
	for weather in ["dry","wet"]:
		for actor in actors:
			actor.kit_soil=.6 if weather=="wet" else 0.0; actor.update_soil(1 if weather=="wet" else 0)
		var a:=await capture(false,weather); var b:=await capture(true,weather)
		var first:=a.get_data(); var second:=b.get_data()
		var changed:=0; var major:=0; var total:=0.0; var worst:=0
		for i in range(first.size()):
			var delta:=absi(int(first[i])-int(second[i])); worst=maxi(worst,delta); total+=delta
			if delta>0: changed+=1
			if delta>16: major+=1
		var mean:=total/first.size(); var fraction:=float(major)/first.size()
		print("VISUAL ",weather," mean_channel_error=",mean," changed_fraction=",float(changed)/first.size()," large_error_fraction=",fraction," max=",worst)
		if mean>.25 or fraction>.001: failures+=1
	print("BATCH VISUAL failures=",failures)
	world.free(); quit(0 if failures==0 else 1)
