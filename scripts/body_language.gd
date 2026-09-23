extends RefCounted
## Match-aware, visual-only gestures. No movement, ball or input state is changed.
const SCAN_TIME := 0.46
const POINT_TIME := 0.58
const BALANCE_TIME := 0.58
var enabled := false
var ball_target := Vector3.ZERO
var scan_age := SCAN_TIME
var scan_cooldown := 0.0
var scan_side := 1.0
var was_incoming := false
var urgent := false
var point_age := POINT_TIME
var point_weight := 0.0
var point_cancelled := false
var point_cooldown := 0.0
var point_target := Vector3.ZERO
var point_left := false
var balance_age := BALANCE_TIME
var balance_strength := 0.0
var balance_direction := Vector3.ZERO
var contact_cooldown := 0.0
var contact_count := 0
var shielding := 0.0
var shield_target := Vector3.ZERO
var shield_seen := false
var shield_left := false
var contest_weight := 0.0
var contest_target := Vector3.ZERO
var contest_seen := false
var contest_side := 1.0
var contest_shoulder := false
var contest_pressure := 0.0

func reset(p) -> void:
	clear_intent()
	scan_cooldown=0.4+fmod(p.number*0.29,2.0)
	point_cooldown=0.6+fmod(p.number*0.71+p.team*0.43,3.3)
	scan_side=-1.0 if p.number%2==0 else 1.0
	balance_age=BALANCE_TIME
	balance_strength=0
	contact_cooldown=0
	contact_count=0
	shielding=0; shield_seen=false
	contest_weight=0; contest_seen=false
	p.head_joint.rotation=Vector3.ZERO
	for eye in p.eye_joints: eye.rotation=Vector3.ZERO

func clear_intent() -> void:
	enabled=false
	scan_age=SCAN_TIME
	point_age=POINT_TIME
	point_weight=0
	point_cancelled=false
	was_incoming=false
	urgent=false

func available(p) -> bool:
	return enabled and not p.official and not p.prematch and not p.dismissed and p.action_timer<=0 and p.set_piece_pose=="" and p.celebration=="" and p.discipline_pose=="" and not p.saluting

func free_arms(p) -> bool:
	return available(p) and not p.keeper and p.reaction.kind=="" and p.kick_timer<=0 and p.receive_timer<=0 and p.shot_preparation<=0 and p.shot_ready_blend<0.01 and p.call_timer<=0 and not p.protecting and not p.jockeying and p.feint_time<=0

func can_balance(p) -> bool:
	return available(p) and not p.keeper and p.kick_timer<=0 and p.shot_preparation<=0 and p.shot_ready_blend<0.01 and p.feint_time<=0

func observe(game,index: int) -> void:
	var p=game.players[index]
	enabled=game.state=="playing" and p.visible
	ball_target=game.ball.global_position
	shield_seen=false
	contest_seen=false
	if not available(p): return
	# Read an actual nearby opponent in the ball contest. Both participants
	# independently brace toward one another; spectators and teammates do not.
	if can_balance(p) and p.receive_timer<=0 and game.flat_distance(p.position,game.ball.position)<3.2:
		var closest := 1.10
		for other in game.players:
			if not other.visible or other.team==p.team or other.dismissed or other.keeper or other.action_timer>0: continue
			var gap: Vector3=(other.position-p.position)*Vector3(1,0,1)
			var distance := gap.length()
			if distance<.25 or distance>=closest: continue
			closest=distance; contest_seen=true
			contest_pressure=clampf((1.15-distance)*2.2+.25+absf((p.velocity-other.velocity).dot(gap.normalized()))*.055,.25,1)
			contest_target=other.position+Vector3.UP*1.05
			var local: Vector3=p.rig.global_basis.inverse()*gap.normalized()
			contest_side=-1.0 if local.x<0 else 1.0
			contest_shoulder=absf(local.x)>.68 and p.facing.dot(other.facing)>.35
	if (game.dribbler==index or p.protecting) and not p.keeper:
		var nearest := 1.55
		for other in game.players:
			if not other.visible or other.team==p.team or other.dismissed: continue
			var gap: Vector3=(other.position-p.position)*Vector3(1,0,1)
			if gap.length()<nearest and gap.normalized().dot(p.facing)<.35:
				nearest=gap.length(); shield_seen=true
				shield_target=other.position+Vector3.UP*1.18
				var side: float=p.rig.to_local(other.position).x
				if absf(side)>.15: shield_left=side<0
	var offset: Vector3=(ball_target-p.global_position)*Vector3(1,0,1)
	var distance := offset.length()
	var ball_velocity: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
	var relative: Vector3=(ball_velocity-p.velocity)*Vector3(1,0,1)
	var arrival := offset.dot(-relative)/maxf(relative.length_squared(),0.01)
	var incoming := arrival>0 and arrival<2.2 and relative.length()>2.5 and (offset+relative*arrival).length()<2.5
	urgent=distance<3.3 or (incoming and arrival<0.42)
	var owner: int=game.dribbler
	var supporting: bool=owner>=0 and owner!=index and game.players[owner].team==p.team
	if p.kick_timer>0 or p.shot_preparation>0 or p.keeper:
		scan_age=SCAN_TIME
	elif not urgent and distance>4 and balance_age>=BALANCE_TIME:
		if (incoming and not was_incoming and arrival>0.68) or (supporting and distance<30 and scan_cooldown<=0):
			scan_age=0
			scan_cooldown=3.4+fmod(p.number*0.37,1.8)
			scan_side=-scan_side
	was_incoming=incoming
	if not supporting or not game.support.targets.has(index) or urgent:
		point_cancelled=true
		return
	if point_age<POINT_TIME and (point_target-p.position).normalized().dot(p.facing)<-0.35: point_cancelled=true
	if not free_arms(p) or point_cooldown>0 or point_age<POINT_TIME or balance_age<BALANCE_TIME or distance<4 or distance>32: return
	var target: Vector3=game.support.targets[index]
	var route: Vector3=(target-p.position)*Vector3(1,0,1)
	if route.length()<2.5 or route.length()>18 or route.normalized().dot(p.facing)<-0.35: return
	# At most two nearby teammates signal, at individually staggered intervals.
	var pointing := 0
	for q in game.players:
		if not q.visible: continue
		if q.team==p.team:
			if q.body_language.point_age<POINT_TIME: pointing+=1
		else:
			if game.flat_distance(q.position,target)<2.4: return
			var near := Geometry3D.get_closest_point_to_segment(q.position*Vector3(1,0,1),game.ball.position*Vector3(1,0,1),target*Vector3(1,0,1))
			if game.flat_distance(near,q.position)<1.0: return
	if pointing>=2: return
	point_target=target
	point_left=(route.rotated(Vector3.UP,-p.rig.rotation.y)).x<0
	point_age=0
	point_weight=0
	point_cancelled=false
	point_cooldown=2.15+fmod(p.number*0.53+p.team*0.7,1.8)

func update(p,delta: float) -> void:
	contest_weight=move_toward(contest_weight,contest_pressure if contest_seen and can_balance(p) and p.receive_timer<=0 else 0.0,delta*(7 if contest_seen else 5))
	shielding=move_toward(shielding,1.0 if shield_seen and can_balance(p) and p.receive_timer<=0 else 0.0,delta*6)
	scan_age=minf(SCAN_TIME,scan_age+delta)
	point_age=minf(POINT_TIME,point_age+delta)
	balance_age=minf(BALANCE_TIME,balance_age+delta)
	scan_cooldown=maxf(0,scan_cooldown-delta)
	point_cooldown=maxf(0,point_cooldown-delta)
	contact_cooldown=maxf(0,contact_cooldown-delta)
	var point_envelope := 0.0 if point_cancelled else smoothstep(0,0.12,point_age)*(1-smoothstep(0.34,POINT_TIME,point_age))
	point_weight=move_toward(point_weight,point_envelope,delta*5.0)
	if point_cancelled and point_weight<=0: point_age=POINT_TIME
	if not available(p):
		scan_age=SCAN_TIME
		point_age=POINT_TIME
		point_weight=0
		balance_age=BALANCE_TIME
	elif not free_arms(p):
		point_age=POINT_TIME
		point_weight=0

func contact(p,direction: Vector3,strength: float) -> void:
	if not can_balance(p) or contact_cooldown>0: return
	balance_age=0
	balance_strength=clampf(strength,0.18,0.85)
	balance_direction=direction.normalized()
	contact_cooldown=0.95
	contact_count+=1
	point_age=POINT_TIME
	scan_age=SCAN_TIME

func collisions(p,travel_velocity: Vector3) -> void:
	if not enabled: return
	for i in range(p.get_slide_collision_count()):
		var collision: KinematicCollision3D=p.get_slide_collision(i)
		var other=collision.get_collider()
		if not other is CharacterBody3D or not other.has_method("receive_impact"): continue
		var normal := collision.get_normal()*Vector3(1,0,1)
		if normal.length()<0.5: continue
		normal=normal.normalized()
		var closing: float=-(travel_velocity-other.velocity).dot(normal)
		if closing<1.15: continue
		contact(p,normal,closing/9.0)
		other.body_language.contact(other,-normal,closing/9.0)

func apply_pose(p) -> void:
	if not can_balance(p): return
	if contest_weight>0:
		var weight := contest_weight
		var arm: Node3D=p.left_arm if contest_side<0 else p.right_arm
		var elbow: Node3D=p.left_elbow if contest_side<0 else p.right_elbow
		var local: Vector3=(contest_target-p.global_position).rotated(Vector3.UP,-p.rig.rotation.y).normalized()
		# A compact bent arm at the opponent's upper body, never a punching
		# extension. The opposite arm opens for balance while feet keep running.
		var brace := Vector3(-.28,contest_side*.18,contest_side*.72)
		if not contest_shoulder:
			var toward: Vector3=(p.spine.global_basis.inverse()*(contest_target-arm.global_position)).normalized()
			arm.quaternion=arm.quaternion.slerp(Quaternion(Vector3.DOWN,toward),weight*.72)
		else: arm.rotation=arm.rotation.lerp(brace,weight)
		elbow.rotation.x=lerpf(elbow.rotation.x,1.05 if contest_shoulder else .8,weight)
		var counter: Node3D=p.right_arm if contest_side<0 else p.left_arm
		counter.rotation.z=lerpf(counter.rotation.z,-contest_side*.65,weight*.65)
		p.spine.rotation.z=lerpf(p.spine.rotation.z,-local.x*.19,weight)
		p.spine.rotation.x=lerpf(p.spine.rotation.x,local.z*.12,weight)
		p.spine.rotation.y=lerpf(p.spine.rotation.y,-contest_side*.14,weight)
		point_cancelled=true
		return
	if shielding>0:
		# A bent forearm feels the opponent behind the shoulder. This is a visual
		# shielding gesture, never a strike, push impulse or invisible protection.
		var arm: Node3D=p.left_arm if shield_left else p.right_arm
		var elbow: Node3D=p.left_elbow if shield_left else p.right_elbow
		var side := -1.0 if shield_left else 1.0
		arm.rotation=arm.rotation.lerp(Vector3(-.32,side*.28,side*1.03),shielding)
		elbow.rotation.x=lerpf(elbow.rotation.x,.92,shielding)
		p.spine.rotation.y=lerpf(p.spine.rotation.y,-side*.14,shielding*.65)
		point_cancelled=true
		return
	if balance_age<BALANCE_TIME:
		var hit := smoothstep(0,0.075,balance_age)*(1-smoothstep(0.15,BALANCE_TIME,balance_age))*balance_strength
		var settle := sin(clampf((balance_age-0.18)/0.4,0,1)*PI)*0.20*balance_strength
		var local: Vector3=balance_direction.rotated(Vector3.UP,-p.rig.rotation.y)
		# The shoulders yield, then counterbalance while the knees absorb contact.
		# Blend to bounded poses rather than adding to last frame's torso rotation.
		p.spine.rotation=p.spine.rotation.lerp(Vector3(local.z*0.25,-local.x*0.13,-local.x*0.28),hit)
		p.spine.rotation.z=lerpf(p.spine.rotation.z,local.x*0.12,settle)
		p.left_arm.rotation=p.left_arm.rotation.lerp(Vector3(0.22,0,-1.12),hit)
		p.right_arm.rotation=p.right_arm.rotation.lerp(Vector3(0.32,0,1.12),hit)
		p.left_elbow.rotation.x=lerpf(p.left_elbow.rotation.x,0.35,hit)
		p.right_elbow.rotation.x=lerpf(p.right_elbow.rotation.x,0.45,hit)
		p.left_knee.rotation.x-=hit*0.15
		p.right_knee.rotation.x-=hit*0.15
		return
	if not free_arms(p) or point_age>=POINT_TIME: return
	var weight := point_weight
	var arm: Node3D=p.left_arm if point_left else p.right_arm
	var elbow: Node3D=p.left_elbow if point_left else p.right_elbow
	var direction: Vector3=point_target-arm.global_position
	direction.y=-0.13
	direction=(p.spine.global_basis.inverse()*direction).normalized()
	arm.quaternion=arm.quaternion.slerp(Quaternion(Vector3.DOWN,direction),weight)
	elbow.rotation.x=lerpf(elbow.rotation.x,0.12,weight)

func apply_gaze(p,delta: float) -> void:
	var yaw := 0.0
	var pitch := 0.0
	if available(p):
		var local: Vector3=p.spine.to_local(ball_target)-p.head_joint.position
		yaw=atan2(-local.x,-local.z)
		# Keep the same shoulder when a ball directly behind crosses the centre.
		if absf(yaw)>2.5 and absf(p.head_joint.rotation.y)>0.2: yaw=absf(yaw)*signf(p.head_joint.rotation.y)
		yaw=clampf(yaw,-1.20,1.20)
		pitch=clampf(atan2(local.y,Vector2(local.x,local.z).length()),-0.48,0.36)
		if scan_age<SCAN_TIME and not urgent:
			var glance := smoothstep(0,0.09,scan_age)*(1-smoothstep(0.23,SCAN_TIME,scan_age))
			yaw=lerpf(yaw,scan_side*1.12,glance)
			pitch=lerpf(pitch,0.04,glance)
	if p.reaction.kind!="" and p.reaction.weight>0.12:
		var hold: float=p.reaction.weight
		if p.reaction.kind=="miss":
			yaw=lerpf(yaw,0,hold)
			pitch=lerpf(pitch,-0.34,hold)
		elif p.reaction.kind=="captain":
			yaw=lerpf(yaw,0,hold*0.55)
			pitch=lerpf(pitch,0.08,hold)
		elif p.reaction.kind=="appeal":
			var toward: Vector3=p.spine.to_local(p.reaction.focus)-p.head_joint.position
			yaw=lerpf(yaw,clampf(atan2(-toward.x,-toward.z),-1.0,1.0),hold)
			pitch=lerpf(pitch,0.06,hold)
	p.head_joint.rotation.y=move_toward(p.head_joint.rotation.y,yaw,delta*5.4)
	p.head_joint.rotation.x=lerpf(p.head_joint.rotation.x,pitch,1-exp(-delta*13))
	var eye_rotation := Vector3.ZERO
	if available(p):
		var direction: Vector3=p.head_joint.to_local(ball_target)-Vector3(0,0.19,-0.17)
		eye_rotation=Vector3(clampf(atan2(direction.y,Vector2(direction.x,direction.z).length()),-0.18,0.18),clampf(atan2(-direction.x,-direction.z),-0.24,0.24),0)
		if scan_age<SCAN_TIME and not urgent: eye_rotation*=0.2
	for eye in p.eye_joints: eye.rotation=eye.rotation.lerp(eye_rotation,1-exp(-delta*22))
