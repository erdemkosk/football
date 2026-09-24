extends RefCounted
## Only the presentation actors use these poses. The live roster slots stay stable.
const RUN_SPEED := 9.2

static func copy_pose(source, target) -> void:
	source.flush_running_pose()
	target.global_transform=source.global_transform
	target.facing=source.facing; target.velocity=source.velocity
	target.run_phase=source.run_phase; target.motion_clock=source.motion_clock
	target.rig.transform=source.rig.transform
	for i in range(source.kick_joints.size()):
		target.kick_joints[i].transform=source.kick_joints[i].transform
	target.head_joint.transform=source.head_joint.transform
	target.motion_transition.reset()
	target.motion_transition.state="celebrate_handshake"
	for joint in target.kick_joints: target.motion_transition.previous.append(joint.quaternion)
	target.reset_physics_interpolation()
	if is_instance_valid(target.render_batch): target.render_batch.sync_pose()

static func sit(p, weight: float) -> void:
	# Seat top is 0.515 m; the pelvis clears it while the soles stay on the floor.
	var hip_height := .57
	var knee_height: float=p.boot_ground_height()+.42*p.rig.scale.y
	var thigh := acos(clampf((hip_height-knee_height)/(.33*p.rig.scale.y),-.5,.8))
	p.rig.position=p.rig.position.lerp(Vector3(0,hip_height-p.position.y-.85*p.rig.scale.y,0),weight)
	p.rig.rotation.x=lerp_angle(p.rig.rotation.x,0,weight)
	p.rig.rotation.z=lerp_angle(p.rig.rotation.z,0,weight)
	p.rig.rotation.y=lerp_angle(p.rig.rotation.y,PI*.5,weight)
	p.spine.rotation=p.spine.rotation.lerp(Vector3(-.10,0,0),weight)
	p.head_joint.rotation=p.head_joint.rotation.lerp(Vector3.ZERO,weight)
	for i in range(2):
		var side := -1.0 if i==0 else 1.0
		var leg=p.left_leg if i==0 else p.right_leg
		var knee=p.left_knee if i==0 else p.right_knee
		var arm=p.left_arm if i==0 else p.right_arm
		var elbow=p.left_elbow if i==0 else p.right_elbow
		leg.rotation=leg.rotation.lerp(Vector3(thigh,0,side*.045),weight)
		knee.rotation=knee.rotation.lerp(Vector3(-thigh,0,0),weight)
		arm.rotation=arm.rotation.lerp(Vector3(.38,0,side*.10),weight)
		elbow.rotation=elbow.rotation.lerp(Vector3(.92,0,0),weight)
