extends RefCounted
## Stable upper-body signatures; the boot contact and physics remain authoritative.
const Arm=preload("res://scripts/arm_pose.gd")
const LABELS:=["ÇEVİK","GÜÇLÜ","SAKİN","AKICI"]

static func apply(p) -> void:
	if p.official or p.action_timer>0 or p.discipline_pose!="" or p.celebration!="": return
	var style: int=p.idle_habit
	if p.prematch and p.saluting:
		var wave: float=sin(p.motion_clock*5.0+p.appearance_id*.31)
		match style:
			0: # A short open-handed wave.
				p.right_arm.rotation=Vector3(.18,0,2.30+wave*.10); p.right_elbow.rotation.x=.65
			1: # A hand over the badge.
				Arm.reach(p.right_arm,p.right_elbow,Vector3(-.12,.34,-.24),Vector3(1,-.7,0),1)
			2: # Two restrained claps in front of the chest.
				for side in [-1,1]:
					Arm.reach(p.left_arm if side<0 else p.right_arm,p.left_elbow if side<0 else p.right_elbow,Vector3(side*(.06+.04*(wave+1)),.38,-.35),Vector3(side,-.5,0),1)
			3:
				p.right_arm.rotation=Vector3(.55,0,1.65); p.right_elbow.rotation.x=1.65
		return
	if p.keeper or p.prematch or p.protecting or p.jockeying or not p.skill_move.is_empty() or p.set_piece_pose!="": return
	var ready: float=p.shot_ready_blend if p.kick_timer<=0 else 0.0
	var receive: float=smoothstep(0,.08,p.receive_timer)*smoothstep(0,.10,p.receive_duration-p.receive_timer) if p.kick_timer<=0 else 0.0
	var weight:=maxf(ready,receive*.7)
	if weight<=0: return
	var spread: float=[.10,.28,.04,.18][style]*weight
	p.left_arm.rotation.z-=spread; p.right_arm.rotation.z+=spread
	var elbow: float=[.22,-.12,.08,.16][style]*weight
	p.left_elbow.rotation.x+=elbow; p.right_elbow.rotation.x+=elbow
	# The shoulder character does not move the contact leg or the torso capsule.
	p.left_arm.rotation.y+=[.10,-.06,.03,-.13][style]*weight
	p.right_arm.rotation.y-=[.10,-.06,.03,-.13][style]*weight
