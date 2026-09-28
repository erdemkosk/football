extends RefCounted
## Save selection follows the keeper's existing delayed read. These poses do
## not enlarge the ball collider or guarantee a save.
var kind := ""
var duration := .8
var target := Vector3.ZERO
var foot := 1
var saved_at := -10.0
var recovery := .45
var secured := false
var start_pose: Array[Quaternion] = []
const Arm=preload("res://scripts/arm_pose.gd")
var landed_at:=-1.0
var brace_point:=Vector3.INF
var brace_weight:=0.0
var brace_left:=false
var command_at:=-10.0
var command_next:=0.0
var command_target:=Vector3.ZERO

func reset() -> void:
	kind=""; saved_at=-10; secured=false; start_pose.clear()
	begin_dive(); command_at=-10; command_next=0

func begin_dive() -> void:
	landed_at=-1; brace_point=Vector3.INF; brace_weight=0

func ground_contact(p) -> void:
	if p.action_timer>0 and p.pose in ["keeper_smother","keeper_rebound"]: return
	if p.pose!="dive" or p.action_timer<=0:
		landed_at=-1; brace_point=Vector3.INF; brace_weight=0; return
	if landed_at<0 and p.dive_launched and p.dive_duration-p.action_timer>.25 and p.is_on_floor(): landed_at=p.motion_clock

func slide_velocity(p) -> Vector3:
	if landed_at<0: return Vector3.ZERO
	var age: float=p.motion_clock-landed_at
	var wet: float=p.surface.wetness if is_instance_valid(p.surface) else 0.0
	var length:=lerpf(.20,.32,wet)
	return Vector3.RIGHT*p.dive_direction*minf(p.dive_speed*.24,.85)*(1-smoothstep(0,length,age))

func grip_target(p) -> Vector3:
	if not secured or saved_at<0 or not p.distribution_move.is_empty(): return p.hand_center()
	# The free palm can brace on the grass without pulling a secured ball down.
	var chest: Vector3=p.spine.to_global(Vector3(0,.30,-.39))
	return target.lerp(chest,smoothstep(0,.30,p.motion_clock-saved_at))

func direct_defence(p,point: Vector3,allowed: bool) -> void:
	if not allowed:
		command_at=-10; return
	if p.motion_clock>=command_next:
		command_target=point; command_at=p.motion_clock
		command_next=p.motion_clock+7.0+p.idle_habit*.6

func command_weight(p) -> float:
	if p.action_timer>0 or p.kick_timer>0 or p.set_piece_pose!="" or p.celebration!="" or p.prematch or secured: return 0
	var age: float=p.motion_clock-command_at
	return smoothstep(0,.18,age)*(1-smoothstep(.68,1.05,age))

func rebound_ready(p) -> bool:
	var age: float=p.motion_clock-saved_at
	return age>=recovery and age<2.2 and p.is_on_floor()

func start(p,style: String,point: Vector3,second: bool=false) -> bool:
	if not p.keeper or (not second and (p.action_timer>0 or p.tackle_cooldown>0)): return false
	if second and not rebound_ready(p): return false
	kind=style; target=point; secured=false; foot=p.ball_actions.choose_foot(p,point)
	brace_point=Vector3.INF; brace_weight=0; command_at=-10
	duration={"foot":.64,"spread":.82,"smother":1.05,"rebound":.85,"catch":.68}.get(style,.82)
	p.pose="keeper_"+style; p.action_timer=duration; p.tackle_cooldown=duration+.12
	p.kick_timer=0; p.receive_timer=0
	start_pose.clear()
	for joint in p.kick_joints: start_pose.append(joint.quaternion)
	return true

func saved(p) -> void:
	saved_at=p.motion_clock
	recovery=.72 if p.pose=="dive" else (.56 if kind in ["smother","rebound"] else .34)
	p.touch_cooldown=maxf(p.touch_cooldown,recovery)

func can_save(p,point: Vector3) -> bool:
	if p.motion_clock-saved_at<recovery: return false
	var age: float=duration-p.action_timer
	if age<.045 or age>duration*.7: return false
	var hands: float=minf(p.left_hand.global_position.distance_to(point),p.right_hand.global_position.distance_to(point))
	if kind in ["smother","rebound"]: return hands<.46 or p.spine.to_global(Vector3(0,.12,-.1)).distance_to(point)<.43
	var feet: float=minf(p.left_knee.to_global(p.ball_actions.BOOT).distance_to(point),p.right_knee.to_global(p.ball_actions.BOOT).distance_to(point))
	var torso: Vector3=Geometry3D.get_closest_point_to_segment(point,p.spine.to_global(Vector3(0,-.25,0)),p.spine.to_global(Vector3(0,.50,0)))
	# Torso radius includes the ball (the standing capsule already contacts at
	# about .56 m). Keep that physical block credited during a spread save.
	return hands<.43 or feet<.37 or torso.distance_to(point)<.60

func special(p) -> bool:
	return kind in ["punch","tip"] and p.pose in ["claim","dive"] and p.action_timer>0

func high_save(p,style: String,point: Vector3) -> void:
	kind=style; target=point; secured=false
	foot=0 if p.rig.to_local(point).x<0 else 1
	# A lateral dive rolls the near shoulder underneath the body. The upper
	# (opposite) arm reaches the high corner while the lower arm balances.
	if p.pose=="dive": foot=1-foot

func apply_high(p) -> void:
	var age: float=(.8 if p.pose=="claim" else p.dive_duration)-p.action_timer
	var weight := smoothstep(.035,.13,age)*(1-smoothstep(.56,.8,age))
	var point := target
	var after: float=p.motion_clock-saved_at
	if after<.3:
		point+=Vector3.UP*.17*smoothstep(0,.14,after)
		if kind=="punch": point+=p.facing*.18*smoothstep(0,.14,after)
	var local: Vector3=p.spine.to_local(point)
	if kind=="punch":
		p.spine.rotation.x-=.12*weight
		for side in [-1.0,1.0]:
			preload("res://scripts/arm_pose.gd").reach(p.left_arm if side<0 else p.right_arm,p.left_elbow if side<0 else p.right_elbow,local+Vector3(side*.045,0,0),Vector3(side,-.4,0),weight)
	else:
		var arm: Node3D=p.left_arm if foot==0 else p.right_arm
		var elbow: Node3D=p.left_elbow if foot==0 else p.right_elbow
		preload("res://scripts/arm_pose.gd").reach(arm,elbow,local,Vector3(-1 if foot==0 else 1,0,0),weight)
		var other: Node3D=p.right_arm if foot==0 else p.left_arm
		other.rotation=other.rotation.lerp(Vector3(.35,0,.95 if foot==0 else -.95),weight)
		(p.right_elbow if foot==0 else p.left_elbow).rotation.x=lerpf(.7,.95,weight)

func apply_save_pose(p) -> void:
	if special(p):
		var sole: float=minf(p.left_knee.to_global(p.ball_actions.BOOT).y,p.right_knee.to_global(p.ball_actions.BOOT).y)
		p.rig.position.y+=maxf(0,(p.global_position.y if p.pose=="claim" else 0.0)+p.boot_ground_height()-sole)
		apply_high(p)
		return
	if not p.pose.begins_with("keeper_") or p.action_timer<=0: return
	var age: float=duration-p.action_timer
	var entry := smoothstep(0,.11,age)
	var weight := entry*(1-smoothstep(duration*.56,duration,age))
	var gather := smoothstep(0,.32,p.motion_clock-saved_at) if secured else 0.0
	var side := -1.0 if foot==0 else 1.0
	if kind=="catch":
		# Meet chest-height deliveries with two cupped hands, then fold the ball
		# into the body. Actual glove proximity still decides the catch.
		p.spine.rotation.x=-.16
		var local: Vector3=p.spine.to_local(target)
		var reach := clampf(atan2(local.y-.40,maxf(.12,-local.z)), -.35,.80)
		p.left_arm.rotation=Vector3(1.20+reach,0,.20)
		p.right_arm.rotation=Vector3(1.20+reach,0,-.20)
		p.left_elbow.rotation.x=lerpf(.35,1.10,gather)
		p.right_elbow.rotation.x=p.left_elbow.rotation.x
	elif kind=="foot":
		p.spine.rotation=Vector3(-.18,-side*.22,side*.2)*weight
		p.left_arm.rotation=Vector3(.35,0,-.95*weight)
		p.right_arm.rotation=Vector3(.35,0,.95*weight)
		var leg: Node3D=p.left_leg if foot==0 else p.right_leg
		var knee: Node3D=p.left_knee if foot==0 else p.right_knee
		var point := target
		point.y=maxf(point.y-.04,p.position.y+.13)
		p.locomotion.solve_leg(leg,knee,p.rig.to_local(point)-leg.position,weight)
	elif kind=="spread":
		p.rig.position.y=lerpf(-.15,-.32,weight)
		p.left_leg.rotation=Vector3(.30,0,-.46*weight)
		p.right_leg.rotation=Vector3(.30,0,.46*weight)
		p.left_knee.rotation.x=-.65; p.right_knee.rotation.x=-.65
		p.left_arm.rotation=Vector3(.50,0,-1.45*weight)
		p.right_arm.rotation=Vector3(.50,0,1.45*weight)
		p.left_elbow.rotation.x=.25; p.right_elbow.rotation.x=.25
		p.spine.rotation.x=-.26
	else:
		# A low scoop followed by a protected curl around the ball; the second
		# attempt is a shorter push from the knees, not another upright dive.
		p.rig.position.y=lerpf(-.15,-.56,weight)
		p.spine.rotation.x=-.85*weight
		p.left_leg.rotation=Vector3(.6,0,-.16)
		p.right_leg.rotation=Vector3(.3,0,.20)
		p.left_knee.rotation.x=-2.20*weight; p.right_knee.rotation.x=-1.95*weight
		p.left_arm.rotation=Vector3(1.10,0,.28)
		p.right_arm.rotation=Vector3(1.10,0,-.28)
		p.left_elbow.rotation.x=.18; p.right_elbow.rotation.x=.18
		if kind=="rebound":
			p.rig.position.x=side*.10*weight
			p.spine.rotation.z=side*.22*weight
			var reach_arm: Node3D=p.left_arm if foot==0 else p.right_arm
			reach_arm.rotation.x=1.30
			var brace_arm: Node3D=p.right_arm if foot==0 else p.left_arm
			brace_arm.rotation.x=.95
		if secured:
			p.left_elbow.rotation.x=lerpf(.18,.85,gather); p.right_elbow.rotation.x=p.left_elbow.rotation.x
		# Stand through one loaded knee instead of unfolding both legs together.
		# An unsecured keeper keeps the near glove available for the rebound.
		var rising := sin(smoothstep(duration*.56,duration,age)*PI)
		var support_knee: Node3D=p.left_knee if foot==0 else p.right_knee
		support_knee.rotation.x-=rising*.45
		p.spine.rotation.z+=side*rising*.10
		if not secured:
			var glove: Node3D=p.left_arm if foot==0 else p.right_arm
			glove.rotation.x+=rising*.20
	if start_pose.size()==p.kick_joints.size():
		for i in range(p.kick_joints.size()): p.kick_joints[i].quaternion=start_pose[i].slerp(p.kick_joints[i].quaternion,entry)
	if kind=="catch":
		var point: Vector3=p.spine.to_local(target).lerp(Vector3(0,.26,-.24),gather)
		preload("res://scripts/arm_pose.gd").reach(p.left_arm,p.left_elbow,point+Vector3(-.09,0,0),Vector3(-1,-.6,0),weight)
		preload("res://scripts/arm_pose.gd").reach(p.right_arm,p.right_elbow,point+Vector3(.09,0,0),Vector3(1,-.6,0),weight)
	var lowest: float=minf(p.left_knee.to_global(p.ball_actions.BOOT).y,p.right_knee.to_global(p.ball_actions.BOOT).y)
	p.rig.position.y+=maxf(0,p.global_position.y+p.boot_ground_height()-lowest)

func apply(p) -> void:
	apply_save_pose(p)
	brace_weight=0
	var recovering: bool=p.action_timer>0 and (p.pose=="dive" or p.pose in ["keeper_smother","keeper_rebound"])
	if recovering:
		var progress: float=smoothstep(.90,p.dive_duration,p.dive_duration-p.action_timer) if p.pose=="dive" else smoothstep(duration*.52,duration,duration-p.action_timer)
		if p.pose!="dive":
			# Fold a loaded knee before lowering the hip. Merely reaching from
			# the standing scoop leaves the support glove floating in the air.
			var load:=smoothstep(.02,.22,progress)*(1-smoothstep(.60,1.0,progress))
			p.rig.position.y=lerpf(p.rig.position.y,-.61,load)
			p.spine.rotation.x=lerpf(p.spine.rotation.x,-1.25,load)
			var leg: Node3D=p.left_leg if foot==0 else p.right_leg
			var knee: Node3D=p.left_knee if foot==0 else p.right_knee
			leg.rotation.x=lerpf(leg.rotation.x,1.35,load)
			knee.rotation.x=lerpf(knee.rotation.x,-2.65,load)
			var other_leg: Node3D=p.right_leg if foot==0 else p.left_leg
			other_leg.rotation.x=lerpf(other_leg.rotation.x,1.15,load)
			var other: Node3D=p.right_knee if foot==0 else p.left_knee
			other.rotation.x=lerpf(other.rotation.x,-2.70,load)
			var sole: float=minf(p.left_knee.to_global(p.ball_actions.BOOT).y,p.right_knee.to_global(p.ball_actions.BOOT).y)
			p.rig.position.y+=maxf(0,p.global_position.y+p.boot_ground_height()-sole)
		brace_weight=smoothstep(.06,.28,progress)*(1-smoothstep(.56,.90,progress))
		brace_left=p.dive_direction*cos(p.dive_yaw)<0 if p.pose=="dive" else foot==0
		if brace_weight>.01:
			var arm: Node3D=p.left_arm if brace_left else p.right_arm
			var elbow: Node3D=p.left_elbow if brace_left else p.right_elbow
			if not brace_point.is_finite():
				brace_point=arm.global_position+p.facing*.13
				brace_point.y=.055
			Arm.reach(arm,elbow,p.spine.to_local(brace_point),Vector3(-1 if brace_left else 1,-.5,.1),brace_weight,.275,.30)
	if secured and saved_at>=0 and p.distribution_move.is_empty():
		var point: Vector3=p.spine.to_local(grip_target(p))
		var gather:=smoothstep(0,.12,p.motion_clock-saved_at)
		for side in [-1,1]:
			var weight:=gather*(1-brace_weight if (side<0)==brace_left else 1.0)
			Arm.reach(p.left_arm if side<0 else p.right_arm,p.left_elbow if side<0 else p.right_elbow,point+Vector3(side*.17,0,0),Vector3(side,-.5,0),weight,.275,.30)
	if brace_weight>.2:
		var hand: Node3D=p.left_hand if brace_left else p.right_hand
		if hand.global_position.y<.045:
			var floor_point: Vector3=hand.global_position; floor_point.y=.055
			Arm.reach(p.left_arm if brace_left else p.right_arm,p.left_elbow if brace_left else p.right_elbow,p.spine.to_local(floor_point),Vector3(-1 if brace_left else 1,-.5,.1),1,.275,.30)
	var command:=command_weight(p)
	if command>0:
		var toward: Vector3=p.spine.to_local(command_target)
		var side: float=-1 if toward.x<0 else 1
		var point:=Vector3(side*.60,.38,-.24)
		point.z-=maxf(0,sin((p.motion_clock-command_at)*8))*.05
		Arm.reach(p.left_arm if side<0 else p.right_arm,p.left_elbow if side<0 else p.right_elbow,point,Vector3(side,-.3,0),command,.275,.30)
