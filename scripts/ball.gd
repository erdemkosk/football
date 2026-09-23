extends RigidBody3D
const G = preload("res://scripts/geometry.gd")
const Dimensions = preload("res://scripts/ball_dimensions.gd")
const RADIUS := Dimensions.RADIUS
const GROUND_HEIGHT := Dimensions.GROUND_HEIGHT
const Motion = preload("res://scripts/ball_motion.gd")
const P = preload("res://scripts/pitch_dimensions.gd")
var pending_reset := false
var reset_position := Vector3.ZERO
var pending_velocity := Vector3.ZERO
var pending_kick := false
var kick_velocity := Vector3.ZERO
var spin := 0.0
var active := true
var previous_position := Vector3.ZERO
var rolling_angle := 0.0
var ground_bounce_age := INF
var previous_vertical_speed := 0.0
var goal_nets: Array[Node3D] = []
var pending_touch := false
var touch_velocity := Vector3.ZERO
var touch_impulse_limit := 0.0
var control_acceleration := Vector3.ZERO
var pending_control := false
var held_by: Node3D
var hold_target := Vector3.ZERO
var held_collision_mask := 11
var surface: Node3D
var shell: MeshInstance3D
var skin: Node3D
var streak := 0.0
var streak_dir := Vector3.FORWARD
var rubber := 0.0
var rubber_vel := 0.0
var rubber_axis := Vector3.UP
var roll_amount := 0.0
var roll_dir := Vector3.FORWARD
var ghosts: Array[MeshInstance3D] = []
var surface_materials: Array[StandardMaterial3D] = []
var shown_surface_wetness := -1.0

func update_surface_wetness(wet: float) -> void:
	if absf(wet-shown_surface_wetness)<.002: return
	shown_surface_wetness=wet
	for i in range(surface_materials.size()):
		var material := surface_materials[i]
		material.roughness=lerpf(.70 if i==0 else .75,.27 if i==0 else .34,wet)
		material.metallic_specular=lerpf(.35,.55,wet)

func hold(player: Node3D) -> void:
	if held_by==player: return
	release_hold()
	held_by=player
	hold_target=global_position
	held_collision_mask=collision_mask
	collision_mask=0
	pending_touch=false
	pending_control=false
	pending_kick=false
	active=true
	for net in goal_nets: net.release_ball()

func release_hold() -> void:
	if held_by!=null: collision_mask=held_collision_mask
	held_by=null

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
	mass = 0.43
	continuous_cd = true
	can_sleep = false
	collision_layer = 4
	collision_mask = 11
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0
	# Ground rolling loss is explicit; generic angular damping would brake it twice.
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0
	contact_monitor = true
	max_contacts_reported = 8
	var physics = PhysicsMaterial.new()
	physics.friction = 0.45
	physics.bounce = 0.56
	physics_material_override = physics
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = RADIUS
	collision.shape = shape
	add_child(collision)
	skin=Node3D.new()
	skin.name="BallSkin"
	skin.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(skin)
	shell = G.sphere(skin,RADIUS,Vector3.ZERO,G.material(Color("f1eee2"),0.7))
	surface_materials.append(shell.material_override)
	var panel_material := G.material(Color("1a252c"),0.75)
	surface_materials.append(panel_material)
	var trail := StandardMaterial3D.new()
	trail.albedo_color=Color("f1eee2",0.28)
	trail.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	trail.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 3:
		var ghost := G.sphere(self,RADIUS,Vector3.ZERO,trail)
		ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.top_level=true
		ghost.visible=false
		ghosts.append(ghost)
	# Twelve pentagonal panels at icosahedron vertices; seams rotate with the physical ball.
	var phi = (1+sqrt(5.0))/2
	var directions: Array[Vector3] = []
	for a in [-1,1]:
		for b in [-1,1]:
			directions.append(Vector3(0,a,b*phi).normalized())
			directions.append(Vector3(a,b*phi,0).normalized())
			directions.append(Vector3(b*phi,0,a).normalized())
	for d in directions:
		var panel = CylinderMesh.new()
		panel.top_radius = RADIUS*0.29545
		panel.bottom_radius = panel.top_radius
		panel.height = RADIUS*0.01364
		panel.radial_segments = 5
		var node = G.mesh(skin,panel,panel_material,d*RADIUS)
		var axis = Vector3.UP.cross(d)
		if axis.length()>0.001: node.quaternion = Quaternion(axis.normalized(),acos(Vector3.UP.dot(d)))

func place(p: Vector3, v: Vector3 = Vector3.ZERO) -> void:
	release_hold()
	for net in goal_nets: net.release_ball()
	reset_position = p
	pending_velocity = v
	pending_reset = true
	ground_bounce_age=INF; previous_vertical_speed=0
	pending_kick = false
	pending_touch = false
	pending_control = false
	spin = 0
	streak=0
	clear_rubber()
	if is_instance_valid(shell): shell.scale=Vector3.ONE
	for ghost in ghosts: ghost.visible=false

func mark_drive(v: Vector3,amount: float=1.0) -> void:
	streak=clampf(amount,0,1)
	streak_dir=(v*Vector3(1,0,1)).normalized()
	if streak_dir.length()<0.01: streak_dir=Vector3.FORWARD

func ping(dir: Vector3,strength: float) -> void:
	if dir.length()<0.01: return
	rubber_axis=dir.normalized()
	rubber_vel+=clampf(strength,0.0,1.35)*16.5

func clear_rubber() -> void:
	rubber=0
	rubber_vel=0
	rubber_axis=Vector3.UP
	roll_amount=0
	roll_dir=Vector3.FORWARD
	if is_instance_valid(skin): skin.transform=Transform3D.IDENTITY

func deform_basis(axis: Vector3,along: float,side: float) -> Basis:
	var n: Vector3=axis.normalized()
	var k: float=along-side
	return Basis(
		Vector3(side+k*n.x*n.x,k*n.x*n.y,k*n.x*n.z),
		Vector3(k*n.y*n.x,side+k*n.y*n.y,k*n.y*n.z),
		Vector3(k*n.z*n.x,k*n.z*n.y,side+k*n.z*n.z))

func _process(delta: float) -> void:
	streak=maxf(0,streak-delta*4.2)
	var travel: Vector3=linear_velocity*Vector3(1,0,1)
	if pending_kick: travel=kick_velocity*Vector3(1,0,1)
	var grounded: bool=held_by==null and position.y<RADIUS+0.14
	var wanted: float=smoothstep(3.2,20.0,travel.length()) if grounded else 0.0
	if travel.length()>0.4: roll_dir=travel.normalized()
	roll_amount=move_toward(roll_amount,wanted,delta*(10.0 if wanted>roll_amount else 6.0))
	if held_by!=null:
		rubber=move_toward(rubber,0,delta*10)
		rubber_vel=0
		roll_amount=move_toward(roll_amount,0,delta*10)
	else:
		rubber_vel+=-rubber*175.0*delta
		rubber_vel*=exp(-7.4*delta)
		rubber+=rubber_vel*delta
		if absf(rubber)<0.004 and absf(rubber_vel)<0.10:
			rubber=0
			rubber_vel=0
	if is_instance_valid(skin):
		var world: Vector3=rubber_axis if rubber_axis.length()>0.01 else Vector3.UP
		if streak>0.04: world=world.lerp(streak_dir,streak*0.55)
		if roll_amount>0.03: world=world.lerp(roll_dir,roll_amount*0.88)
		var local: Vector3=(get_global_transform_interpolated().basis.inverse()*world)
		if local.length()<0.01: local=Vector3.UP
		var along: float=clampf(1.0-rubber*0.16+streak*0.035+roll_amount*0.035,.90,1.10)
		var side: float=clampf(1.0+rubber*0.08-streak*0.015-roll_amount*0.017,.94,1.08)
		var basis := deform_basis(local,along,side)
		basis.y*=1.0-roll_amount*.015
		skin.basis=basis
	if not is_instance_valid(shell): return
	shell.scale=Vector3.ONE
	# A single interpolated ball reads cleanly at speed. Three displaced copies
	# made its silhouette look like repeated jumps, especially against the grass.
	for ghost in ghosts: ghost.visible=false

func strike(v: Vector3, curve: float = 0) -> void:
	ground_bounce_age=INF; previous_vertical_speed=v.y
	release_hold()
	pending_touch = false
	pending_control = false
	kick_velocity = v
	pending_kick = true
	spin = curve
	sleeping = false
	ping(v,clampf(v.length()/28.0,0.32,1.3))

func touch(v: Vector3,max_impulse: float) -> void:
	if pending_kick: return
	touch_velocity = v
	touch_impulse_limit = max_impulse
	pending_touch = true
	sleeping = false

func guide(acceleration: Vector3) -> void:
	# One physics step of close-control assistance, never a transform lock.
	if pending_kick or held_by!=null: return
	control_acceleration=acceleration*Vector3(1,0,1)
	pending_control=true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if pending_reset:
		state.transform = Transform3D(Basis.IDENTITY,reset_position)
		reset_physics_interpolation.call_deferred()
		state.linear_velocity = pending_velocity
		state.angular_velocity = Vector3.ZERO
		pending_reset = false
		previous_position = reset_position
	if not active:
		pending_control=false
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return
	if is_instance_valid(held_by):
		# A damped hand constraint carries the existing rigid body without moving
		# its transform. Acquisition, lifting and lowering all remain continuous.
		var relative: Vector3=state.linear_velocity-held_by.velocity
		var acceleration: Vector3=(hold_target-state.transform.origin)*196-relative*28-state.total_gravity
		state.linear_velocity+=acceleration.limit_length(180)*state.step
		state.angular_velocity=state.angular_velocity.move_toward(Vector3.ZERO,state.step*12)
		return
	if pending_kick:
		state.linear_velocity = kick_velocity
		state.angular_velocity = Vector3(kick_velocity.z/RADIUS,spin*6,-kick_velocity.x/RADIUS)
		pending_kick = false
	if pending_touch:
		var impulse := ((touch_velocity-state.linear_velocity)*mass).limit_length(touch_impulse_limit)
		state.apply_central_impulse(impulse)
		pending_touch = false
	if pending_control:
		state.apply_central_impulse(control_acceleration*mass*state.step)
		pending_control=false
	var v = state.linear_velocity
	ground_bounce_age+=state.step
	var last_vertical := previous_vertical_speed
	if last_vertical< -1 and v.y>0.65 and state.transform.origin.y<RADIUS+0.18:
		for contact in range(state.get_contact_count()):
			if state.get_contact_local_normal(contact).y>0.55:
				ground_bounce_age=0
				if last_vertical< -1.2: ping(Vector3.UP,clampf(-last_vertical/10.0,0.22,1.05))
	previous_vertical_speed=v.y
	var resistance := Motion.profile(surface,state.transform.origin)
	if is_instance_valid(surface): physics_material_override.bounce=surface.ball_bounce(state.transform.origin)
	var speed := Vector2(v.x,v.z).length()
	var grounded: bool=state.transform.origin.y<RADIUS+0.10
	# Fast ground travel otherwise chatters: gravity + turf bounce inject a few
	# millimetres of vertical hop every step. Keep a real descending bounce.
	var rolling: bool=grounded and (absf(v.y)<1.2 or (absf(v.y)<2.4 and last_vertical>-3.0))
	if rolling:
		physics_material_override.bounce=0.0
		var remaining := Motion.rolling_speed(speed,state.step,resistance)
		var horizontal := Vector2(v.x,v.z).normalized()*remaining
		v.x=horizontal.x; v.z=horizontal.y
		v.y=0
		var yaw := move_toward(state.angular_velocity.y,0,state.step*resistance.x*5)
		state.angular_velocity=Vector3(v.z/RADIUS,yaw,-v.x/RADIUS)
		var settled := state.transform
		settled.origin.y=GROUND_HEIGHT
		state.transform=settled
		previous_vertical_speed=0
	else:
		v=Motion.air_velocity(v,state.step,Motion.air_drag(surface))
		state.angular_velocity*=exp(-0.04*state.step)
		v=Motion.apply_spin(v,spin,state.step)
	spin=Motion.decay_spin(spin,state.step,not rolling,resistance.x)
	# Character collision correction can push this small sphere through the
	# turf between CCD sweeps. Resolve that penetration against the same flat
	# ground used by the stadium, so the ball cannot fall out of the match.
	var point := state.transform.origin
	if not rolling and is_instance_valid(surface) and absf(point.x)<P.TURF_COLLISION_SIZE.x*.5 and absf(point.z)<P.TURF_COLLISION_SIZE.z*.5 and point.y<RADIUS:
		var corrected := state.transform
		corrected.origin.y=RADIUS
		state.transform=corrected
		if v.y<0:
			if v.y< -1.2: ping(Vector3.UP,clampf(-v.y/10.0,0.22,1.05))
			v.y=-v.y*physics_material_override.bounce if v.y< -1.2 else 0.0
			ground_bounce_age=0
	state.linear_velocity = v
	for net in goal_nets: net.contact(state,RADIUS,mass)
