extends CharacterBody3D
const G = preload("res://scripts/geometry.gd")
const Locomotion = preload("res://scripts/locomotion.gd")
var locomotion := Locomotion.new()
const BodyLanguage = preload("res://scripts/body_language.gd")
var body_language := BodyLanguage.new()
var head_joint := Node3D.new()
var eye_joints: Array[Node3D] = []
static var hair_mesh: ArrayMesh
var kit_materials: Dictionary = {}
var kit_clean: Dictionary = {}
var kit_soil := 0.0
var kit_pattern: MeshInstance3D
var team := 0
var number := 10
var shirt_number := 10
var shirt_label: Label3D
var keeper := false
var display_name := "EGE"
var home := Vector3.ZERO
var desired := Vector3.ZERO
var facing := Vector3.FORWARD
var energy := 1.0
var sprinting := false
const SPRINT_DRAIN := 0.053
const RUN_DRAIN := 0.0067
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
var discipline_pose := ""
var discipline_age := 0.0
var protecting := false
var jockeying := false
var feint_time := 0.0
var feint_side := 1.0
var skill_cooldown := 0.0
var stamina_free_movement := false
var shot_preparation := 0.0
var shot_ready_blend := 0.0
var wrapping := 0.0
var kick_power := 0.35
var kick_duration := 0.32
var kick_style := "laces"
var kick_joints: Array[Node3D] = []
var kick_start_pose: Array[Vector3] = []
var receive_timer := 0.0
var receive_duration := 0.34
var receive_style := ""
var body_scale := Vector3(1.25,1.20,1.25)
var idle_habit := 0
var idle_rest := 0.0
var stance := 0.0
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
	kick_joints.assign([left_leg,right_leg,left_knee,right_knee,spine,left_arm,right_arm,left_elbow,right_elbow])
	apply_build()
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
	kit_materials={"jersey":jersey,"trim":trim,"shorts":shorts,"socks":socks}
	var skin = G.material([Color("d6a079"),Color("8c593b"),Color("bb7e54"),Color("e2b28c")][number%4])
	var hair = G.material([Color("201e1b"),Color("32261d"),Color("6e5030")][number%3])
	var boots = G.material(Color("e8d867") if number%3==0 else Color("182229"))
	if official: boots=G.material(Color("12171b"))
	G.cylinder(rig,0.255,0.55,Vector3(0,1.22,0),jersey,0.30)
	G.cylinder(rig,0.12,0.06,Vector3(0,1.51,0),trim)
	# Chest stripe, crest, shoulder piping and collar give the kits a real silhouette.
	if not official: kit_pattern=G.block(rig,Vector3(0.40,0.09,0.025),Vector3(0,1.27,-0.30),trim)
	G.block(rig,Vector3(0.07,0.095,0.03),Vector3(-0.12,1.4,-0.30),trim)
	G.cylinder(rig,0.235,0.27,Vector3(0,0.83,0),shorts)
	G.cylinder(rig,0.095,0.12,Vector3(0,1.56,0),skin)
	rig.add_child(head_joint)
	head_joint.name="Head"
	head_joint.position=Vector3(0,1.60,0)
	var head = G.sphere(head_joint,0.205,Vector3(0,0.16,0),skin)
	head.scale = Vector3(0.86,1.1,0.91)
	# A fitted scalp shell covers the head's crown; an offset squashed sphere
	# intersected the forehead and exposed a skin-coloured patch on every player.
	var haircut = G.mesh(head_joint,scalp_mesh(),hair,Vector3(0,0.16,0))
	haircut.name="HairCap"
	G.sphere(head_joint,0.045,Vector3(0,0.15,-0.181),skin)
	var eye_white := G.material(Color("cbc8b8"))
	var iris := G.material(Color("292921"))
	for side in [-1,1]:
		var eye := Node3D.new()
		head_joint.add_child(eye)
		eye.position=Vector3(side*0.071,0.19,-0.171)
		eye_joints.append(eye)
		var white := G.sphere(eye,0.026,Vector3.ZERO,eye_white)
		white.scale=Vector3(1,0.42,0.25)
		var pupil := G.sphere(eye,0.012,Vector3(0,0,-0.006),iris)
		pupil.scale=Vector3(0.85,0.62,0.30)
		for part in [white,pupil]:
			part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.visibility_range_end=35.0
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
	shirt_label=back
	shirt_number=number
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

static func scalp_mesh() -> ArrayMesh:
	if hair_mesh!=null: return hair_mesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var radii := Vector3(0.186,0.241,0.198)
	for ring in range(7):
		for sector in range(17):
			var around := sector*TAU/16.0
			# A higher front hairline leaves the face open; the back covers the nape.
			var edge := lerpf(1.24,1.78,(1-cos(around))*0.5)
			var angle := edge*ring/6.0
			var normal := Vector3(sin(angle)*sin(around),cos(angle),-sin(angle)*cos(around))
			vertices.append(normal*radii)
			normals.append((normal/radii).normalized())
	for ring in range(6):
		for sector in range(16):
			var a := ring*17+sector
			indices.append_array(PackedInt32Array([a,a+17,a+1,a+1,a+17,a+18]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_INDEX]=indices
	hair_mesh=ArrayMesh.new()
	hair_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return hair_mesh

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
	receive_timer=0
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
	dive_speed = clampf((absf(side)-1.45)/maxf(time_available-0.10,0.18),0.7,5.8)
	dive_yaw = atan2(-facing.x,-facing.z)
	dive_launched = false

func can_save(ball_position: Vector3) -> bool:
	if pose in ["fall","stumble"] and action_timer>0: return false
	if pose=="claim" and action_timer>0:
		return minf(left_hand.global_position.distance_to(ball_position),right_hand.global_position.distance_to(ball_position))<0.65
	if pose=="dive" and action_timer>0:
		if dive_duration-action_timer>0.84: return false
		return minf(left_hand.global_position.distance_to(ball_position),right_hand.global_position.distance_to(ball_position))<0.40 or spine.to_global(Vector3(0,0.3,0)).distance_to(ball_position)<0.42
	return minf(left_hand.global_position.distance_to(ball_position),right_hand.global_position.distance_to(ball_position))<0.43 or (Vector2(global_position.x-ball_position.x,global_position.z-ball_position.z).length()<0.60 and ball_position.y<1.60)

func start_claim(target_height: float=2.8,time_available: float=0.35) -> void:
	if not keeper or action_timer>0 or tackle_cooldown>0: return
	pose="claim"
	action_timer=0.8
	tackle_cooldown=1.25
	velocity.y=clampf((target_height-2.3+10*time_available*time_available)/maxf(time_available,0.15),2.2,6.5)

func step(delta: float,stoppage_speed: float=0.0) -> void:
	feint_time=maxf(0,feint_time-delta)
	skill_cooldown=maxf(0,skill_cooldown-delta)
	if wall_hold>0:
		wall_hold=maxf(0,wall_hold-delta)
		if wall_hold==0: set_piece_pose=""
	if wall_jump_delay>=0:
		wall_jump_delay-=delta
		if wall_jump_delay<0: velocity.y=5.4
	call_timer = maxf(0,call_timer-delta)
	call_label.visible = false
	motion_clock += delta
	action_timer = maxf(0,action_timer-delta)
	tackle_cooldown = maxf(0,tackle_cooldown-delta)
	touch_cooldown = maxf(0,touch_cooldown-delta)
	kick_timer = maxf(0,kick_timer-delta)
	receive_timer = maxf(0,receive_timer-delta)
	if Vector2(velocity.x,velocity.z).length()>1.2 or kick_timer>0 or shot_preparation>0 or action_timer>0:
		idle_rest=0
	else:
		idle_rest=minf(1.2,idle_rest+delta)
	ai_think += delta
	update_stamina(delta)
	var speed := movement_speed()
	# Substitution exits remain physical but do not inherit match fatigue.
	if stamina_free_movement and stoppage_speed>0: speed=stoppage_speed
	if is_instance_valid(surface):
		speed*=1.0-surface.mud_at(position)*0.16
		stain(delta)
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
	var driving := Vector2(desired.x,desired.z).length()>0.05
	var current_speed := Vector2(velocity.x,velocity.z).length()
	var target_speed := Vector2(target.x,target.z).length()
	var acceleration := lerpf(38,56,smoothstep(0.08,0.4,energy))
	var sprint_acceleration := lerpf(11,16,smoothstep(0.08,0.4,energy))
	var deceleration := lerpf(8,12,smoothstep(0.08,0.4,energy))
	var settle := lerpf(7,10,smoothstep(0.08,0.4,energy))
	if stamina_free_movement and stoppage_speed>0:
		acceleration=56
		sprint_acceleration=16
		deceleration=12
		settle=10
	# Dives and slides retain their own launch timing.
	if action_timer>0:
		acceleration=23
		sprint_acceleration=23
		deceleration=23
		settle=23
	var rate := acceleration
	if not driving:
		rate=deceleration
	elif current_speed>target_speed+0.25:
		rate=settle
	elif active_sprint and current_speed>5.4:
		rate=sprint_acceleration
	if is_instance_valid(surface): rate*=surface.grip_at(position)
	velocity.x = move_toward(velocity.x,target.x,delta*rate)
	velocity.z = move_toward(velocity.z,target.z,delta*rate)
	velocity.y -= 20*delta
	var travel_velocity := velocity
	move_and_slide()
	body_language.collisions(self,travel_velocity)
	if desired.length()>0.05 and action_timer<=0 and (not keeper or stoppage_speed>0) and not protecting and not jockeying and kick_timer<=0 and shot_preparation<=0:
		facing = desired.normalized()
	if facing.length()>0.1 and not (pose=="dive" and action_timer>0):
		rig.rotation.y = lerp_angle(rig.rotation.y,atan2(-facing.x,-facing.z),1-exp(-delta*12))
	var horizontal := Vector3(velocity.x,0,velocity.z)
	acceleration_lean = acceleration_lean.lerp((horizontal-last_horizontal)/maxf(delta,0.001),1-exp(-delta*7))
	locomotion.update(self,delta,last_horizontal)
	body_language.update(self,delta)
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
	if stamina_free_movement:
		active_sprint=false
		return
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
	if active_sprint: return lerpf(8.8,10.4,smoothstep(0.08,0.4,energy))
	return lerpf(4.6,6.5 if keeper else 6.2,smoothstep(0.08,0.3,energy))

func begin_kick(power: float,duration: float,style: String="laces") -> void:
	kick_power=power
	kick_duration=duration
	kick_style=style if style in ["inside","laces","chip"] else "laces"
	kick_timer=duration
	receive_timer=0
	idle_rest=0
	shot_preparation=0
	# Start from the current stride, including a quick tap or a running shot.
	kick_start_pose.clear()
	for joint in kick_joints: kick_start_pose.append(joint.rotation)

func begin_receive(style: String) -> void:
	if action_timer>0 or kick_timer>0 or keeper: return
	receive_style=style if style in ["chest","thigh","foot"] else "foot"
	receive_duration=0.46 if receive_style=="chest" else (0.38 if receive_style=="thigh" else 0.30)
	receive_timer=receive_duration

func apply_build() -> void:
	var seed: int=shirt_number if shirt_number>0 else number
	var height := 1.20
	var width := 1.25
	if official:
		height=1.18; width=1.22
	elif keeper:
		height=1.28; width=1.22
	elif number in [2,3,4,5]:
		height=1.24+fmod(float(seed)*0.017,0.05)
		width=1.28
	elif number in [7,11]:
		height=1.16+fmod(float(seed)*0.013,0.04)
		width=1.18
	else:
		height=1.18+fmod(float(seed)*0.021,0.06)
		width=1.22+fmod(float(seed)*0.019,0.08)
	body_scale=Vector3(width,height,width)
	idle_habit=seed%4
	stance=0.08 if keeper else (0.055 if number in [2,3,4,5] else 0.0)
	rig.scale=body_scale
	if body_collision!=null and body_collision.shape is CapsuleShape3D:
		var shape: CapsuleShape3D=body_collision.shape
		shape.height=1.72*(height/1.20)
		shape.radius=0.33*(width/1.25)
		body_collision.position.y=shape.height*0.5

func animate_shot(delta: float,amount: float,stride: float) -> void:
	var ready := shot_preparation if action_timer<=0 and kick_timer<=0 else 0.0
	shot_ready_blend=move_toward(shot_ready_blend,ready,delta*5.5)
	if action_timer>0: return
	if shot_ready_blend>0:
		# Charging is a running/standing ready posture, never a held backswing.
		# Leave both legs in their gait so support keeps alternating naturally.
		var balance := shot_ready_blend
		spine.rotation=spine.rotation.lerp(Vector3(-0.12-amount*0.12,-0.2-wrapping*0.15,0.025),balance)
		left_arm.rotation=left_arm.rotation.lerp(Vector3(-stride*0.42*amount+0.08,0,-0.38-wrapping*0.1),balance)
		right_arm.rotation=right_arm.rotation.lerp(Vector3(stride*0.42*amount-0.15,0,0.32),balance)
		left_elbow.rotation.x=lerpf(left_elbow.rotation.x,0.65+stride*0.14*amount,balance)
		right_elbow.rotation.x=lerpf(right_elbow.rotation.x,0.75-stride*0.14*amount,balance)
	if kick_timer<=0: return
	var progress := clampf(1-kick_timer/kick_duration,0,1)
	var entry := smoothstep(0,0.09,progress)
	var sweep := smoothstep(0,0.24,progress)
	var recoil := smoothstep(0.28,0.68,progress)
	var recover := smoothstep(0.50,1.0,progress)
	var plant := 1-smoothstep(0.28,0.74,progress)
	# Contact -> follow-through -> knee recovery -> live running stride.
	# The ball is released immediately; only the visual follow-through takes time.
	var inside: float=1.0 if kick_style=="inside" else 0.0
	var chip: float=1.0 if kick_style=="chip" else 0.0
	var hip := lerpf(lerpf(0.42,lerpf(lerpf(0.85,0.72,inside),lerpf(1.24,0.92,inside),kick_power),sweep),0.12,recoil)
	if chip>0: hip=lerpf(lerpf(0.50,lerpf(0.95,1.18,kick_power),sweep),0.18,recoil)
	var knee := lerpf(lerpf(-0.12,-0.28,sweep),-0.86,recoil)
	var open := inside*lerpf(0.0,0.46,sweep)
	var poses: Array[Vector3] = [
		Vector3(0.24,0,-0.045-inside*0.08),Vector3(hip,open,0.045+inside*0.16),
		Vector3(-0.42,0,0),Vector3(knee,0,inside*0.22),
		Vector3(-0.12-kick_power*0.16*sweep-chip*0.18*sweep,lerpf(-0.12,0.3,sweep)*kick_power+inside*0.22*sweep,-0.055*sweep),
		Vector3(0.18+0.22*sweep,0,-0.55-kick_power*0.25*sweep),
		Vector3(-0.32+0.72*sweep,0,0.38+0.14*sweep),
		Vector3(lerpf(0.62,0.4,sweep)+recoil*0.25,0,0),
		Vector3(lerpf(0.85,0.5,sweep)+recoil*0.2,0,0)
	]
	for i in range(kick_joints.size()):
		var joint := kick_joints[i]
		var weight := plant if i in [0,2] else 1-recover
		var rotation_target := joint.rotation.lerp(poses[i],weight)
		joint.rotation=kick_start_pose[i].lerp(rotation_target,entry) if kick_start_pose.size()==kick_joints.size() else rotation_target

func apply_receive() -> void:
	var progress := 1.0-receive_timer/maxf(receive_duration,0.01)
	var hold := smoothstep(0,0.16,progress)*(1.0-smoothstep(0.58,1.0,progress))
	if receive_style=="chest":
		spine.rotation.x=lerpf(spine.rotation.x,-0.08+0.22*hold,hold)
		left_arm.rotation=left_arm.rotation.lerp(Vector3(1.15,0,-0.72),hold)
		right_arm.rotation=right_arm.rotation.lerp(Vector3(1.15,0,0.72),hold)
		left_elbow.rotation.x=lerpf(left_elbow.rotation.x,0.55,hold)
		right_elbow.rotation.x=lerpf(right_elbow.rotation.x,0.55,hold)
	elif receive_style=="thigh":
		right_leg.rotation.x=lerpf(right_leg.rotation.x,0.95,hold)
		right_knee.rotation.x=lerpf(right_knee.rotation.x,-0.28,hold)
		spine.rotation.x=lerpf(spine.rotation.x,-0.18,hold)
		left_arm.rotation.z=lerpf(left_arm.rotation.z,-0.55,hold)
	else:
		right_leg.rotation.x=lerpf(right_leg.rotation.x,0.42,hold)
		right_knee.rotation.x=lerpf(right_knee.rotation.x,-0.72,hold)
		spine.rotation.x=lerpf(spine.rotation.x,-0.16,hold)

func animate(delta: float) -> void:
	var amount: float=clampf(Vector2(velocity.x,velocity.z).length()/8.7,0,1)
	var tired: float=0.0 if energy>0.42 else clampf((0.42-energy)/0.42,0,1)
	var gait: float=amount*(1.0-tired*0.28)
	var stride = sin(run_phase)
	var idle = sin(motion_clock*(1.55 if tired>0.4 else 2.0)+number*0.8)
	var blend = 1-exp(-delta*14)
	var local_accel = acceleration_lean.rotated(Vector3.UP,-rig.rotation.y)
	left_leg.rotation = Vector3(0.10+stride*0.78*gait,0,-0.035)
	right_leg.rotation = Vector3(0.10-stride*0.78*gait,0,0.035)
	left_knee.rotation.x = -0.19-maxf(0,-stride)*1.08*gait
	right_knee.rotation.x = -0.19-maxf(0,stride)*1.08*gait
	left_arm.rotation = Vector3(-stride*0.55*gait-0.08-tired*0.12,0,-0.13)
	right_arm.rotation = Vector3(stride*0.55*gait-0.08-tired*0.12,0,0.13)
	left_elbow.rotation.x = 0.50+gait*0.34+stride*0.09+tired*0.18
	right_elbow.rotation.x = 0.50+gait*0.34-stride*0.09+tired*0.18
	spine.rotation = spine.rotation.lerp(Vector3(-0.065-amount*0.12-tired*0.10-stance-(0.065 if exhausted else 0.0),sin(run_phase)*gait*0.065,-stride*gait*0.035),blend)
	if exhausted:
		spine.position.y = 0.94+sin(motion_clock*5.0)*0.012
	else: spine.position.y = 0.94
	rig.position = rig.position.lerp(Vector3(idle*0.013*(1-amount),-0.03+absf(stride)*0.045*amount,0),blend)
	rig.rotation.x = lerp_angle(rig.rotation.x,-0.035-amount*0.075+clampf(local_accel.z*0.006,-0.08,0.08),blend)
	rig.rotation.z = lerp_angle(rig.rotation.z,clampf(-local_accel.x*0.010,-0.16,0.16)+idle*0.015*(1-amount),blend)
	body_collision.rotation = Vector3.ZERO
	if body_collision.shape is CapsuleShape3D:
		body_collision.position = Vector3(0,(body_collision.shape as CapsuleShape3D).height*0.5,0)
	else:
		body_collision.position = Vector3(0,0.87,0)
	locomotion.apply_pose(self,gait,stride)
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
	if idle_rest>0.35 and gait<0.12 and shot_preparation<=0 and kick_timer<=0 and receive_timer<=0 and action_timer<=0 and call_timer<=0 and body_language.point_weight<=0.05 and body_language.point_cooldown<=0 and not keeper and not protecting and not jockeying:
		var rest: float=smoothstep(0.35,0.7,idle_rest)
		match idle_habit:
			1:
				left_arm.rotation=left_arm.rotation.lerp(Vector3(0.35,0,-1.15),rest)
				right_arm.rotation=right_arm.rotation.lerp(Vector3(0.35,0,1.15),rest)
				left_elbow.rotation.x=lerpf(left_elbow.rotation.x,1.15,rest)
				right_elbow.rotation.x=lerpf(right_elbow.rotation.x,1.15,rest)
			2:
				right_arm.rotation=right_arm.rotation.lerp(Vector3(0.85,0.35,0.55),rest)
				right_elbow.rotation.x=lerpf(right_elbow.rotation.x,1.35,rest)
			3:
				left_leg.rotation.x+=0.18*rest
				left_knee.rotation.x-=0.22*rest
				spine.rotation.z+=0.04*rest
	animate_shot(delta,amount,stride)
	if receive_timer>0 and kick_timer<=0 and action_timer<=0: apply_receive()
	if call_timer>0 and kick_timer<=0 and shot_preparation<=0:
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
	elif set_piece_pose in ["carry","pickup","throw","receive"]:
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
			if number%3==1:
				right_arm.rotation=Vector3(0.15,0,2.72+pulse*0.22)
				left_arm.rotation=Vector3(0.4,0,-0.35)
				right_elbow.rotation.x=0.22
				left_elbow.rotation.x=0.7
			elif number%3==2:
				left_arm.rotation=Vector3(0.05,0,-2.35)
				right_arm.rotation=Vector3(0.05,0,2.35)
				left_elbow.rotation.x=1.15
				right_elbow.rotation.x=1.15
				spine.rotation.x=0.16
			else:
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

	body_language.apply_pose(self)
	locomotion.finish_pose(self)
	if discipline_pose!="" and action_timer<=0:
		var pulse := sin(motion_clock*6.2+number)*0.12
		if discipline_pose=="protest":
			left_arm.rotation=Vector3(0.72+pulse,0,-0.72)
			right_arm.rotation=Vector3(0.95-pulse,0,0.62)
			left_elbow.rotation.x=0.95
			right_elbow.rotation.x=0.85+pulse
			spine.rotation.z=pulse*0.3
		elif discipline_pose=="shove":
			var reach := smoothstep(0.08,0.28,discipline_age)*(1-smoothstep(0.40,0.8,discipline_age))
			left_arm.rotation=Vector3(lerpf(0.75,1.38,reach),0,-0.18)
			right_arm.rotation=Vector3(lerpf(0.75,1.38,reach),0,0.18)
			left_elbow.rotation.x=lerpf(1.35,0.08,reach)
			right_elbow.rotation.x=left_elbow.rotation.x
			spine.rotation.x=-0.08-reach*0.20
		elif discipline_pose=="separate":
			left_arm.rotation=Vector3(0.8+pulse*0.2,0,-1.22)
			right_arm.rotation=Vector3(0.8-pulse*0.2,0,1.22)
			left_elbow.rotation.x=0.35
			right_elbow.rotation.x=0.35
		elif discipline_pose=="dismissed":
			spine.rotation.x=-0.235-amount*0.12
			left_arm.rotation.x*=0.55
			right_arm.rotation.x*=0.55
	body_language.apply_gaze(self,delta)

func hand_center() -> Vector3:
	return (left_hand.global_position+right_hand.global_position)*0.5

func animate_dive() -> void:
	var time := dive_duration-action_timer
	var launch := smoothstep(0.10,0.36,time)
	var recover := smoothstep(0.94,dive_duration,time)
	var spread := launch*(1-recover)
	var airborne_roll := lerpf(1.48,1.25,(dive_height-0.2)/2.1)
	var roll := spread*lerpf(airborne_roll,1.46,smoothstep(0.50,0.76,time))
	rig.basis = (Basis(Vector3.FORWARD,dive_direction*roll)*Basis(Vector3.UP,dive_yaw)).scaled(body_scale)
	# Rotate around the pelvis, not the feet: the body lands above the turf.
	var pelvis_height := lerpf(1.08,0.44,spread)
	if time<0.10: pelvis_height -= smoothstep(0.0,0.1,time)*0.17
	rig.position = Vector3(0,pelvis_height,0)-rig.basis*Vector3(0,0.9,0)
	spine.rotation = Vector3(-0.10,0,dive_direction*0.035)
	# Bring both gloves toward the same interception point. Splayed arms left a gap
	# through the middle of an otherwise correctly positioned diving save.
	left_arm.rotation = Vector3(0.12,0,-lerpf(0.4,3.16,spread))
	right_arm.rotation = Vector3(0.12,0,lerpf(0.4,3.16,spread))
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

func apply_kit(colors: Dictionary) -> void:
	if official or kit_materials.is_empty(): return
	var keeper_color := Color("d7b83c") if team==0 else Color("5998ac")
	var primary: Color=colors.primary
	if Vector3(keeper_color.r-primary.r,keeper_color.g-primary.g,keeper_color.b-primary.b).length()<0.45: keeper_color=Color("d096bd")
	kit_materials.jersey.albedo_color=keeper_color if keeper else primary
	kit_materials.socks.albedo_color=kit_materials.jersey.albedo_color
	kit_materials.trim.albedo_color=colors.accent
	kit_materials.shorts.albedo_color=Color("171d23") if keeper else colors.shorts
	kit_clean={"jersey":kit_materials.jersey.albedo_color,"socks":kit_materials.socks.albedo_color,"shorts":kit_materials.shorts.albedo_color}
	kit_soil=0
	shirt_label.modulate=colors.accent
	if kit_pattern!=null:
		kit_pattern.scale=Vector3(1,1,1) if int(colors.pattern)==0 else (Vector3(0.32,4.1,1) if int(colors.pattern)==1 else Vector3(1.03,2.3,1))
		kit_pattern.rotation.z=deg_to_rad(-24) if int(colors.pattern)==2 else 0.0
	apply_build()

func stain(delta: float) -> void:
	if official or kit_clean.is_empty() or kit_materials.is_empty(): return
	if is_instance_valid(surface) and is_instance_valid(surface.game) and surface.game.state not in ["playing","restart","set_piece"]: return
	var play: float=clampf(surface.clock/240.0,0,1) if is_instance_valid(surface) else 0.0
	var mud: float=surface.mud_at(position) if is_instance_valid(surface) else 0.0
	var wet: float=surface.wetness if is_instance_valid(surface) else 0.0
	var gain: float=(0.016+play*0.028+mud*0.045+wet*0.012)*delta
	if pose in ["slide","dive"] and action_timer>0: gain+=0.085*delta
	kit_soil=minf(0.82,kit_soil+gain)
	var dirt := Color(0.24,0.19,0.11)
	kit_materials.jersey.albedo_color=kit_clean.jersey.lerp(dirt,kit_soil*0.40)
	kit_materials.shorts.albedo_color=kit_clean.shorts.lerp(dirt,kit_soil*0.55)
	kit_materials.socks.albedo_color=kit_clean.socks.lerp(dirt,kit_soil*0.64)
