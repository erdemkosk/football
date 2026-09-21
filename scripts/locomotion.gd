extends RefCounted
## Visual locomotion follows the physics body. It never delays an input, writes
## velocity or locks facing; shots, tackles and goalkeeper actions have priority.
const BOOT := Vector3(0,-0.42,-0.05)
const SOLE := 0.102
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

func available(p) -> bool:
	return p.action_timer<=0 and p.kick_timer<=0 and p.shot_preparation<=0 and p.set_piece_pose=="" and p.celebration=="" and p.discipline_pose=="" and not p.saluting and p.feint_time<=0

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
	var request: Vector3=p.desired*Vector3(1,0,1)
	var moving := request.length()>0.05
	var old_speed := previous_velocity.length()
	var deceleration := (old_speed-speed)/maxf(delta,0.001)
	var changed := moving and (previous_request.length()<0.05 or previous_request.normalized().dot(request.normalized())<0.64)
	var turning := changed and old_speed>2.0 and previous_velocity.normalized().dot(request.normalized())<0.58
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
	if moving: brake_latched=false
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
	anchor.y=p.global_position.y+SOLE

func apply_pose(p,amount: float,stride: float) -> void:
	if not available(p): return
	var lateral := smoothstep(0.2,0.85,absf(side))*(1-backward*0.45)
	var direction := signf(side)
	var reverse_stride := stride*lerpf(1.0,-0.62,backward)
	# Backpedalling has shorter reversed steps. Side steps open and gather the
	# feet while the chest keeps facing the opponent or the ball.
	for i in range(2):
		var leg: Node3D=p.left_leg if i==0 else p.right_leg
		var knee: Node3D=p.left_knee if i==0 else p.right_knee
		var sign_leg := -1.0 if i==0 else 1.0
		var phase := -stride*sign_leg
		leg.rotation.x=lerpf(0.1-reverse_stride*sign_leg*0.78*amount,0.13+phase*0.12*amount,lateral)
		leg.rotation.z=lerpf(sign_leg*0.035,sign_leg*0.18+stride*direction*0.20*amount,lateral)
		var lift := lerpf(maxf(0,-phase),maxf(0,phase),backward)
		knee.rotation.x=-0.19-lift*lerpf(1.08,0.68,lateral)*amount-lateral*0.1-backward*0.06
		if braking>0.01:
			leg.rotation.x=lerpf(leg.rotation.x,0.44 if i==plant_leg else -0.12,braking*0.78)
			knee.rotation.x=lerpf(knee.rotation.x,-0.58 if i==plant_leg else -0.42,braking*0.85)
		knee.rotation.x-=cut*0.16
	# Bounded pelvis shift transfers weight onto the outside support leg.
	var support_side := -1.0 if plant_leg==0 else 1.0
	p.rig.position.x=sin(p.motion_clock*2.0+p.number*0.8)*0.013*(1-amount)+support_side*cut*0.055
	p.rig.rotation.z=lerp_angle(p.rig.rotation.z,-side*0.08-cut_side*cut*0.12,maxf(lateral,cut)*0.55)
	p.rig.rotation.x=lerp_angle(p.rig.rotation.x,0.09,braking*0.65)
	p.spine.rotation.x=lerpf(p.spine.rotation.x,-0.22,backward*0.45+braking*0.35)
	p.spine.rotation.z=lerpf(p.spine.rotation.z,cut_side*cut*0.12,lateral*0.25+cut*0.6)
	var balance := maxf(lateral*0.65,maxf(braking,cut))
	p.left_arm.rotation.z=lerpf(p.left_arm.rotation.z,-0.52,balance)
	p.right_arm.rotation.z=lerpf(p.right_arm.rotation.z,0.52,balance)
	p.left_arm.rotation.x=lerpf(p.left_arm.rotation.x,-reverse_stride*0.34*amount,lateral*0.6+backward*0.5)
	p.right_arm.rotation.x=lerpf(p.right_arm.rotation.x,reverse_stride*0.34*amount,lateral*0.6+backward*0.5)

func finish_pose(p) -> void:
	if not available(p): return
	# Ground after shielding/jockeying bends the knees, too.
	var height := minf(p.left_knee.to_global(BOOT).y,p.right_knee.to_global(BOOT).y)
	p.rig.position.y-=height-p.global_position.y-SOLE
	plant_weight=0
	if plant_leg>=0 and plant_age<PLANT_TIME and p.is_on_floor():
		plant_weight=smoothstep(0,0.025,plant_age)
		var leg: Node3D=p.left_leg if plant_leg==0 else p.right_leg
		var knee: Node3D=p.left_knee if plant_leg==0 else p.right_knee
		var target: Vector3=p.rig.to_local(anchor)-leg.position
		# Begin recovery before the hip runs out of reach. Blend from the actual
		# last pose to the live stride, even if the physics body turns immediately.
		if (plant_age>0.03 and target.length()>0.73) or plant_age>0.085 or absf(anchor.y-p.global_position.y-SOLE)>0.15:
			plant_age=PLANT_TIME
			plant_weight=0
			release_age=0
			release_hip=last_hip
			release_knee=last_knee
		elif plant_weight>0:
			# Blend the contact point, not the hip and knee independently. Joint
			# interpolation can sweep the toe through the turf during release.
			var contact: Vector3=knee.to_global(BOOT).lerp(anchor,plant_weight)
			contact.y=maxf(contact.y,p.global_position.y+SOLE)
			solve_leg(leg,knee,p.rig.to_local(contact)-leg.position,1.0)
	if plant_leg>=0:
		var leg: Node3D=p.left_leg if plant_leg==0 else p.right_leg
		var knee: Node3D=p.left_knee if plant_leg==0 else p.right_knee
		if release_age<RELEASE_TIME:
			var recovery := smoothstep(0,RELEASE_TIME,release_age)
			leg.quaternion=release_hip.slerp(leg.quaternion,recovery)
			knee.quaternion=release_knee.slerp(knee.quaternion,recovery)
			# During recovery the other boot takes support. Only the visual pelvis
			# follows it; the CharacterBody and its collision capsule stay untouched.
			height=minf(p.left_knee.to_global(BOOT).y,p.right_knee.to_global(BOOT).y)
			p.rig.position.y-=height-p.global_position.y-SOLE
		last_hip=leg.quaternion
		last_knee=knee.quaternion
	feet.assign([p.left_knee.to_global(BOOT),p.right_knee.to_global(BOOT)])

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
	knee.rotation.x=lerpf(knee.rotation.x,bend,weight)
