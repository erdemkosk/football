extends RefCounted
## Five instanced material groups per pose keep thousands of articulated fans inexpensive.
const G = preload("res://scripts/geometry.gd")
const KitGraphics = preload("res://scripts/kit_graphics.gd")
var rng := RandomNumberGenerator.new()
var fans: Array[Dictionary] = []
var chairs: Array[Transform3D] = []
var chair_colors: Array[Color] = []
var chair_marks: Array[Dictionary] = []
var seat_nodes: Array[MultiMeshInstance3D] = []
var seat_sources: Array[PackedInt32Array] = []
var home_kit := {}
var away_kit := {}
var material := ShaderMaterial.new()
var cloth_material: ShaderMaterial
var prop_materials: Array[ShaderMaterial] = []
var prop_fans: Array[Dictionary] = []
var animation_uniforms: Array[String] = []
var clock := 0.0
var event_age := 100.0
var event_duration := 0.0
var event_kind := ""
var wave_age := 100.0
var wave_cooldown := 0.0
var danger := 0.0
var home_attack := -1.0
var excitement := 0.0
var follow := 0.0
var progress := 0.0
var margin := 0
var home_support := .35
var away_support := .35
var hush := 0.0
var hush_team := 0
var anticipation := 0.0
var surge := 0.0
var event_side := 0
var home_only := false
var session_fill := 1.0
var published: Dictionary = {}
var upload_age := 0.0
var upload_group := 0

static func visiting(position: Vector3) -> bool:
	# Opposite long stand, +z half: the sideline camera actually sees this block.
	return position.x<-18.0 and position.z>12.0

func context(score: Array,time: float,length: float) -> void:
	progress=clampf(time/maxf(1,length),0,1)
	margin=int(score[0])-int(score[1])
	var late := smoothstep(.65,.95,progress)
	home_support=.34+late*(.57 if margin in [-1,0] else (.3 if margin==1 else .05))
	away_support=.34+late*(.57 if margin in [0,1] else (.3 if margin== -1 else .05))
var ball_focus := Vector3.ZERO
var cloth := [Color("23363a"),Color("34434c"),Color("29483f"),Color("4b5554"),Color("647267"),Color("706654"),Color("76524d"),Color("a2a493"),Color("536a79"),Color("393933")]
var skins := [Color("ba9073"),Color("aa7b59"),Color("755340"),Color("c4a18b"),Color("916443")]
var hairs := [Color("302820"),Color("463a2c"),Color("605443"),Color("242828"),Color("807c6c")]

func seat_tint(mark: Dictionary,home: Dictionary={},visitor: Dictionary={}) -> Color:
	if home.is_empty(): home=home_kit
	if visitor.is_empty(): visitor=away_kit
	var away: bool=mark.get("away",false)
	var kit: Dictionary=visitor if away else home
	var primary: Color=kit.get("badge_primary",kit.get("primary",Color("2a4a40") if not away else Color("7a3a34")))
	var accent: Color=kit.get("badge_accent",kit.get("accent",Color("c4b07a") if not away else Color("d8c6a0")))
	# Plastic seats stay darker than shirts so the bowl reads as a mass.
	var base := primary.darkened(0.24).lerp(Color("1a2422"),0.16)
	if base.get_luminance()>0.42: base=base.lerp(Color("1a2422"),0.42)
	var stripe := accent.darkened(0.10).lerp(primary,0.30)
	if stripe.get_luminance()>0.48: stripe=stripe.lerp(Color("1a2422"),0.35)
	var row: int=int(mark.get("row",0))
	var section: int=int(mark.get("section",0))
	if away:
		if row%4==0 or row%4==1: base=stripe.darkened(0.04)
	elif row%6==0:
		base=stripe.darkened(0.08)
	if not away and section%3==1: base=base.darkened(0.08)
	return base.lerp(Color("24302c"),float(mark.get("speck",0.0))*0.14)

func paint_seats(home: Dictionary={},visitor: Dictionary={}) -> void:
	if home.is_empty(): home=home_kit
	if visitor.is_empty(): visitor=away_kit
	for i in range(chair_marks.size()):
		chair_colors[i]=seat_tint(chair_marks[i],home,visitor)
	for batch in range(seat_nodes.size()):
		var multi: MultiMesh=seat_nodes[batch].multimesh
		var sources: PackedInt32Array=seat_sources[batch]
		for i in range(sources.size()):
			multi.set_instance_color(i,chair_colors[sources[i]])

func seat(position: Vector3, angle: float, row: int, section: int) -> void:
	var transform := Transform3D(Basis(Vector3.UP,angle),position)
	var away := visiting(position)
	var mark := {"away":away,"row":row,"section":section,"speck":rng.randf()}
	chairs.append(transform)
	chair_marks.append(mark)
	chair_colors.append(seat_tint(mark))
	# Small contiguous gaps replace a regular checkerboard of occupied seats.
	var occupancy := 0.97 if section%3!=0 else 0.93
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
	seat_material.vertex_color_is_srgb = true
	instances(parent,"Seats",chair.commit(),chairs,chair_colors,[],seat_material)
	material.shader = load("res://shaders/crowd.gdshader")
	cloth_material=material.duplicate()
	cloth_material.set_shader_parameter("club_cloth",true)
	for uniform in material.shader.get_shader_uniform_list():
		if uniform.name not in ["club_cloth","home_color","home_accent","away_color","away_accent"]: animation_uniforms.append(uniform.name)
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
			instances(parent,"Fans_%s_%d" % [part,pose],animated,transforms,colors[part],phases,cloth_material if part=="cloth" else material)
	build_supporter_props(parent)
	reset()
	set_session(false)

func build_supporter_props(parent: Node3D) -> void:
	# Sparse, spatially separated holders; no per-fan processing or dynamic lights.
	var occupied: Dictionary = {}
	var transforms := {"banner":[],"flag":[]}
	var phases := {"banner":[],"flag":[]}
	var colors := {"banner":[],"flag":[]}
	for fan in fans:
		if fan.pose!=3: continue
		var at: Vector3=fan.transform.origin
		var cell := Vector3i(floori(at.x/11.0),floori(at.y/6.0),floori(at.z/11.0))
		if occupied.has(cell): continue
		occupied[cell]=true
		var kind := "flag" if prop_fans.size()%2==0 else "banner"
		if prop_fans.size()>=96: break
		prop_fans.append({"kind":kind,"transform":fan.transform,"phase":fan.phase})
		transforms[kind].append(fan.transform)
		phases[kind].append(fan.phase)
		colors[kind].append(Color.WHITE)
	for kind in ["banner","flag"]:
		var mat := ShaderMaterial.new()
		mat.shader=load("res://shaders/supporter_"+kind+".gdshader")
		mat.set_shader_parameter("supporter_prop",true)
		if kind=="flag": mat.set_shader_parameter("flag_prop",true)
		if kind=="banner": mat.set_shader_parameter("slogan",load("res://assets/branding/supporter-slogan.svg"))
		prop_materials.append(mat)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		if kind=="banner":
			box(surface,Vector3(1.12,.48,.025),Vector3(0,2.065,-.11))
		else:
			cylinder(surface,.018,.018,1.30,Vector3(.25,2.42,-.11))
			surface.deindex()
			# Subdivided fabric bends along the pole and ripples toward its free edge.
			for y in range(6):
				for x in range(12):
					for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
						var uv := Vector2((x+corner.x)/12.0,(y+corner.y)/6.0)
						surface.set_normal(Vector3.FORWARD)
						surface.set_uv(uv)
						surface.add_vertex(Vector3(.27+uv.x*1.35,2.17+uv.y*.88,-.11))
		instances(parent,"Supporter_"+kind,surface.commit(),transforms[kind],colors[kind],phases[kind],mat)

func reset() -> void:
	published.clear(); upload_age=0; upload_group=0
	home_attack=-1.0
	clock = 0
	event_age = 100
	event_duration = 0
	event_kind = ""
	wave_age = 100
	wave_cooldown = 0
	danger = 0
	excitement = 0
	follow = 0
	ball_focus = Vector3.ZERO
	hush=0; hush_team=0; anticipation=0; surge=0; home_support=.35; away_support=.35; progress=0; margin=0
	material.set_shader_parameter("home_support",home_support)
	material.set_shader_parameter("away_support",away_support)
	material.set_shader_parameter("hush",0.0)
	material.set_shader_parameter("hush_team",0.0)
	material.set_shader_parameter("surge",0.0)
	material.set_shader_parameter("danger",0.0)
	material.set_shader_parameter("follow",0.0)
	material.set_shader_parameter("ball_focus",Vector3.ZERO)
	material.set_shader_parameter("event_duration",0.0)
	material.set_shader_parameter("event_strength",0.0)
	material.set_shader_parameter("event_goal",false)
	material.set_shader_parameter("event_entrance",false)
	material.set_shader_parameter("event_style",0)
	material.set_shader_parameter("event_age",event_age)
	material.set_shader_parameter("wave_age",wave_age)
	material.set_shader_parameter("crowd_time",clock)
	sync_cloth()

func set_clubs(home: Dictionary,away: Dictionary) -> void:
	home_kit=home; away_kit=away
	for pair in [["home",home],["away",away]]:
		cloth_material.set_shader_parameter(pair[0]+"_color",pair[1].badge_primary)
		cloth_material.set_shader_parameter(pair[0]+"_accent",pair[1].badge_accent)
		for prop in prop_materials:
			prop.set_shader_parameter(pair[0]+"_color",pair[1].badge_primary)
			prop.set_shader_parameter(pair[0]+"_accent",pair[1].badge_accent)
			if prop.get_shader_parameter("flag_prop")==true:
				prop.set_shader_parameter(pair[0]+"_badge",KitGraphics.badge(int(pair[1].get("club_id",0)),pair[1].badge_primary,pair[1].badge_accent))
	paint_seats(home,home if home_only else away)

func set_session(practice: bool) -> void:
	home_only=practice
	session_fill=0.08 if practice else 1.0
	for mat in [material,cloth_material]+prop_materials:
		if mat==null: continue
		mat.set_shader_parameter("home_only",home_only)
		mat.set_shader_parameter("occupancy",session_fill)
	if not home_kit.is_empty(): paint_seats(home_kit,home_kit if practice else away_kit)

func sync_cloth() -> void:
	if cloth_material==null: return
	for key in animation_uniforms:
		var value: Variant=material.get_shader_parameter(key)
		publish(key,value)

func publish(key: String,value: Variant) -> void:
	if published.has(key) and published[key]==value: return
	published[key]=value
	material.set_shader_parameter(key,value)
	if cloth_material!=null: cloth_material.set_shader_parameter(key,value)
	if key in ["supporter_prop","flag_prop"]: return
	for prop in prop_materials: prop.set_shader_parameter(key,value)

func react(kind: String,team: int,location: Vector3) -> void:
	# A pass or save must not cut off an ongoing goal celebration.
	if event_kind=="goal" and event_age<event_duration and kind!="goal": return
	if kind=="shot" and event_kind=="shot" and event_age<0.35: return
	if kind=="tackle" and event_age<1.0: return
	event_kind = kind
	event_side=team
	event_age = 0
	event_duration = {"entrance":6.0,"goal":19.0,"shot":3.8,"save":4.5,"miss":3.5,"tackle":2.8}.get(kind,2.5)
	material.set_shader_parameter("event_style",{"shot":1,"save":2,"miss":3,"tackle":4}.get(kind,0))
	material.set_shader_parameter("event_team",float(team))
	material.set_shader_parameter("event_goal",kind=="goal")
	material.set_shader_parameter("event_entrance",kind=="entrance")
	var significance := 1.0
	if kind=="goal" and progress>.8 and abs(margin)<=1: significance=1.3
	material.set_shader_parameter("event_strength",significance if kind in ["goal","save"] else (0.9 if kind=="shot" else 0.75))
	material.set_shader_parameter("event_duration",event_duration)
	material.set_shader_parameter("event_age",0.0)
	hush_team=team if kind=="miss" else (1-team if kind=="goal" else 0)
	material.set_shader_parameter("hush_team",float(hush_team))
	if kind=="goal" and team==0: start_wave(location,3.5)
	sync_cloth()

func start_wave(location: Vector3,delay: float = 0.35) -> void:
	if wave_cooldown>0: return
	wave_age = -delay
	wave_cooldown = 22
	material.set_shader_parameter("wave_origin",fposmod(atan2(location.z/60,location.x/45)/TAU,1.0))
	material.set_shader_parameter("wave_age",wave_age)
	sync_cloth()

func update(delta: float,ball_position: Vector3,ball_velocity: Vector3,team: int,playing: bool,late_close_match: bool) -> void:
	clock += delta
	var silence: float=1.0 if event_kind=="goal" and event_age<2.8 else (.55 if event_kind=="miss" and event_age<1.4 else 0.0)
	silence=maxf(silence,anticipation*0.55)
	hush=move_toward(hush,silence,delta*(3 if silence>hush else .65))
	event_age += delta
	wave_age += delta
	wave_cooldown = maxf(0,wave_cooldown-delta)
	var forward := home_attack if team==0 else -home_attack
	var target := 0.0
	if playing and ball_position.z*forward>8:
		var depth := clampf((ball_position.z*forward-8.0)/34.0,0,1)
		var width := 1.0-smoothstep(18.0,34.0,absf(ball_position.x))*0.32
		target=depth*width
		if ball_position.z*forward>28 and absf(ball_position.x)<24:
			target=maxf(target,clampf((ball_position.z*forward-28)/19,0,1))
		if ball_velocity.z*forward< -3: target*=0.35
	danger = lerpf(danger,target,1-exp(-delta*(3.5 if target>danger else 1.3)))
	var home_push: float=danger if team==0 else 0.0
	surge=lerpf(surge,home_push,1-exp(-delta*(3.2 if home_push>surge else 1.4)))
	if playing and late_close_match and team==0 and danger>0.65 and event_age>3:
		start_wave(ball_position)
	excitement = maxf(danger*0.55,(1.0 if event_kind=="goal" else 0.82)*clampf((event_duration-event_age)/1.5,0,1))
	ball_focus=ball_position
	follow=lerpf(follow,0.78 if playing else 0.08,1-exp(-delta*2.4))
	# Animation clocks remain smooth. Slow atmosphere uploads alternate groups;
	# event changes bypass this schedule and reach every material immediately.
	publish("crowd_time",clock)
	publish("event_age",event_age)
	publish("wave_age",wave_age)
	upload_age+=delta
	if upload_age<1.0/30.0: return
	upload_age=fmod(upload_age,1.0/30.0)
	if upload_group==0:
		publish("danger",danger)
		publish("danger_team",float(team))
		publish("follow",follow)
		publish("ball_focus",ball_focus)
	else:
		publish("home_support",home_support)
		publish("away_support",away_support)
		publish("surge",surge)
		publish("hush",hush)
		publish("hush_team",float(hush_team))
	upload_group=1-upload_group

func follow_weight(perimeter: float) -> float:
	var azimuth := fposmod(atan2(ball_focus.z/60.0,ball_focus.x/45.0)/TAU,1.0)
	var around := minf(absf(perimeter-azimuth),1.0-absf(perimeter-azimuth))
	return follow*(1.0-smoothstep(0.04,0.22,around))

func instances(parent: Node3D,label: String,mesh: Mesh,transforms: Array,colors: Array,phases: Array,mat: Material) -> void:
	# A stadium-wide MultiMesh draws every fan even when only one stand is visible.
	# Local batches keep every seat and animation, while enabling frustum culling.
	var sections: Dictionary = {}
	for i in range(transforms.size()):
		var at: Vector3=transforms[i].origin
		var cell := Vector2i(floori(at.x/20.0),floori(at.z/20.0))
		if not sections.has(cell): sections[cell]=[]
		sections[cell].append(i)
	mesh.surface_set_material(0,mat)
	var section := 0
	for indices in sections.values():
		instance_section(parent,label if section==0 else "%s_sector%d" % [label,section],mesh,transforms,colors,phases,indices)
		section+=1

func instance_section(parent: Node3D,label: String,mesh: Mesh,transforms: Array,colors: Array,phases: Array,indices: Array) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = not phases.is_empty()
	multi.mesh = mesh
	multi.instance_count = indices.size()
	for i in range(indices.size()):
		var source: int=indices[i]
		multi.set_instance_transform(i,transforms[source])
		multi.set_instance_color(i,colors[source])
		if not phases.is_empty(): multi.set_instance_custom_data(i,phases[source])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not phases.is_empty(): node.extra_cull_margin=0.8
	if label.begins_with("Supporter_flag"): node.extra_cull_margin=1.2
	parent.add_child(node)
	if label.begins_with("Seats"):
		seat_nodes.append(node)
		var packed := PackedInt32Array()
		for source in indices: packed.append(source)
		seat_sources.append(packed)

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
