extends Node3D
## Two bounded GPU batches: soft grounding and wet, articulated reflections.
const P = preload("res://scripts/pitch_dimensions.gd")
var game
var shadows: MultiMeshInstance3D
var reflections: MultiMeshInstance3D
var reflection_material := ShaderMaterial.new()

func _ready() -> void:
	name="PitchPresence"
	var plane := PlaneMesh.new(); plane.size=Vector2.ONE
	var mat := ShaderMaterial.new(); mat.shader=load("res://shaders/contact_shadow.gdshader")
	shadows=batch(plane,mat,96)
	var shape := SphereMesh.new(); shape.radius=1; shape.height=2; shape.radial_segments=8; shape.rings=4
	reflection_material.shader=load("res://shaders/wet_reflection.gdshader")
	reflection_material.set_shader_parameter("half_pitch",Vector2(P.HALF_WIDTH,P.HALF_LENGTH))
	reflections=batch(shape,reflection_material,256)

func batch(mesh: Mesh,material: Material,count: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new(); var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D; multi.use_colors=true
	multi.mesh=mesh; multi.instance_count=count; multi.visible_instance_count=0
	node.multimesh=multi; node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb=AABB(Vector3(-65,-1,-60),Vector3(130,18,120))
	add_child(node); return node

func shadow(index: int,at: Vector3,size: Vector2,opacity: float,yaw: float=0) -> void:
	shadows.multimesh.set_instance_transform(index,Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(size.x,1,size.y)),Vector3(at.x,.025,at.z)))
	shadows.multimesh.set_instance_color(index,Color(0,0,0,opacity))

func _process(_delta: float) -> void: update_visuals()

func update_visuals() -> void:
	if game==null or not is_instance_valid(game.ball): return
	var count := 0; var reflected := 0
	var ball=game.ball
	if ball.is_visible_in_tree() and absf(ball.position.x)<P.HALF_WIDTH+4 and absf(ball.position.z)<55:
		var height := maxf(0,ball.position.y-ball.RADIUS)
		var radius := .36+minf(height,12)*.045
		shadow(count,ball.global_position,Vector2.ONE*radius,.50/(1+height*.12)); count+=1
	var wet: float=game.weather.wetness
	reflections.visible=wet>.25
	reflection_material.set_shader_parameter("wetness",wet)
	reflection_material.set_shader_parameter("clock",game.weather.clock)
	for p in game.players+game.referees.actors:
		if not p.is_visible_in_tree() or absf(p.position.x)>P.HALF_WIDTH+4 or absf(p.position.z)>55: continue
		var height: float=maxf(0,p.position.y)
		shadow(count,p.position,Vector2(.9,1.05)*(1+height*.15),.22/(1+height*2)); count+=1
		for knee in [p.left_knee,p.right_knee]:
			var foot: Vector3=knee.to_global(Vector3(0,-.42,-.05))
			shadow(count,foot,Vector2(.27,.43),.42*(1-smoothstep(.10,.65,foot.y)),p.rig.rotation.y); count+=1
		if not reflections.visible: continue
		var kit: Color=p.kit_materials.jersey.albedo_color
		var shorts: Color=p.kit_materials.shorts.albedo_color
		var skin: Color=p.kit_materials.skin.albedo_color
		var parts := [[p.spine,Vector3(0,.27,0),Vector3(.28,.29,.19),kit],
			[p.head_joint,Vector3(0,.15,0),Vector3(.17,.21,.17),skin],
			[p.left_leg,Vector3(0,-.14,0),Vector3(.11,.2,.11),shorts],
			[p.right_leg,Vector3(0,-.14,0),Vector3(.11,.2,.11),shorts],
			[p.left_knee,Vector3(0,-.22,0),Vector3(.08,.22,.09),kit],
			[p.right_knee,Vector3(0,-.22,0),Vector3(.08,.22,.09),kit],
			[p.left_arm,Vector3(0,-.14,0),Vector3(.095,.24,.09),kit],
			[p.right_arm,Vector3(0,-.14,0),Vector3(.095,.24,.09),kit]]
		for part in parts:
			var node: Node3D=part[0]
			reflections.multimesh.set_instance_transform(reflected,node.global_transform*Transform3D(Basis.from_scale(part[2]),part[1]))
			reflections.multimesh.set_instance_color(reflected,part[3]); reflected+=1
	shadows.multimesh.visible_instance_count=count
	reflections.multimesh.visible_instance_count=reflected
