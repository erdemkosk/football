extends Node3D
## Match-day equipment is decorative; it cannot obstruct a restart or ball retrieval.
const G = preload("res://scripts/geometry.gd")
const P = preload("res://scripts/pitch_dimensions.gd")
const BALL_RADIUS = preload("res://scripts/ball_dimensions.gd").RADIUS
var items: Array[Dictionary] = []
var batch_stats: Dictionary = {}
var cream := G.material(Color("e6e3d5"))
var navy := G.material(Color("223640"))
var bottle := G.material(Color("5c97a2"),.28)
var orange := G.material(Color("f18c46"))
var lime := G.material(Color("c9dc5a"))
var towel_fabric := G.material(Color("e6e3d5"))
var bib_fabrics: Array[StandardMaterial3D] = [G.material(Color("f18c46")),G.material(Color("c9dc5a"))]

func _ready() -> void:
	name="MatchDayEquipment"
	towel_fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
	for fabric in bib_fabrics: fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
	for side in [-1,1]:
		for z in [-48.6,0,48.6]: spare_ball(Vector3(side*(P.HALF_WIDTH+3.9),BALL_RADIUS+.015,z+.65))
	for team in range(2):
		var z := -12.0 if team==0 else 12.0
		bottle_carrier(Vector3(P.HALF_WIDTH+4.9,.015,z+6.65),team)
		# A towel hangs over the cooler; the small bib stand sits at the dugout end.
		towel(Vector3(P.HALF_WIDTH+4.565,.72,z+5.75),team)
		bib(Vector3(P.HALF_WIDTH+5.22,1.10,z-4.80),team)
		var rolled := item("rolled_towel",Vector3(P.HALF_WIDTH+5.45,.13,z+6.4))
		var roll := G.cylinder(rolled,.115,.39,Vector3.ZERO,cream)
		roll.rotation.z=PI*.5
		G.cylinder(roll,.118,.04,Vector3(0,.10,0),navy)
	batch_stats=preload("res://scripts/static_geometry.gd").batch(self,[])

func item(kind: String,at: Vector3) -> Node3D:
	var group := Node3D.new()
	group.name=kind+str(items.size())
	add_child(group); group.position=at
	items.append({"kind":kind,"position":at})
	return group

func spare_ball(at: Vector3) -> void:
	var group := item("spare_ball",at)
	G.sphere(group,BALL_RADIUS,Vector3.ZERO,cream)
	var phi := (1+sqrt(5.0))/2
	for a in [-1,1]:
		for b in [-1,1]:
			for direction in [Vector3(0,a,b*phi).normalized(),Vector3(a,b*phi,0).normalized(),Vector3(b*phi,0,a).normalized()]:
				var panel := CylinderMesh.new()
				panel.top_radius=BALL_RADIUS*.29545; panel.bottom_radius=panel.top_radius
				panel.height=BALL_RADIUS*.014; panel.radial_segments=5
				var patch := G.mesh(group,panel,navy,direction*BALL_RADIUS)
				patch.quaternion=Quaternion(Vector3.UP,direction)

func bottle_carrier(at: Vector3,team: int) -> void:
	var group := item("bottle_carrier",at)
	G.block(group,Vector3(.54,.07,.36),Vector3(0,.035,0),navy)
	for side in [-1,1]:
		G.block(group,Vector3(.55,.12,.025),Vector3(0,.14,side*.18),navy)
		G.block(group,Vector3(.025,.12,.36),Vector3(side*.27,.14,0),navy)
	for x in [-.17,0,.17]:
		for z in [-.085,.085]:
			G.cylinder(group,.054,.24,Vector3(x,.19,z),bottle,.046)
			G.cylinder(group,.034,.035,Vector3(x,.33,z),orange if team==0 else lime)
	for x in [-.29,.29]: G.rod(group,Vector3(x,.1,0),Vector3(x,.43,0),.014,navy)
	G.rod(group,Vector3(-.29,.43,0),Vector3(.29,.43,0),.018,navy)

func towel(at: Vector3,team: int) -> void:
	var group := item("towel",at)
	# Stitched strips follow a fold over the cooler edge, then hang down its face.
	var strips := 12
	for i in range(strips):
		var a := -0.23+i*.46/strips
		var b := a+.46/strips
		var ripple := sin(i*1.7)*.012
		var next := sin((i+1)*1.7)*.012
		cloth_quad(group,Vector3(.25,.002,a),Vector3(.25,.002,b),Vector3(0,.012+ripple,a),Vector3(0,.012+next,b),towel_fabric)
		cloth_quad(group,Vector3(0,.012+ripple,a),Vector3(0,.012+next,b),Vector3(-.025+ripple,-.41,a),Vector3(-.025+next,-.41,b),towel_fabric)
	G.block(group,Vector3(.012,.024,.44),Vector3(-.041,-.35,0),orange if team==0 else navy)

func bib(at: Vector3,team: int) -> void:
	var group := item("training_bib",at)
	var fabric := bib_fabrics[team]
	for z in [-.32,.32]:
		G.rod(group,Vector3(-.04,-1.08,z),Vector3(-.04,.28,z),.018,navy)
		G.rod(group,Vector3(-.21,-1.08,z),Vector3(.14,-1.08,z),.018,navy)
	G.rod(group,Vector3(-.04,.28,-.32),Vector3(-.04,.28,.32),.018,navy)
	for side in [-1,1]:
		# Open neck and separate straps make this read as a vest, not a solid rectangle.
		cloth_quad(group,Vector3(-.10,.28,side*.095),Vector3(-.10,.28,side*.22),Vector3(-.14,.06,side*.095),Vector3(-.14,.06,side*.22),fabric)
	cloth_quad(group,Vector3(-.14,.06,-.23),Vector3(-.14,.06,.23),Vector3(-.19,-.30,-.21),Vector3(-.17,-.32,.21),fabric)
	cloth_quad(group,Vector3(.02,.28,-.22),Vector3(.02,.28,.22),Vector3(.04,-.28,-.20),Vector3(.05,-.29,.20),fabric)
	G.block(group,Vector3(.012,.022,.36),Vector3(-.184,-.245,0),cream)

func cloth_quad(parent: Node3D,a: Vector3,b: Vector3,c: Vector3,d: Vector3,mat: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [a,b,c,b,d,c]: surface.add_vertex(point)
	surface.generate_normals()
	G.mesh(parent,surface.commit(),mat,Vector3.ZERO)
