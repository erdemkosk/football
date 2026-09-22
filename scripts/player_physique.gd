extends RefCounted
## Stable roster identity: changing a formation/kit never rolls a new body.
static func profile(club: int,member: int,is_keeper: bool=false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed=(club+1)*7919+(member+1)*104729
	var bounds := Vector2i(173,191)
	if is_keeper: bounds=Vector2i(186,198)
	elif member in [2,3,13]: bounds=Vector2i(183,195)
	elif member in [5,8,10,16]: bounds=Vector2i(167,181)
	elif member in [1,4,12]: bounds=Vector2i(173,185)
	var height := rng.randi_range(bounds.x,bounds.y)
	var bmi := rng.randf_range(21.0,24.8)
	var weight := clampi(roundi(pow(height/100.0,2)*bmi),58,96)
	return {"height_cm":height,"weight_kg":weight}
