extends CharacterBody3D
const G = preload("res://scripts/geometry.gd")
var team := 0
var number := 10
var keeper := false
var display_name := "EGE"
var home := Vector3.ZERO
var desired := Vector3.ZERO
var facing := Vector3.FORWARD
var energy := 1.0
var sprinting := false
const SPRINT_DRAIN := 0.16
const RUN_DRAIN := 0.02
const EXHAUSTION_LIMIT := 0.08
const RECOVERY_LIMIT := 0.32
var exhausted := false
var active_sprint := false
var recovery_delay := 0.0
var action_timer := 0.0
var set_piece_pose := ""
var handling_blend := 0.0
var yellow_cards := 0
var fouls_committed := 0
var dismissed := false
var wall_hold := 0.0
var wall_jump_delay := -1.0
var tackle_cooldown := 0.0
var kick_timer := 0.0
var touch_cooldown := 0.0
var ai_think := 0.0
var dive_direction := 1.0
var pose := "run"
var rig := Node3D.new()
var left_leg := Node3D.new()
var right_leg := Node3D.new()
var left_arm := Node3D.new()
var right_arm := Node3D.new()
var left_knee := Node3D.new()
var right_knee := Node3D.new()
var left_elbow := Node3D.new()
var right_elbow := Node3D.new()
var spine := Node3D.new()
var left_hand: Node3D
var right_hand: Node3D
var body_collision: CollisionShape3D
var dive_duration := 1.45
var dive_yaw := 0.0
var dive_height := 1.0
var dive_speed := 4.0
var dive_launched := false
var motion_clock := 0.0
var last_horizontal := Vector3.ZERO
var acceleration_lean := Vector3.ZERO
var run_phase := 0.0
var chosen := false
var call_timer := 0.0
var call_label := Label3D.new()
var marker: MeshInstance3D
var slide_duration := 0.72
var skid_last := Vector3.ZERO
var surface: Node3D
var prematch := false
var saluting := false
var official := false
var celebration := ""
var protecting := false
var jockeying := false
var feint_time := 0.0
var feint_side := 1.0
var skill_cooldown := 0.0
var shot_preparation := 0.0
var kick_power := 0.35
var kick_duration := 0.32
var impact_direction := Vector3.ZERO
var impact_strength := 0.0
var impact_duration := 0.8

func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = 0.3
	var shape = CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 1.72
	var collision = CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.87
	add_child(collision)
	body_collision = collision
	add_child(rig)
	build_model()
	rig.scale = Vector3(1.25,1.20,1.25)
	var torus = TorusMesh.new()
	torus.inner_radius = 0.67
	torus.outer_radius = 0.72
	torus.rings = 32
	torus.ring_segments = 6
	var mat = G.material(Color("e8df92"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker = G.mesh(self,torus,mat,Vector3(0,0.035,0))
	marker.scale.y = 0.18
	add_child(call_label)
	call_label.text = "PAS!"
	call_label.position = Vector3(0,2.65,0)
	call_label.font_size = 48
	call_label.pixel_size = 0.008
	call_label.modulate = Color("f2df93")
	call_label.outline_size = 8
	call_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	call_label.visible = false

func build_model() -> void:
	var kit_color = Color("e5ece5") if team==0 else Color("d34532")
	if keeper: kit_color = Color("d7b83c") if team==0 else Color("5998ac")
	if official: kit_color=Color("171b20")
	var jersey = G.material(kit_color)
	var trim = G.material(Color("193d39") if team==0 else Color("f1d7bd"))
	if official: trim=G.material(Color("bbc4c5"))
	var shorts = G.material(Color("133933") if team==0 else Color("eee3d2"))
	if keeper or official: shorts = G.material(Color("171d23"))
	var socks = G.material(kit_color)
	var skin = G.material([Color("d6a079"),Color("8c593b"),Color("bb7e54"),Color("e2b28c")][number%4])
	var hair = G.material([Color("201e1b"),Color("32261d"),Color("6e5030")][number%3])
	var boots = G.material(Color("e8d867") if number%3==0 else Color("182229"))
	if official: boots=G.material(Color("12171b"))
	G.cylinder(rig,0.255,0.55,Vector3(0,1.22,0),jersey,0.30)
	G.cylinder(rig,0.12,0.06,Vector3(0,1.51,0),trim)
	# Chest stripe, crest, shoulder piping and collar give the kits a real silhouette.
	if not official: G.block(rig,Vector3(0.40,0.09,0.025),Vector3(0,1.27,-0.30),trim)
	G.block(rig,Vector3(0.07,0.095,0.03),Vector3(-0.12,1.4,-0.30),trim)
	G.cylinder(rig,0.235,0.27,Vector3(0,0.83,0),shorts)
	G.cylinder(rig,0.095,0.12,Vector3(0,1.56,0),skin)
	var head = G.sphere(rig,0.205,Vector3(0,1.76,0),skin)
	head.scale = Vector3(0.86,1.1,0.91)
	var haircut = G.sphere(rig,0.20,Vector3(0,1.85,0.025),hair)
	haircut.scale = Vector3(0.9,0.64,0.94)
	G.sphere(rig,0.045,Vector3(0,1.75,-0.181),skin)
	for side in [-1,1]:
		var leg = left_leg if side<0 else right_leg
		rig.add_child(leg)
		leg.position = Vector3(side*0.14,0.85,0)
		G.cylinder(leg,0.10,0.30,Vector3(0,-0.14,0),shorts)
		var knee = left_knee if side<0 else right_knee
		leg.add_child(knee)
		knee.position = Vector3(0,-0.33,0)
		G.sphere(knee,0.084,Vector3.ZERO,skin)
		G.cylinder(knee,0.081,0.12,Vector3(0,-0.055,0),skin)
		G.cylinder(knee,0.075,0.29,Vector3(0,-0.24,0),socks)
		G.cylinder(knee,0.079,0.045,Vector3(0,-0.14,0),trim)
		var boot = G.sphere(knee,0.115,Vector3(0,-0.42,-0.05),boots)
		boot.scale = Vector3(0.77,0.61,1.65)
		var arm = left_arm if side<0 else right_arm
		rig.add_child(arm)
		arm.position = Vector3(side*0.3,1.43,0)
		G.cylinder(arm,0.105,0.24,Vector3(0,-0.1,0),jersey)
		var elbow = left_elbow if side<0 else right_elbow
		arm.add_child(elbow)
		elbow.position = Vector3(0,-0.24,0)
		G.sphere(elbow,0.077,Vector3.ZERO,skin)
		G.cylinder(elbow,0.072,0.25,Vector3(0,-0.125,0),skin)
		var hand = G.sphere(elbow,0.103 if keeper else 0.08,Vector3(0,-0.29,0),G.material(Color("ececd7")) if keeper else skin)
		if side<0: left_hand = hand
		else: right_hand = hand
	var back = Label3D.new()
	back.text = "" if official else str(number)
	back.font_size = 96
	back.pixel_size = 0.0036
	back.outline_size = 0
	back.modulate = Color("173b35") if team==0 else Color("fff1d7")
	back.rotation.y = 0
	rig.add_child(back)
	back.position = Vector3(0,1.27,0.31)
	# A waist pivot lets the torso bend independently of hips and planted feet.
	rig.add_child(spine)
	spine.position = Vector3(0,0.94,0)
	for part in rig.get_children():
		if part==spine or part.position.y<1.0: continue
		var local_position: Vector3 = part.position
		part.reparent(spine,false)
		part.position = local_position-spine.position

func start_slide(direction: Vector3) -> void:
	pose = "slide"
	action_timer = slide_duration
	tackle_cooldown = 1.35
	if direction.length() > 0.1:
		facing = direction.normalized()
	var current := Vector2(velocity.x, velocity.z).length()
	velocity = facing * maxf(current + 5.5, 15.5)
	skid_last = Vector3.ZERO

func receive_impact(direction: Vector3,strength: float) -> void:
	if action_timer>0 and pose in ["stumble","fall"]: return
	impact_direction=(direction*Vector3(1,0,1)).normalized()
	impact_strength=clampf(strength,0,1)
	impact_duration=lerpf(0.5,1.12,impact_strength)
	action_timer=impact_duration
	pose="fall" if impact_strength>0.7 else "stumble"
	velocity=velocity*0.25+impact_direction*lerpf(1.5,4.2,impact_strength)
	facing=-impact_direction
	kick_timer=0
	shot_preparation=0
	touch_cooldown=impact_duration+0.15
	tackle_cooldown=maxf(tackle_cooldown,impact_duration)

func start_dive(side: float, target_height: float = 1.0, time_available: float = 0.45) -> void:
	if not keeper or action_timer>0 or tackle_cooldown>0: return
	pose = "dive"
	action_timer = dive_duration
	tackle_cooldown = dive_duration+0.3
	dive_direction = 1.0 if side>=0 else -1.0
	dive_height = clampf(target_height,0.2,2.3)
	dive_speed = clampf((absf(side)-1.45)/maxf(time_available-0.10,0.18),0.7,6.7)
	dive_yaw = atan2(-facing.x,-facing.z)
	dive_launched = false

func can_save(ball_position: Vector3) -> bool:
	if pose=="claim" and action_timer>0:
		return minf(left_hand.global_position.distance_to(ball_position),right_hand.global_position.distance_to(ball_position))<0.65
	if pose=="dive" and action_timer>0:
		if dive_duration-action_timer>0.84: return false
		return minf(left_hand.global_position.distance_to(ball_position),right_hand.global_position.distance_to(ball_position))<0.72 or spine.to_global(Vector3(0,0.3,0)).distance_to(ball_position)<0.52
	return Vector2(global_position.x-ball_position.x,global_position.z-ball_position.z).length()<0.9 and ball_position.y<1.75

func start_claim(target_height: float=2.8,time_available: float=0.35) -> void:
	if not keeper or action_timer>0 or tackle_cooldown>0: return
	pose="claim"
	action_timer=0.8
	tackle_cooldown=1.25
	velocity.y=clampf((target_height-2.3+10*time_available*time_available)/maxf(time_available,0.15),2.2,6.5)

func step(delta: float) -> void:
	feint_time=maxf(0,feint_time-delta)
	skill_cooldown=maxf(0,skill_cooldown-delta)
	if wall_hold>0:
		wall_hold=maxf(0,wall_hold-delta)
		if wall_hold==0: set_piece_pose=""
	if wall_jump_delay>=0:
		wall_jump_delay-=delta
		if wall_jump_delay<0: velocity.y=5.4
	call_timer = maxf(0,call_timer-delta)
	call_label.visible = call_timer>0
	motion_clock += delta
	action_timer = maxf(0,action_timer-delta)
	tackle_cooldown = maxf(0,tackle_cooldown-delta)
	touch_cooldown = maxf(0,touch_cooldown-delta)
	kick_timer = maxf(0,kick_timer-delta)
	ai_think += delta
	update_stamina(delta)
	var speed := movement_speed()
	if is_instance_valid(surface): speed*=1.0-surface.mud_at(position)*0.16
	var target = desired.limit_length(1)*speed
	if action_timer>0:
		if pose=="poke": target*=0.2
		elif pose=="claim": target*=0.35
		elif pose == "slide":
			var t := action_timer / slide_duration
			target = facing * lerpf(5.5, 16.0, t)
			leave_skid()
		elif pose == "dive":
			var time := dive_duration-action_timer
			target = Vector3.ZERO
			if time>=0.10 and not dive_launched:
				velocity = Vector3(dive_direction*dive_speed,lerpf(2.6,7.0,(dive_height-0.2)/2.1),0)
				dive_launched = true
			if time>=0.10 and time<0.52: target.x = dive_direction*dive_speed
			elif time<0.77: target.x = dive_direction*minf(2.0,dive_speed)*(1.0-(time-0.52)/0.25)
		elif pose in ["stumble","fall"]:
			var progress := 1-action_timer/impact_duration
			target=impact_direction*lerpf(1.5,4.2,impact_strength)*(1-smoothstep(0,0.65,progress))
	var acceleration := lerpf(13,23,smoothstep(0.08,0.4,energy))
	# Dives and slides retain their own launch timing.
	if action_timer>0: acceleration = 23
	if is_instance_valid(surface): acceleration*=surface.grip_at(position)
	velocity.x = move_toward(velocity.x,target.x,delta*acceleration)
	velocity.z = move_toward(velocity.z,target.z,delta*acceleration)
	velocity.y -= 20*delta
	move_and_slide()
	if desired.length()>0.05 and action_timer<=0 and not keeper and not protecting and not jockeying and kick_timer<=0 and shot_preparation<=0:
		facing = desired.normalized()
	if facing.length()>0.1 and not (pose=="dive" and action_timer>0):
		rig.rotation.y = lerp_angle(rig.rotation.y,atan2(-facing.x,-facing.z),1-exp(-delta*12))
	var horizontal := Vector3(velocity.x,0,velocity.z)
	acceleration_lean = acceleration_lean.lerp((horizontal-last_horizontal)/maxf(delta,0.001),1-exp(-delta*7))
	last_horizontal = horizontal
	run_phase += horizontal.length()*delta*1.8
	animate(delta)
	if is_instance_valid(surface): surface.player_step(self,delta)
	marker.visible = chosen and pose not in ["slide","dive"]

func reset_stamina() -> void:
	energy = 1
	exhausted = false
	active_sprint = false
	sprinting = false
	recovery_delay = 0

func update_stamina(delta: float) -> void:
	var moving := desired.length()>0.1 and action_timer<=0
	recovery_delay = maxf(0,recovery_delay-delta)
	if exhausted and energy>=RECOVERY_LIMIT and not sprinting:
		exhausted = false
	active_sprint = moving and sprinting and not exhausted and energy>EXHAUSTION_LIMIT
	if active_sprint:
		energy -= SPRINT_DRAIN*delta
		recovery_delay = 0.75
	elif moving and not exhausted and desired.length()>0.45:
		energy -= RUN_DRAIN*minf(desired.length(),1)*delta
		recovery_delay = 0.75
	elif recovery_delay<=0:
		energy += (0.045 if moving else 0.12)*delta
	energy = clampf(energy,0,1)
	if energy<=EXHAUSTION_LIMIT:
		exhausted = true
		active_sprint = false

func movement_speed() -> float:
	if exhausted: return 3.4
	if active_sprint: return lerpf(7.0,8.7,smoothstep(0.08,0.4,energy))
	return lerpf(4.6,6.5 if keeper else 6.2,smoothstep(0.08,0.3,energy))

func animate(delta: float) -> void:
	var amount = clampf(Vector2(velocity.x,velocity.z).length()/8.7,0,1)
	var stride = sin(run_phase)
	var idle = sin(motion_clock*2.0+number*0.8)
	var blend = 1-exp(-delta*14)
	var local_accel = acceleration_lean.rotated(Vector3.UP,-rig.rotation.y)
	left_leg.rotation = Vector3(0.10+stride*0.78*amount,0,-0.035)
	right_leg.rotation = Vector3(0.10-stride*0.78*amount,0,0.035)
	left_knee.rotation.x = -0.19-maxf(0,-stride)*1.08*amount
	right_knee.rotation.x = -0.19-maxf(0,stride)*1.08*amount
	left_arm.rotation = Vector3(-stride*0.55*amount-0.08,0,-0.13)
	right_arm.rotation = Vector3(stride*0.55*amount-0.08,0,0.13)
	left_elbow.rotation.x = 0.50+amount*0.34+stride*0.09
	right_elbow.rotation.x = 0.50+amount*0.34-stride*0.09
	spine.rotation = spine.rotation.lerp(Vector3(-0.065-amount*0.12-(0.065 if exhausted else 0.0),sin(run_phase)*amount*0.065,-stride*amount*0.035),blend)
	if exhausted:
		spine.position.y = 0.94+sin(motion_clock*5.0)*0.012
	else: spine.position.y = 0.94
	rig.position = rig.position.lerp(Vector3(idle*0.013*(1-amount),-0.03+absf(stride)*0.045*amount,0),blend)
	rig.rotation.x = lerp_angle(rig.rotation.x,-0.035-amount*0.075+clampf(local_accel.z*0.006,-0.08,0.08),blend)
	rig.rotation.z = lerp_angle(rig.rotation.z,clampf(-local_accel.x*0.010,-0.16,0.16)+idle*0.015*(1-amount),blend)
	body_collision.rotation = Vector3.ZERO
	body_collision.position = Vector3(0,0.87,0)
	if keeper and not prematch:
		spine.rotation.x = lerpf(spine.rotation.x,-0.28,blend)
		rig.position.y = lerpf(rig.position.y,-0.15,blend)
		left_leg.rotation.x += 0.20
		right_leg.rotation.x += 0.20
		left_knee.rotation.x -= 0.42
		right_knee.rotation.x -= 0.42
		left_arm.rotation = Vector3(0.28,0,-0.40)
		right_arm.rotation = Vector3(0.28,0,0.40)
		left_elbow.rotation.x = 0.98
		right_elbow.rotation.x = 0.98
	if saluting:
		right_arm.rotation=Vector3(0.15,0,2.65+sin(motion_clock*5+number)*0.16)
		right_elbow.rotation.x=0.35+sin(motion_clock*4+number)*0.12
	if shot_preparation>0 and action_timer<=0:
		right_leg.rotation.x=-0.3-shot_preparation*0.5
		right_knee.rotation.x=-0.65-shot_preparation*0.35
		left_knee.rotation.x=-0.42
		spine.rotation=Vector3(-0.18,-0.12-shot_preparation*0.13,0.06)
		left_arm.rotation.z=-0.7
		right_arm.rotation.z=0.6
	if kick_timer>0:
		var kick_progress := clampf(1.0-kick_timer/kick_duration,0,1)
		var follow := 1-smoothstep(0.06,1.0,kick_progress)
		right_leg.rotation.x = lerpf(0.65,1.38,kick_power)*follow
		right_knee.rotation.x = -0.2-0.32*kick_progress
		left_knee.rotation.x = -0.38
		spine.rotation.x = -0.16-0.20*kick_power*follow
		spine.rotation.y = 0.3*kick_power*follow
		left_arm.rotation.z = -0.8
		right_arm.rotation.z = 0.45
	if call_timer>0 and kick_timer<=0:
		right_arm.rotation.z = 2.75+sin(motion_clock*9)*0.12
		right_elbow.rotation.x = 0.25
	if action_timer>0:
		if pose=="poke":
			var reach := sin(PI*(1-action_timer/0.38))
			right_leg.rotation.x=0.95*reach
			right_knee.rotation.x=-0.08
			left_knee.rotation.x=-0.5
			spine.rotation.x=-0.25
			left_arm.rotation.z=-0.7
		elif pose=="claim":
			left_arm.rotation=Vector3(PI-0.2,0,-0.15)
			right_arm.rotation=Vector3(PI-0.2,0,0.15)
			left_elbow.rotation.x=0.15
			right_elbow.rotation.x=0.15
			left_knee.rotation.x=-0.5
			right_knee.rotation.x=-0.5
		elif pose=="slide":
			rig.rotation.x = 1.38
			rig.rotation.z = 0.58
			rig.position = Vector3(facing.x * 1.05, 0.18, facing.z * 1.05)
			spine.rotation = Vector3(-0.14,0,-0.08)
			right_leg.rotation.x = 0.25
			left_leg.rotation.x = 0.82
			right_knee.rotation.x = -0.06
			left_knee.rotation.x = -0.70
			left_arm.rotation.x = -0.7
			right_arm.rotation.x = 0.15
			left_arm.rotation.z = -1.35
			right_arm.rotation.z = 0.85
		elif pose=="dive": animate_dive()
		elif pose in ["stumble","fall"]:
			var progress := 1-action_timer/impact_duration
			var envelope := smoothstep(0,0.14,progress)*(1-smoothstep(0.52,1.0,progress))
			rig.rotation.x=-envelope*(1.3 if pose=="fall" else 0.35)
			rig.rotation.z=envelope*0.14
			rig.position.y=0.12*envelope
			spine.rotation=Vector3(-0.2*envelope,0,0)
			left_leg.rotation.x=0.6*envelope
			right_leg.rotation.x=-0.4*envelope
			left_knee.rotation.x=-0.55*envelope
			right_knee.rotation.x=-0.7*envelope
			left_arm.rotation.z=-1.1*envelope
			right_arm.rotation.z=1.2*envelope
			if pose=="fall":
				body_collision.rotation.x=-1.25*envelope
				body_collision.position.y=lerpf(0.87,0.38,envelope)
	else:
		pose = "run"
		# Keep the supporting boot on the turf as the hip and knee flex.
		var sole_height := minf(left_knee.to_global(Vector3(0,-0.42,-0.05)).y,right_knee.to_global(Vector3(0,-0.42,-0.05)).y)-0.084
		rig.position.y -= sole_height-global_position.y-0.018
	if set_piece_pose=="wall":
		left_arm.rotation=Vector3(-0.22,0,-0.2)
		right_arm.rotation=Vector3(-0.22,0,0.2)
		left_elbow.rotation.x=1.8
		right_elbow.rotation.x=1.8
		left_knee.rotation.x=-0.28
		right_knee.rotation.x=-0.28
	elif set_piece_pose in ["carry","pickup","throw"]:
		var crouch := handling_blend if set_piece_pose=="pickup" else 0.0
		var overhead := handling_blend if set_piece_pose=="throw" else 0.0
		spine.rotation.x=-0.08-crouch*0.85
		rig.rotation.x=0
		rig.position.y-=0.43*crouch
		left_leg.rotation.x+=crouch*0.75
		right_leg.rotation.x+=crouch*0.75
		left_knee.rotation.x-=crouch*1.1
		right_knee.rotation.x-=crouch*1.1
		var arm_angle := lerpf(lerpf(0.7,1.0,crouch),PI-0.22,overhead)
		left_arm.rotation=Vector3(arm_angle,0,0.2)
		right_arm.rotation=Vector3(arm_angle,0,-0.2)
		left_elbow.rotation.x=lerpf(lerpf(1.4,0.1,crouch),0.48,overhead)
		right_elbow.rotation.x=left_elbow.rotation.x

	if action_timer<=0 and (protecting or jockeying):
		spine.rotation.x=-0.2
		left_knee.rotation.x-=0.22
		right_knee.rotation.x-=0.22
		left_arm.rotation.z=-0.85 if protecting else -0.45
		right_arm.rotation.z=0.85 if protecting else 0.45
	if feint_time>0 and action_timer<=0:
		var sway := sin((1-feint_time/0.48)*TAU)*feint_side
		spine.rotation.z=sway*0.25
		right_leg.rotation.z=sway*0.25
		left_arm.rotation.z=-0.65-sway*0.3
		right_arm.rotation.z=0.65-sway*0.3
	if celebration!="" and action_timer<=0:
		var pulse := sin(motion_clock*8.5+number)
		if celebration=="cheer":
			left_arm.rotation=Vector3(0.2,0,-2.55-pulse*0.18)
			right_arm.rotation=Vector3(0.2,0,2.55+pulse*0.18)
			left_elbow.rotation.x=0.3
			right_elbow.rotation.x=0.3
			spine.rotation.x=0.04
		elif celebration=="embrace":
			left_arm.rotation=Vector3(1.3,0,-0.52)
			right_arm.rotation=Vector3(1.3,0,0.52)
			left_elbow.rotation.x=0.65+pulse*0.15
			right_elbow.rotation.x=0.65-pulse*0.15
		elif celebration=="applaud":
			left_arm.rotation=Vector3(0.8,0,0.3+pulse*0.12)
			right_arm.rotation=Vector3(0.8,0,-0.3-pulse*0.12)
			left_elbow.rotation.x=1.55
			right_elbow.rotation.x=1.55
		elif celebration=="dejected":
			spine.rotation.x=-0.30
			if number%3==0:
				left_arm.rotation=Vector3(2.2,0,-0.4)
				right_arm.rotation=Vector3(2.2,0,0.4)
				left_elbow.rotation.x=1.0
				right_elbow.rotation.x=1.0

func hand_center() -> Vector3:
	return (left_hand.global_position+right_hand.global_position)*0.5

func animate_dive() -> void:
	var time := dive_duration-action_timer
	var launch := smoothstep(0.10,0.36,time)
	var recover := smoothstep(0.94,dive_duration,time)
	var spread := launch*(1-recover)
	var airborne_roll := lerpf(1.48,1.25,(dive_height-0.2)/2.1)
	var roll := spread*lerpf(airborne_roll,1.46,smoothstep(0.50,0.76,time))
	rig.basis = (Basis(Vector3.FORWARD,dive_direction*roll)*Basis(Vector3.UP,dive_yaw)).scaled(Vector3(1.25,1.20,1.25))
	# Rotate around the pelvis, not the feet: the body lands above the turf.
	var pelvis_height := lerpf(1.08,0.44,spread)
	if time<0.10: pelvis_height -= smoothstep(0.0,0.1,time)*0.17
	rig.position = Vector3(0,pelvis_height,0)-rig.basis*Vector3(0,0.9,0)
	spine.rotation = Vector3(-0.10,0,dive_direction*0.035)
	left_arm.rotation = Vector3(0.12,0,-lerpf(0.4,2.85,spread))
	right_arm.rotation = Vector3(0.12,0,lerpf(0.4,2.85,spread))
	left_elbow.rotation.x = lerpf(0.9,0.14,spread)
	right_elbow.rotation.x = lerpf(0.9,0.14,spread)
	left_leg.rotation.x = 0.10+spread*0.25
	right_leg.rotation.x = -spread*0.18
	left_knee.rotation.x = -0.25-spread*0.35
	right_knee.rotation.x = -0.25-spread*0.14
	body_collision.rotation.z = -dive_direction*roll
	body_collision.position.y = lerpf(0.87,0.36,spread)

func leave_skid() -> void:
	if is_instance_valid(surface): return # Persistent pooled marks are managed by the surface.
	var here := Vector3(global_position.x, 0.02, global_position.z)
	if skid_last == Vector3.ZERO:
		skid_last = here
		return
	var travel := here - skid_last
	travel.y = 0
	if travel.length() < 0.24:
		return
	var parent := get_parent()
	if parent == null:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.38, 0.01, travel.length() + 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.11, 0.10, 0.05, 0.58)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mark := MeshInstance3D.new()
	mark.mesh = mesh
	mark.material_override = mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mark)
	mark.global_position = (here + skid_last) * 0.5
	mark.global_position.y = 0.02
	if travel.length() > 0.001:
		mark.look_at(mark.global_position + travel, Vector3.UP)
	skid_last = here
	var fade := mark.create_tween()
	fade.tween_interval(2.6)
	fade.tween_property(mat, "albedo_color:a", 0.0, 2.4)
	fade.tween_callback(mark.queue_free)
