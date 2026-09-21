extends SubViewportContainer
var player: CharacterBody3D
var viewport: SubViewport
var age := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	stretch=true
	viewport=SubViewport.new()
	viewport.size=Vector2i(size)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(0,0,0,0)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("c9e6ed")
	env.environment.ambient_light_energy=0.65
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-30,-35,0)
	light.light_energy=1.8
	world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-20,140,0)
	fill.light_color=Color("a6ccc8")
	fill.light_energy=0.7
	world.add_child(fill)
	player=preload("res://scripts/footballer.gd").new()
	player.number=10
	world.add_child(player)
	player.collision_layer=0; player.collision_mask=0
	player.marker.visible=false
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.9
	world.add_child(camera)
	camera.position=Vector3(0,1.3,-7)
	camera.look_at(Vector3(0,1.13,0))
	camera.current=true

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	age+=delta
	player.animate(delta)
	player.rig.rotation.y=sin(age*0.45)*0.15+0.15

func show_kit(colors: Dictionary,side: int) -> void:
	player.team=side
	player.apply_kit(colors)
