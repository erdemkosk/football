extends RefCounted
## Visual locomotion follows the physics body. It never delays an input, writes
## velocity or locks facing; shots, tackles and goalkeeper actions have priority.
const BOOT := Vector3(0,-0.42,-0.05)
const PLANT_TIME := 0.18
const RELEASE_TIME := 0.12
var side := 0.0
var backward := 0.0
var braking := 0.0
var cut := 0.0
var cut_side := 1.0
var mode := "run"
var plant_age := PLANT_TIME
var plant_leg := -1
var plant_weight := 0.0
var anchor := Vector3.ZERO
var feet: Array[Vector3] = []
var previous_request := Vector3.ZERO
var previous_position := Vector3.ZERO
var sampled := false
var brake_latched := false
var cooldown := 0.0
var release_age := RELEASE_TIME
var release_hip := Quaternion.IDENTITY
var release_knee := Quaternion.IDENTITY
var last_hip := Quaternion.IDENTITY
var last_knee := Quaternion.IDENTITY
var last_pelvis := 0.0
var release_pelvis := 0.0
var adjustment := 0.0
var adjustment_side := 0.0
var stop_age := 1.0
var stop_leg := -1

func reset() -> void:
	side=0; backward=0; braking=0; cut=0
	mode="run"
	plant_age=PLANT_TIME; plant_leg=-1; plant_weight=0
	feet.clear()
	previous_request=Vector3.ZERO
	sampled=false
	brake_latched=false
	cooldown=0
	release_age=RELEASE_TIME
	adjustment=0; adjustment_side=0; stop_age=1; stop_leg=-1

func available(p) -> bool:
	return p.action_timer<=0 and p.kick_timer<=0 and p.receive_timer<=0 and p.shot_preparation<=0 and p.set_piece_pose=="" and p.celebration=="" and p.discipline_pose=="" and not p.saluting and p.feint_time<=0

func update(p,delta: float,previous_velocity: Vector3) -> void:
	var velocity: Vector3=p.velocity*Vector3(1,0,1)
	var speed := velocity.length()
	if sampled and p.position.distance_to(previous_position)>maxf(1.0,speed*delta*3+0.1): reset()
	previous_position=p.position
	sampled=true
	if not available(p):
		reset()
		return
	cooldown=maxf(0,cooldown-delta)
	plant_age=minf(PLANT_TIME,plant_age+delta)
	release_age=minf(RELEASE_TIME,release_age+delta)
	cut=move_toward(cut,0,delta*4.5)
	adjustment=move_toward(adjustment,0,delta*4)
	var request: Vector3=p.desired*Vector3(1,0,1)
	var moving := request.length()>0.05
	var old_speed := previous_velocity.length()
	var deceleration := (old_speed-speed)/maxf(delta,0.001)
	var changed := moving and (previous_request.length()<0.05 or previous_request.normalized().dot(request.normalized())<0.64)
	var turning := changed and old_speed>2.0 and previous_velocity.normalized().dot(request.normalized())<0.58
	if moving and old_speed>2 and previous_request.length()>.05:
		var angle := previous_request.signed_angle_to(request,Vector3.UP)
		if absf(angle)>.12 and absf(angle)<.9:
			adjustment=maxf(adjustment,smoothstep(.12,.75,absf(angle)))
			adjustment_side=-signf(angle)
	if turning and cooldown<=0:
		var angle := previous_velocity.signed_angle_to(request,Vector3.UP)
		cut_side=-1.0 if angle>0 else 1.0
		cut=clampf(old_speed/6.0,0.4,1.0)
		plant(p,0 if cut_side>0 else 1)
		cooldown=0.22
	var brake_target := smoothstep(2.5,11.0,deceleration)*smoothstep(0.1,2.5,speed)*(1-cut)
	if not moving and speed>0.25: brake_target=maxf(brake_target,smoothstep(0.25,4.0,speed))
	braking=lerpf(braking,brake_target,1-exp(-delta*20))
	if not moving and old_speed>2.5 and not brake_latched and cooldown<=0:
		var front := 0
		if feet.size()==2 and (feet[1]-feet[0]).dot(previous_velocity)>0: front=1
		plant(p,front)
		brake_latched=true
		stop_age=0
		stop_leg=1-plant_leg
	# A second, shorter support step absorbs the remaining coast. A new input
	# cancels it immediately, without touching velocity or the running phase.
	if moving:
		brake_latched=false; stop_age=1; stop_leg=-1
	elif stop_age<.42:
		var before := stop_age
		stop_age+=delta
		if before<.23 and stop_age>=.23 and stop_leg>=0 and speed>.35:
			plant(p,stop_leg)
	previous_request=request
	var local: Vector3=velocity.rotated(Vector3.UP,-p.rig.rotation.y)
	var direction := local/maxf(speed,0.001)
	var moving_blend := smoothstep(0.15,1.1,speed)
	side=lerpf(side,direction.x*moving_blend,1-exp(-delta*18))
	backward=lerpf(backward,smoothstep(0.12,0.75,direction.z)*moving_blend,1-exp(-delta*18))
	mode="cut" if cut>0.15 else ("brake" if braking>0.25 else ("back" if backward>0.5 else ("side" if absf(side)>0.55 else "run")))

func plant(p,leg: int) -> void:
	# If the outside boot is mid-swing, pivot on the boot already bearing
	# weight instead of forcing a floating foot down with an impossible reach.
	if feet.size()==2 and feet[leg].y-feet[1-leg].y>0.035: leg=1-leg
	plant_leg=leg
	plant_age=0
	release_age=RELEASE_TIME
	var hip: Node3D=p.left_leg if leg==0 else p.right_leg
	var knee: Node3D=p.left_knee if leg==0 else p.right_knee
	last_hip=hip.quaternion
	last_knee=knee.quaternion
	anchor=feet[leg] if feet.size()==2 else knee.to_global(BOOT)
	anchor.y=p.global_position.y+p.boot_ground_height()

func apply_pose(p,amount: float,stride: float) -> void:
	if not available(p): return
	var rig: Node3D=p.rig
	var spine: Node3D=p.spine
	var left_arm: Node3D=p.left_arm
	var right_arm: Node3D=p.right_arm
	var gait_width: float=p.gait_width
	var lateral := smoothstep(0.2,0.85,absf(side))*(1-backward*0.45)
	var direction := signf(side)
	var reverse_stride := stride*lerpf(1.0,-0.62,backward)*(1-adjustment*.22)
	# Backpedalling has shorter reversed steps. Side steps open and gather the
	# feet while the chest keeps facing the opponent or the ball.
	for i in range(2):
		var leg: Node3D=p.left_leg if i==0 else p.right_leg
		var knee: Node3D=p.left_knee if i==0 else p.right_knee
		var sign_leg := -1.0 if i==0 else 1.0
		var phase := -stride*sign_leg
		var leg_rotation:=leg.rotation
		leg_rotation.x=lerpf(0.1-reverse_stride*sign_leg*0.78*amount,0.13+phase*0.12*amount,lateral)
		leg_rotation.z=lerpf(sign_leg*0.035*gait_width,sign_leg*0.18*gait_width+stride*direction*0.20*amount,lateral)
		var lift := lerpf(maxf(0,-phase),maxf(0,phase),backward)
		var knee_rotation:=knee.rotation
		knee_rotation.x=-0.19-lift*lerpf(1.08,0.68,lateral)*amount-lateral*0.1-backward*0.06
		if braking>0.01:
			leg_rotation.x=lerpf(leg_rotation.x,0.44 if i==plant_leg else -0.12,braking*0.78)
			knee_rotation.x=lerpf(knee_rotation.x,-0.58 if i==plant_leg else -0.42,braking*0.85)
		knee_rotation.x-=cut*0.16+adjustment*.06
		leg.rotation=leg_rotation; knee.rotation=knee_rotation
	# Bounded pelvis shift transfers weight onto the outside support leg.
	var support_side := -1.0 if plant_leg==0 else 1.0
	rig.position.x=sin(p.motion_clock*2.0+p.number*0.8)*0.013*(1-amount)+support_side*cut*0.055
	# Compress into the support step, then let ground IK release the loaded foot.
	var load:=sin(clampf(plant_age/PLANT_TIME,0,1)*PI)*cut
	rig.position.y-=load*.045
	var rig_rotation := rig.rotation
	rig_rotation.z=lerp_angle(rig_rotation.z,-side*0.08-cut_side*cut*0.12-adjustment_side*adjustment*.055,maxf(adjustment,maxf(lateral,cut))*0.55)
	rig_rotation.x=lerp_angle(rig_rotation.x,0.09,braking*0.65)
	rig.rotation=rig_rotation
	# The free leg takes a short catch step while the supporting knee loads.
	if braking>.25 and plant_leg>=0:
		var free_leg: Node3D=p.right_leg if plant_leg==0 else p.left_leg
		free_leg.rotation.x+=sin(clampf(plant_age/PLANT_TIME,0,1)*PI)*braking*.16
	var spine_rotation := spine.rotation
	spine_rotation.x=lerpf(spine_rotation.x,-0.22,backward*0.45+braking*0.35)
	spine_rotation.z=lerpf(spine_rotation.z,cut_side*cut*0.12,lateral*0.25+cut*0.6)
	spine_rotation.y=lerpf(spine_rotation.y,-cut_side*cut*.16,cut*.7)
	spine.rotation=spine_rotation
	var balance := maxf(lateral*0.65,maxf(braking,cut))
	var left_rotation := left_arm.rotation
	var right_rotation := right_arm.rotation
	left_rotation.z=lerpf(left_rotation.z,-0.52,balance)
	right_rotation.z=lerpf(right_rotation.z,0.52,balance)
	left_rotation.x=lerpf(left_rotation.x,-reverse_stride*0.34*amount,lateral*0.6+backward*0.5)
	right_rotation.x=lerpf(right_rotation.x,reverse_stride*0.34*amount,lateral*0.6+backward*0.5)
	left_arm.rotation=left_rotation; right_arm.rotation=right_rotation

func finish_pose(p) -> void:
	if not available(p): return
	# Ground after shielding/jockeying bends the knees, too.
	var height := minf(p.left_knee.to_global(BOOT).y,p.right_knee.to_global(BOOT).y)
	p.rig.position.y-=height-p.global_position.y-p.boot_ground_height()
	plant_weight=0
	if plant_leg>=0 and plant_age<PLANT_TIME and p.is_on_floor():
		# Shorter legs need a gentler load-in for the same world-space running speed.
		plant_weight=smoothstep(0,0.035,plant_age)
		var leg: Node3D=p.left_leg if plant_leg==0 else p.right_leg
		var knee: Node3D=p.left_knee if plant_leg==0 else p.right_knee
		var target: Vector3=p.rig.to_local(anchor)-leg.position
		# Different stride lengths can arrive on a straighter support knee.
		# Lower the visual pelvis a little before asking that leg to bear weight.
		if target.length()>.72 and plant_age<.065:
			p.rig.position.y-=clampf((target.length()-.71)*1.5,0,.12)*plant_weight
			target=p.rig.to_local(anchor)-leg.position
		# Begin recovery before the hip runs out of reach. Blend from the actual
		# last pose to the live stride, even if the physics body turns immediately.
		if (plant_age>0.03 and target.length()>0.72) or plant_age>0.085 or absf(anchor.y-p.global_position.y-p.boot_ground_height())>0.15:
			plant_age=PLANT_TIME
			plant_weight=0
			release_age=0
			release_hip=last_hip
			release_knee=last_knee
			release_pelvis=last_pelvis
		elif plant_weight>0:
			# Blend the contact point, not the hip and knee independently. Joint
			# interpolation can sweep the toe through the turf during release.
			var contact: Vector3=knee.to_global(BOOT).lerp(anchor,plant_weight)
			contact.y=maxf(contact.y,p.global_position.y+p.boot_ground_height())
			solve_leg(leg,knee,p.rig.to_local(contact)-leg.position,1.0)
	if plant_leg>=0:
		var leg: Node3D=p.left_leg if plant_leg==0 else p.right_leg
		var knee: Node3D=p.left_knee if plant_leg==0 else p.right_knee
		if release_age<RELEASE_TIME:
			var recovery := smoothstep(0,RELEASE_TIME,release_age)
			p.rig.position.y=lerpf(release_pelvis,p.rig.position.y,recovery)
			leg.quaternion=release_hip.slerp(leg.quaternion,recovery)
			knee.quaternion=release_knee.slerp(knee.quaternion,recovery)
			# During recovery the other boot takes support. Only the visual pelvis
			# follows it; the CharacterBody and its collision capsule stay untouched.
	# Pelvis compression must not push the free boot through the turf.
	var floor_y: float=p.global_position.y+p.boot_ground_height()
	if feet.size()!=2: feet.resize(2)
	for i in range(2):
		var leg: Node3D=p.left_leg if i==0 else p.right_leg
		var knee: Node3D=p.left_knee if i==0 else p.right_knee
		var point: Vector3=knee.to_global(BOOT)
		if point.y<floor_y-.002:
			point.y=floor_y
			solve_leg(leg,knee,p.rig.to_local(point)-leg.position,1)
			# IK changed this knee; refresh only this foot before sharing the result.
			point=knee.to_global(BOOT)
		feet[i]=point
	if plant_leg>=0:
		last_hip=(p.left_leg if plant_leg==0 else p.right_leg).quaternion
		last_knee=(p.left_knee if plant_leg==0 else p.right_knee).quaternion
	last_pelvis=p.rig.position.y

func solve_leg(leg: Node3D,knee: Node3D,target: Vector3,weight: float) -> void:
	# Two-bone IK, including the boot's forward offset, in the rig's local space.
	var upper := 0.33
	var lower := Vector2(0.42,0.05).length()
	var reach := clampf(target.length(),0.18,upper+lower-0.003)
	var spread := atan2(target.x,-target.y)
	var plane := target.rotated(Vector3.BACK,-spread)
	var aim := atan2(-plane.z,-plane.y)
	var hip := aim+acos(clampf((upper*upper+reach*reach-lower*lower)/(2*upper*reach),-1,1))
	var bend := -acos(clampf((reach*reach-upper*upper-lower*lower)/(2*upper*lower),-1,1))-atan2(0.05,0.42)
	var rotation := Basis(Vector3.BACK,spread)*Basis(Vector3.RIGHT,hip)
	leg.quaternion=leg.quaternion.slerp(Quaternion(rotation),weight)
	# A quaternion carried over from a turning touch can decompose to a 180°
	# Z rotation. Replacing only Euler X then points the boot into the air.
	# Solve the complete hinge orientation before any deliberate ankle twist.
	knee.quaternion=knee.quaternion.slerp(Quaternion(Vector3.RIGHT,bend),weight)
