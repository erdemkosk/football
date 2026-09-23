extends RefCounted
## Merge opaque, immutable stadium pieces by material and spatial cell.
## Original vertices, normals, materials, shadow flags and collisions are retained.
const CELL_SIZE := 24.0

static func batch(root: Node3D,excluded: Array) -> Dictionary:
	var groups: Dictionary = {}
	collect(root,root,excluded,groups)
	var sources := 0
	var batches := 0
	for group in groups.values():
		if group.size()<2: continue
		var first: MeshInstance3D=group[0]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for node in group:
			surface.append_from(node.mesh,0,root.global_transform.affine_inverse()*node.global_transform)
		surface.index()
		var combined := MeshInstance3D.new()
		combined.name="StaticBatch%d" % batches
		combined.mesh=surface.commit()
		combined.material_override=first.get_active_material(0)
		combined.cast_shadow=first.cast_shadow
		combined.layers=first.layers
		root.add_child(combined)
		for node in group:
			# Keep transform parents (e.g. lamp housings with glass children).
			node.mesh=null
			sources+=1
		batches+=1
	return {"sources":sources,"batches":batches}

static func collect(node: Node,root: Node3D,excluded: Array,groups: Dictionary) -> void:
	if node in excluded: return
	if node is MeshInstance3D and node.mesh!=null and node.visible and node.mesh.get_surface_count()==1:
		var mat=node.get_active_material(0)
		# Transparent sorting and shader-local coordinates must stay independent.
		# Explicit opt-in only for opaque shaders using world-space coordinates.
		var batchable: bool=(mat is StandardMaterial3D and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED) or (mat is ShaderMaterial and mat.get_meta("static_world_space_opaque",false))
		if batchable:
			var location: Vector3=root.to_local(node.global_position)
			var cell := Vector3i(floori(location.x/CELL_SIZE),floori(location.y/CELL_SIZE),floori(location.z/CELL_SIZE))
			var key := "%s:%s:%s:%s" % [mat.get_instance_id(),node.cast_shadow,node.layers,cell]
			if not groups.has(key): groups[key]=[]
			groups[key].append(node)
	for child in node.get_children(): collect(child,root,excluded,groups)
