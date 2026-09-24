extends SceneTree
## Requires a graphical renderer: the headless dummy does not retain MultiMesh buffers.
const G=preload("res://scripts/geometry.gd")
const Batcher=preload("res://scripts/static_geometry.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Run render_integrity_check without --headless to inspect GPU instance buffers.")
		quit(2); return
	var fixture := Node3D.new()
	root.add_child(fixture)
	fixture.position=Vector3(20,3,-12)
	fixture.rotation.y=0.4
	var mat=G.material(Color("567890"))
	var a=G.block(fixture,Vector3(2,1,3),Vector3(4,0,5),mat)
	a.rotation.y=0.7
	var b=G.block(a,Vector3.ONE,Vector3(2,3,1),mat)
	var glass=mat.duplicate()
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var transparent=G.block(fixture,Vector3.ONE,Vector3(1,0,0),glass)
	var animated=G.block(fixture,Vector3.ONE,Vector3(2,0,0),mat)
	var before := vertices([a,b],fixture)
	var stats=Batcher.batch(fixture,[animated])
	var merged: Array=[]
	for child in fixture.get_children():
		if str(child.name).begins_with("StaticBatch"): merged.append(child)
	check(stats.sources==2 and stats.batches==1,"Static pieces combine into one draw without swallowing excluded actors")
	var after := vertices(merged,fixture)
	var matching: bool=before.size()==after.size()
	for vertex in before:
		var found := false
		for i in range(after.size()):
			if vertex.distance_to(after[i])<0.0001:
				after.remove_at(i); found=true; break
		matching=matching and found
	check(matching,"Every triangle keeps its position through rotated and nested parents")
	check(b.get_parent()==a and transparent.mesh!=null and animated.mesh!=null,"Transform parents, transparent glass and animated meshes remain intact")
	mat.albedo_color=Color.RED
	check(merged[0].material_override==mat and merged[0].material_override.albedo_color==Color.RED,"Shared material changes still reach the batched geometry")
	fixture.free()
	var game=load("res://main.tscn").instantiate()
	root.add_child(game); await physics_frame
	game.set_physics_process(false); game.set_process(false)
	var crowd=game.stadium.crowd
	var expected: Dictionary={}
	for fan in crowd.fans: expected[fan.transform.origin]=fan
	var count := 0
	var seats := 0
	var exact := true
	var local_bounds := true
	for node in game.stadium.get_children():
		if not node is MultiMeshInstance3D: continue
		if str(node.name).begins_with("Seats"): seats+=node.multimesh.instance_count
		if not str(node.name).begins_with("Fans_skin_"): continue
		var multi: MultiMesh=node.multimesh
		var bounds: AABB=multi.get_aabb()
		# 40 m blocks since the crowd gained mesh LODs (fewer draws per pass).
		local_bounds=local_bounds and bounds.size.x<43 and bounds.size.z<43
		for i in range(multi.instance_count):
			var transform := multi.get_instance_transform(i)
			var fan: Dictionary=expected.get(transform.origin,{})
			exact=exact and not fan.is_empty()
			if fan.is_empty(): continue
			exact=exact and transform.is_equal_approx(fan.transform) and multi.get_instance_color(i).is_equal_approx(fan.skin) and multi.get_instance_custom_data(i).is_equal_approx(fan.phase)
			count+=1
	check(count==crowd.fans.size() and seats==crowd.chairs.size(),"All supporters and all seats survive spatial batching")
	print("CROWD COUNTS: ",count,"/",crowd.fans.size()," seats=",seats,"/",crowd.chairs.size())
	check(exact,"Every fan retains their location, pose transform, skin color and animation timing")
	check(local_bounds,"Crowd batches have local bounds so unseen stands can be culled")
	check(game.stadium.static_batch_stats.sources>1000 and game.stadium.static_batch_stats.batches<500,"Full stadium removes thousands of separate static render instances")
	print("STATIC BATCHES: ",game.stadium.static_batch_stats)
	game.free()
	print("RENDER INTEGRITY CHECK: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func vertices(nodes: Array,relative: Node3D) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	for node in nodes:
		var transform: Transform3D=relative.global_transform.affine_inverse()*node.global_transform
		var arrays: Array=node.mesh.surface_get_arrays(0)
		for index in arrays[Mesh.ARRAY_INDEX]: result.append(transform*arrays[Mesh.ARRAY_VERTEX][index])
	return result
