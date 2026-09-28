extends RefCounted
const Graphics = preload("res://scripts/kit_graphics.gd")
static var materials: Array[ShaderMaterial] = []
static var last_goal: Array=[]

static func goal_state(amount: float,primary: Color,accent: Color,age: float) -> void:
	var value: Array=[amount,primary,accent,age]
	if value==last_goal: return
	last_goal=value
	for mat in materials:
		mat.set_shader_parameter("goal_amount",amount)
		mat.set_shader_parameter("goal_primary",primary)
		mat.set_shader_parameter("goal_accent",accent)
		mat.set_shader_parameter("event_age",age)

static func face(parent: Node3D,size: Vector2,phase: int) -> MeshInstance3D:
	if materials.is_empty():
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="128" viewBox="0 0 2048 128">'
		var titles := ["STARTING ELEVEN","OYUN SENIN","SEFC FOOTBALL","PLAY WITH HEART"]
		for i in range(4):
			var background := "#152e34" if i%2==0 else "#ceb673"
			var ink := "#f4e9c6" if i%2==0 else "#152e34"
			svg+='<rect x="%d" width="512" height="128" fill="%s"/>' % [i*512,background]
			svg+='<g transform="translate(%.2f -18) scale(1.5 1.6)">' % (i*512+256-768*1.5)
			svg+=Graphics.name_print(titles[i],ink)+'</g>'
			svg+='<path d="M%d 109H%d" stroke="%s" stroke-width="3" opacity=".5"/>' % [i*512+32,i*512+480,ink]
		var atlas := Graphics.raster(svg+'</svg>')
		var goal_svg:='<svg xmlns="http://www.w3.org/2000/svg" width="512" height="128"><g transform="translate(-896 -18) scale(1.5 1.6)">'+Graphics.name_print("GOL","#ffffff")+'</g></svg>'
		var goal_atlas:=Graphics.raster(goal_svg)
		for i in range(4):
			var mat := ShaderMaterial.new(); mat.shader=load("res://shaders/led_board.gdshader")
			mat.set_shader_parameter("art",atlas); mat.set_shader_parameter("phase",i*.25)
			mat.set_shader_parameter("goal_art",goal_atlas)
			materials.append(mat)
	var panel := MeshInstance3D.new(); var quad := QuadMesh.new(); quad.size=size
	panel.mesh=quad; panel.material_override=materials[posmod(phase,4)]
	panel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(panel); panel.position.z=.068; panel.name="MovingLED"
	return panel
