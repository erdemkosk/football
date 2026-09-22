extends RefCounted
## Visual people keep their own lanes without becoming obstacles for the football.
const CLEARANCE := 1.12

static func outside_direction(at: Vector3) -> Vector3:
	return Vector3(1 if at.x>=0 else -1,0,0)

static func lane(point: Vector3) -> Vector3:
	if absf(point.z)<50.4:
		point.x=signf(point.x)*clampf(absf(point.x),32.55,35.18)
	return point

static func separate(point: Vector3,obstacles: Array[Vector3]) -> Vector3:
	point=lane(point)
	for obstacle in obstacles:
		var gap := (point-obstacle)*Vector3(1,0,1)
		if gap.length()<CLEARANCE:
			var direction := gap.normalized() if gap.length()>0.02 else outside_direction(obstacle)
			point=lane(obstacle+direction*CLEARANCE)
			# The advertising boards bound the outer lane. Go around in z
			# instead of pushing a person through the board or onto the pitch.
			var across := absf(point.x-obstacle.x)
			if across<CLEARANCE:
				var along := sqrt(CLEARANCE*CLEARANCE-across*across)
				if absf(point.z-obstacle.z)<along:
					point.z=obstacle.z+(1 if gap.z>=0 else -1)*along
			point.y=0
	return point

static func route(start: Vector3,target: Vector3,obstacles: Array[Vector3]) -> Vector3:
	target=separate(target,obstacles)
	for obstacle in obstacles:
		var near := Geometry3D.get_closest_point_to_segment(obstacle,start,target)
		if near.distance_to(obstacle)<CLEARANCE+0.12 and start.distance_to(obstacle)<3.8:
			# Follow a short arc around the person, including when crossing lanes
			# to pick up a ball on their other side. A fixed outward point deadlocks there.
			var from := start-obstacle
			var to := target-obstacle
			var angle := atan2(from.z,from.x)
			var turn := wrapf(atan2(to.z,to.x)-angle,-PI,PI)
			if absf(turn)>0.12:
				angle+=clampf(turn,-0.65,0.65)
				return lane(obstacle+Vector3(cos(angle),0,sin(angle))*(CLEARANCE+0.3))
	return target
