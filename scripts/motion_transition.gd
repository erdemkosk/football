extends RefCounted
## Cross-fade only the visual joints at action boundaries. Physics, the current
## running phase and input processing never wait for a pose to finish.
var state := ""
var previous: Array[Quaternion] = []
var origin: Array[Quaternion] = []
var age := 1.0
const DURATION := .09

func reset() -> void:
	state=""; previous.clear(); origin.clear(); age=1

func apply(p,delta: float) -> void:
	var next: String=p.pose if p.action_timer>0 else ("skill" if not p.skill_move.is_empty() else ("kick" if p.kick_timer>0 else ("receive" if p.receive_timer>0 else "run")))
	if next!=state:
		origin=previous.duplicate(); age=0; state=next
	age+=delta
	if delta<.1 and age<DURATION and origin.size()==p.kick_joints.size():
		var weight := smoothstep(0,DURATION,age)
		for i in range(p.kick_joints.size()):
			p.kick_joints[i].quaternion=origin[i].slerp(p.kick_joints[i].quaternion,weight)
	previous.clear()
	for joint in p.kick_joints: previous.append(joint.quaternion)
