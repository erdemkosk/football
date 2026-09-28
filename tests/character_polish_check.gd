extends SceneTree
const Body=preload("res://scripts/player_body_mesh.gd")
const Face=preload("res://scripts/character_face.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func run() -> void:
	var outward:=true
	for side in [-1,1]:
		for keeper in [false,true]:
			var data:=Body.hand_surface(side,keeper,0,0).surface_get_arrays(0)
			var vertices: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array=data[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				var a:=indices[i]; var b:=indices[i+1]; var c:=indices[i+2]
				var face:=-(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
				outward=outward and face.dot(normals[a]+normals[b]+normals[c])>0
	check(outward,"Palms, finger sides and fingertip caps face outward on both hands and gloves")
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false); game.ball.freeze=true
	var p=game.players[9]
	p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO; p.kick_timer=0; p.receive_timer=0; p.pose="run"
	p.protecting=false; p.jockeying=false; p.celebration=""; p.call_timer=0; p.discipline_pose=""; p.set_piece_pose=""
	p.hand_pose.apply(p,1)
	var relaxed: Vector4=p.hand_pose.snapshot(); var anchor: Transform3D=p.left_hand.global_transform
	check(p.left_hand.mesh==Body.hand(-1,false) and p.left_hand.mesh.get_blend_shape_count()==2,"Hands share cached curl/spread surfaces")
	p.velocity=Vector3.FORWARD*9; p.hand_pose.apply(p,1.0/120)
	check(p.hand_pose.curls.x>relaxed.x and p.hand_pose.curls.x<.30,"Sprint fingers start closing gradually on the first frame")
	p.hand_pose.apply(p,1); var sprint: Vector4=p.hand_pose.snapshot()
	check(sprint.x>.55 and p.left_hand.global_transform==anchor,"Sprint fingers curl without moving the wrist/contact anchor")
	p.protecting=true; p.hand_pose.apply(p,1)
	check(p.hand_pose.curls.x<.13 and p.hand_pose.spreads.x>.50,"Shielding opens and spreads the fingers")
	var still: Vector4=p.hand_pose.snapshot(); p.protecting=false; p.velocity=Vector3.ZERO; p.hand_pose.apply(p,0)
	check(p.hand_pose.snapshot()==still,"A zero-time or paused update does not move fingers")
	var keeper=game.players[11]; keeper.action_timer=.5; keeper.set_piece_pose=""; keeper.keeper_motion.secured=false
	keeper.hand_pose.apply(keeper,1)
	check(keeper.hand_pose.curls.x<.06 and keeper.hand_pose.spreads.x>.75,"A keeper reaches with open gloves")
	keeper.set_piece_pose="carry"; keeper.hand_pose.apply(keeper,1)
	check(keeper.hand_pose.curls.x>.35 and keeper.hand_pose.spreads.x<.30,"Carrying a ball cups the keeper's fingers")
	var batch=p.render_batch
	if batch==null:
		batch=load("res://scripts/rigid_player_batch.gd").new(); batch.setup(p)
	check(p.left_hand.get_parent()==p.left_elbow and p.right_hand.get_parent()==p.right_elbow and p.left_hand not in batch.sources,"Rigid batching leaves articulated fingers and wrist anchors live")
	game.replay.setup()
	p.hand_pose.restore(p,relaxed); var a: Dictionary=game.replay.snapshot()
	p.hand_pose.restore(p,sprint); var b: Dictionary=game.replay.snapshot()
	game.replay.apply_hands(a,b,.5)
	check(p.hand_pose.snapshot().is_equal_approx(relaxed.lerp(sprint,.5)),"Replays interpolate the recorded finger pose")
	game.replay.apply_hands(a,a)
	check(p.hand_pose.snapshot().is_equal_approx(relaxed),"Replay restoration returns the live finger pose")
	var valid:=true
	for id in range(24):
		var mesh:=Face.model(id,30); var data:=mesh.surface_get_arrays(0)
		valid=valid and mesh.get_surface_count()==1 and data[Mesh.ARRAY_VERTEX].size()<3600
		for normal: Vector3 in data[Mesh.ARRAY_NORMAL]: valid=valid and normal.is_finite() and normal.length()>.99
	check(valid,"Integrated nose and face retain finite normals and the existing mesh budget")
	p.shirt_skin.sync_pose(); var before: Transform3D=p.shirt_skin.poses[14]
	var head_anchor: Vector3=p.head_joint.position
	p.head_joint.rotation=Vector3(-.25,.6,0); p.shirt_skin.sync_pose()
	check(not p.shirt_skin.poses[14].is_equal_approx(before) and p.head_joint.position==head_anchor,"Upper neck follows a head turn while the gameplay head anchor stays fixed")
	p.update_soil(1)
	check(p.face_detail.head.material_override.roughness==p.kit_materials.skin.roughness and p.face_detail.mouth.material_override.roughness==p.kit_materials.skin.roughness,"Face, lips and body share the wet-skin response")
	print("CHARACTER POLISH CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
