extends RefCounted
## One planted leg, a height-aware striking leg and a short continuous recovery.
const BOOT := Vector3(0,-0.42,-0.05)
var foot := 1
var contact_time := 0.16
var duration := 0.52
var target := Vector3.ZERO
var aim := Vector3.FORWARD
var hit := false
var kind := "volley"
var start: Array[Quaternion] = []

func boot(p) -> Vector3:
	return (p.left_knee if foot==0 else p.right_knee).to_global(BOOT)

func begin(p,plan: Dictionary,direction: Vector3) -> void:
	target=plan.point; kind=plan.kind; hit=false
	foot=p.ball_actions.choose_foot(p,target)
	p.ball_actions.foot=foot
	aim=(direction*Vector3(1,0,1)).normalized()
	contact_time=clampf(plan.time,0.10,0.26); duration=contact_time+0.36
	start.clear()
	for joint in p.kick_joints: start.append(joint.quaternion)
	p.pose="volley"; p.action_timer=duration
	p.kick_timer=0; p.receive_timer=0; p.shot_preparation=0; p.shot_ready_blend=0
	p.facing=aim; p.energy=maxf(0,p.energy-0.024)
	var jump: float=clampf(plan.get("jump",0.0),0,3.6)
	if jump>0 and p.is_on_floor():
		p.velocity.y=jump
		p.header_airborne=true
		p.energy=maxf(0,p.energy-.008)

func apply(p) -> void:
	var age: float=duration-p.action_timer
	var entry := smoothstep(0,0.065,age)
	var swing := smoothstep(0,contact_time*0.85,age)
	if kind=="power": swing=smoothstep(contact_time*.44,contact_time*.96,age)
	var recover := smoothstep(contact_time+0.08,duration,age)
	var side := -1.0 if foot==0 else 1.0
	var high := smoothstep(0.5,1.5,target.y-p.position.y)
	# Counterbalance with the torso and arms; the support boot stays on the turf.
	var poses: Array[Vector3]=[
		Vector3(0.12,0,-0.04),Vector3(0.12,0,0.04),Vector3(-0.22,0,0),Vector3(-0.22,0,0),
		Vector3(0.06+high*0.20,-side*0.20*swing,-side*high*0.15),
		Vector3(-0.22,0,-0.70-high*0.25),Vector3(0.15,0,0.70+high*0.25),
		Vector3(0.70,0,0),Vector3(0.85,0,0)]
	for i in range(p.kick_joints.size()):
		var joint: Node3D=p.kick_joints[i]
		joint.quaternion=start[i].slerp(Quaternion.from_euler(poses[i]).slerp(joint.quaternion,recover),entry)
	p.rig.rotation.x=lerpf(p.rig.rotation.x,0,entry*(1-recover))
	p.rig.rotation.z=lerpf(p.rig.rotation.z,0,entry*(1-recover))
	var support=p.right_knee if foot==0 else p.left_knee
	if p.is_on_floor(): p.rig.position.y-=support.to_global(BOOT).y-p.global_position.y-0.102
	var point := target-aim*0.10
	if hit: point+=aim*smoothstep(contact_time,contact_time+0.14,age)*0.26+Vector3.UP*0.08
	var leg=p.left_leg if foot==0 else p.right_leg
	var knee=p.left_knee if foot==0 else p.right_knee
	p.locomotion.solve_leg(leg,knee,p.rig.to_local(point)-leg.position,swing*(1-recover))
	if kind=="power" and age<contact_time*.5:
		leg.rotation.x=-.68*sin(PI*age/(contact_time*.5))*entry
		knee.rotation.x=-.8*entry
	if kind=="outside":
		knee.rotation.y+=side*.38*swing*(1-recover)
		p.spine.rotation.y+=side*.22*swing*(1-recover)
	p.head_joint.rotation.x=lerpf(p.head_joint.rotation.x,0.14,entry*(1-recover))
