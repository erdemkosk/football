extends RefCounted
const Arm = preload("res://scripts/arm_pose.gd")
## Small, continuous player-specific gestures, layered over the live stride.
var kind := ""
var age := 0.0

func apply(p,delta: float) -> void:
	if p.celebration!=kind: kind=p.celebration; age=0
	age+=delta
	if p.action_timer>0 or kind not in ["fist","badge","crowd","heart","wings"]: return
	var weight := smoothstep(0,.24,age)
	var pulse := sin(age*5.2+p.shirt_number*.43)
	var left := Vector3(.15,0,-.35)
	var right := Vector3(.15,0,.35)
	var elbows := Vector2(.5,.5)
	match kind:
		"fist":
			right=Vector3(.3+pulse*.22,-.12,2.1+pulse*.15)
			elbows.y=1.25+pulse*.25
			p.spine.rotation.z=lerpf(p.spine.rotation.z,-.06*pulse,weight)
		"badge":
			right=Vector3(.9,-.55,-.48)
			elbows.y=1.65+maxf(0,pulse)*.18
			left=Vector3(.22,0,-.42)
		"crowd":
			right=Vector3(2.15,.15,.40+pulse*.06)
			elbows.y=.18
			left=Vector3(.5,0,-.8); elbows.x=1.2
		"heart":
			left=Vector3(.78,0,.34); right=Vector3(.78,0,-.34)
			elbows=Vector2(1.9,1.9)
		"wings":
			left=Vector3(-.1,0,-1.30-pulse*.04)
			right=Vector3(-.1,0,1.30+pulse*.04)
			elbows=Vector2(.26,.26)
	p.left_arm.rotation=p.left_arm.rotation.lerp(left,weight)
	p.right_arm.rotation=p.right_arm.rotation.lerp(right,weight)
	p.left_elbow.rotation.x=lerpf(p.left_elbow.rotation.x,elbows.x,weight)
	p.right_elbow.rotation.x=lerpf(p.right_elbow.rotation.x,elbows.y,weight)
	if kind=="badge":
		Arm.reach(p.right_arm,p.right_elbow,Vector3(-.11,.34,-.23-maxf(0,pulse)*.04),Vector3(1,-.7,0),weight)
	elif kind=="heart":
		Arm.reach(p.left_arm,p.left_elbow,Vector3(-.055,.36,-.33),Vector3(-1,-.4,0),weight)
		Arm.reach(p.right_arm,p.right_elbow,Vector3(.055,.36,-.33),Vector3(1,-.4,0),weight)
