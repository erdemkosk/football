extends ShaderMaterial
## Spine-driven jersey fold. Texture and dirt stay on the same material.

func _init() -> void:
	shader=load("res://shaders/jersey.gdshader")
	var blank := Image.create(1,1,false,Image.FORMAT_RGBA8)
	blank.fill(Color.WHITE)
	set_shader_parameter("albedo_tex",ImageTexture.create_from_image(blank))
	set_shader_parameter("albedo",Color.WHITE)
	set_shader_parameter("bend",Vector3.ZERO)

var albedo_color: Color:
	set(value): set_shader_parameter("albedo",value)
	get:
		var value: Variant=get_shader_parameter("albedo")
		return value if value is Color else Color.WHITE

var albedo_texture: Texture2D:
	set(value): set_shader_parameter("albedo_tex",value)
	get:
		var value: Variant=get_shader_parameter("albedo_tex")
		return value if value is Texture2D else null

func set_bend(value: Vector3) -> void:
	set_shader_parameter("bend",value)
