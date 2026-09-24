extends RefCounted
## Render-only ribbon through the ball's recent world positions.
const LIFETIME := .22
const EMIT_TIME := 1.1
const MAX_LENGTH := 6.0
const MAX_POINTS := 32
var ball
var node: MeshInstance3D
var mesh: ImmediateMesh
var points: Array[Vector3] = []
var born: Array[float] = []
var clock := 0.0
var remaining := 0.0
var strength := 1.0

func setup(owner: Node3D) -> void:
	ball=owner
	mesh=ImmediateMesh.new()
	node=MeshInstance3D.new()
	node.name="PowerShotTrail"
	node.mesh=mesh
	node.top_level=true
	node.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader=preload("res://scripts/power_shot_trail.gdshader")
	node.material_override=material
	owner.add_child(node)
	node.global_transform=Transform3D.IDENTITY
	node.hide()

func clear() -> void:
	remaining=0; clock=0
	points.clear(); born.clear()
	if mesh!=null: mesh.clear_surfaces()
	if node!=null: node.hide()

func begin() -> void:
	clear()
	remaining=EMIT_TIME
	strength=lerpf(.72,1.0,clampf((ball.kick_velocity.length()-28)/18,0,1))
	points.append(ball.global_position); born.append(clock)

func stop_emitting() -> void:
	remaining=0

func update(delta: float) -> void:
	if remaining<=0 and points.is_empty(): return
	if not ball.active or ball.freeze or ball.pending_reset:
		clear(); return
	clock+=delta
	remaining=maxf(0,remaining-delta)
	var speed: float=ball.kick_velocity.length() if ball.pending_kick else ball.linear_velocity.length()
	if ball.held_by!=null or speed<12: stop_emitting()
	var at: Vector3=ball.get_global_transform_interpolated().origin
	if not points.is_empty() and at.distance_to(points.back())>maxf(3,speed*delta*2.5+.4):
		# A restart or replay seek must never draw a stripe across the pitch.
		clear(); return
	if remaining>0 and (points.is_empty() or at.distance_to(points.back())>.06):
		points.append(at); born.append(clock)
	while not born.is_empty() and (clock-born[0]>=LIFETIME or points.size()>MAX_POINTS):
		points.pop_front(); born.pop_front()
	var length := 0.0
	for i in range(points.size()-2,-1,-1):
		length+=points[i].distance_to(points[i+1])
		if length>MAX_LENGTH:
			for removed in range(i+1): points.pop_front(); born.pop_front()
			break
	draw()

func draw() -> void:
	mesh.clear_surfaces()
	node.visible=points.size()>=2
	if not node.visible: return
	var camera: Camera3D=ball.get_viewport().get_camera_3d()
	if camera==null: node.hide(); return
	var eye: Vector3=camera.get_global_transform_interpolated().origin
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var tangent: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var side: Vector3=tangent.cross((eye-points[i]).normalized()).normalized()
		if side.length_squared()<.01: side=camera.global_basis.x
		var life := clampf(1-(clock-born[i])/LIFETIME,0,1)
		var progress := float(i)/float(points.size()-1)
		var width := .16*strength*pow(life,.6)*smoothstep(0,.25,progress)
		# Leave the ball's front and silhouette clear at the head of the ribbon.
		var center: Vector3=points[i]-tangent*ball.RADIUS*.7
		mesh.surface_set_color(Color(1,1,1,life*strength))
		mesh.surface_set_uv(Vector2(progress,0)); mesh.surface_add_vertex(center-side*width)
		mesh.surface_set_uv(Vector2(progress,1)); mesh.surface_add_vertex(center+side*width)
	mesh.surface_end()
