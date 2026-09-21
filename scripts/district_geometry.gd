extends RefCounted
## Bake colored architectural details directly into local meshes, not scene nodes.
var cell_size := 96.0
var groups: Dictionary = {}
var shapes: Dictionary = {}
var part_count := 0

func _init() -> void:
	var cube := BoxMesh.new(); cube.size=Vector3.ONE
	var round := CylinderMesh.new(); round.top_radius=1; round.bottom_radius=1; round.height=1; round.radial_segments=8
	var crown := SphereMesh.new(); crown.radius=1; crown.height=2; crown.radial_segments=8; crown.rings=3
	var plane := PlaneMesh.new(); plane.size=Vector2.ONE
	for entry in [["box",cube],["round",round],["crown",crown],["plane",plane]]:
		shapes[entry[0]]=entry[1].surface_get_arrays(0)

func box(size: Vector3,at: Vector3,color: Color,kind: String="solid",rotation: Basis=Basis.IDENTITY) -> void:
	add("box",Transform3D(rotation.scaled_local(size),at),color,kind)

func add(shape: String,transform: Transform3D,color: Color,kind: String="solid") -> void:
	var cell := Vector3i(floori(transform.origin.x/cell_size),0,floori(transform.origin.z/cell_size)) if cell_size>0 else Vector3i.ZERO
	var key := "%s:%s" % [cell,kind]
	if not groups.has(key):
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[key]={"surface":surface,"origin":Vector3(cell)*cell_size,"kind":kind}
	var group: Dictionary=groups[key]
	var surface: SurfaceTool=group.surface
	var arrays: Array=shapes[shape]
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var normal_matrix := transform.basis.inverse().transposed()
	for index in arrays[Mesh.ARRAY_INDEX]:
		surface.set_color(color)
		surface.set_uv(uv[index])
		surface.set_normal((normal_matrix*normals[index]).normalized())
		surface.add_vertex(transform*vertices[index]-group.origin)
	part_count+=1

func finish(parent: Node3D,materials: Dictionary) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	for group in groups.values():
		var surface: SurfaceTool=group.surface
		surface.index()
		var node := MeshInstance3D.new()
		node.name="District_"+group.kind+"_"+str(result.size())
		node.mesh=surface.commit()
		node.material_override=materials[group.kind]
		node.layers=2
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if group.kind=="solid" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node); node.position=group.origin
		result.append(node)
	groups.clear()
	return result
