extends RefCounted
const Impact = preload("res://scripts/impact_motion.gd")
var kind := ""
var age := 0.0
var duration := 1.0
var weight := 0.0
var live := true
var ball_position := Vector3.ZERO
var focus := Vector3.ZERO

func reset() -> void:
	kind=""; age=0; weight=0

func begin(value: String,point: Vector3) -> void:
	kind=value; focus=point; age=0; weight=0
	duration=1.25 if kind=="miss" else (0.85 if kind=="sorry" else 1.0)

func available(p) -> bool:
	return p.action_timer<=0 and p.kick_timer<=0 and p.receive_timer<=0 and p.shot_preparation<=0 and p.set_piece_pose=="" and p.celebration=="" and p.discipline_pose=="" and not p.saluting and not p.keeper

func update(p,delta: float) -> void:
	if kind=="": return
	age+=delta
	if not available(p):
		# A close-range miss can cross the line before the shot follow-through
		# ends. Keep that event briefly queued, without interrupting the kick.
		if weight==0 and age<0.65 and p.kick_timer>0: return
		reset(); return
	# Football always wins: a nearby loose rebound or fresh input
	# returns the arms to the live stride without holding the player's movement.
	if live and ((p.chosen and p.desired.length()>0.25) or p.position.distance_to(ball_position)<9): age=maxf(age,duration)
	elif live and p.desired.length()>0.25: duration=minf(duration,0.40)
	var target := 1.0 if age<duration else 0.0
	weight=move_toward(weight,target,delta*(5.5 if target>0 else 12.0))
	if age>=duration and weight<=0: reset()

func apply(p) -> void:
	if kind=="" or weight<=0 or not available(p): return
	var w := smoothstep(0,1,weight)
	if kind=="miss":
		for side in [-1,1]:
			var target: Vector3=p.head_joint.to_global(Vector3(side*0.16,0.26,-0.06))
			Impact.reach_hand(p,side<0,target,w)
	elif kind=="sorry":
		p.right_arm.rotation=p.right_arm.rotation.lerp(Vector3(0.30,0,2.4),w)
		p.right_elbow.rotation.x=lerpf(p.right_elbow.rotation.x,0.35,w)
	else:
		# Bring the palms together in front of the chest, then separate them.
		var gap := 0.058+0.11*(0.5+0.5*cos(age*21))
		for side in [-1,1]:
			var target: Vector3=p.spine.to_global(Vector3(side*gap,0.40,-0.38))
			Impact.reach_hand(p,side<0,target,w,true)
