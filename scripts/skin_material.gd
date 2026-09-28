extends ShaderMaterial
## Shared skin response for face, body and fingers; authored colours stay linear.
func _init(vertex_colors: bool=false) -> void:
	shader=preload("res://shaders/skin.gdshader")
	set_shader_parameter("vertex_colors",vertex_colors)
var albedo_color: Color:
	set(value): set_shader_parameter("pigment",value)
	get: return get_shader_parameter("pigment")
var roughness: float:
	set(value): set_shader_parameter("roughness",value)
	get: return get_shader_parameter("roughness")
