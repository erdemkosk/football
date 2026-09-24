extends Node
## One bounded, independent scene. No stadium shadows or full match simulation in menus.
const Footballer=preload("res://scripts/footballer.gd")
var viewport: SubViewport
var actor
var scene: Node3D
var elapsed:=0.0
var identity:=""
var hero_label:="KAPTAN"
var hero_name:=""

func hero(s) -> String:
	var c=s.game.career; var ids: Array=c.club().roster
	var newcomers: Array=ids.filter(func(id): return c.player(id).get("arrival",{}).get("club","")==c.world.user and not c.player(id).arrival.get("debut",true))
	var chosen: String=""
	if not newcomers.is_empty():
		newcomers.sort_custom(func(a,b): return c.player(a).arrival.day>c.player(b).arrival.day)
		chosen=newcomers[0]; hero_label="YENİ TRANSFER"
	else:
		chosen=c.club().lineup[0]
		for id in c.club().lineup:
			if c.player(id).shirt==6: chosen=id; break
		hero_label="KAPTAN"
	hero_name=c.player(chosen).name
	return chosen

func configure(data: Dictionary) -> void:
	var key: String=data.name+str(data.get("club",""))
	if identity==key: return
	identity=key
	if viewport==null: build()
	if actor!=null: actor.free()
	actor=Footballer.new(); actor.number=data.get("appearance_number",data.shirt); actor.keeper=data.keeper
	scene.add_child(actor); actor.apply_identity(data); actor.apply_kit(data.kit)
	var tint: Color=preload("res://scripts/ui_style.gd").club_tint(data.kit)
	for light in scene.get_children():
		if light is DirectionalLight3D and light.light_energy<1: light.light_color=tint.lightened(.45)
	actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	actor.collision_layer=0; actor.collision_mask=0; actor.marker.hide(); actor.call_label.hide()
	actor.position=Vector3(-1.35,0,0); actor.rotation.y=.15; actor.animate(0)

func material(color: Color,emission: bool=false) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=.8
	if emission: m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func block(at: Vector3,dimensions: Vector3,color: Color,glow: bool=false) -> void:
	var mesh:=MeshInstance3D.new(); var shape:=BoxMesh.new(); shape.size=dimensions
	mesh.mesh=shape; mesh.material_override=material(color,glow); mesh.position=at; scene.add_child(mesh)

func build() -> void:
	viewport=SubViewport.new(); viewport.size=Vector2i(1040,570); viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X; add_child(viewport)
	scene=Node3D.new(); viewport.add_child(scene)
	var env:=WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("0b1424")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color("aabfd6"); env.environment.ambient_light_energy=.65
	scene.add_child(env)
	for i in range(2):
		var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-28,-20 if i==0 else 135,0)
		light.light_color=Color("fff2d7") if i==0 else Color("88ceeb"); light.light_energy=1.35 if i==0 else .8; scene.add_child(light)
	block(Vector3(0,-.1,0),Vector3(50,.2,50),Color("183c3c"))
	var seats:=MultiMeshInstance3D.new(); var batch:=MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D; batch.use_colors=true
	var seat_mesh:=BoxMesh.new(); seat_mesh.size=Vector3(.55,.25,.38)
	batch.mesh=seat_mesh; batch.instance_count=13*28
	seats.multimesh=batch
	var seat_material:=material(Color.WHITE); seat_material.vertex_color_use_as_albedo=true
	seats.material_override=seat_material; scene.add_child(seats)
	for i in range(13):
		block(Vector3(0,.35+i*.4,6+i*.43),Vector3(35,.15,.6),Color("17232f") if i%2==0 else Color("1c2c3a"))
		for j in range(28):
			batch.set_instance_transform(i*28+j,Transform3D(Basis.IDENTITY,Vector3(-14+j*1.0,.53+i*.4,6+i*.43)))
			batch.set_instance_color(i*28+j,Color("253b4a") if (i+j)%3 else Color("304a57"))
	for x in [-11.0,-6.0,0.0,6.0,11.0]:
		block(Vector3(x,6.4,10),Vector3(3.1,.16,.14),Color("d0f3e7"),true)
	block(Vector3(0,.006,2.7),Vector3(25,.016,.045),Color("9fbbaa"))
	block(Vector3(0,.008,-.8),Vector3(.05,.02,9),Color("9fbbaa"))
	var ball:=MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=.12; sphere.height=.24
	ball.mesh=sphere; ball.material_override=material(Color("eee7ce")); ball.position=Vector3(-.94,.12,-.4); scene.add_child(ball)
	var cam:=Camera3D.new(); scene.add_child(cam); cam.position=Vector3(0,1.5,-4.2); cam.look_at(Vector3(0,1.15,0)); cam.fov=37; cam.current=true

func _process(delta: float) -> void:
	if viewport==null: return
	var active: bool=get_parent().visible and get_parent().page=="hub"
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active or actor==null: return
	elapsed+=delta
	if get_parent().game.experience.reduce_motion: return
	actor.rig.rotation.z=sin(elapsed*.85)*.014
	actor.head_joint.rotation.y=sin(elapsed*.45)*.13
	actor.left_arm.rotation.z=-.12+sin(elapsed)*.015
	actor.right_arm.rotation.z=.12-sin(elapsed)*.015

func picture() -> Texture2D:
	return viewport.get_texture() if viewport!=null else null
