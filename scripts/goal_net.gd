extends Node3D
## A pinned spring lattice shared by rendering and ball contact.
const NODE_MASS := 0.12
const TENSION := 90.0
const RESTORING := 55.0
const DAMPING := 30.0
const MAX_STRETCH := 0.95
var panels: Array[Dictionary] = []
var awake := false
var impact_count := 0

func build(side: int) -> void:
	var front := float(side)*50.0
	var rear := front+side*2.4
	add_panel(Vector3(-3.66,0,rear),Vector3(3.66,0,rear),Vector3(-3.66,1.9,rear),Vector3(3.66,1.9,rear),Vector3(0,0,side),30,10)
	for x in [-3.66,3.66]:
		add_panel(Vector3(x,0,front),Vector3(x,0,rear),Vector3(x,2.44,front),Vector3(x,1.9,rear),Vector3(signf(x),0,0),12,12)
	add_panel(Vector3(-3.66,2.44,front),Vector3(3.66,2.44,front),Vector3(-3.66,1.9,rear),Vector3(3.66,1.9,rear),Vector3(0,2.4,side*0.54).normalized(),30,12)

func add_panel(a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3,cols: int,rows: int) -> void:
	var rest := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var pinned := PackedByteArray()
	for y in range(rows+1):
		for x in range(cols+1):
			var s := float(x)/cols
			var t := float(y)/rows
			rest.append(a.lerp(b,s).lerp(c.lerp(d,s),t))
			uv.append(Vector2(s,t))
			pinned.append(1 if x==0 or x==cols or y==0 or y==rows else 0)
	for y in range(rows):
		for x in range(cols):
			var i := y*(cols+1)+x
			indices.append_array(PackedInt32Array([i,i+1,i+cols+1,i+1,i+cols+2,i+cols+1]))
	var displacement := PackedFloat32Array()
	var velocity := PackedFloat32Array()
	displacement.resize(rest.size())
	velocity.resize(rest.size())
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/net.gdshader")
	material.set_shader_parameter("grid_count",Vector2(a.distance_to(b),a.distance_to(c))/0.19)
	var instance := MeshInstance3D.new()
	instance.mesh = ArrayMesh.new()
	instance.material_override = material
	add_child(instance)
	var panel := {"a":a,"b":b,"c":c,"d":d,"normal":normal,"cols":cols,"rows":rows,"rest":rest,"uv":uv,"indices":indices,"pinned":pinned,"offset":displacement,"velocity":velocity,"instance":instance,"contact_side":0.0}
	panels.append(panel)
	refresh_mesh(panel)

func _physics_process(delta: float) -> void:
	if not awake: return
	var energy := 0.0
	for panel in panels:
		var offsets: PackedFloat32Array = panel.offset
		var speeds: PackedFloat32Array = panel.velocity
		var width: int = panel.cols+1
		for y in range(1,panel.rows):
			for x in range(1,panel.cols):
				var i: int = y*width+x
				var laplacian := offsets[i-1]+offsets[i+1]+offsets[i-width]+offsets[i+width]-4*offsets[i]
				speeds[i] += (TENSION*laplacian-RESTORING*offsets[i]-DAMPING*speeds[i])*delta
		for i in range(offsets.size()):
			offsets[i] = clampf(offsets[i]+speeds[i]*delta,-MAX_STRETCH,MAX_STRETCH)
			if absf(offsets[i])>=MAX_STRETCH: speeds[i] *= 0.2
			energy = maxf(energy,absf(offsets[i])+absf(speeds[i])*0.1)
		panel.offset = offsets
		panel.velocity = speeds
	if energy<0.0005: reset()

func _process(_delta: float) -> void:
	if awake:
		for panel in panels: refresh_mesh(panel)

func release_ball() -> void:
	for panel in panels: panel.contact_side = 0.0

func reset() -> void:
	awake = false
	release_ball()
	for panel in panels:
		panel.offset.fill(0)
		panel.velocity.fill(0)
		refresh_mesh(panel)

func refresh_mesh(panel: Dictionary) -> void:
	var vertices: PackedVector3Array = panel.rest.duplicate()
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(vertices.size()):
		vertices[i] += panel.normal*panel.offset[i]
		normals[i] = panel.normal
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = panel.uv
	arrays[Mesh.ARRAY_INDEX] = panel.indices
	panel.instance.mesh.clear_surfaces()
	panel.instance.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

func contact(state: PhysicsDirectBodyState3D,radius: float,mass: float) -> void:
	var position := state.transform.origin
	if absf(position.z)<49.0 or absf(position.x)>5.2 or position.y>4:
		release_ball()
		return
	for panel in panels:
		var normal: Vector3 = panel.normal
		var edge: Vector3 = panel.b-panel.a
		var s: float = (position-panel.a).dot(edge)/edge.length_squared()
		if s<0 or s>1:
			panel.contact_side = 0.0
			continue
		var bottom: Vector3 = panel.a.lerp(panel.b,s)
		var vertical: Vector3 = panel.c.lerp(panel.d,s)-bottom
		var t := (position-bottom).dot(vertical)/vertical.length_squared()
		if t<0 or t>1:
			panel.contact_side = 0.0
			continue
		var gx: float = s*panel.cols
		var gy: float = t*panel.rows
		var ix := mini(int(gx),panel.cols-1)
		var iy := mini(int(gy),panel.rows-1)
		var fx := gx-ix
		var fy := gy-iy
		var index: int = iy*(panel.cols+1)+ix
		var ids := [index,index+1,index+panel.cols+1,index+panel.cols+2]
		var weights := [(1-fx)*(1-fy),fx*(1-fy),(1-fx)*fy,fx*fy]
		var stretch := 0.0
		var net_speed := 0.0
		var inverse_mass := 0.0
		for j in range(4):
			stretch += panel.offset[ids[j]]*weights[j]
			net_speed += panel.velocity[ids[j]]*weights[j]
			if panel.pinned[ids[j]]==0: inverse_mass += weights[j]*weights[j]/NODE_MASS
		var distance := (position-bottom).dot(normal)-stretch
		var relative_speed := state.linear_velocity.dot(normal)-net_speed
		# Swept contact covers a full physics step, even for the hardest shots.
		var contact_side: float = panel.contact_side
		if contact_side==0: contact_side = signf(distance)
		if contact_side==0: contact_side = -signf(relative_speed)
		var gap := distance*contact_side-radius
		if gap>maxf(0,-relative_speed*contact_side*state.step):
			if gap>0.3: panel.contact_side = 0.0
			continue
		panel.contact_side = contact_side
		# Project residual penetration onto the same deformed surface.
		# Keeping the contact side prevents fast balls swapping sides of the net.
		if gap< -0.01:
			position += normal*contact_side*(-gap-0.01)
			state.transform.origin = position
		var approach := relative_speed*contact_side
		if approach>=0 and gap>=-0.01: continue
		var impulse := maxf(0,-approach-maxf(gap,0)/state.step+maxf(-gap-0.005,0)*18)/(1.0/mass+inverse_mass)
		if impulse<=0: continue
		state.linear_velocity += normal*contact_side*impulse/mass
		# Tangential friction lets a captured ball drop down the mesh.
		var tangent := state.linear_velocity-normal*state.linear_velocity.dot(normal)
		state.linear_velocity -= tangent*minf(0.16,impulse*0.16)
		state.angular_velocity *= 0.96
		for j in range(4):
			if panel.pinned[ids[j]]==0:
				panel.velocity[ids[j]] -= contact_side*impulse*weights[j]/NODE_MASS
		awake = true
		impact_count += 1

func max_deformation() -> float:
	var result := 0.0
	for panel in panels:
		for value in panel.offset: result = maxf(result,absf(value))
	return result
