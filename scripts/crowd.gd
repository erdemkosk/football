extends RefCounted
## Five instanced material groups per pose keep thousands of articulated fans inexpensive.
const G = preload("res://scripts/geometry.gd")
var rng := RandomNumberGenerator.new()
var fans: Array[Dictionary] = []
var chairs: Array[Transform3D] = []
var chair_colors: Array[Color] = []
var material := ShaderMaterial.new()
var clock := 0.0
var event_age := 100.0
var event_duration := 0.0
var event_kind := ""
var wave_age := 100.0
var wave_cooldown := 0.0
var danger := 0.0
var excitement := 0.0
var cloth := [Color("23363a"),Color("34434c"),Color("29483f"),Color("4b5554"),Color("647267"),Color("706654"),Color("76524d"),Color("a2a493"),Color("536a79"),Color("393933")]
var skins := [Color("ba9073"),Color("aa7b59"),Color("755340"),Color("c4a18b"),Color("916443")]
var hairs := [Color("302820"),Color("463a2c"),Color("605443"),Color("242828"),Color("807c6c")]

func seat(position: Vector3, angle: float, row: int, section: int) -> void:
	var transform := Transform3D(Basis(Vector3.UP,angle),position)
	chairs.append(transform)
	chair_colors.append(Color("324b44").lerp(Color("485550"),rng.randf()*0.32))
	# Small contiguous gaps replace a regular checkerboard of occupied seats.
	var occupancy := 0.94 if section%3!=0 else 0.85
	if rng.randf()>occupancy: return
	var pose := 0
	var random := rng.randf()
	if random>0.88: pose = 3
	elif random>0.70: pose = 2
	elif random>0.47: pose = 1
	var scale_value := rng.randf_range(0.90,1.08)
	var person := Transform3D(Basis(Vector3.UP,angle+rng.randf_range(-0.13,0.13)).scaled(Vector3(rng.randf_range(0.91,1.10),scale_value,1)),position+Vector3(rng.randf_range(-0.07,0.07),0,rng.randf_range(-0.07,0.07)))
	var shirt: Color = cloth[rng.randi()%cloth.size()]
	if section%4==0 and rng.randf()>0.55: shirt = Color("31584b")
	var away := position.x>38 and position.z>25
	if away: shirt = Color("88584f").lerp(shirt,0.45)
	var perimeter := fposmod(atan2(position.z/60,position.x/45)/TAU,1.0)
	fans.append({"transform":person,"pose":pose,"cloth":shirt.darkened(rng.randf()*0.13),"skin":skins[rng.randi()%skins.size()],"hair":hairs[rng.randi()%hairs.size()],"pants":Color("293234").lerp(Color("4f5450"),rng.randf()*0.65),"phase":Color(rng.randf(),(0.5 if away else 0.0)+rng.randf()*0.49,float(row)/12,perimeter)})

func build(parent: Node3D) -> void:
	var chair := SurfaceTool.new()
	chair.begin(Mesh.PRIMITIVE_TRIANGLES)
	box(chair,Vector3(0.49,0.09,0.45),Vector3(0,0.44,0))
	box(chair,Vector3(0.49,0.45,0.085),Vector3(0,0.66,0.19))
	var seat_material := G.material(Color("a0aba3"))
	seat_material.vertex_color_use_as_albedo = true
	instances(parent,"Seats",chair.commit(),chairs,chair_colors,[],seat_material)
	material.shader = load("res://shaders/crowd.gdshader")
	var cheering := person_meshes(3)
	for pose in range(4):
		var model := person_meshes(pose)
		var transforms: Array[Transform3D] = []
		var colors: Dictionary = {"cloth":[],"skin":[],"hair":[],"pants":[],"shoes":[]}
		var phases: Array[Color] = []
		for fan in fans:
			if fan.pose!=pose: continue
			transforms.append(fan.transform)
			phases.append(fan.phase)
			for part in ["cloth","skin","hair","pants"]: colors[part].append(fan[part])
			colors.shoes.append(Color("202825"))
		for part in model:
			# UV channels carry a matching raised-arm pose, blended on the GPU.
			var arrays: Array = model[part].surface_get_arrays(0)
			var target: PackedVector3Array = cheering[part].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var xy := PackedVector2Array()
			var z := PackedVector2Array()
			for i in range(vertices.size()):
				var offset := target[i]-vertices[i]
				xy.append(Vector2(offset.x,offset.y))
				z.append(Vector2(offset.z,0))
			arrays[Mesh.ARRAY_TEX_UV] = xy
			arrays[Mesh.ARRAY_TEX_UV2] = z
			var animated := ArrayMesh.new()
			animated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			instances(parent,"Fans_%s_%d" % [part,pose],animated,transforms,colors[part],phases,material)
	reset()

func reset() -> void:
	clock = 0
	event_age = 100
	event_duration = 0
	event_kind = ""
	wave_age = 100
	wave_cooldown = 0
	danger = 0
	excitement = 0
	material.set_shader_parameter("danger",0.0)
	material.set_shader_parameter("event_duration",0.0)
	material.set_shader_parameter("event_age",event_age)
	material.set_shader_parameter("wave_age",wave_age)
	material.set_shader_parameter("crowd_time",clock)

func react(kind: String,team: int,location: Vector3) -> void:
	# A pass or save must not cut off an ongoing goal celebration.
	if event_kind=="goal" and event_age<event_duration and kind!="goal": return
	if kind=="shot" and event_age<1.2: return
	event_kind = kind
	event_age = 0
	event_duration = 6.0 if kind=="entrance" else (12.0 if kind=="goal" else (2.6 if kind=="save" else 1.8))
	material.set_shader_parameter("event_team",float(team))
	material.set_shader_parameter("event_goal",kind=="goal")
	material.set_shader_parameter("event_entrance",kind=="entrance")
	material.set_shader_parameter("event_strength",1.0 if kind=="goal" else (0.8 if kind=="save" else 0.48))
	material.set_shader_parameter("event_duration",event_duration)
	material.set_shader_parameter("event_age",0.0)
	if kind=="goal" and team==0: start_wave(location,3.5)

func start_wave(location: Vector3,delay: float = 0.35) -> void:
	if wave_cooldown>0: return
	wave_age = -delay
	wave_cooldown = 22
	material.set_shader_parameter("wave_origin",fposmod(atan2(location.z/60,location.x/45)/TAU,1.0))
	material.set_shader_parameter("wave_age",wave_age)

func update(delta: float,ball_position: Vector3,ball_velocity: Vector3,team: int,playing: bool,late_close_match: bool) -> void:
	clock += delta
	event_age += delta
	wave_age += delta
	wave_cooldown = maxf(0,wave_cooldown-delta)
	var forward := -1.0 if team==0 else 1.0
	var target := 0.0
	if playing and ball_position.z*forward>28 and absf(ball_position.x)<24:
		target = clampf((ball_position.z*forward-28)/19,0,1)
		if ball_velocity.z*forward< -3: target *= 0.25
	danger = lerpf(danger,target,1-exp(-delta*(3.5 if target>danger else 1.3)))
	if playing and late_close_match and team==0 and danger>0.65 and event_age>3:
		start_wave(ball_position)
	excitement = maxf(danger*0.55,(1.0 if event_kind=="goal" else 0.55)*clampf((event_duration-event_age)/1.5,0,1))
	material.set_shader_parameter("crowd_time",clock)
	material.set_shader_parameter("event_age",event_age)
	material.set_shader_parameter("wave_age",wave_age)
	material.set_shader_parameter("danger",danger)
	material.set_shader_parameter("danger_team",float(team))

func instances(parent: Node3D,label: String,mesh: Mesh,transforms: Array,colors: Array,phases: Array,mat: Material) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = not phases.is_empty()
	multi.mesh = mesh
	mesh.surface_set_material(0,mat)
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i,transforms[i])
		multi.set_instance_color(i,colors[i])
		if not phases.is_empty(): multi.set_instance_custom_data(i,phases[i])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

func person_meshes(pose: int) -> Dictionary:
	var tools: Dictionary = {}
	for name in ["cloth","skin","hair","pants","shoes"]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[name] = surface
	var standing := pose>=2
	var hip := 0.84 if standing else 0.58
	var chest := hip+0.31
	var head := hip+0.76
	cylinder(tools.cloth,0.175,0.235,0.46,Vector3(0,chest,0))
	ellipsoid(tools.skin,Vector3(0.14,0.17,0.145),Vector3(0,head,-0.015))
	ellipsoid(tools.hair,Vector3(0.145,0.10,0.149),Vector3(0,head+0.09,0.015))
	cylinder(tools.skin,0.074,0.074,0.11,Vector3(0,head-0.18,0))
	ellipsoid(tools.skin,Vector3(0.037,0.045,0.04),Vector3(0,head,-0.15))
	cylinder(tools.pants,0.17,0.17,0.18,Vector3(0,hip,0))
	for side in [-1,1]:
		var knee := Vector3(side*0.13,0.44,-0.32) if not standing else Vector3(side*0.13,0.43,0)
		var ankle := Vector3(side*0.15,0.12,-0.29) if not standing else Vector3(side*0.14,0.12,-0.025)
		rod(tools.pants,Vector3(side*0.12,hip,0),knee,0.085)
		rod(tools.pants,knee,ankle,0.072)
		ellipsoid(tools.shoes,Vector3(0.084,0.065,0.15),ankle+Vector3(0,-0.04,-0.06))
		var shoulder := Vector3(side*0.215,chest+0.16,0)
		var elbow := Vector3(side*0.28,chest-0.10,-0.08)
		var hand := Vector3(side*0.17,chest-0.31,-0.28)
		if pose==1:
			elbow = Vector3(side*0.27,chest-0.11,-0.12)
			hand = Vector3(side*0.07,chest+0.06,-0.33)
		elif pose==2:
			hand = Vector3(side*0.27,chest-0.39,-0.025)
		elif pose==3:
			elbow = Vector3(side*0.36,chest+0.42,-0.045)
			hand = Vector3(side*0.25,chest+0.68,-0.11)
		rod(tools.cloth,shoulder,shoulder.lerp(elbow,0.60),0.094)
		rod(tools.skin,shoulder.lerp(elbow,0.60),elbow,0.064)
		rod(tools.skin,elbow,hand,0.059)
		ellipsoid(tools.skin,Vector3(0.065,0.075,0.058),hand)
	var meshes: Dictionary = {}
	for part in tools: meshes[part] = tools[part].commit()
	return meshes

func box(surface: SurfaceTool,size: Vector3,p: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	surface.append_from(mesh,0,Transform3D(Basis.IDENTITY,p))

func cylinder(surface: SurfaceTool,bottom: float,top: float,height: float,p: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 8
	surface.append_from(mesh,0,Transform3D(Basis.IDENTITY,p))

func ellipsoid(surface: SurfaceTool,size: Vector3,p: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 8
	mesh.rings = 4
	surface.append_from(mesh,0,Transform3D(Basis.IDENTITY.scaled(size),p))

func rod(surface: SurfaceTool,a: Vector3,b: Vector3,radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius*0.91
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	var direction := (b-a).normalized()
	var axis := Vector3.UP.cross(direction)
	var basis := Basis.IDENTITY
	if axis.length()>0.001: basis = Basis(axis.normalized(),acos(clampf(Vector3.UP.dot(direction),-1,1)))
	surface.append_from(mesh,0,Transform3D(basis,(a+b)*0.5))
