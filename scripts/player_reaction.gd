extends RefCounted
const Impact = preload("res://scripts/impact_motion.gd")
var kind := ""
var age := 0.0
var duration := 1.0
var hold := 0.0
var weight := 0.0
var live := true
var ball_position := Vector3.ZERO
var focus := Vector3.ZERO

func reset() -> void:
	kind=""; age=0; hold=0; weight=0

func begin(value: String,point: Vector3) -> void:
	kind=value; focus=point; age=0; weight=0
	duration={"appeal":1.5,"captain":1.35,"miss":1.25,"sorry":0.85}.get(kind,1.0)
	# Let the wide/over finish be seen before the hands-on-hips pose.
	hold=1.45 if kind=="miss" and live else 0.0

func available(p) -> bool:
	return p.action_timer<=0 and p.kick_timer<=0 and p.receive_timer<=0 and p.shot_preparation<=0 and p.set_piece_pose=="" and p.celebration=="" and p.discipline_pose=="" and not p.saluting and not p.keeper

func update(p,delta: float) -> void:
	if kind=="": return
	age+=delta
	var play_on: bool=live and ((p.chosen and p.desired.length()>0.25) or p.position.distance_to(ball_position)<9)
	if age<hold:
		if play_on: reset()
		return
	if not available(p):
		# A close-range miss can cross the line before the shot follow-through
		# ends. Keep that event briefly queued, without interrupting the kick.
		if weight==0 and age<hold+0.65 and p.kick_timer>0: return
		reset(); return
	# Football always wins: a nearby loose rebound or fresh input
	# returns the arms to the live stride without holding the player's movement.
	var pose_age := age-hold
	if play_on: pose_age=duration
	elif live and p.desired.length()>0.25: duration=minf(duration,0.40)
	var target := 1.0 if pose_age<duration else 0.0
	weight=move_toward(weight,target,delta*(5.5 if target>0 else 12.0))
	if pose_age>=duration and weight<=0: reset()

func apply(p) -> void:
	if kind=="" or weight<=0 or not available(p): return
	var w := smoothstep(0,1,weight)
	if kind=="miss":
		p.left_arm.rotation=p.left_arm.rotation.lerp(Vector3(0.58,0.32,-1.18),w)
		p.right_arm.rotation=p.right_arm.rotation.lerp(Vector3(0.58,-0.32,1.18),w)
		p.left_elbow.rotation.x=lerpf(p.left_elbow.rotation.x,1.38,w)
		p.right_elbow.rotation.x=lerpf(p.right_elbow.rotation.x,1.38,w)
		p.spine.rotation.x=lerpf(p.spine.rotation.x,-0.22,w)
	elif kind=="appeal":
		p.left_arm.rotation=p.left_arm.rotation.lerp(Vector3(0.12,0.08,-2.08),w)
		p.right_arm.rotation=p.right_arm.rotation.lerp(Vector3(0.12,-0.08,2.08),w)
		p.left_elbow.rotation.x=lerpf(p.left_elbow.rotation.x,0.08,w)
		p.right_elbow.rotation.x=lerpf(p.right_elbow.rotation.x,0.08,w)
		p.spine.rotation.x=lerpf(p.spine.rotation.x,0.10,w)
	elif kind=="captain":
		var pulse := 0.5+0.5*sin(age*7.2)
		p.left_arm.rotation=p.left_arm.rotation.lerp(Vector3(1.08,0.18,-0.88-pulse*0.10),w)
		p.right_arm.rotation=p.right_arm.rotation.lerp(Vector3(1.08,-0.18,0.88+pulse*0.10),w)
		p.left_elbow.rotation.x=lerpf(p.left_elbow.rotation.x,0.16,w)
		p.right_elbow.rotation.x=lerpf(p.right_elbow.rotation.x,0.16,w)
		p.spine.rotation.x=lerpf(p.spine.rotation.x,-0.06,w)
	elif kind=="sorry":
		p.right_arm.rotation=p.right_arm.rotation.lerp(Vector3(0.30,0,2.4),w)
		p.right_elbow.rotation.x=lerpf(p.right_elbow.rotation.x,0.35,w)
	else:
		# Bring the palms together in front of the chest, then separate them.
		var gap := 0.058+0.11*(0.5+0.5*cos(age*21))
		for side in [-1,1]:
			var target: Vector3=p.spine.to_global(Vector3(side*gap,0.40,-0.38))
			Impact.reach_hand(p,side<0,target,w,true)
