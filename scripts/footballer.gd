extends CharacterBody3D
const G = preload("res://scripts/geometry.gd")
const KitGraphics = preload("res://scripts/kit_graphics.gd")
const KitCloth = preload("res://scripts/kit_cloth.gd")
const Attributes = preload("res://scripts/player_attributes.gd")
# The authored rig was enlarged for the old arcade view. World units are metres.
const WORLD_SCALE := 0.76
const REFERENCE_SCALE := Vector3(1.25,1.20,1.25)*WORLD_SCALE
var attributes: Dictionary=Attributes.profile(0,9)
var career_id := ""
var natural_position := -1
var appearance_id := -1
var contest_weight := 0.0
var contest_direction := Vector3.ZERO
var landing_age := 1.0
var landing_strength := 0.0
var header_airborne := false
var aerial_preparing := false
const Physique = preload("res://scripts/player_physique.gd")
const Locomotion = preload("res://scripts/locomotion.gd")
var locomotion := Locomotion.new()
var defer_running_pose := false
var pending_pose_delta := 0.0
var running_pose_interval := 0.0
var render_batch: Node3D

func can_defer_running_pose() -> bool:
	return not keeper and pose=="run" and action_timer<=0 and kick_timer<=0 and receive_timer<=0 and shot_preparation<=0 and not ball_actions.contact_pending and dribble_motion.freshness<=0 and not protecting and not jockeying and not aerial_preparing and skill_move.is_empty() and feint_time<=0 and set_piece_pose=="" and celebration=="" and discipline_pose=="" and contest_weight<=0 and body_language.contest_weight<=0 and locomotion.cut<=0 and locomotion.braking<.02 and locomotion.plant_weight<=0

func flush_running_pose() -> void:
	if pending_pose_delta<=0: return
	var delta := pending_pose_delta
	pending_pose_delta=0
	animate(delta)
const BodyLanguage = preload("res://scripts/body_language.gd")
var body_language := BodyLanguage.new()
var head_joint := Node3D.new()
var eye_joints: Array[Node3D] = []
var eye_forms: Array[Node3D] = []
var boot_meshes: Array[MeshInstance3D] = []
const Appearance = preload("res://scripts/player_appearance.gd")
var appearance: Dictionary = {}
const BallActions = preload("res://scripts/ball_actions.gd")
const ImpactMotion = preload("res://scripts/impact_motion.gd")
const PlayerReaction = preload("res://scripts/player_reaction.gd")
var ball_actions := BallActions.new()
var dribble_motion := preload("res://scripts/dribble_motion.gd").new()
var impact_motion := ImpactMotion.new()
var reaction := PlayerReaction.new()
var motion_transition := preload("res://scripts/motion_transition.gd").new()
var keeper_motion := preload("res://scripts/keeper_motion.gd").new()
var gait_cadence := 1.8
var gait_stride := 1.0
var gait_width := 1.0
var gait_sway := 1.0
var kick_character := 1.0
var tackle_foot := 1
var tackle_target := Vector3.ZERO
static var hair_mesh: ArrayMesh
const HairStyles=preload("res://scripts/hair_styles.gd")
var haircut: MeshInstance3D
var hair_style := 0
var kit_materials: Dictionary = {}
var kit_clean: Dictionary = {}
var kit_soil := 0.0
var shown_soil := -1.0
var shown_wetness := -1.0
var kit_colors: Dictionary = {}
var jersey_body: MeshInstance3D
var captain := false
var captain_band: MeshInstance3D
var gloves: Array[MeshInstance3D] = []
var team := 0
var number := 10
var shirt_number := 10
var height_cm := 180
var weight_kg := 76
var keeper := false
var display_name := "EGE"
var home := Vector3.ZERO
var desired := Vector3.ZERO
var facing := Vector3.FORWARD
var energy := 1.0
var sprinting := false
const SPRINT_DRAIN := 0.026
const RUN_DRAIN := 0.0027
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
var celebration_motion := preload("res://scripts/celebration_pose.gd").new()
var chosen := false
var call_timer := 0.0
var call_label := Label3D.new()
var marker: MeshInstance3D
var slide_duration := 0.72
var slide_rise := 0.40
var sprint_load := 0.0
var breath := 0.0
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
var defensive_turn_load := 0.0
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
var body_scale := REFERENCE_SCALE
var receiving_facing := Vector3.ZERO
var idle_habit := 0
var idle_rest := 0.0
var stance := 0.0
var impact_direction := Vector3.ZERO
var impact_strength := 0.0
var impact_duration := 0.8
var skill_move: Dictionary = {}
var dummy_time := 0.0
var distribution_move: Dictionary = {}
const SkillMoves = preload("res://scripts/skill_moves.gd")
const Distribution = preload("res://scripts/keeper_distribution.gd")
var volley_motion := preload("res://scripts/volley_pose.gd").new()
var header_duration := 0.72
var header_hit_age := -1.0
var header_start: Array[Quaternion] = []

func begin_header(jump: float,direction: Vector3) -> void:
	pose="header"; action_timer=header_duration; header_hit_age=-1
	kick_timer=0; receive_timer=0; shot_preparation=0; shot_ready_blend=0
	header_start.clear()
	for joint in kick_joints: header_start.append(joint.quaternion)
	facing=(direction*Vector3(1,0,1)).normalized()
	velocity.y=maxf(velocity.y,jump)
	header_airborne=jump>0.1
	energy=maxf(0,energy-0.018-jump*0.003)

func animate_header() -> void:
	var age := header_duration-action_timer
	var entry := smoothstep(0,0.065,age)
	var recover := smoothstep(0.40,header_duration,age)
	var nod := 0.0 if header_hit_age<0 else smoothstep(0,0.065,header_hit_age)*(1-smoothstep(0.14,0.34,header_hit_age))
	var poses: Array[Vector3]=[
		Vector3(0.18,0,-0.08),Vector3(0.30,0,0.10),Vector3(-0.58,0,0),Vector3(-0.84,0,0),
		Vector3(0.12-nod*0.44,0,0),Vector3(0.32,0,-0.72),Vector3(0.42,0,0.75),Vector3(0.95,0,0),Vector3(1.05,0,0)]
	for i in range(kick_joints.size()):
		var joint: Node3D=kick_joints[i]
		var target := Quaternion.from_euler(poses[i]).slerp(joint.quaternion,recover)
		joint.quaternion=header_start[i].slerp(target,entry)
	head_joint.rotation.x=lerpf(head_joint.rotation.x,0.16-nod*0.45,(1-recover)*entry)
	head_joint.rotation.y=lerpf(head_joint.rotation.y,0.0,entry*(1-recover))
	if is_on_floor():
		var sole := minf(left_knee.to_global(Vector3(0,-0.42,-0.05)).y,right_knee.to_global(Vector3(0,-0.42,-0.05)).y)
		rig.position.y-=sole-global_position.y-boot_ground_height()

func _ready() -> void:
	# Keep the 120 Hz joint animation local; ball interpolation is independent.
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	shirt_number=number
	var physique := Physique.profile(team,number-1,keeper)
	height_cm=physique.height_cm; weight_kg=physique.weight_kg
	build_model()
	kick_joints.assign([left_leg,right_leg,left_knee,right_knee,spine,left_arm,right_arm,left_elbow,right_elbow])
	apply_build()
	if not official:
		apply_kit({"primary":Color("e5ece5") if team==0 else Color("d34532"),"accent":Color("193d39") if team==0 else Color("f1d7bd"),"shorts":Color("133933") if team==0 else Color("eee3d2"),"pattern":0,"club_id":team})
	var torus = TorusMesh.new()
	torus.inner_radius = 0.67*WORLD_SCALE
	torus.outer_radius = 0.72*WORLD_SCALE
	torus.rings = 32
	torus.ring_segments = 6
	var mat = G.material(Color("e8df92"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker = G.mesh(self,torus,mat,Vector3(0,0.035,0))
	marker.scale.y = 0.18
	add_child(call_label)
	call_label.text = "PAS!"
	call_label.position = Vector3(0,height_cm/100.0+0.28,0)
	call_label.font_size = 48
	call_label.pixel_size = 0.008
	call_label.modulate = Color("f2df93")
	call_label.outline_size = 8
	call_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	call_label.visible = false
	# Construct a live stance before the first rendered frame, including actors
	# created for a lineup or swapped in while the simulation is stopped.
	run_phase=fmod(shirt_number*2.399+team*.71,TAU)
	motion_clock=shirt_number*.173+team*.41
	animate(1.0)
	# Batch the rigid clothing/skin pieces while keeping all gameplay joints.
	if DisplayServer.get_name()!="headless":
		render_batch=preload("res://scripts/rigid_player_batch.gd").new()
		render_batch.setup(self)
		if "--unbatched-players" in OS.get_cmdline_user_args(): render_batch.set_active(false)

func build_model() -> void:
	var kit_color = Color("e5ece5") if team==0 else Color("d34532")
	if keeper: kit_color = Color("d7b83c") if team==0 else Color("5998ac")
	if official: kit_color=Color("171b20")
	var jersey := KitCloth.new(); jersey.albedo_color=kit_color
	var trim = G.material(Color("193d39") if team==0 else Color("f1d7bd"))
	if official: trim=G.material(Color("bbc4c5"))
	var shorts := KitCloth.new(); shorts.albedo_color=Color("133933") if team==0 else Color("eee3d2")
	if keeper or official: shorts.albedo_color=Color("171d23")
	shorts.set_shader_parameter("garment",1)
	var socks := KitCloth.new(); socks.albedo_color=kit_color; socks.set_shader_parameter("garment",2)
	kit_materials={"jersey":jersey,"trim":trim,"shorts":shorts,"socks":socks}
	var skin = G.material(Appearance.SKIN_TONES[0])
	var hair = G.material([Color("201e1b"),Color("32261d"),Color("6e5030")][number%3])
	kit_materials.skin=skin; kit_materials.hair=hair
	var knees := KitCloth.new(); knees.albedo_color=skin.albedo_color; knees.set_shader_parameter("garment",3)
	kit_materials.knees=knees
	var boots = G.material(Color.WHITE,.65)
	boots.vertex_color_use_as_albedo=true
	kit_materials.boots=boots
	var printed := KitCloth.new()
	printed.albedo_color=kit_color
	kit_materials["printed"]=printed
	jersey_body=G.mesh(rig,KitGraphics.torso_mesh(),printed,Vector3(0,1.22,0))
	jersey_body.name="JerseyCloth"
	G.cylinder(rig,0.12,0.06,Vector3(0,1.51,0),trim)
	G.cylinder(rig,0.235,0.27,Vector3(0,0.83,0),shorts)
	G.cylinder(rig,0.095,0.12,Vector3(0,1.56,0),skin)
	rig.add_child(head_joint)
	head_joint.name="Head"
	head_joint.position=Vector3(0,1.60,0)
	var head = G.sphere(head_joint,0.205,Vector3(0,0.16,0),skin)
	head.scale = Vector3(0.86,1.1,0.91)
	# A fitted scalp shell covers the head's crown; an offset squashed sphere
	# intersected the forehead and exposed a skin-coloured patch on every player.
	haircut = G.mesh(head_joint,scalp_mesh(),hair,Vector3(0,0.16,0))
	haircut.name="HairCap"
	refresh_hair()
	var nose=G.sphere(head_joint,0.045,Vector3(0,0.15,-0.181),skin)
	G.combine_rigid(head_joint,[head,nose],"head_skin")
	var eye_white := G.material(Color("cbc8b8"))
	var iris := G.material(Color("292921"))
	for side in [-1,1]:
		var eye := Node3D.new()
		head_joint.add_child(eye)
		eye.position=Vector3(side*0.071,0.19,-0.171)
		eye_joints.append(eye)
		var form:=Node3D.new(); form.name="EyeForm"; eye.add_child(form); eye_forms.append(form)
		var white := G.sphere(form,0.026,Vector3.ZERO,eye_white)
		white.scale=Vector3(1,0.42,0.25)
		var pupil := G.sphere(form,0.012,Vector3(0,0,-0.006),iris)
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
		var kneecap=G.sphere(knee,0.084,Vector3.ZERO,knees)
		var shin=G.cylinder(knee,0.081,0.12,Vector3(0,-0.055,0),knees)
		G.combine_rigid(knee,[kneecap,shin],"knee_skin")
		G.cylinder(knee,0.075,0.29,Vector3(0,-0.24,0),socks)
		G.cylinder(knee,0.079,0.045,Vector3(0,-0.14,0),trim)
		var boot = G.mesh(knee,Appearance.boot_mesh(0),boots,Vector3(0,-0.42,-0.05))
		boot.name="Boot"; boot_meshes.append(boot)
		boot.scale = Vector3(0.77,0.61,1.65)
		var arm = left_arm if side<0 else right_arm
		rig.add_child(arm)
		arm.position = Vector3(side*0.315,1.43,0)
		G.cylinder(arm,0.105,0.24,Vector3(0,-0.1,0),jersey)
		if side<0 and not official:
			captain_band=G.cylinder(arm,.111,.088,Vector3(0,-.155,0),G.material(Color("f7df68")))
			captain_band.name="CaptainArmband"; captain_band.visible=false
			G.cylinder(captain_band,.113,.016,Vector3(0,0,0),G.material(Color("15272e")))
		var elbow = left_elbow if side<0 else right_elbow
		arm.add_child(elbow)
		elbow.position = Vector3(0,-0.24,0)
		var elbow_cap=G.sphere(elbow,0.077,Vector3.ZERO,skin)
		var forearm=G.cylinder(elbow,0.072,0.25,Vector3(0,-0.125,0),skin)
		var hand = G.sphere(elbow,0.103 if keeper else 0.08,Vector3(0,-0.29,0),G.material(Color("ececd7")) if keeper else skin)
		if keeper:
			G.combine_rigid(elbow,[elbow_cap,forearm],"forearm_skin")
		else:
			G.combine_rigid(elbow,[elbow_cap,forearm,hand],"forearm_hand_skin",[hand])
		if keeper:
			hand.scale=Vector3(1.05,1.3,.66)
			gloves.append(hand); hand.name="KeeperGlove"
			G.block(hand,Vector3(.145,.12,.03),Vector3(0,-.025,.063),G.material(Color("253a48")))
			G.cylinder(hand,.085,.058,Vector3(0,.09,0),G.material(Color("ef9e42")))
		if side<0: left_hand = hand
		else: right_hand = hand
	# A waist pivot lets the torso bend independently of hips and planted feet.
	rig.add_child(spine)
	spine.position = Vector3(0,0.94,0)
	for part in rig.get_children():
		if part==spine or part.position.y<1.0: continue
		var local_position: Vector3 = part.position
		part.reparent(spine,false)
		part.position = local_position-spine.position
	refresh_appearance()

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
	action_timer = slide_duration+slide_rise
	tackle_cooldown = 1.35
	if direction.length() > 0.1:
		facing = direction.normalized()
	var current := Vector2(velocity.x, velocity.z).length()
	velocity = facing * maxf(current * 0.45 + 2.2, 8.4)
	skid_last = Vector3.ZERO

func receive_impact(direction: Vector3,strength: float) -> void:
	if action_timer>0 and pose in ["stumble","fall"]: return
	impact_direction=(direction*Vector3(1,0,1)).normalized()
	impact_strength=clampf(strength,0,1)
	impact_duration=lerpf(0.5,1.12,impact_strength)
	action_timer=impact_duration
	pose="fall" if impact_strength>0.7 else "stumble"
	velocity=velocity*0.25+impact_direction*lerpf(1.5,4.2,impact_strength)
	impact_motion.begin(self)
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
	if pose.begins_with("keeper_") and action_timer>0: return keeper_motion.can_save(self,ball_position)
	if motion_clock-keeper_motion.saved_at<keeper_motion.recovery: return false
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
	var glove_height := body_scale.y*1.94
	velocity.y=clampf((target_height-glove_height+10*time_available*time_available)/maxf(time_available,0.15),2.2,6.5)

func step(delta: float,stoppage_speed: float=0.0) -> void:
	if pending_pose_delta>0:
		# A cut/brake needs the last real world-space foot anchors before the
		# body moves, even when it begins between two rendered frames.
		var old_request: Vector3=locomotion.previous_request
		var moving := desired.length_squared()>=.0025
		var was_moving := old_request.length_squared()>=.0025
		if moving!=was_moving or (moving and was_moving and desired.normalized().dot(old_request.normalized())<.64):
			flush_running_pose()
	landing_age+=delta
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
	if pose=="slide" and action_timer<=slide_rise: pose="rise"
	tackle_cooldown = maxf(0,tackle_cooldown-delta)
	touch_cooldown = maxf(0,touch_cooldown-delta)
	kick_timer = maxf(0,kick_timer-delta)
	receive_timer = maxf(0,receive_timer-delta)
	if header_hit_age>=0: header_hit_age+=delta
	if Vector2(velocity.x,velocity.z).length()>1.2 or kick_timer>0 or shot_preparation>0 or action_timer>0:
		idle_rest=0
	else:
		idle_rest=minf(1.2,idle_rest+delta)
	ai_think += delta
	update_stamina(delta)
	var speed := movement_speed()
	var sampled_mud := -1.0
	# Substitution exits remain physical but do not inherit match fatigue.
	if stamina_free_movement and stoppage_speed>0: speed=stoppage_speed
	if is_instance_valid(surface):
		# Position and weather stay fixed until move_and_slide below. Share the
		# identical patch evaluation across speed, dirt and traction this step.
		sampled_mud=surface.mud_at(position)
		speed*=1.0-sampled_mud*0.16
		stain(delta,sampled_mud)
	var target = desired.limit_length(1)*speed
	if action_timer>0:
		if pose=="poke": target*=0.2
		elif pose=="keeper_rebound":
			var reach: Vector3=(keeper_motion.target-position)*Vector3(1,0,1)
			var age := keeper_motion.duration-action_timer
			target=reach.normalized()*minf(reach.length()*3,2.2)*(1-smoothstep(.20,.50,age))
		elif pose.begins_with("keeper_"): target*=.08
		elif pose=="claim": target*=0.35
		elif pose=="volley": target=Vector3(velocity.x,0,velocity.z).lerp(target,.55)
		elif pose in ["finish","intercept"]: target*=0.45
		elif pose=="header": target=Vector3(velocity.x,0,velocity.z).lerp(target,0.12)
		elif pose == "slide":
			var t := (action_timer-slide_rise)/slide_duration
			target = facing * lerpf(2.6, 8.6, clampf(t,0,1))
			leave_skid()
		elif pose=="rise":
			target*=0.08
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
	var energy_blend := smoothstep(0.08,0.4,energy)
	var acceleration_attribute := Attributes.multiplier(attributes.acceleration,.19)
	var pace := accel_pace()
	var acceleration: float=lerpf(38,56,energy_blend)*acceleration_attribute*pace
	var sprint_acceleration: float=lerpf(11,16,energy_blend)*acceleration_attribute*pace
	var deceleration := lerpf(8,12,energy_blend)*pace
	var settle := lerpf(7,10,energy_blend)*pace
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
	# A carrying cut plants the outside foot to brake the old sprint. Using
	# the slow straight-line sprint acceleration here makes the body overshoot
	# its own turn touch even though the new direction has already been pressed.
	if dribble_motion.freshness>0 and driving and current_speed>2 and Vector3(velocity.x,0,velocity.z).dot(desired.normalized())<current_speed*.92:
		rate=maxf(rate,acceleration)
	if defensive_turn_load>0 and action_timer<=0:
		rate=minf(rate,lerpf(28,12,defensive_turn_load)*Attributes.multiplier(attributes.get("defending",attributes.balance),.16))
	if is_instance_valid(surface): rate*=surface.grip_at(position,sampled_mud)
	velocity.x = move_toward(velocity.x,target.x,delta*rate)
	velocity.z = move_toward(velocity.z,target.z,delta*rate)
	velocity.y -= 20*delta
	var travel_velocity := velocity
	var stride_origin := position
	move_and_slide()
	if header_airborne and is_on_floor() and travel_velocity.y< -1:
		header_airborne=false; landing_age=0
		landing_strength=clampf(absf(travel_velocity.y)/8,0.2,1)*Attributes.multiplier(144-attributes.balance,.16)
	body_language.collisions(self,travel_velocity)
	if desired.length()>0.05 and action_timer<=0 and (not keeper or stoppage_speed>0) and not protecting and not jockeying and kick_timer<=0 and shot_preparation<=0 and not aerial_preparing:
		facing = desired.normalized()
	if receiving_facing.length_squared()>.1 and action_timer<=0 and kick_timer<=0 and not aerial_preparing:
		facing=receiving_facing
	if facing.length()>0.1 and not (pose in ["dive","fall","stumble","slide","rise"] and action_timer>0):
		rig.rotation.y = lerp_angle(rig.rotation.y,atan2(-facing.x,-facing.z),1-exp(-delta*12))
	var horizontal := Vector3(velocity.x,0,velocity.z)
	acceleration_lean = acceleration_lean.lerp((horizontal-last_horizontal)/maxf(delta,0.001),1-exp(-delta*7))
	locomotion.update(self,delta,last_horizontal)
	body_language.update(self,delta)
	ball_actions.update(delta)
	dribble_motion.update(self,delta)
	reaction.update(self,delta)
	last_horizontal = horizontal
	# Actual ground displacement keeps the stride from cycling against a body
	# or advertising a longer step than collision resolution allowed.
	var stride_distance := ((position-stride_origin)*Vector3(1,0,1)).length()
	run_phase += minf(stride_distance,travel_velocity.length()*delta+.01)*gait_cadence
	if defer_running_pose and can_defer_running_pose():
		pending_pose_delta+=delta
	else:
		var pose_delta := delta+pending_pose_delta
		pending_pose_delta=0
		animate(pose_delta)
	if is_instance_valid(surface): surface.player_step(self,delta)
	marker.visible = chosen and pose not in ["slide","dive","rise"]

func reset_stamina() -> void:
	energy = 1
	exhausted = false
	active_sprint = false
	sprinting = false
	recovery_delay = 0
	sprint_load=0
	breath=0

func update_stamina(delta: float) -> void:
	if stamina_free_movement:
		active_sprint=false
		sprint_load=0
		breath=0
		return
	var moving := desired.length()>0.1 and action_timer<=0
	recovery_delay = maxf(0,recovery_delay-delta)
	if exhausted and energy>=RECOVERY_LIMIT and not sprinting:
		exhausted = false
	active_sprint = moving and sprinting and not exhausted and energy>EXHAUSTION_LIMIT
	if active_sprint:
		energy -= SPRINT_DRAIN*delta/Attributes.multiplier(attributes.get("stamina",72),.25)
		recovery_delay = 0.75
	elif moving and not exhausted and desired.length()>0.45:
		energy -= RUN_DRAIN*minf(desired.length(),1)*delta/Attributes.multiplier(attributes.get("stamina",72),.25)
		recovery_delay = 0.75
	elif recovery_delay<=0:
		energy += (0.045 if moving else 0.12)*delta
	energy = clampf(energy,0,1)
	if energy<=EXHAUSTION_LIMIT:
		exhausted = true
		active_sprint = false
	if active_sprint: sprint_load=minf(5.5,sprint_load+delta*1.25)
	elif Vector2(velocity.x,velocity.z).length()>2.6: sprint_load=maxf(0,sprint_load-delta*0.38)
	else: sprint_load=maxf(0,sprint_load-delta*0.20)

const MOVEMENT_PACE := 0.68
const ACCEL_PACE := 0.78

func movement_pace() -> float:
	return MOVEMENT_PACE*(2.0 if prematch else 1.0)

func accel_pace() -> float:
	return ACCEL_PACE*(2.0 if prematch else 1.0)

func movement_speed() -> float:
	if exhausted: return 3.4*movement_pace()
	if active_sprint: return movement_pace()*lerpf(8.8,10.4,smoothstep(0.08,0.4,energy))*Attributes.multiplier(attributes.pace,.17)
	return movement_pace()*lerpf(4.6,6.5 if keeper else 6.2,smoothstep(0.08,0.3,energy))*Attributes.multiplier(attributes.pace,.055)

func begin_kick(power: float,duration: float,style: String="laces",point: Vector3=Vector3.INF,direction: Vector3=Vector3.ZERO,pressure: float=0) -> void:
	if point.is_finite(): ball_actions.prepare_kick(self,point,direction,pressure)
	kick_power=power
	kick_duration=duration+ball_actions.difficulty*0.04
	kick_style=style if style in ["inside","laces","chip"] else "laces"
	kick_timer=kick_duration
	receive_timer=0
	idle_rest=0
	shot_preparation=0
	# Start from the current stride, including a quick tap or a running shot.
	kick_start_pose.clear()
	for joint in kick_joints: kick_start_pose.append(joint.rotation)

func begin_receive(style: String,point: Vector3=Vector3.INF,incoming: Vector3=Vector3.ZERO,reach: float=0) -> void:
	if action_timer>0 or kick_timer>0 or keeper: return
	receive_style=style if style in ["chest","thigh","foot"] else "foot"
	receive_duration=0.46 if receive_style=="chest" else (0.38 if receive_style=="thigh" else 0.30)
	receive_duration+=clampf(incoming.length()/25,0,1)*0.12+reach*0.07
	receive_timer=receive_duration
	ball_actions.begin_receive(self,point if point.is_finite() else position+facing*0.55+Vector3.UP*preload("res://scripts/ball_dimensions.gd").GROUND_HEIGHT,incoming,reach)

func identity() -> Dictionary:
	return {"name":display_name,"shirt":shirt_number,"height_cm":height_cm,"weight_kg":weight_kg,"keeper":keeper,"attributes":attributes.duplicate(),"career_id":career_id,"role":natural_position,"appearance_id":appearance_id,"captain":captain}

func refresh_hair() -> void:
	if haircut==null: return
	var identity_value: int=appearance_id if appearance_id>=0 else shirt_number-1
	hair_style=HairStyles.style_for(identity_value)
	haircut.mesh=HairStyles.model(hair_style,scalp_mesh())
	kit_materials.hair.albedo_color=HairStyles.color_for(identity_value)

func refresh_appearance() -> void:
	var identity_value: int=appearance_id if appearance_id>=0 else shirt_number-1
	appearance=Appearance.profile(identity_value)
	if official: appearance.boots=0
	if kit_materials.has("skin"): kit_materials.skin.albedo_color=Appearance.SKIN_TONES[appearance.skin]
	if kit_materials.has("knees"): kit_materials.knees.albedo_color=Appearance.SKIN_TONES[appearance.skin]
	var form: Vector3=Appearance.EYE_FORMS[appearance.eyes]
	for i in range(eye_forms.size()):
		eye_forms[i].scale=Vector3(form.x,form.y,1)
		eye_forms[i].rotation.z=form.z*(-1 if i==0 else 1)
	for boot in boot_meshes: boot.mesh=Appearance.boot_mesh(appearance.boots)
	refresh_hair()

func apply_identity(data: Dictionary) -> void:
	career_id=data.get("career_id","")
	var role_value=data.get("role",-1)
	natural_position=int(role_value) if role_value is int else int(data.get("natural_group",-1))
	appearance_id=data.get("appearance_id",-1)
	display_name=data.get("name",display_name)
	shirt_number=int(data.get("shirt",shirt_number))
	set_captain(bool(data.get("captain",shirt_number==6)))
	refresh_appearance()
	attributes=data.get("attributes",Attributes.profile(team,shirt_number-1,keeper)).duplicate()
	var fallback := Physique.profile(team,shirt_number-1,keeper)
	height_cm=clampi(int(data.get("height_cm",fallback.height_cm)),166,199)
	weight_kg=clampi(int(data.get("weight_kg",fallback.weight_kg)),58,96)
	apply_build()
	refresh_shirt()

func apply_build() -> void:
	# Preserve each player's proportions while putting the rig in metre scale.
	var height := REFERENCE_SCALE.y*height_cm/180.0
	var mass_ratio := weight_kg/76.0*180.0/height_cm
	var width := clampf(1.25*sqrt(mass_ratio),1.10,1.40)*WORLD_SCALE
	var depth := clampf(1.25*pow(mass_ratio,0.42),1.12,1.38)*WORLD_SCALE
	if official: height=1.18*WORLD_SCALE; width=1.22*WORLD_SCALE; depth=1.22*WORLD_SCALE
	body_scale=Vector3(width,height,depth)
	# Vary the build without stretching faces with the shoulders.
	head_joint.scale=Vector3(clampf(REFERENCE_SCALE.x/width,.94,1.07),clampf(REFERENCE_SCALE.y/height,.96,1.05),clampf(REFERENCE_SCALE.z/depth,.94,1.07))
	idle_habit=shirt_number%4
	stance=0.08 if keeper else (0.055 if number in [2,3,4,5] else 0.0)
	var agility := clampf((float(attributes.control)+float(attributes.acceleration)-144)/70,-1,1)
	var build := clampf((weight_kg-76)/20.0+(height_cm-180)/38.0,-1,1)
	gait_cadence=(1.8/WORLD_SCALE)*clampf(180.0/height_cm+agility*.055-build*.045,.85,1.17)
	gait_stride=clampf(1+build*.09-agility*.06,.87,1.13)
	gait_width=1+build*.3
	gait_sway=1+build*.28-agility*.16
	kick_character=clampf(1+build*.12-agility*.08,.85,1.18)
	rig.scale=body_scale
	jersey_body.scale.x=clampf(1.0+build*.065,.95,1.07)
	left_arm.position.x=-.315*jersey_body.scale.x
	right_arm.position.x=.315*jersey_body.scale.x
	if body_collision!=null and body_collision.shape is CapsuleShape3D:
		var shape: CapsuleShape3D=body_collision.shape
		# The capsule already had human height; align its width to the smaller rig.
		shape.height=1.72*(height/REFERENCE_SCALE.y)
		shape.radius=0.33*(width/1.25)
		body_collision.position.y=shape.height*0.5
	call_label.position.y=height_cm/100.0+0.28

func boot_ground_height() -> float:
	# Boot mesh radius × its local Y scale, plus the grass clearance.
	return 0.115*0.61*body_scale.y+0.018

func animate_shot(delta: float,amount: float,stride: float) -> void:
	var ready := shot_preparation if action_timer<=0 and kick_timer<=0 else 0.0
	shot_ready_blend=move_toward(shot_ready_blend,ready,delta*5.5)
	if action_timer>0: return
	if shot_ready_blend>0:
		# Charging is a running/standing ready posture, never a held backswing.
		# Leave both legs in their gait so support keeps alternating naturally.
		var balance := shot_ready_blend
		var side := -1.0 if ball_actions.foot==0 else 1.0
		spine.rotation=spine.rotation.lerp(Vector3(-0.12-amount*0.12,(-0.2-wrapping*0.15)*side+ball_actions.kick_turn*0.32,0.025*side),balance)
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
	# Ordinary kicks overlay a measured boot approach before this follow-through.
	var inside: float=1.0 if kick_style=="inside" else 0.0
	var chip: float=1.0 if kick_style=="chip" else 0.0
	var hip := lerpf(lerpf(lerpf(0.42,0.20,inside),lerpf(lerpf(0.85,0.44,inside),lerpf(1.24,0.92,inside),kick_power),sweep),0.12,recoil)
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
	poses[4].y*=kick_character
	poses[4].z+=ball_actions.difficulty*0.16*sweep
	poses[5].z-=ball_actions.difficulty*0.28*sweep
	poses[6].z+=ball_actions.difficulty*0.22*sweep
	poses=ball_actions.mirror_poses(poses)
	# Footwork mirrors; turning toward the aimed direction must not.
	poses[4].y+=ball_actions.kick_turn*0.24*sweep
	for i in range(kick_joints.size()):
		var joint := kick_joints[i]
		var support := i in ([0,2] if ball_actions.foot==1 else [1,3])
		var weight := plant if support else 1-recover
		var rotation_target := joint.rotation.lerp(poses[i],weight)
		joint.quaternion=Quaternion.from_euler(kick_start_pose[i]).slerp(Quaternion.from_euler(rotation_target),entry) if kick_start_pose.size()==kick_joints.size() else Quaternion.from_euler(rotation_target)

func apply_receive() -> void:
	ball_actions.apply_receive(self)

func animate(delta: float) -> void:
	pending_pose_delta=0
	var amount: float=clampf(Vector2(velocity.x,velocity.z).length()/8.7,0,1)
	var tired: float=0.0 if energy>0.42 else clampf((0.42-energy)/0.42,0,1)
	# A carrier uses compact steps, leaving room for the next touch. The blend
	# preserves the current stride when acquiring or releasing the ball.
	var gait: float=amount*(1.0-tired*0.28)*gait_stride*lerpf(1.0,.76,dribble_motion.gait_weight)
	var stride = sin(run_phase)
	var idle = sin(motion_clock*(1.55 if tired>0.4 else 2.0)+number*0.8)
	var blend = 1-exp(-delta*14)
	var local_accel = acceleration_lean.rotated(Vector3.UP,-rig.rotation.y)
	left_leg.rotation = Vector3(0.10+stride*0.78*gait,0,-0.035*gait_width)
	right_leg.rotation = Vector3(0.10-stride*0.78*gait,0,0.035*gait_width)
	left_knee.rotation = Vector3(-0.19-maxf(0,-stride)*1.08*gait,0,0)
	right_knee.rotation = Vector3(-0.19-maxf(0,stride)*1.08*gait,0,0)
	left_arm.rotation = Vector3(-stride*0.55*gait-0.08-tired*0.12,0,-0.13)
	right_arm.rotation = Vector3(stride*0.55*gait-0.08-tired*0.12,0,0.13)
	# Start every overlay from a complete live pose. Hand IK can rotate all
	# three axes; retaining its old yaw/roll twisted later dives and gestures.
	left_elbow.rotation = Vector3(0.50+gait*0.34+stride*0.09+tired*0.18,0,0)
	right_elbow.rotation = Vector3(0.50+gait*0.34-stride*0.09+tired*0.18,0,0)
	spine.rotation = spine.rotation.lerp(Vector3(-0.065-amount*0.12-tired*0.10-stance-(0.065 if exhausted else 0.0),sin(run_phase)*gait*0.065*gait_sway,-stride*gait*0.035*gait_sway),blend)
	if exhausted:
		spine.position.y = 0.94+sin(motion_clock*5.0)*0.012
	else: spine.position.y = 0.94
	rig.position = rig.position.lerp(Vector3(idle*0.013*(1-amount),-0.03+absf(stride)*0.045*amount,0),blend)
	rig.rotation.x = lerp_angle(rig.rotation.x,-0.035-amount*0.075+clampf(local_accel.z*0.006,-0.08,0.08),blend)
	rig.rotation.z = lerp_angle(rig.rotation.z,clampf(-local_accel.x*0.010,-0.16,0.16)+idle*0.015*(1-amount),blend)
	# A standing capsule does not change with every running pose. Avoid
	# resubmitting its transform to the physics server 120 times a second.
	if body_collision.rotation!=Vector3.ZERO: body_collision.rotation=Vector3.ZERO
	var collision_center := Vector3(0,0.87,0)
	if body_collision.shape is CapsuleShape3D:
		collision_center.y=(body_collision.shape as CapsuleShape3D).height*0.5
	if body_collision.position!=collision_center: body_collision.position=collision_center
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
	if breath<=0.14 and idle_rest>0.35 and gait<0.12 and shot_preparation<=0 and kick_timer<=0 and receive_timer<=0 and action_timer<=0 and call_timer<=0 and body_language.point_weight<=0.05 and body_language.point_cooldown<=0 and not keeper and not protecting and not jockeying:
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
			var elapsed := .38-action_timer
			var reach := smoothstep(0,.12,elapsed)*(1-smoothstep(.16,.38,elapsed))
			var leg: Node3D=left_leg if tackle_foot==0 else right_leg
			var knee: Node3D=left_knee if tackle_foot==0 else right_knee
			var support_knee: Node3D=right_knee if tackle_foot==0 else left_knee
			leg.rotation.x=.95*reach; knee.rotation.x=-.08; support_knee.rotation.x=-.5
			var point := tackle_target
			point.y=maxf(global_position.y+.12,point.y-.04)
			locomotion.solve_leg(leg,knee,rig.to_local(point)-leg.position,reach)
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
		elif pose=="rise": animate_rise()
		elif pose=="dive": animate_dive()
		elif pose=="header": animate_header()
		elif pose in ["volley","finish","intercept"]: volley_motion.apply(self)
		elif pose in ["stumble","fall"]:
			impact_motion.apply(self)
	else:
		pose = "run"
		# Keep the supporting boot on the turf as the hip and knee flex.
		var sole_height := minf(left_knee.to_global(Vector3(0,-0.42,-0.05)).y,right_knee.to_global(Vector3(0,-0.42,-0.05)).y)
		rig.position.y -= sole_height-global_position.y-boot_ground_height()
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
		if celebration=="handshake":
			right_arm.rotation=Vector3(1.02,.48,-.08)
			right_elbow.rotation.x=.24+sin(motion_clock*9)*.09
			spine.rotation.x=-.06
			left_arm.rotation=Vector3(.15,0,-.16)
			left_elbow.rotation.x=.35
		elif celebration=="cheer":
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

	celebration_motion.apply(self,delta)
	apply_contest_pose()
	body_language.apply_pose(self)
	locomotion.finish_pose(self)
	SkillMoves.pose(self)
	Distribution.pose(self)
	if dummy_time>0:
		left_leg.rotation.z=-.28; right_leg.rotation.z=.28
		spine.rotation.y=sin(dummy_time*PI/.68)*.7
		left_arm.rotation.z=-.55; right_arm.rotation.z=.55
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
	motion_transition.apply(self,delta)
	if (kick_timer>0 or receive_timer>0 or motion_transition.age<motion_transition.DURATION) and action_timer<=0 and skill_move.is_empty() and set_piece_pose=="" and celebration=="" and not ball_actions.contact_pending and locomotion.plant_weight<=0 and dribble_motion.freshness<=0:
		var sole_height := minf(left_knee.to_global(ball_actions.BOOT).y,right_knee.to_global(ball_actions.BOOT).y)
		rig.position.y-=sole_height-global_position.y-boot_ground_height()
	ball_actions.finish_pose(self)
	dribble_motion.gait.apply(self,delta)
	dribble_motion.apply(self)
	dribble_motion.finish_pose(self,delta)
	keeper_motion.apply(self)
	reaction.apply(self)
	if reaction.kind=="": apply_breath(delta)
	body_language.apply_gaze(self,delta)
	if breath>0.08 and reaction.kind=="":
		head_joint.rotation.x=lerpf(head_joint.rotation.x,0.36+0.07*sin(motion_clock*3.1+number),smoothstep(0.08,0.5,breath))
	update_cloth()

func update_cloth() -> void:
	if kit_materials.has("printed") and kit_materials.printed.has_method("set_bend"):
		kit_materials.printed.set_bend(spine.rotation)

func hand_center() -> Vector3:
	return (left_hand.global_position+right_hand.global_position)*0.5

func animate_rise() -> void:
	var progress := 1.0-action_timer/maxf(0.08,slide_rise)
	var sit := 1.0-smoothstep(0.0,0.40,progress)
	var kneel := smoothstep(0.14,0.50,progress)*(1.0-smoothstep(0.58,0.96,progress))
	var stand := smoothstep(0.52,1.0,progress)
	rig.rotation.x=1.20*sit+0.36*kneel
	rig.rotation.z=0.46*sit+0.10*kneel
	rig.position=Vector3(facing.x,0,facing.z)*lerpf(0.92,0.0,stand)+Vector3(0,0.16*sit+0.07*kneel,0)
	spine.rotation=Vector3(-0.18*sit-0.32*kneel-0.08*stand,0,-0.06*sit)
	left_leg.rotation.x=0.86*sit+1.02*kneel+0.12*stand
	right_leg.rotation.x=0.28*sit+0.22*kneel+0.10*stand
	left_knee.rotation.x=-0.72*sit-1.28*kneel-0.22*stand
	right_knee.rotation.x=-0.10*sit-0.58*kneel-0.20*stand
	left_arm.rotation=Vector3(-0.55*sit-0.22*kneel,0,-1.15*sit-0.70*kneel-0.16*stand)
	right_arm.rotation=Vector3(0.12*sit+0.85*kneel,0,0.72*sit+0.55*kneel+0.14*stand)
	left_elbow.rotation.x=0.18*sit+0.85*kneel+0.48*stand
	right_elbow.rotation.x=0.22*sit+1.05*kneel+0.48*stand
	if kneel>0.2:
		var plant: Vector3=left_knee.to_global(Vector3(0,-0.08,0.04))
		plant.y=global_position.y+0.08
		impact_motion.reach_hand(self,true,plant,kneel*0.85,true)

func apply_breath(delta: float) -> void:
	var planted: bool=action_timer<=0 and kick_timer<=0 and receive_timer<=0 and shot_preparation<=0
	planted=planted and desired.length()<0.22 and Vector2(velocity.x,velocity.z).length()<1.8
	planted=planted and not keeper and not protecting and not jockeying and celebration=="" and set_piece_pose=="" and not saluting
	var want := 0.0
	if planted and (sprint_load>1.35 or exhausted and sprint_load>0.40):
		want=clampf((sprint_load-0.75)/2.3,0,1)
		if exhausted: want=maxf(want,0.58)
	breath=move_toward(breath,want,delta*(3.4 if want>breath else 5.0))
	if breath<=0.04: return
	var heave := 0.5+0.5*sin(motion_clock*(2.7 if exhausted else 3.5)+number)
	var w := smoothstep(0.04,0.55,breath)
	spine.rotation.x=lerpf(spine.rotation.x,-0.46-heave*0.11,w)
	spine.position.y=lerpf(spine.position.y,0.86+heave*0.020,w)
	left_leg.rotation.x=lerpf(left_leg.rotation.x,0.38,w)
	right_leg.rotation.x=lerpf(right_leg.rotation.x,0.34,w)
	left_knee.rotation.x=lerpf(left_knee.rotation.x,-0.72,w)
	right_knee.rotation.x=lerpf(right_knee.rotation.x,-0.68,w)
	rig.position.y=lerpf(rig.position.y,-0.06,w)
	impact_motion.reach_hand(self,true,left_knee.to_global(Vector3(0,-0.04,0.06)),w,true)
	impact_motion.reach_hand(self,false,right_knee.to_global(Vector3(0,-0.04,0.06)),w,true)

func animate_dive() -> void:
	var time := dive_duration-action_timer
	var launch := smoothstep(0.10,0.36,time)
	var recover := smoothstep(0.94,dive_duration,time)
	var spread := launch*(1-recover)
	var airborne_roll := lerpf(1.48,1.25,(dive_height-0.2)/2.1)
	var roll := spread*lerpf(airborne_roll,1.46,smoothstep(0.50,0.76,time))
	# Scale in body space: a broader torso must not become longer when diving.
	rig.basis = (Basis(Vector3.FORWARD,dive_direction*roll)*Basis(Vector3.UP,dive_yaw)).scaled_local(body_scale)
	# Rotate around the pelvis, not the feet: the body lands above the turf.
	var pelvis_height := lerpf(body_scale.y*0.9,0.44*WORLD_SCALE,spread)
	if time<0.10: pelvis_height -= smoothstep(0.0,0.1,time)*0.17*WORLD_SCALE
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
	body_collision.position.y = lerpf(body_collision.shape.height*0.5,body_collision.shape.radius+0.025,spread)

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
	kit_colors=colors.duplicate()
	var keeper_color: Color=colors.get("keeper_color",Color("d7b83c") if team==0 else Color("5998ac"))
	var primary: Color=colors.primary
	if not colors.has("keeper_color") and Vector3(keeper_color.r-primary.r,keeper_color.g-primary.g,keeper_color.b-primary.b).length()<0.45: keeper_color=Color("d096bd")
	kit_materials.jersey.albedo_color=keeper_color if keeper else primary
	kit_materials.socks.albedo_color=kit_materials.jersey.albedo_color
	kit_materials.trim.albedo_color=colors.accent
	kit_materials.shorts.albedo_color=Color("171d23") if keeper else colors.shorts
	kit_clean={"jersey":kit_materials.jersey.albedo_color,"socks":kit_materials.socks.albedo_color,"shorts":kit_materials.shorts.albedo_color}
	kit_soil=0
	update_soil(0.0)
	refresh_shirt()

func refresh_shirt() -> void:
	if official or kit_colors.is_empty() or kit_materials.is_empty(): return
	var colors := kit_colors.duplicate()
	if keeper:
		colors.primary=kit_clean.jersey
		colors.accent=Color("17272b")
	kit_materials.printed.albedo_texture=KitGraphics.shirt(colors,shirt_number,keeper,display_name)
	kit_materials.printed.albedo_color=Color.WHITE.lerp(Color(.82,.79,.70),kit_soil*.12)

func set_captain(value: bool) -> void:
	captain=value and not official
	if is_instance_valid(captain_band): captain_band.visible=captain

func stain(delta: float,sampled_mud: float=-1.0) -> void:
	if official or kit_clean.is_empty() or kit_materials.is_empty(): return
	if is_instance_valid(surface) and is_instance_valid(surface.game) and surface.game.state not in ["playing","restart","set_piece"]: return
	var mud: float=sampled_mud if sampled_mud>=0 else (surface.mud_at(position) if is_instance_valid(surface) else 0.0)
	var wet: float=surface.wetness if is_instance_valid(surface) else 0.0
	var moving := clampf(Vector2(velocity.x,velocity.z).length()/6.0,0,1)
	var gain: float=(.00045+moving*(.0013+mud*.004+wet*.0007))*delta
	if pose in ["slide","dive","fall"] and action_timer>0 and position.y<.3: gain+=(.10+mud*.12)*delta
	kit_soil=minf(0.82,kit_soil+gain)
	# Dirt still accumulates at physics rate. Sub-pixel colour changes do not
	# need seventeen material uploads per footballer on every physics step.
	if absf(kit_soil-shown_soil)>=.0005 or absf(wet-shown_wetness)>=.001: update_soil(wet)

func update_soil(wet: float) -> void:
	shown_soil=kit_soil; shown_wetness=wet
	kit_materials.printed.albedo_color=Color.WHITE.lerp(Color(.82,.79,.70),kit_soil*.12)
	if not kit_clean.is_empty(): kit_materials.jersey.albedo_color=kit_clean.jersey.lerp(Color(.24,.19,.11),kit_soil*.035)
	for part in ["jersey","printed","shorts","socks","knees"]:
		var material: ShaderMaterial=kit_materials[part]
		material.set_shader_parameter("soil",minf(1,kit_soil*(1.35 if part in ["socks","knees"] else 1.0)))
		material.set_shader_parameter("wetness",wet)
		material.set_shader_parameter("soil_seed",float(posmod(appearance_id+shirt_number*7,73)))

func apply_contest_pose() -> void:
	if not (action_timer<=0 or pose=="header") or set_piece_pose!="" or celebration!="": return
	if contest_weight>0:
		var local := contest_direction.rotated(Vector3.UP,-rig.rotation.y)
		var load: float=contest_weight*Attributes.multiplier(144-attributes.balance,.18)
		spine.rotation.z=lerpf(spine.rotation.z,-local.x*.19,load)
		spine.rotation.y=lerpf(spine.rotation.y,local.x*.12,load)
		var arm: Node3D=left_arm if local.x<0 else right_arm
		arm.rotation=arm.rotation.lerp(Vector3(.48,0,signf(local.x)*.48),load)
		var elbow: Node3D=left_elbow if local.x<0 else right_elbow
		elbow.rotation.x=lerpf(elbow.rotation.x,1.15,load)
		# Put the hip between ball and challenger; the two players share opposite
		# contact directions, so their balance reactions match the same collision.
		if protecting:
			rig.position.x+=local.x*.065*load
			rig.position.z+=local.z*.04*load
			spine.rotation.y-=local.x*.30*load
			left_leg.rotation.z-=.09*load; right_leg.rotation.z+=.09*load
		var disrupted := absf(sin(run_phase))*.16*load
		if local.x<0: left_knee.rotation.x-=disrupted
		else: right_knee.rotation.x-=disrupted
		rig.position.y-=disrupted*.10
	if landing_age<.32:
		var absorb := sin(landing_age/.32*PI)*landing_strength
		left_knee.rotation.x-=absorb*.24; right_knee.rotation.x-=absorb*.21
		spine.rotation.x-=absorb*.10
		rig.position.y-=absorb*.055
