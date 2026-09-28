extends ShaderMaterial
## Shares one shader; each identity retains its own pigment and wetness response.
func _init() -> void: shader=preload("res://shaders/hair.gdshader")
var albedo_color: Color:
	set(value): set_shader_parameter("pigment",value)
	get: return get_shader_parameter("pigment")
var roughness: float:
	set(value): set_shader_parameter("roughness",value)
	get: return get_shader_parameter("roughness")
