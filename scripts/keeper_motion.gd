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

func reset() -> void:
	kind=""; saved_at=-10; secured=false; start_pose.clear()

func rebound_ready(p) -> bool:
	var age: float=p.motion_clock-saved_at
	return age>=recovery and age<2.2 and p.is_on_floor()

func start(p,style: String,point: Vector3,second: bool=false) -> bool:
	if not p.keeper or (not second and (p.action_timer>0 or p.tackle_cooldown>0)): return false
	if second and not rebound_ready(p): return false
	kind=style; target=point; secured=false; foot=p.ball_actions.choose_foot(p,point)
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

func apply(p) -> void:
	if not p.pose.begins_with("keeper_") or p.action_timer<=0: return
	var age: float=duration-p.action_timer
	var entry := smoothstep(0,.11,age)
	var weight := entry*(1-smoothstep(duration*.56,duration,age))
	var side := -1.0 if foot==0 else 1.0
	if kind=="catch":
		# Meet chest-height deliveries with two cupped hands, then fold the ball
		# into the body. Actual glove proximity still decides the catch.
		p.spine.rotation.x=-.16
		var local: Vector3=p.spine.to_local(target)
		var reach := clampf(atan2(local.y-.40,maxf(.12,-local.z)), -.35,.80)
		p.left_arm.rotation=Vector3(1.20+reach,0,.20)
		p.right_arm.rotation=Vector3(1.20+reach,0,-.20)
		p.left_elbow.rotation.x=.35 if not secured else 1.10
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
			p.left_elbow.rotation.x=.85; p.right_elbow.rotation.x=.85
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
		var point: Vector3=p.spine.to_local(target) if not secured else Vector3(0,.26,-.24)
		preload("res://scripts/arm_pose.gd").reach(p.left_arm,p.left_elbow,point+Vector3(-.09,0,0),Vector3(-1,-.6,0),weight)
		preload("res://scripts/arm_pose.gd").reach(p.right_arm,p.right_elbow,point+Vector3(.09,0,0),Vector3(1,-.6,0),weight)
	var lowest: float=minf(p.left_knee.to_global(p.ball_actions.BOOT).y,p.right_knee.to_global(p.ball_actions.BOOT).y)
	p.rig.position.y+=maxf(0,p.global_position.y+p.boot_ground_height()-lowest)
