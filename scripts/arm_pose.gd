extends RefCounted
## Two-joint visual reach in the shoulder parent's space; no body/ball movement.
static func reach(arm: Node3D,elbow: Node3D,target: Vector3,pole: Vector3,weight: float) -> void:
	var offset := target-arm.position
	var distance := clampf(offset.length(),.07,.529)
	var direction := offset.normalized()
	if direction.length()<.1: return
	var bend := (pole-direction*pole.dot(direction)).normalized()
	if bend.length()<.1: bend=direction.cross(Vector3.RIGHT).normalized()
	var along := (.24*.24+distance*distance-.29*.29)/(2*distance)
	var joint := direction*along+bend*sqrt(maxf(0,.24*.24-along*along))
	var upper := Quaternion(Vector3.DOWN,joint.normalized())
	var lower := Quaternion(Vector3.DOWN,upper.inverse()*((direction*distance-joint).normalized()))
	arm.quaternion=arm.quaternion.slerp(upper,weight)
	elbow.quaternion=elbow.quaternion.slerp(lower,weight)
