extends RefCounted
## Two-joint visual reach in the shoulder parent's space; no body/ball movement.
static func reach(arm: Node3D,elbow: Node3D,target: Vector3,pole: Vector3,weight: float,upper_length: float=.24,lower_length: float=.29) -> void:
	var offset := target-arm.position
	var distance := clampf(offset.length(),absf(upper_length-lower_length)+.02,upper_length+lower_length-.001)
	var direction := offset.normalized()
	if direction.length()<.1: return
	var bend := (pole-direction*pole.dot(direction)).normalized()
	if bend.length()<.1: bend=direction.cross(Vector3.RIGHT).normalized()
	var along := (upper_length*upper_length+distance*distance-lower_length*lower_length)/(2*distance)
	var joint := direction*along+bend*sqrt(maxf(0,upper_length*upper_length-along*along))
	var upper := Quaternion(Vector3.DOWN,joint.normalized())
	var lower := Quaternion(Vector3.DOWN,upper.inverse()*((direction*distance-joint).normalized()))
	arm.quaternion=arm.quaternion.slerp(upper,weight)
	elbow.quaternion=elbow.quaternion.slerp(lower,weight)
