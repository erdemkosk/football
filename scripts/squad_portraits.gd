extends Node
## One small photo studio, reused on demand; match rendering never pays for portraits.
signal portrait_ready(key: String)
const Footballer = preload("res://scripts/footballer.gd")
var cache: Dictionary = {}
var pending: Dictionary = {}
var studio: SubViewport
var model
var current := ""
var frames := 0

func key_for(data: Dictionary) -> String:
	return "%s/%d/%d/%d/%d/%s/%s/%d" % [data.name,data.shirt,data.get("appearance_id",data.get("appearance_number",data.shirt)),data.height_cm,data.weight_kg,data.kit.primary.to_html(),data.kit.accent.to_html(),data.kit.get("club_id",0)]

func request(data: Dictionary) -> String:
	var key := key_for(data)
	if not cache.has(key) and key!=current: pending[key]=data.duplicate(true)
	return key

func photo(data: Dictionary) -> Texture2D:
	return cache.get(key_for(data))

func _process(_delta: float) -> void:
	if DisplayServer.get_name()=="headless" or not get_parent().visible or get_parent().stage!="tactics":
		if studio!=null: studio.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	if studio!=null:
		studio.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		frames+=1
		if frames<3: return
		var picture := studio.get_texture().get_image()
		if not picture.is_empty():
			picture.generate_mipmaps()
			cache[current]=ImageTexture.create_from_image(picture)
			if cache.size()>72: cache.erase(cache.keys()[0])
			portrait_ready.emit(current)
		studio.queue_free(); studio=null; model=null; current=""
		return
	if pending.is_empty(): return
	current=pending.keys()[0]
	var data: Dictionary=pending[current]
	pending.erase(current)
	build_studio(data)
	frames=0

func build_studio(data: Dictionary) -> void:
	studio=SubViewport.new()
	studio.size=Vector2i(256,256)
	studio.transparent_bg=true
	studio.own_world_3d=true
	studio.msaa_3d=Viewport.MSAA_4X
	studio.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(studio)
	var world := Node3D.new(); studio.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0,0,0,0)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("e7eee4")
	environment.environment.ambient_light_energy=0.72
	world.add_child(environment)
	for i in range(2):
		var light := DirectionalLight3D.new()
		light.rotation_degrees=Vector3(-25,-30 if i==0 else 125,0)
		light.light_energy=1.5 if i==0 else 0.7
		light.light_color=Color("fff1d6") if i==0 else Color("bddeeb")
		world.add_child(light)
	model=Footballer.new()
	model.number=data.get("appearance_number",data.shirt)
	model.keeper=data.keeper
	world.add_child(model)
	model.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	model.apply_identity(data)
	model.apply_kit(data.kit)
	model.collision_layer=0; model.collision_mask=0
	model.marker.visible=false; model.call_label.visible=false
	model.animate(0)
	model.rig.rotation.y=-0.12 if int(data.shirt)%2==0 else 0.12
	model.head_joint.rotation.y=-model.rig.rotation.y*0.6
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.50*model.WORLD_SCALE
	world.add_child(camera)
	var center: float=model.head_joint.global_position.y+.04
	camera.position=Vector3(0,center,-5)
	camera.look_at(Vector3(0,center,0))
	camera.current=true
