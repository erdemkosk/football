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
var body_yaw := 0.0
var follow_position := Vector3.ZERO

func boot(p) -> Vector3:
	return (p.left_knee if foot==0 else p.right_knee).to_global(BOOT)

func begin(p,plan: Dictionary,direction: Vector3) -> void:
	target=plan.point; kind=plan.kind; hit=false
	body_yaw=p.rig.rotation.y; follow_position=p.position
	foot=p.ball_actions.choose_foot(p,target)
	p.ball_actions.foot=foot
	aim=(direction*Vector3(1,0,1)).normalized()
	contact_time=clampf(plan.time,0.10,0.42); duration=contact_time+(0.42 if kind=="power" else 0.36)
	if kind=="bicycle": duration=contact_time+.72
	start.clear()
	for joint in p.kick_joints: start.append(joint.quaternion)
	p.pose="volley"; p.action_timer=duration
	p.kick_timer=0; p.receive_timer=0; p.shot_preparation=0; p.shot_ready_blend=0
	if kind!="bicycle": p.facing=aim
	p.energy=maxf(0,p.energy-(.065 if kind=="bicycle" else .024))
	var jump: float=clampf(plan.get("jump",0.0),0,3.6)
	if jump>0 and p.is_on_floor():
		p.velocity.y=jump
		p.header_airborne=true
		p.energy=maxf(0,p.energy-.008)

func apply(p) -> void:
	if kind=="bicycle": apply_bicycle(p); return
	var age: float=duration-p.action_timer
	var entry := smoothstep(0,0.065,age)
	var swing := smoothstep(0,contact_time*0.85,age)
	if kind=="power": swing=smoothstep(contact_time*.44,contact_time*.96,age)
	var recover := smoothstep(contact_time+(0.16 if kind=="power" else 0.08),duration,age)
	var side := -1.0 if foot==0 else 1.0
	var high := smoothstep(0.5,1.5,target.y-p.position.y)
	var drop := 0.07*swing*(1.0-recover)*entry if kind=="power" else 0.0
	# Counterbalance with the torso and arms; the support boot stays on the turf.
	var poses: Array[Vector3]=[
		Vector3(0.12,0,-0.04),Vector3(0.12,0,0.04),Vector3(-0.22,0,0),Vector3(-0.22,0,0),
		Vector3(0.06+high*0.20,-side*0.20*swing,-side*high*0.15),
		Vector3(-0.22,0,-0.70-high*0.25),Vector3(0.15,0,0.70+high*0.25),
		Vector3(0.70,0,0),Vector3(0.85,0,0)]
	for i in range(p.kick_joints.size()):
		var joint: Node3D=p.kick_joints[i]
		joint.quaternion=start[i].slerp(Quaternion.from_euler(poses[i]).slerp(joint.quaternion,recover),entry)
	p.rig.rotation.x=lerpf(p.rig.rotation.x,0.22*drop/maxf(0.001,0.07),entry*(1-recover))
	p.rig.rotation.z=lerpf(p.rig.rotation.z,0,entry*(1-recover))
	var support=p.right_knee if foot==0 else p.left_knee
	if p.is_on_floor(): p.rig.position.y-=support.to_global(BOOT).y-p.global_position.y-p.boot_ground_height()+drop
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
	elif kind=="side_volley":
		p.spine.rotation.z+=side*.24*swing*(1-recover)
		p.spine.rotation.y+=side*.34*swing*(1-recover)
		knee.rotation.y+=side*.14*swing*(1-recover)
	elif kind=="half_volley":
		p.spine.rotation.x-=.13*swing*(1-recover)
		support.rotation.x-=.18*swing*(1-recover)
	p.head_joint.rotation.x=lerpf(p.head_joint.rotation.x,0.14,entry*(1-recover))

func apply_bicycle(p) -> void:
	var age: float=duration-p.action_timer
	var entry := smoothstep(0,contact_time*.85,age)
	var recover := smoothstep(contact_time+.18,duration,age)
	var weight := entry*(1-recover)
	# Pivot around the pelvis: the body leans back while the real CharacterBody
	# jumps and lands normally. No horizontal teleport or extra contact radius.
	var roll := 1.62*weight
	p.rig.basis=(Basis(Vector3.UP,body_yaw)*Basis(Vector3.RIGHT,roll)).scaled_local(p.body_scale)
	p.rig.position=Vector3(0,p.body_scale.y*.88,0)-p.rig.basis*Vector3(0,.88,0)
	p.spine.rotation=Vector3(-.12,0,0)*weight
	p.left_arm.rotation=Vector3(.2,0,-1.12*weight)
	p.right_arm.rotation=Vector3(.2,0,1.12*weight)
	p.left_elbow.rotation.x=.65; p.right_elbow.rotation.x=.65
	var leg=p.left_leg if foot==0 else p.right_leg
	var knee=p.left_knee if foot==0 else p.right_knee
	var other=p.right_leg if foot==0 else p.left_leg
	var support=p.right_knee if foot==0 else p.left_knee
	other.rotation=Vector3(-.95*weight,0,0); support.rotation=Vector3(-1.0*weight,0,0)
	var point := target
	if hit: point+=p.position-follow_position+aim*.20*smoothstep(contact_time,contact_time+.18,age)
	p.locomotion.solve_leg(leg,knee,p.rig.to_local(point)-leg.position,weight)
	p.head_joint.rotation.x=-.15*weight
