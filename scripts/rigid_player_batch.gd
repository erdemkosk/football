extends Node3D
## Rigid skinning keeps the authored joints and materials, batching only pieces
## whose shape, visibility and local transform do not change during a match.
var actor: Node3D
var skeleton: RID
var joints: Array[Node3D]=[]
var joint_parents: PackedInt32Array=[]
var sources: Array[MeshInstance3D]=[]
var parents: Array[Node3D]=[]
var batches: Array[MeshInstance3D]=[]
var shown_pose: Array[Transform3D]=[]
var active := false

func setup(player: Node3D) -> void:
	actor=player
	name="RigidPlayerBatch"
	actor.rig.add_child(self)
	var groups: Dictionary={}
	var allowed: Array=[]
	for key in ["jersey","trim","shorts","socks","skin","knees"]:
		allowed.append(actor.kit_materials[key])
	for item in actor.rig.find_children("*","MeshInstance3D",true,false):
		var part: MeshInstance3D=item
		if part.mesh==null or part.get_child_count()>0 or part.get_parent()==actor.head_joint: continue
		if part.material_override not in allowed or part.visibility_range_end>0: continue
		if not part.visible or part.mesh.get_surface_count()!=1: continue
		var material: Material=part.material_override
		if not groups.has(material): groups[material]=[]
		groups[material].append(part)
	var mesh:=ArrayMesh.new()
	for material in groups:
		var parts: Array=groups[material]
		if parts.size()<2: continue
		var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
		var vertices:=PackedVector3Array(); var normals:=PackedVector3Array()
		var uvs:=PackedVector2Array(); var indices:=PackedInt32Array()
		var bones:=PackedInt32Array(); var weights:=PackedFloat32Array()
		for part: MeshInstance3D in parts:
			var parent: Node3D=part.get_parent()
			var bone:=add_joint(parent)
			var data: Array=part.mesh.surface_get_arrays(0)
			var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array=data[Mesh.ARRAY_TEX_UV]
			var index: PackedInt32Array=data[Mesh.ARRAY_INDEX]
			var offset:=vertices.size()
			var normal_basis:=part.basis.inverse().transposed()
			for i in range(points.size()):
				vertices.append(part.transform*points[i])
				normals.append((normal_basis*ns[i]).normalized())
				uvs.append(uv[i] if i<uv.size() else Vector2.ZERO)
				bones.append_array(PackedInt32Array([bone,0,0,0]))
				weights.append_array(PackedFloat32Array([1,0,0,0]))
			for i in index: indices.append(offset+i)
			sources.append(part); parents.append(parent)
		arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_TEX_UV]=uvs; arrays[Mesh.ARRAY_INDEX]=indices
		arrays[Mesh.ARRAY_BONES]=bones; arrays[Mesh.ARRAY_WEIGHTS]=weights
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,material)
	var batch:=MeshInstance3D.new(); batch.mesh=mesh
	add_child(batch); batches.append(batch)
	skeleton=RenderingServer.skeleton_create()
	RenderingServer.skeleton_allocate_data(skeleton,joints.size())
	shown_pose.resize(joints.size())
	for i in range(joints.size()): RenderingServer.skeleton_bone_set_transform(skeleton,i,Transform3D.IDENTITY)
	RenderingServer.instance_attach_skeleton(batch.get_instance(),skeleton)
	RenderingServer.frame_pre_draw.connect(sync_pose)
	set_active(true)

func set_active(value: bool) -> void:
	if active==value: return
	active=value
	for i in range(sources.size()):
		if active: parents[i].remove_child(sources[i])
		else: parents[i].add_child(sources[i])
	for batch in batches: batch.visible=active
	if active: sync_pose()

func sync_pose() -> void:
	if not active: return
	# No animation interpolation is introduced; the player already renders the
	# current authored pose. Contacts continue to use the original joint nodes.
	for i in range(joints.size()):
		var pose:=Transform3D.IDENTITY
		if joints[i]!=actor.rig:
			pose=shown_pose[joint_parents[i]]*joints[i].transform
		if pose==shown_pose[i]: continue
		shown_pose[i]=pose
		RenderingServer.skeleton_bone_set_transform(skeleton,i,pose)

func add_joint(joint: Node3D) -> int:
	var existing:=joints.find(joint)
	if existing>=0: return existing
	var parent_index: int=-1 if joint==actor.rig else add_joint(joint.get_parent())
	joint_parents.append(parent_index); joints.append(joint)
	return joints.size()-1

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(sync_pose): RenderingServer.frame_pre_draw.disconnect(sync_pose)
	if skeleton.is_valid(): RenderingServer.free_rid(skeleton)
	if active:
		for source in sources: source.free()
