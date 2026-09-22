extends RefCounted
## Dismissal is immediate in the match rules; its presentation leaves on foot.
const Player = preload("res://scripts/footballer.gd")
var game
var exits: Array[Dictionary] = []

func reset() -> void:
	for entry in exits:
		if is_instance_valid(entry.actor): entry.actor.queue_free()
	exits.clear()
	clear_poses()

func clear_poses() -> void:
	for p in game.players: p.discipline_pose=""

func begin(index: int,victim: int = -1) -> void:
	var source=game.players[index]
	# Keep the same face, hair, kit and shirt number without leaving a playable
	# body in the roster, passing search, offside line or substitution system.
	var actor=Player.new()
	actor.team=source.team
	actor.number=source.number
	actor.keeper=source.keeper
	actor.display_name=source.display_name
	actor.name="DismissedPlayer%d" % index
	game.add_child(actor)
	actor.transform=source.transform
	actor.apply_identity(source.identity())
	actor.apply_kit(game.clubs.kit(source.team))
	actor.rig.transform=source.rig.transform
	actor.head_joint.rotation=source.head_joint.rotation
	for j in range(actor.eye_joints.size()): actor.eye_joints[j].rotation=source.eye_joints[j].rotation
	for j in range(actor.kick_joints.size()): actor.kick_joints[j].rotation=source.kick_joints[j].rotation
	actor.energy=source.energy
	actor.surface=game.weather
	actor.prematch=true
	actor.facing=source.facing
	actor.velocity=source.velocity
	actor.pose=source.pose
	actor.action_timer=source.action_timer
	actor.impact_duration=source.impact_duration
	actor.impact_direction=source.impact_direction
	actor.impact_strength=source.impact_strength
	actor.impact_motion.yaw=source.impact_motion.yaw
	actor.impact_motion.local_direction=source.impact_motion.local_direction
	actor.impact_motion.start=source.impact_motion.start.duplicate()
	actor.slide_duration=source.slide_duration
	actor.dive_duration=source.dive_duration
	actor.dive_yaw=source.dive_yaw
	actor.dive_direction=source.dive_direction
	actor.dive_height=source.dive_height
	actor.dive_speed=source.dive_speed
	actor.dive_launched=source.dive_launched
	actor.collision_layer=0
	actor.collision_mask=3
	actor.marker.visible=false
	actor.discipline_pose="protest"
	var center: Vector3=source.position*Vector3(1,0,1)
	var rivals: Array[int]=nearby(1-source.team,center,index)
	var teammates: Array[int]=nearby(source.team,center,index)
	var opponent: int=rivals[0] if not rivals.is_empty() else -1
	if victim in rivals and game.flat_distance(game.players[victim].position,center)<8: opponent=victim
	var direction := Vector3.FORWARD
	if opponent>=0:
		direction=(game.players[opponent].position-center)*Vector3(1,0,1)
		if direction.length()<0.1: direction=Vector3.FORWARD
		direction=direction.normalized()
	var helpers: Array[int]=[]
	if not teammates.is_empty(): helpers.append(teammates[0])
	for rival in rivals:
		if rival!=opponent: helpers.append(rival); break
	exits.append({actor=actor,index=index,center=center,direction=direction,opponent=opponent,
		helpers=helpers,phase="card",age=0.0,pushed=false,gate=0})
	game.charging=false
	game.charge=0
	game.cancel_pass()
	game.controller.clear_shot_aim()
	game.match_camera.snap=true

func nearby(team: int,point: Vector3,excluded: int) -> Array[int]:
	var result: Array[int]=[]
	for i in range(game.players.size()):
		var p=game.players[i]
		if i!=excluded and p.team==team and p.visible and not p.dismissed and not p.keeper:
			result.append(i)
	result.sort_custom(func(a,b): return game.flat_distance(game.players[a].position,point)<game.flat_distance(game.players[b].position,point))
	return result

func blocks_restart() -> bool:
	for entry in exits:
		if entry.phase!="exit" or entry.actor.position.x<33.3: return true
	return false

func confrontation() -> Dictionary:
	for entry in exits:
		if entry.phase!="exit": return entry
	return {}

func calming() -> bool:
	var entry := confrontation()
	return not entry.is_empty() and entry.phase in ["confront","separate"]

func update(delta: float) -> bool:
	if exits.is_empty() or game.state in ["paused","replay","setup","ceremony"]: return false
	var blocked := blocks_restart()
	var active := confrontation()
	if blocked:
		# Let the dead ball keep bouncing and rolling. Only football decisions and
		# the restart collector wait for the referee to restore order.
		for p in game.players:
			if not p.visible: continue
			p.desired=Vector3.ZERO
			p.sprinting=false
			p.chosen=false
			p.shot_preparation=0
			p.kick_timer=0
			p.set_piece_pose=""
			p.discipline_pose=""
		if not active.is_empty(): choreograph(active,delta)
		for p in game.players:
			if not p.visible: continue
			p.stamina_free_movement=true
			p.step(delta,5.8)
			p.stamina_free_movement=false
			if p.discipline_pose!="" and not active.is_empty(): face(p,active.center,delta)
	for entry in exits.duplicate():
		if entry.phase=="exit": walk_out(entry,delta)
		else:
			var actor=entry.actor
			actor.stamina_free_movement=true
			actor.step(delta,3.2)
			var look: Vector3=entry.center+entry.direction*2 if entry.phase!="card" else game.referees.actors[0].position
			face(actor,look,delta)
	return blocked

func choreograph(entry: Dictionary,delta: float) -> void:
	entry.age+=delta
	var actor=entry.actor
	var center: Vector3=entry.center
	var direction: Vector3=entry.direction
	var tangent := direction.cross(Vector3.UP)
	var separating: bool=entry.phase=="separate"
	var opponent=game.players[entry.opponent] if entry.opponent>=0 else null
	if opponent!=null and (not opponent.visible or opponent.dismissed): opponent=null
	actor.desired=((center-direction*(0.7 if separating else 0))-actor.position)*Vector3(1,0,1)
	actor.discipline_pose="shove" if entry.phase=="confront" else "protest"
	actor.discipline_age=entry.age
	if opponent!=null:
		var target: Vector3=center+direction*(2.3 if separating else 1.12)
		opponent.desired=((target-opponent.position)*Vector3(1,0,1)).limit_length(1)
		opponent.discipline_pose="protest"
	for h in range(entry.helpers.size()):
		var helper=game.players[entry.helpers[h]]
		if not helper.visible or helper.dismissed: continue
		var target: Vector3=center+direction*0.65+tangent*((-1 if h==0 else 1)*(0.68 if separating else 2.3))
		helper.desired=((target-helper.position)*Vector3(1,0,1)).limit_length(1)
		helper.discipline_pose="separate" if separating else "protest"
	if entry.phase=="card":
		# Do not leave before the red card, including the preceding second yellow.
		game.rules.card_time=maxf(game.rules.card_time,1.0)
		var gathered: bool=opponent==null or game.flat_distance(opponent.position,actor.position)<1.65
		if game.referees.card_stage=="" and entry.age>1.2 and (gathered or entry.age>12):
			entry.phase="confront" if opponent!=null and gathered else "separate"
			entry.age=0
	elif entry.phase=="confront":
		if entry.age>=0.28 and not entry.pushed:
			entry.pushed=true
			if opponent!=null and game.flat_distance(opponent.position,actor.position)<1.75:
				opponent.receive_impact(direction,0.22)
				game.audio.contact("body_hit",0.24,0.65)
		if entry.age>0.85: entry.phase="separate"; entry.age=0
	elif entry.phase=="separate" and entry.age>1.8:
		entry.phase="exit"
		entry.age=0
		actor.discipline_pose="dismissed"
		clear_poses()
		game.match_camera.snap=true

func walk_out(entry: Dictionary,delta: float) -> void:
	var actor=entry.actor
	var targets: Array[Vector3]=[Vector3(33.8,0,clampf(entry.center.z,-46,46)),Vector3(35.0,0,0),Vector3(46.0,0,0)]
	var target: Vector3=targets[entry.gate]
	if game.flat_distance(actor.position,target)<0.5:
		entry.gate+=1
		if entry.gate>=targets.size():
			actor.queue_free()
			exits.erase(entry)
			return
		target=targets[entry.gate]
	target=game.set_pieces.recovery.around_goal(actor.position,target)
	var offset: Vector3=(target-actor.position)*Vector3(1,0,1)
	actor.desired=offset.limit_length(1)
	# Depart around standing footballers instead of passing through them or
	# waiting forever behind a frozen restart formation. The ball is excluded.
	for p in game.players:
		if not p.visible: continue
		var gap: Vector3=(actor.position-p.position)*Vector3(1,0,1)
		var distance := gap.length()
		if distance>0.01 and distance<1.8 and offset.dot(-gap)>0:
			var tangent := Vector3(-offset.z,0,offset.x).normalized()
			if tangent.dot(gap)<0: tangent=-tangent
			actor.desired+=tangent*(1.8-distance)*1.8
	actor.stamina_free_movement=true
	actor.step(delta,6.8)

func face(actor,point: Vector3,delta: float) -> void:
	if actor.action_timer>0: return
	var look: Vector3=(point-actor.position)*Vector3(1,0,1)
	if look.length()<0.1: return
	actor.facing=look.normalized()
	actor.rig.rotation.y=lerp_angle(actor.rig.rotation.y,atan2(-look.x,-look.z),1-exp(-delta*10))

func update_camera(_delta: float) -> bool:
	var entry := confrontation()
	if entry.is_empty():
		for departure in exits:
			if departure.actor.position.x<33.3:
				entry=departure
				break
	if entry.is_empty() or game.state in ["menu","setup","replay"]: return false
	var leaving: bool=entry.phase=="exit"
	var focus: Vector3=(entry.actor.position if leaving else entry.center)+Vector3(0,0.9,0)
	var offset := Vector3(-11 if leaving or focus.x>18 else 11,7.5,-12 if focus.z>33 else 12)
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=44
	game.camera.position=focus+offset
	game.camera.look_at(focus)
	game.camera_focus=focus*Vector3(1,0,1)
	return true
