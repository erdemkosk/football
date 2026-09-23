extends RefCounted
## Technique follows the incoming ball and the player's body, never a dice roll.
static func technique(game,p,point: Vector3,incoming: Vector3,aim: Vector3,time: float,bounced: bool) -> String:
	var height: float=point.y-p.position.y
	if bounced and height<.85: return "half_volley"
	var direction := (aim*Vector3(1,0,1)).normalized()
	if direction.length()<.1: direction=p.facing
	var offset: Vector3=(point-p.position)*Vector3(1,0,1)
	var running: float=(p.velocity*Vector3(1,0,1)).length()
	if height>1.15 and height<1.95 and time>=.16 and time<=.42 and offset.length()<.68 and p.facing.dot(direction)<-.45 and running<4.8 and p.energy>.4 and p.attributes.finishing>=72 and p.is_on_floor():
		var clear := true
		for other in game.players:
			if other==p or not other.visible or other.dismissed: continue
			if game.flat_distance(other.position,p.position)<1.65: clear=false; break
		if clear: return "bicycle"
	var lateral: float=absf(offset.dot(direction.cross(Vector3.UP)))
	var across: float=absf(incoming.normalized().dot(direction.cross(Vector3.UP)))
	if height>.72 and lateral>.18 and across>.55: return "side_volley"
	return "volley"
