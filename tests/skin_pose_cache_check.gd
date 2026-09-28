extends SceneTree
## Compare rendered bone transforms with the original world-space equations.
## The reference includes volume correctives and the unscaled upper neck.
var checks:=0
var failures:=0
var worst_error:=0.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func reference(skin) -> Array[Transform3D]:
	var p=skin.actor
	var inverse: Transform3D=p.jersey_body.global_transform.affine_inverse()
	var poses: Array[Transform3D]=[]
	for i in range(skin.joints.size()):
		var at: Transform3D=skin.joints[i].global_transform
		if i==0: at.basis=at.basis*Basis.from_scale(Vector3(p.jersey_body.scale.x,1,1))
		poses.append(inverse*at*skin.bind_inverse[i])
	for i in range(4):
		var joint: Node3D=skin.joints[[3,4,8,9][i]]
		var parent: Node3D=skin.joints[[1,2,6,7][i]]
		var q:=joint.quaternion
		var half:=Quaternion.IDENTITY.slerp(q,.5)
		var volume:=minf(1.32,1.0/maxf(.5,cos(Quaternion.IDENTITY.angle_to(q)*.5)))
		var bend:=Transform3D(Basis(half)*Basis.from_scale(Vector3(1,1,volume)),joint.position)
		poses.append(inverse*parent.global_transform*bend*skin.bind_inverse[10+i])
	var neck: Transform3D=p.head_joint.global_transform
	neck.basis=neck.basis*Basis.from_scale(Vector3.ONE/p.head_joint.scale)
	poses.append(inverse*neck*skin.bind_inverse[14])
	return poses
func equivalent(skin) -> bool:
	skin.sync_pose()
	var before:=reference(skin)
	var error:=0.0
	for i in range(before.size()):
		var a: Transform3D=before[i]; var b: Transform3D=skin.poses[i]
		error=maxf(error,a.origin.distance_to(b.origin))
		for axis in range(3): error=maxf(error,a.basis[axis].distance_to(b.basis[axis]))
	worst_error=maxf(worst_error,error)
	return error<.00004 # Float32 world inverse roundoff; under 0.04 mm locally.
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var p=load("res://scripts/footballer.gd").new(); world.add_child(p)
	var probe:=GDScript.new()
	probe.source_code='extends "res://scripts/shirt_skin.gd"\nvar uploads:=0\nfunc upload(index: int,pose: Transform3D) -> void:\n\tif poses[index]!=pose: uploads+=1\n\tsuper.upload(index,pose)\n'
	if probe.reload()!=OK: quit(1); return
	p.shirt_skin.body.free(); p.shirt_skin.free()
	p.shirt_skin=probe.new(); p.shirt_skin.setup(p)
	var skin=p.shirt_skin
	check(equivalent(skin),"Initial skin matches the original world-space deformation")
	var before: Array=skin.poses.duplicate()
	skin.uploads=0
	for frame in range(120):
		p.position=Vector3(sin(frame*.03)*32,.4,cos(frame*.07)*49)
		p.rotation=Vector3(.1,frame*.09,.04)
		p.rig.rotation=Vector3(.25,frame*.1,.35)
		world.rotation.y=frame*.02
		skin.sync_pose()
	check(skin.uploads==0 and skin.poses==before and equivalent(skin),"World translation, facing and rig motion reuse every unchanged local bone")
	skin.uploads=0; p.head_joint.rotation=Vector3(-.3,.6,.1)
	check(equivalent(skin) and skin.uploads==1,"A head turn updates only the upper neck, with scale removed")
	skin.uploads=0; p.left_elbow.rotation.x+=.5
	check(equivalent(skin) and skin.uploads==2,"An elbow bend updates its bone and volume corrective")
	skin.uploads=0; p.left_arm.rotation.z-=.4
	check(equivalent(skin) and skin.uploads==3,"A shoulder change propagates to its elbow and corrective")
	p.left_elbow.position+=Vector3(.01,-.015,.02)
	p.left_elbow.scale=Vector3(1.03,.97,1.02)
	check(equivalent(skin),"Joint offsets and nonuniform scale invalidate the cached pose")
	p.jersey_body.rotation=Vector3(.02,.04,.01); p.jersey_body.position.y+=.015
	p.jersey_body.scale=Vector3(1.07,.99,1.02)
	check(equivalent(skin),"A mesh-local transform change refreshes every dependent bone")
	p.jersey_body.rotation=Vector3.ZERO; p.jersey_body.position=Vector3(0,.28,0)
	p.jersey_body.scale=Vector3.ONE; p.left_elbow.position=Vector3(0,-.275,0); p.left_elbow.scale=Vector3.ONE
	var all_match:=true
	for build in [[165,58],[180,77],[199,98]]:
		p.height_cm=build[0]; p.weight_kg=build[1]; p.apply_build()
		for frame in range(180):
			p.velocity=Vector3(sin(frame*.07)*7,0,-6); p.motion_clock+=1.0/60; p.run_phase+=.12
			p.kick_timer=.4*(1-frame/60.0) if frame<60 else 0.0; p.kick_duration=.46
			p.action_timer=0; p.celebration="cheer" if frame>=120 else ""
			p.motion_transition.reset(); p.animate(1.0/60)
			all_match=equivalent(skin) and all_match
	check(all_match,"540 running, kicking and raised-arm poses across three physiques retain their deformation")
	var saved: Array[Transform3D]=[]
	for joint in skin.joints: saved.append(joint.transform)
	var saved_head: Transform3D=p.head_joint.transform
	var saved_mesh: Transform3D=p.jersey_body.transform
	for joint in skin.joints: joint.rotation+=Vector3(.2,.3,.4)
	p.head_joint.rotation.y+=.4; p.jersey_body.scale.x=.98; skin.sync_pose()
	for i in range(skin.joints.size()): skin.joints[i].transform=saved[i]
	p.head_joint.transform=saved_head; p.jersey_body.transform=saved_mesh
	check(equivalent(skin),"Restoring recorded joint transforms refreshes the skin immediately")
	p.hide(); p.right_knee.rotation.x-=.4; skin.sync_pose(); p.show()
	check(equivalent(skin),"A hidden player's changed pose remains correct on return")
	var boot: Vector3=p.left_knee.to_global(p.ball_actions.BOOT)
	var wrist: Transform3D=p.left_hand.global_transform
	var head: Transform3D=p.head_joint.global_transform
	skin.sync_pose()
	check(boot==p.left_knee.to_global(p.ball_actions.BOOT) and wrist==p.left_hand.global_transform and head==p.head_joint.global_transform,"Skin synchronization never modifies the physical boot, glove or head anchors")
	print("SKIN CACHE CHECK: %d checks, %d failures; maximum reference error=%.8f" % [checks,failures,worst_error])
	world.free(); quit(1 if failures else 0)
