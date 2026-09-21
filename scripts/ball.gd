extends RigidBody3D
const G = preload("res://scripts/geometry.gd")
const RADIUS := 0.22
var pending_reset := false
var reset_position := Vector3.ZERO
var pending_velocity := Vector3.ZERO
var pending_kick := false
var kick_velocity := Vector3.ZERO
var spin := 0.0
var active := true
var previous_position := Vector3.ZERO
var rolling_angle := 0.0
var goal_nets: Array[Node3D] = []
var pending_touch := false
var touch_velocity := Vector3.ZERO
var touch_impulse_limit := 0.0
var held_by: Node3D
var hold_target := Vector3.ZERO
var held_collision_mask := 11
var surface: Node3D

func hold(player: Node3D) -> void:
	if held_by==player: return
	release_hold()
	held_by=player
	hold_target=global_position
	held_collision_mask=collision_mask
	collision_mask=0
	pending_touch=false
	pending_kick=false
	active=true
	for net in goal_nets: net.release_ball()

func release_hold() -> void:
	if held_by!=null: collision_mask=held_collision_mask
	held_by=null

func _ready() -> void:
	mass = 0.43
	continuous_cd = true
	can_sleep = false
	collision_layer = 4
	collision_mask = 11
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0
	angular_damp = 0.18
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
	var shell = G.sphere(self,RADIUS,Vector3.ZERO,G.material(Color("f1eee2"),0.7))
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
		panel.top_radius = 0.065
		panel.bottom_radius = 0.065
		panel.height = 0.003
		panel.radial_segments = 5
		var node = G.mesh(self,panel,G.material(Color("1a252c"),0.75),d*RADIUS)
		var axis = Vector3.UP.cross(d)
		if axis.length()>0.001: node.quaternion = Quaternion(axis.normalized(),acos(Vector3.UP.dot(d)))

func place(p: Vector3, v: Vector3 = Vector3.ZERO) -> void:
	release_hold()
	for net in goal_nets: net.release_ball()
	reset_position = p
	pending_velocity = v
	pending_reset = true
	pending_kick = false
	pending_touch = false
	spin = 0

func strike(v: Vector3, curve: float = 0) -> void:
	release_hold()
	pending_touch = false
	kick_velocity = v
	pending_kick = true
	spin = curve
	sleeping = false

func touch(v: Vector3,max_impulse: float) -> void:
	if pending_kick: return
	touch_velocity = v
	touch_impulse_limit = max_impulse
	pending_touch = true
	sleeping = false

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if pending_reset:
		state.transform = Transform3D(Basis.IDENTITY,reset_position)
		state.linear_velocity = pending_velocity
		state.angular_velocity = Vector3.ZERO
		pending_reset = false
		previous_position = reset_position
	if not active:
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
	var v = state.linear_velocity
	var resistance := 1.15
	if is_instance_valid(surface):
		resistance=surface.ball_drag(state.transform.origin)
		physics_material_override.bounce=surface.ball_bounce(state.transform.origin)
	var speed = Vector2(v.x,v.z).length()
	if state.transform.origin.y < 0.30 and absf(v.y)<1.2:
		var horizontal = Vector2(v.x,v.z).move_toward(Vector2.ZERO,resistance*state.step)
		v.x = horizontal.x
		v.z = horizontal.y
		state.angular_velocity = Vector3(v.z/RADIUS,state.angular_velocity.y,-v.x/RADIUS)
	else:
		v -= v*speed*0.0018*state.step
		var curve = Vector3(-v.z,0,v.x)*spin*0.08
		v += curve*state.step
	spin = move_toward(spin,0,state.step*0.17)
	state.linear_velocity = v
	for net in goal_nets: net.contact(state,RADIUS,mass)
