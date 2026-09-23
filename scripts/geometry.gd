extends RefCounted
static var rigid_meshes: Dictionary={}

static func combine_rigid(parent: Node3D,parts: Array,cache_key: String) -> MeshInstance3D:
	# Same vertices, normals, UVs and material; fewer moving render instances.
	if not rigid_meshes.has(cache_key):
		var builder:=SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in parts: builder.append_from(part.mesh,0,part.transform)
		rigid_meshes[cache_key]=builder.commit()
	var result:=mesh(parent,rigid_meshes[cache_key],parts[0].material_override,Vector3.ZERO)
	result.name="Rigid_"+cache_key
	for part in parts: part.free()
	return result

static func material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

static func mesh(parent: Node3D, shape: Mesh, mat: Material, p: Vector3) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	parent.add_child(node)
	node.position = p
	return node

static func block(parent: Node3D, size: Vector3, p: Vector3, mat: Material) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, mat, p)

static func sphere(parent: Node3D, radius: float, p: Vector3, mat: Material) -> MeshInstance3D:
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 16
	shape.rings = 8
	return mesh(parent, shape, mat, p)

static func cylinder(parent: Node3D, radius: float, height: float, p: Vector3, mat: Material, top: float = -1) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top
	shape.height = height
	shape.radial_segments = 12
	return mesh(parent, shape, mat, p)

static func rod(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> MeshInstance3D:
	var node = cylinder(parent, width, a.distance_to(b), (a + b) * 0.5, mat)
	var direction = (b-a).normalized()
	var axis = Vector3.UP.cross(direction)
	if axis.length() > 0.001: node.quaternion = Quaternion(axis.normalized(), acos(clampf(Vector3.UP.dot(direction),-1,1)))
	return node

static func collision_box(parent: Node3D, size: Vector3, p: Vector3, bounce: float = 0.3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape = BoxShape3D.new()
	shape.size = size
	var col = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	body.position = p
	var physics = PhysicsMaterial.new()
	physics.bounce = bounce
	physics.friction = 0.6
	body.physics_material_override = physics
	return body
