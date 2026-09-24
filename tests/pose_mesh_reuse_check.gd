extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func vertices(node: MeshInstance3D) -> Array[Vector3]:
	var out: Array[Vector3]=[]
	var arrays=node.mesh.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for i in indices: out.append(node.transform*points[i])
	return out
func run() -> void:
	var source=FileAccess.get_file_as_string("res://tests/footballer_mesh_before.gd")
	source=source.replace("res://scripts/locomotion.gd","res://tests/locomotion_transforms_before.gd")
	source=source.replace("res://scripts/dribble_motion.gd","res://tests/dribble_transforms_before.gd")
	var script=GDScript.new(); script.source_code=source; check(script.reload()==OK,"old script loads")
	var old=script.new(); var current=load("res://scripts/footballer.gd").new()
	root.add_child(old); root.add_child(current)
	for left in [true,false]:
		var before: Node3D=old.left_elbow if left else old.right_elbow
		var after: Node3D=current.left_elbow if left else current.right_elbow
		var hand: MeshInstance3D=old.left_hand if left else old.right_hand
		var a: Array[Vector3]=vertices(before.get_node("Rigid_forearm_skin")); a.append_array(vertices(hand))
		var b: Array[Vector3]=vertices(after.get_node("Rigid_forearm_hand_skin"))
		check(a.size()==b.size(),"merged triangles retained")
		for i in range(mini(a.size(),b.size())): check(a[i].is_equal_approx(b[i]),"merged vertex retained")
	var poses := 0
	for frame in range(360):
		for p in [old,current]:
			p.velocity=Vector3(sin(frame*.03)*5,0,4)
			p.run_phase+=.11; p.motion_clock+=1.0/120
			p.position=Vector3(sin(frame*.01),0,frame*.006)
			p.dribble_motion.freshness=1.0 if frame>=120 and frame<300 else 0.0
			p.locomotion.update(p,1.0/120,Vector3.ZERO)
			p.animate(1.0/120)
		for i in range(old.kick_joints.size()):
			check(old.kick_joints[i].transform.is_equal_approx(current.kick_joints[i].transform),"same joint pose")
		check(old.left_hand.global_transform.is_equal_approx(current.left_hand.global_transform),"left hand anchor preserved")
		check(old.right_hand.global_transform.is_equal_approx(current.right_hand.global_transform),"right hand anchor preserved")
		check(old.left_knee.to_global(old.ball_actions.BOOT).is_equal_approx(current.left_knee.to_global(current.ball_actions.BOOT)),"left boot preserved")
		check(old.right_knee.to_global(old.ball_actions.BOOT).is_equal_approx(current.right_knee.to_global(current.ball_actions.BOOT)),"right boot preserved")
		poses+=1
	print("POSE/MESH EQUIVALENCE: ",poses," running/carrying poses, ",failures," failures")
	print("MESH INSTANCES old=",old.find_children("*","MeshInstance3D",true,false).filter(func(n): return n.mesh!=null).size()," new=",current.find_children("*","MeshInstance3D",true,false).filter(func(n): return n.mesh!=null).size())
	var old_times: Array[float]=[]; var new_times: Array[float]=[]
	for trial in range(8):
		for p in ([old,current] if trial%2==0 else [current,old]):
			var start := Time.get_ticks_usec()
			for i in range(1000): p.animate(1.0/120)
			var elapsed := float(Time.get_ticks_usec()-start)/1000
			if p==old: old_times.append(elapsed)
			else: new_times.append(elapsed)
	old_times.sort(); new_times.sort()
	print("POSE CPU paired fixed-input old_us=",old_times[4]," new_us=",new_times[4])
	old.free(); current.free(); quit(0 if failures==0 else 1)
