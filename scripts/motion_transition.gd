extends RefCounted
## Cross-fade only the visual joints at action boundaries. Physics, the current
## running phase and input processing never wait for a pose to finish.
var state := ""
var previous: Array[Quaternion] = []
var origin: Array[Quaternion] = []
var age := 1.0
var gait: Array[Quaternion] = []
const DURATION := .14

func reset() -> void:
	state=""; previous.clear(); origin.clear(); gait.clear(); age=1

func capture_gait(p) -> void:
	# Sample this frame's moving legs before the receiving/kicking overlays.
	if p.kick_timer<=0 and p.receive_timer<=0: return
	if gait.size()!=4: gait.resize(4)
	for i in range(4): gait[i]=p.kick_joints[i].quaternion

func release_legs(p) -> void:
	if gait.size()!=4 or p.action_timer>0 or not p.skill_move.is_empty() or p.ball_actions.contact_pending: return
	var moving := smoothstep(.8,4.5,Vector2(p.velocity.x,p.velocity.z).length())
	var weight := 0.0
	if p.kick_timer>0:
		# The boot-contact solver still has final say. Only after impact can the
		# next stride overtake the upper-body follow-through.
		var after_swing: float=maxf(0,p.kick_duration-p.kick_timer-p.kick_duration*.16)
		weight=smoothstep(.075,.20,minf(p.ball_actions.release_age,after_swing))*moving
	elif p.receive_timer>0 and p.receive_style=="foot":
		var progress: float=1-p.receive_timer/maxf(.01,p.receive_duration)
		weight=smoothstep(.30,.72,progress)*moving
	if weight<=0: return
	for i in range(4):
		p.kick_joints[i].quaternion=p.kick_joints[i].quaternion.slerp(gait[i],weight)

func apply(p,delta: float) -> void:
	var next: String=p.pose if p.action_timer>0 else ("skill" if not p.skill_move.is_empty() else ("kick" if p.kick_timer>0 else ("receive" if p.receive_timer>0 else "run")))
	if next=="run" and p.celebration!="": next="celebrate_"+p.celebration
	if next!=state:
		origin=previous.duplicate(); age=0; state=next
	age+=delta
	var joints: Array[Node3D]=p.kick_joints
	var count := joints.size()
	if delta<.1 and age<DURATION and origin.size()==count:
		for i in range(count):
			# Recover the stride quickly; let the chest and arms settle separately.
			var duration := (.065 if i<4 else DURATION) if next=="run" else .09
			var weight := smoothstep(0,duration,age)
			var joint: Node3D=joints[i]
			joint.quaternion=origin[i].slerp(joint.quaternion,weight)

func capture(p) -> void:
	# Remember the final rendered pose, including boot, hand and ground IK.
	# Capturing before those overlays made the next transition start elsewhere.
	var joints: Array[Node3D]=p.kick_joints
	if previous.size()!=joints.size(): previous.resize(joints.size())
	for i in range(joints.size()): previous[i]=joints[i].quaternion
