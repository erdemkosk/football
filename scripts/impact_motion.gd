extends RefCounted
var yaw := 0.0
var local_direction := Vector3.FORWARD
var start: Array[Quaternion] = []

func begin(p) -> void:
	yaw=p.rig.rotation.y
	local_direction=p.impact_direction.rotated(Vector3.UP,-yaw)
	start.clear()
	for joint in p.kick_joints: start.append(joint.quaternion)

static func reach_hand(p,left: bool,point: Vector3,weight: float,elbow_down: bool=false) -> void:
	var arm: Node3D=p.left_arm if left else p.right_arm
	var elbow: Node3D=p.left_elbow if left else p.right_elbow
	var target: Vector3=p.spine.to_local(point)-arm.position
	var distance := clampf(target.length(),0.08,0.527)
	var angle := acos(clampf((0.24*0.24+distance*distance-0.29*0.29)/(0.48*distance),-1,1))
	var bend := -acos(clampf((distance*distance-0.24*0.24-0.29*0.29)/(2*0.24*0.29),-1,1))
	if elbow_down: angle=-angle; bend=-bend
	var rotation := Basis(Quaternion(Vector3.DOWN,target.normalized()))*Basis(Vector3.RIGHT,angle)
	arm.quaternion=arm.quaternion.slerp(rotation.get_rotation_quaternion(),weight)
	elbow.rotation.x=lerpf(elbow.rotation.x,bend,weight)

func apply(p) -> void:
	var progress: float=1-p.action_timer/p.impact_duration
	var entry := smoothstep(0,0.10,progress)
	var recover := smoothstep(0.53,1.0,progress)
	var hit := smoothstep(0,0.24,progress)*(1-recover)
	var falling: bool=p.pose=="fall"
	var force := lerpf(.65,1.15,clampf(p.impact_strength,0,1))
	var pitch := local_direction.z*hit*(1.15 if falling else 0.32)*force
	var roll := -local_direction.x*hit*(1.15 if falling else 0.26)*force
	var orientation := Basis(Vector3.UP,yaw)*Basis.from_euler(Vector3(pitch,0,roll))
	p.rig.basis=orientation.scaled_local(p.body_scale)
	if falling:
		var pelvis := lerpf(p.body_scale.y*0.88,0.32,hit)
		p.rig.position=Vector3(0,pelvis,0)-p.rig.basis*Vector3(0,0.87,0)
		p.body_collision.basis=orientation*Basis(Vector3.UP,-yaw)
		var capsule: CapsuleShape3D=p.body_collision.shape
		# Keep the changing capsule tangent to the turf. A fixed low centre
		# penetrated the ground mid-fall and made physics lift the whole player.
		p.body_collision.position.y=capsule.radius+(capsule.height*0.5-capsule.radius)*absf(p.body_collision.basis.y.y)
	else: p.rig.position.y-=hit*0.055
	p.spine.rotation=Vector3(local_direction.z*0.16*hit,local_direction.x*0.22*hit,-local_direction.x*0.08*hit)
	var support_left := local_direction.x<0
	for i in range(2):
		var leg: Node3D=p.left_leg if i==0 else p.right_leg
		var knee: Node3D=p.left_knee if i==0 else p.right_knee
		var support := (i==0)==support_left
		if not falling:
			# The free foot catches balance after the struck shoulder recoils.
			var catch_step := sin(smoothstep(.25,.95,progress)*PI)*force
			leg.rotation.z+=(-1.0 if i==0 else 1.0)*catch_step*.16
		leg.rotation.x=lerpf(leg.rotation.x,0.72 if support else -0.24,hit)
		knee.rotation.x=lerpf(knee.rotation.x,-0.95 if support else -0.62,hit)
		if falling and local_direction.z>0.35:
			leg.rotation.x=lerpf(leg.rotation.x,0.90 if support else 1.08,hit)
			knee.rotation.x=lerpf(knee.rotation.x,-1.10 if support else -1.30,hit)
		elif falling and local_direction.z< -0.35 and support:
			knee.rotation.x=lerpf(knee.rotation.x,-1.65,hit)
		if falling: leg.rotation.z=lerpf(leg.rotation.z,-local_direction.x*0.38,hit)
	p.left_arm.rotation=p.left_arm.rotation.lerp(Vector3(0.4,0,-1.1),hit)
	p.right_arm.rotation=p.right_arm.rotation.lerp(Vector3(0.4,0,1.1),hit)
	if falling:
		var brace := smoothstep(0.14,0.31,progress)*(1-smoothstep(0.64,0.9,progress))
		var direction: Vector3=p.impact_direction
		for side in [-1,1]:
			var arm: Node3D=p.left_arm if side<0 else p.right_arm
			var target: Vector3=arm.global_position+direction*0.08
			target.y=p.global_position.y+0.10
			reach_hand(p,side<0,target,brace)
		# One knee comes under the hips while the other boot takes weight.
		var rise := sin(smoothstep(0.48,1.0,progress)*PI)
		var knee: Node3D=p.left_knee if support_left else p.right_knee
		knee.rotation.x=lerpf(knee.rotation.x,-1.12,rise*0.65)
	if start.size()==p.kick_joints.size():
		for i in range(start.size()):
			var joint: Node3D=p.kick_joints[i]
			joint.quaternion=start[i].slerp(joint.quaternion,entry)
	# Visual bones cannot sink through the pitch, even during a side landing.
	var lowest: float=minf(p.left_knee.to_global(Vector3(0,-0.42,-0.05)).y,p.right_knee.to_global(Vector3(0,-0.42,-0.05)).y)
	lowest=minf(lowest,minf(p.left_hand.global_position.y,p.right_hand.global_position.y))
	if lowest<p.global_position.y+0.09: p.rig.position.y+=p.global_position.y+0.09-lowest
