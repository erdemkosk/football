extends SceneTree
func _initialize() -> void: call_deferred("run")
func render_material(material: ShaderMaterial,shader: Shader,wetness: float) -> Image:
	material.shader=shader
	material.set_shader_parameter("half_pitch",Vector2(36,50))
	material.set_shader_parameter("wetness",wetness)
	material.set_shader_parameter("play_wear",.4)
	material.set_shader_parameter("rain",1.0 if wetness>0 else 0.0)
	material.set_shader_parameter("weather_clock",4.3)
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=Vector2i(720,600)
	var world:=Node3D.new(); root.add_child(world)
	var plane:=MeshInstance3D.new(); var shape:=PlaneMesh.new(); shape.size=Vector2(88,112); plane.mesh=shape
	var material:=ShaderMaterial.new(); plane.material_override=material; world.add_child(plane)
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-48,-28,0); world.add_child(light)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(40,55,30); camera.look_at(Vector3.ZERO)
	var old:=load("res://tests/grass_wet_before.gdshader"); var revised:=load("res://shaders/grass.gdshader")
	var a:=await render_material(material,old,0.0); var b:=await render_material(material,revised,0.0)
	var source:=a.get_data(); var result:=b.get_data(); var maximum:=0; var total:=0.0
	for i in range(source.size()):
		var delta:=absi(int(source[i])-int(result[i])); maximum=maxi(maximum,delta); total+=delta
	var mean:=total/source.size()
	print("DRY SHADER mean_channel_error=",mean," max=",maximum)
	var failed:=maximum>1 or mean>.001
	for wet in [.01,.25,.55,1.0]:
		var rendered:=await render_material(material,revised,wet)
		if rendered.is_empty(): failed=true
		print("WET SHADER rendered wetness=",wet," size=",rendered.get_size())
	print("WET TURF SHADER CHECK failures=",1 if failed else 0)
	world.free(); quit(1 if failed else 0)
