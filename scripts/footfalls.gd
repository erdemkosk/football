extends RefCounted
## Read the rendered boots after all IK. A lifted boot must touch down before
## it can make another step; cadence and audio never advance the player.
const BOOT := Vector3(0,-.42,-.05)
var lifted: Array[bool] = [false,false]
var previous := Vector3.INF
var sampled := false
var cooldown := 0.0

func reset() -> void:
	lifted=[false,false]; sampled=false; cooldown=0

func sample(p,delta: float) -> void:
	var surface=p.surface
	if not is_instance_valid(surface): reset(); return
	var game=surface.game
	var active: bool=game.state in ["playing","restart","set_piece"] and not game.menu_match.running and p.visible and p.is_on_floor() and p.action_timer<=0 and p.celebration=="" and p.set_piece_pose=="" and p.skill_move.is_empty()
	if not active or delta>.1 or (sampled and p.position.distance_to(previous)>2):
		reset(); previous=p.position
		return
	cooldown=maxf(0,cooldown-delta)
	var speed := Vector2(p.velocity.x,p.velocity.z).length()
	var floor_y: float=p.global_position.y+p.boot_ground_height()
	for i in range(2):
		var knee: Node3D=p.left_knee if i==0 else p.right_knee
		var point: Vector3=knee.to_global(BOOT)
		var height: float=point.y-floor_y
		if height>.035: lifted[i]=true
		elif height<.018 and lifted[i]:
			lifted[i]=false
			if sampled and speed>.6 and cooldown<=0:
				cooldown=.13
				point.y=p.global_position.y
				surface.foot_contact(p,point)
	sampled=true
	previous=p.position
