extends SceneTree
var failures:=0
var comparisons:=0
var max_vertex_error:=0.0
var max_normal_error:=0.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		if failures<12: push_error(message)
func verify(batch) -> void:
	batch.sync_pose()
	var mesh: ArrayMesh=batch.batches[0].mesh
	for s in range(mesh.get_surface_count()):
		var material: Material=mesh.surface_get_material(s)
		var data:=mesh.surface_get_arrays(s)
		var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array=data[Mesh.ARRAY_TEX_UV]
		var bones: PackedInt32Array=data[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array=data[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array=data[Mesh.ARRAY_INDEX]
		var offset:=0; var index_offset:=0
		for p in range(batch.sources.size()):
			var source: MeshInstance3D=batch.sources[p]
			if source.material_override!=material: continue
			var parent: Node3D=batch.parents[p]
			var original:=source.mesh.surface_get_arrays(0)
			var original_points: PackedVector3Array=original[Mesh.ARRAY_VERTEX]
			var original_normals: PackedVector3Array=original[Mesh.ARRAY_NORMAL]
			var original_uv: PackedVector2Array=original[Mesh.ARRAY_TEX_UV]
			var original_indices: PackedInt32Array=original[Mesh.ARRAY_INDEX]
			var world:=parent.global_transform*source.transform
			for i in range(original_points.size()):
				var k:=offset+i
				var bone: Transform3D=batch.shown_pose[bones[k*4]] if DisplayServer.get_name()=="headless" else RenderingServer.skeleton_bone_get_transform(batch.skeleton,bones[k*4])
				var rendered: Transform3D=batch.global_transform*bone
				var error: float=(world*original_points[i]).distance_to(rendered*points[k])
				max_vertex_error=maxf(max_vertex_error,error)
				check(error<.00003,"Skinned vertex matches original world position")
				var a: Vector3=(world.basis.inverse().transposed()*original_normals[i]).normalized()
				var b: Vector3=(batch.global_basis.inverse().transposed()*bone.basis*normals[k]).normalized()
				var normal_error:=a.distance_to(b)
				max_normal_error=maxf(max_normal_error,normal_error)
				check(normal_error<.0003,"Skinned lighting normal matches original")
				if i<original_uv.size(): check(uv[k]==original_uv[i],"Same UV coordinates")
				check(weights[k*4]==1.0 and weights[k*4+1]==0.0,"Rigid single-bone weights")
				comparisons+=1
			for i in original_indices.size(): check(indices[index_offset+i]==offset+original_indices[i],"Same triangle topology")
			offset+=original_points.size(); index_offset+=original_indices.size()
		check(offset==points.size() and index_offset==indices.size(),"No added or missing geometry")
func run() -> void:
	var rng:=RandomNumberGenerator.new(); rng.seed=73022
	for role in range(3):
		var player=load("res://scripts/footballer.gd").new()
		player.keeper=role==1; player.official=role==2
		root.add_child(player)
		var batch=player.render_batch
		if batch==null: batch=load("res://scripts/rigid_player_batch.gd").new(); batch.setup(player)
		check(batch.sources.size()==15 and batch.batches[0].mesh.get_surface_count()==6,"Expected six material surfaces")
		for pose in range(60):
			player.height_cm=rng.randi_range(166,199); player.weight_kg=rng.randi_range(58,96); player.apply_build()
			player.position=Vector3(rng.randf_range(-35,35),rng.randf_range(0,3),rng.randf_range(-55,55))
			player.rig.rotation=Vector3(rng.randf_range(-1.5,1.5),rng.randf_range(-3.1,3.1),rng.randf_range(-1.5,1.5))
			for joint in player.kick_joints: joint.rotation=Vector3(rng.randf_range(-1.8,1.8),rng.randf_range(-.5,.5),rng.randf_range(-1,1))
			var hand: Transform3D=player.left_hand.global_transform
			var boot: Vector3=player.left_knee.to_global(player.ball_actions.BOOT)
			verify(batch)
			check(hand==player.left_hand.global_transform and boot==player.left_knee.to_global(player.ball_actions.BOOT),"Contact anchors unchanged")
		batch.set_active(false)
		for i in range(batch.sources.size()): check(batch.sources[i].get_parent()==batch.parents[i],"Baseline restores original render nodes")
		batch.set_active(true); player.free()
	print("RIGID BATCH: ",comparisons," vertices, max_position_error_m=",max_vertex_error," max_normal_error=",max_normal_error," failures=",failures)
	quit(0 if failures==0 else 1)
