extends SubViewportContainer
signal motion_finished
var player: CharacterBody3D
var viewport: SubViewport
var age := 0.0
var performing := false
var chosen := false
var motion_left := 0.0

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
	player.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	player.collision_layer=0; player.collision_mask=0
	player.marker.visible=false
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.9*player.WORLD_SCALE
	world.add_child(camera)
	camera.position=Vector3(0,1.3*player.WORLD_SCALE,-7)
	camera.look_at(Vector3(0,1.13*player.WORLD_SCALE,0))
	camera.current=true
	stand_idle()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	age+=delta
	if player==null: return
	player.motion_clock+=delta
	if performing:
		player.velocity=player.desired
		player.run_phase+=player.velocity.length()*delta*player.gait_cadence
		player.animate(delta)
		if player.facing.length()>0.1:
			player.rig.rotation.y=lerp_angle(player.rig.rotation.y,atan2(-player.facing.x,-player.facing.z),1-exp(-delta*8))
		motion_left=maxf(0,motion_left-delta)
		if motion_left<=0:
			if chosen:
				hold_selected()
			else:
				stand_idle()
			motion_finished.emit()
	elif chosen:
		player.velocity=Vector3.ZERO
		player.desired=Vector3.ZERO
		player.call_timer=1.0
		player.animate(delta)
	else:
		player.velocity=Vector3.ZERO
		player.desired=Vector3.ZERO
		player.animate(delta)
		player.rig.rotation.y=sin(age*0.45)*0.15+0.15

func show_kit(colors: Dictionary,side: int) -> void:
	player.team=side
	player.apply_kit(colors)

func stand_idle() -> void:
	performing=false
	chosen=false
	motion_left=0
	if player==null: return
	player.desired=Vector3.ZERO
	player.velocity=Vector3.ZERO
	player.saluting=false
	player.celebration=""
	player.protecting=false
	player.call_timer=0
	player.idle_rest=0
	player.idle_habit=0

func hold_selected() -> void:
	chosen=true
	performing=false
	motion_left=0
	if player==null: return
	player.desired=Vector3.ZERO
	player.velocity=Vector3.ZERO
	player.call_timer=1.0
	player.facing=Vector3(0.12,0,-1).normalized()

func play_select() -> void:
	if player==null: return
	chosen=true
	performing=true
	motion_left=0.95
	player.desired=Vector3.ZERO
	player.velocity=Vector3.ZERO
	player.celebration=""
	player.saluting=false
	player.call_timer=1.2
	player.facing=Vector3(0.12,0,-1).normalized()

func play_motion(side: int=0) -> void:
	if player==null: return
	stand_idle()
	performing=true
	motion_left=1.35
	var heading := Vector3(0.75 if side==0 else -0.75,0,-0.65).normalized()
	player.desired=heading*4.4
	player.velocity=player.desired
	player.facing=heading
