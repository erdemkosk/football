extends RefCounted
## Contact-aware footwork. Physics chooses the contact; this follows its outcome.
const BOOT := Vector3(0,-0.42,-0.05)
var foot := 1
var kick_turn := 0.0
var difficulty := 0.0
var receive_foot := 1
var receive_offset := Vector3(0.18,0.22,-0.45)
var incoming := Vector3.ZERO
var firmness := 0.0
var stretch := 0.0
var receive_speed := 0.0
var receive_start: Array[Quaternion] = []
var control_grace := 0.0
var settle_time := 0.0
var contact_cooldown := 0.0
var contact_pending := false
var contact_target := Vector3.ZERO
var contact_age := 0.0
var contact_windup := .055
var contact_origin := Vector3.ZERO
var release_age := 1.0
var release_hip := Quaternion.IDENTITY
var release_knee := Quaternion.IDENTITY
var support_foot := -1
var support_anchor := Vector3.ZERO
var support_age := 1.0
var support_duration := .18
var support_weight := 0.0
var receive_direction := Vector3.ZERO
var receive_distance := 0.0

func reset(p) -> void:
	foot=1; receive_foot=1; kick_turn=0; difficulty=0
	control_grace=0; contact_cooldown=0; settle_time=0
	p.receive_timer=0; p.receive_style=""
	receive_start.clear()
	contact_pending=false; support_foot=-1; support_age=1; support_weight=0; release_age=1
	receive_direction=Vector3.ZERO; receive_distance=0
	p.motion_transition.reset()

func update(delta: float) -> void:
	control_grace=maxf(0,control_grace-delta)
	settle_time=maxf(0,settle_time-delta)
	contact_cooldown=maxf(0,contact_cooldown-delta)
	support_age+=delta
	release_age+=delta

func choose_foot(p,point: Vector3) -> int:
	var local: Vector3=p.rig.to_local(point)
	# A clearly lateral ball belongs to that foot; central balls use the nearer
	# boot in the current stride, with a dead band to avoid rapid foot swapping.
	if absf(local.x)>0.09: return 0 if local.x<0 else 1
	var left: float=p.left_knee.to_global(BOOT).distance_to(point)
	var right: float=p.right_knee.to_global(BOOT).distance_to(point)
	return (0 if left<right else 1) if absf(left-right)>0.10 else int(p.attributes.preferred_foot)

func prepare_kick(p,point: Vector3,direction: Vector3,pressure: float=0) -> void:
	foot=choose_foot(p,point)
	var forward: Vector3=-p.rig.global_basis.z.normalized()
	var aim := (direction*Vector3(1,0,1)).normalized()
	kick_turn=clampf(forward.signed_angle_to(aim,Vector3.UP),-1.05,1.05) if aim.length()>0.1 else 0.0
	var reach: float=Vector2(point.x-p.position.x,point.z-p.position.z).length()
	var balance: float=p.body_language.balance_strength if p.body_language.balance_age<0.45 else p.locomotion.cut*0.5
	difficulty=clampf(absf(kick_turn)*0.35+pressure*0.35+balance*0.35+maxf(0,reach-0.9)*0.35+(1-p.energy)*0.15,0,1)
	plant_support(p,1-foot,.19)

func begin_receive(p,point: Vector3,velocity: Vector3,reach: float) -> void:
	receive_foot=choose_foot(p,point)
	foot=receive_foot
	receive_offset=p.rig.to_local(point)
	receive_offset.x=clampf(receive_offset.x,-0.62,0.62)
	receive_offset.z=clampf(receive_offset.z,-0.72,0.28)
	incoming=velocity.rotated(Vector3.UP,-p.rig.rotation.y)
	firmness=clampf(velocity.length()/19,0,1)
	stretch=clampf(reach,0,1)
	receive_speed=Vector2(p.velocity.x,p.velocity.z).length()
	receive_start.clear()
	for joint in p.kick_joints: receive_start.append(joint.quaternion)
	receive_direction=Vector3.ZERO; receive_distance=0
	plant_support(p,1-receive_foot,.14)

func apply_receive(p) -> void:
	var progress: float=1-p.receive_timer/maxf(p.receive_duration,0.01)
	var entry := smoothstep(0,0.12,progress)
	var hold := 1-smoothstep(0.46,1.0,progress)
	var side := -1.0 if receive_foot==0 else 1.0
	if p.receive_style=="chest":
		# Open to meet it, then yield backwards to take the pace off the ball.
		p.spine.rotation.x=lerpf(p.spine.rotation.x,0.18-firmness*0.28*smoothstep(0.15,0.55,progress),hold)
		p.left_arm.rotation=p.left_arm.rotation.lerp(Vector3(0.72,0,-0.72),hold)
		p.right_arm.rotation=p.right_arm.rotation.lerp(Vector3(0.72,0,0.72),hold)
	else:
		var leg: Node3D=p.left_leg if receive_foot==0 else p.right_leg
		var knee: Node3D=p.left_knee if receive_foot==0 else p.right_knee
		if p.receive_style=="thigh":
			leg.rotation=leg.rotation.lerp(Vector3(0.95-firmness*0.24*smoothstep(0.2,0.6,progress),-side*0.14,side*0.10),hold)
			knee.rotation.x=lerpf(knee.rotation.x,-1.24,hold)
		else:
			var target := receive_offset
			# A firm pass draws the boot back with the incoming ball. On the run,
			# the toe opens into the next stride instead of stopping both legs.
			target+=incoming.normalized()*firmness*0.19*smoothstep(0.15,0.65,progress)
			target.z-=minf(receive_speed/9,1)*0.10*progress
			target+=receive_direction.rotated(Vector3.UP,-p.rig.rotation.y)*minf(.25,receive_distance*.23)*smoothstep(.12,.7,progress)
			target.y=clampf(target.y,0.13,0.42)
			target.x=lerpf(side*0.16,target.x,0.75)
			var hip_start: Quaternion=leg.quaternion
			var knee_start: Quaternion=knee.quaternion
			p.locomotion.solve_leg(leg,knee,target-leg.position,1.0)
			leg.quaternion=hip_start.slerp(leg.quaternion,hold)
			knee.quaternion=knee_start.slerp(knee.quaternion,hold)
			leg.rotation.y+=-side*0.24*hold*(1-stretch)
		p.spine.rotation=p.spine.rotation.lerp(Vector3(-0.12-stretch*0.18,-side*stretch*0.15,-side*stretch*0.10),hold*0.7)
		p.left_arm.rotation.z=lerpf(p.left_arm.rotation.z,-0.40-stretch*0.45,hold)
		p.right_arm.rotation.z=lerpf(p.right_arm.rotation.z,0.40+stretch*0.45,hold)
	if receive_direction.length_squared()>.1:
		var turn: float=p.facing.signed_angle_to(receive_direction,Vector3.UP)
		p.spine.rotation.y+=clampf(turn,-1.1,1.1)*.24*hold*smoothstep(0,.25,progress)
	if receive_start.size()==p.kick_joints.size():
		for i in range(p.kick_joints.size()):
			var joint: Node3D=p.kick_joints[i]
			joint.quaternion=receive_start[i].slerp(joint.quaternion,entry)

func mirror_poses(poses: Array[Vector3]) -> Array[Vector3]:
	if foot==1: return poses
	var result: Array[Vector3]=[]
	for i in [1,0,3,2,4,6,5,8,7]: result.append(poses[i]*Vector3(1,-1,-1))
	return result

func plant_support(p,leg: int,duration: float) -> void:
	support_foot=leg; support_age=0; support_duration=duration
	var knee: Node3D=p.left_knee if leg==0 else p.right_knee
	support_anchor=knee.to_global(BOOT)
	support_anchor.y=p.global_position.y+p.locomotion.SOLE

func start_contact(p,point: Vector3,windup: float) -> void:
	contact_pending=true; contact_target=point; contact_age=0; contact_windup=windup
	release_age=1
	var knee: Node3D=p.left_knee if foot==0 else p.right_knee
	contact_origin=knee.to_global(BOOT)

func finish_contact(p) -> void:
	contact_pending=false; release_age=0
	var leg: Node3D=p.left_leg if foot==0 else p.right_leg
	var knee: Node3D=p.left_knee if foot==0 else p.right_knee
	release_hip=leg.quaternion; release_knee=knee.quaternion
	p.kick_timer=minf(p.kick_timer,p.kick_duration*.84)

func finish_pose(p) -> void:
	if p.action_timer>0 or p.set_piece_pose!="" or p.celebration!="" or not p.skill_move.is_empty():
		support_foot=-1; support_weight=0; return
	if p.kick_timer<=0 and p.receive_timer<=0: return
	if contact_pending:
		var approach: Vector3=(contact_target-p.global_position)*Vector3(1,0,1)
		var step_offset: Vector3=p.global_basis.inverse()*approach.normalized()*clampf(approach.length()-.65,0,.18)
		var entry := smoothstep(0,contact_windup,contact_age)
		p.rig.position.x=lerpf(p.rig.position.x,step_offset.x,entry)
		p.rig.position.z=lerpf(p.rig.position.z,step_offset.z,entry)
	# Support follows an absolute turf point, with an early anatomical release
	# for a fast runner. Nothing modifies the CharacterBody or freezes input.
	support_weight=0
	if support_foot>=0 and support_age<support_duration:
		var support_leg: Node3D=p.left_leg if support_foot==0 else p.right_leg
		var support_knee_node: Node3D=p.left_knee if support_foot==0 else p.right_knee
		var current: Vector3=support_knee_node.to_global(BOOT)
		var weight := smoothstep(0,.025,support_age)*(1-smoothstep(support_duration*.6,support_duration,support_age))
		var vertical: float=clampf((support_anchor.y-current.y)/p.body_scale.y,-.10,.10)
		p.rig.position.y+=vertical*weight
		var local: Vector3=p.rig.to_local(support_anchor)-support_leg.position
		if local.length()<.78 and p.global_position.y<.15:
			support_weight=weight
			p.locomotion.solve_leg(support_leg,support_knee_node,local,weight)
			p.spine.rotation.z+=(-.04 if support_foot==0 else .04)*weight
		else: support_foot=-1
	var leg: Node3D=p.left_leg if foot==0 else p.right_leg
	var knee: Node3D=p.left_knee if foot==0 else p.right_knee
	if contact_pending:
		var entry := smoothstep(0,contact_windup,contact_age)
		var approach: Vector3=(contact_target-p.global_position)*Vector3(1,0,1)
		var point := contact_target-approach.normalized()*.13
		point.y=maxf(p.global_position.y+.12,point.y-.04)
		point=contact_origin.lerp(point,entry)
		p.locomotion.solve_leg(leg,knee,p.rig.to_local(point)-leg.position,1)
	elif release_age<.075:
		var recover := smoothstep(0,.075,release_age)
		leg.quaternion=release_hip.slerp(leg.quaternion,recover)
		knee.quaternion=release_knee.slerp(knee.quaternion,recover)
