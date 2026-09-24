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
	if next=="run" and p.celebration!="": next="celebrate_"+p.celebration
	if next!=state:
		origin=previous.duplicate(); age=0; state=next
	age+=delta
	var joints: Array[Node3D]=p.kick_joints
	var count := joints.size()
	if delta<.1 and age<DURATION and origin.size()==count:
		var weight := smoothstep(0,DURATION,age)
		for i in range(count):
			var joint: Node3D=joints[i]
			joint.quaternion=origin[i].slerp(joint.quaternion,weight)
	if previous.size()!=count: previous.resize(count)
	for i in range(count): previous[i]=joints[i].quaternion
