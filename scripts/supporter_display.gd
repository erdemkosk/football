extends Node3D
## Two reusable cloth displays, revealed for the opening of a rivalry match.
const P=preload("res://scripts/pitch_dimensions.gd")
const Graphics=preload("res://scripts/kit_graphics.gd")
var displays: Array[Dictionary]=[]
var profiles: Array=[]
var heat:=0.0
var age:=0.0
var deployment:=0.0
var game
var covered_props: Array[Dictionary]=[]
var covered:=false

func _ready() -> void:
	for side in range(2):
		var root:=Node3D.new(); add_child(root)
		# Both fabrics sit on the terraces, outside the touchlines and goals.
		root.position=Vector3(-44.5-P.SIDE_SHIFT,5.9,-23 if side==0 else 28)
		# Follow the lower terrace slope, above raised hands rather than inside its steps.
		root.rotation=Vector3(deg_to_rad(-59.5),PI*.5,0)
		var mesh:=MeshInstance3D.new(); var cloth:=PlaneMesh.new()
		cloth.orientation=PlaneMesh.FACE_Z; cloth.size=Vector2(24,12)
		cloth.subdivide_width=24; cloth.subdivide_depth=10; mesh.mesh=cloth
		var material:=ShaderMaterial.new(); material.shader=preload("res://shaders/supporter_tifo.gdshader")
		mesh.material_override=material; mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)
		var title:=Label3D.new(); title.font_size=70; title.pixel_size=.012; title.outline_size=8
		title.position=Vector3(0,-3.5,.2); root.add_child(title)
		displays.append({"root":root,"material":material,"title":title})
	# Existing little flags must not pierce the fabric when supporters unfurl it.
	for node in get_parent().find_children("Supporter_*","MultiMeshInstance3D",true,false):
		for i in range(node.multimesh.instance_count):
			var transform: Transform3D=node.multimesh.get_instance_transform(i)
			var at: Vector3=node.global_transform*transform.origin
			if at.x> -54.5 and at.x< -42.5 and at.y<8 and (absf(at.z+23)<12 or absf(at.z-28)<12):
				covered_props.append({"mesh":node.multimesh,"index":i,"transform":transform})
	visible=false

func cover_props(value: bool) -> void:
	if covered==value: return
	covered=value
	for prop in covered_props:
		var transform: Transform3D=prop.transform
		if covered: transform.basis=transform.basis.scaled(Vector3.ZERO)
		prop.mesh.set_instance_transform(prop.index,transform)

func configure(g,home: Dictionary,away: Dictionary,identities: Array,value: float) -> void:
	game=g; heat=value; profiles=identities; age=0; deployment=0; visible=false
	cover_props(false)
	for side in range(displays.size()):
		var club: Dictionary=home if side==0 else away
		var data: Dictionary=displays[side]; var identity: Dictionary=identities[side]
		data.material.set_shader_parameter("primary",Color(club.primary))
		data.material.set_shader_parameter("accent",Color(club.accent))
		data.material.set_shader_parameter("crest",Graphics.badge(int(club.get("badge_id",side)),Color(club.primary),Color(club.accent)))
		data.material.set_shader_parameter("pattern",int(identity.pattern))
		data.material.set_shader_parameter("unfold",0.0)
		data.title.text=identity.name; data.title.modulate=Color(club.accent).lerp(Color.WHITE,.65)

func _process(delta: float) -> void:
	if game==null or heat<=0: visible=false; cover_props(false); return
	if game.training or game.menu_match.running or game.state in ["menu","career","finished","trophy"]:
		visible=false; cover_props(false); return
	if game.state=="paused": return
	# No second entrance at halftime, on restarts, or when a replay is skipped.
	if game.state=="ceremony" or game.state in ["playing","restart","set_piece"]: age+=delta
	var wanted:=1.0 if game.half==1 and (game.state=="ceremony" or age<32) else 0.0
	if game.experience.reduce_motion: deployment=wanted
	else: deployment=move_toward(deployment,wanted,delta*(.8 if wanted>deployment else .28))
	visible=deployment>.01
	cover_props(deployment>.18)
	for data in displays:
		data.material.set_shader_parameter("unfold",deployment)
		data.material.set_shader_parameter("cloth_time",0.0 if game.experience.reduce_motion else age)
		data.title.visible=deployment>.94
