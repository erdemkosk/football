extends Node3D
const G = preload("res://scripts/geometry.gd")
const Graphics = preload("res://scripts/kit_graphics.gd")
var display: MeshInstance3D
var material := StandardMaterial3D.new()
var outgoing := 0
var incoming := 0

func _ready() -> void:
	name="SubstitutionBoard"
	G.block(self,Vector3(1.00,.47,.085),Vector3.ZERO,G.material(Color("12191d"),.55))
	G.block(self,Vector3(.045,.38,.094),Vector3(-.5,0,0),G.material(Color("536065")))
	G.block(self,Vector3(.045,.38,.094),Vector3(.5,0,0),G.material(Color("536065")))
	var quad := QuadMesh.new(); quad.size=Vector2(.94,.40)
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	display=G.mesh(self,quad,material,Vector3(0,0,-.05)); display.rotation.y=PI
	visible=false

func show_numbers(out_number: int,in_number: int) -> void:
	if outgoing!=out_number or incoming!=in_number or material.albedo_texture==null:
		outgoing=out_number; incoming=in_number
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="112" viewBox="0 0 256 112"><rect width="256" height="112" fill="#0b1516"/>'
		for side in range(2):
			var ink := "#ff6554" if side==0 else "#71f191"
			var number := str(outgoing if side==0 else incoming)
			var x: float=64+side*128-(number.length()*48-8)*.5
			for i in range(number.length()):
				svg+='<path transform="translate(%.2f 31)" d="%s" fill="none" stroke="%s" stroke-width="7" stroke-linejoin="round"/>' % [x+i*48,Graphics.DIGITS[int(number[i])],ink]
			svg+='<path transform="translate(%d 0)" d="%s" fill="none" stroke="%s" stroke-width="4"/>' % [side*128,"M64 8V24M56 17L64 25L72 17" if side==0 else "M64 25V9M56 17L64 9L72 17",ink]
		material.albedo_texture=Graphics.raster(svg+'</svg>')
	visible=true
