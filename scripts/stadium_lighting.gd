extends Node3D
## Match time and weather share one lighting rig; weather never restores a night sun.
var stadium
var period := 0
var rainfall := 0.0
var applied_period := -1
var applied_rain := -1.0
var floodlights: Array[SpotLight3D] = []
var shafts: Array[MeshInstance3D] = []
var shaft_material := ShaderMaterial.new()
var sky_material := ShaderMaterial.new()
var sky_clock := 0.0
var sky_tick := 0.0

func build(arena) -> void:
	stadium=arena
	name="MatchLighting"
	build_sky()
	shaft_material.shader=load("res://shaders/flood_shaft.gdshader")
	shaft_material.set_shader_parameter("glow",Color("d4e4ff"))
	shaft_material.set_shader_parameter("strength",0.0)
	for mount in stadium.architecture.floodlight_mounts:
		var flood := SpotLight3D.new()
		flood.name="RoofFloodlight"+str(floodlights.size()+1)
		add_child(flood)
		flood.position=mount
		var aim := Vector3(-signf(mount.x)*5,0,mount.z*0.28)
		flood.look_at(aim)
		flood.light_color=Color("e6efff")
		# City windows and street lamps have their own baked illumination.
		flood.light_cull_mask=1
		flood.spot_range=140
		flood.spot_angle=67
		flood.spot_attenuation=0.65
		flood.spot_angle_attenuation=0.55
		flood.shadow_enabled=true
		flood.shadow_bias=0.06
		flood.shadow_normal_bias=0.6
		flood.shadow_opacity=0.70
		floodlights.append(flood)
		shafts.append(make_shaft(mount,aim))
	stadium.grass.set_shader_parameter("flood_positions",PackedVector3Array(stadium.architecture.floodlight_mounts))
	apply_weather(0)

func build_sky() -> void:
	var noise := FastNoiseLite.new()
	noise.seed=413
	noise.frequency=0.009
	noise.fractal_octaves=4
	var texture := NoiseTexture2D.new()
	texture.width=512; texture.height=512
	texture.seamless=true; texture.generate_mipmaps=true; texture.noise=noise
	sky_material.shader=load("res://shaders/match_sky.gdshader")
	sky_material.set_shader_parameter("cloud_noise",texture)
	sky_material.set_shader_parameter("cloud_clock",0.0)
	var sky := Sky.new()
	sky.sky_material=sky_material
	sky.radiance_size=Sky.RADIANCE_SIZE_128
	sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
	stadium.env.sky=sky
	stadium.env.background_mode=Environment.BG_SKY
	stadium.env.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED

func _process(delta: float) -> void:
	# Clouds move slowly: a one-second refresh avoids rebuilding the sky every frame.
	sky_clock+=delta; sky_tick+=delta
	if sky_tick<1.0: return
	sky_tick=fmod(sky_tick,1.0)
	sky_material.set_shader_parameter("cloud_clock",sky_clock)

func make_shaft(from: Vector3,toward: Vector3) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius=16.5
	cone.bottom_radius=1.15
	cone.height=46
	cone.radial_segments=40
	cone.rings=1
	cone.cap_top=false; cone.cap_bottom=false
	var shaft := MeshInstance3D.new()
	shaft.mesh=cone
	shaft.material_override=shaft_material
	shaft.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shaft)
	var direction: Vector3=(toward-from).normalized()
	shaft.position=from+direction*23.0
	shaft.quaternion=Quaternion(Vector3.UP,direction)
	shaft.visible=false
	return shaft

func label() -> String:
	return ["ÖĞLEN","GECE","AKŞAM"][period]

func select(value: int) -> void:
	period=clampi(value,0,2)
	apply_weather(rainfall)

func apply_weather(rain: float) -> void:
	rainfall=clampf(rain,0,1)
	if applied_period==period and is_equal_approx(applied_rain,rainfall): return
	applied_period=period; applied_rain=rainfall
	var night := period==1
	var evening := period==2
	var sun: DirectionalLight3D=stadium.sun
	var env: Environment=stadium.env
	apply_color_grade(env,night,evening)
	sun.visible=not night
	sun.rotation_degrees=Vector3(-32,-64,0) if evening else Vector3(-62,-38,0)
	sun.light_color=(Color("ffc788") if evening else Color("fff5e9")).lerp(Color("d8e3ed"),rainfall)
	sun.light_energy=0.0 if night else lerpf(1.12 if evening else 1.10,0.62,rainfall)
	sun.shadow_opacity=lerpf(.64 if evening else .78,0.25,rainfall)
	if night:
		env.background_color=Color("081323").lerp(Color("111a27"),rainfall)
		env.ambient_light_color=Color("8daccd")
		env.ambient_light_energy=lerpf(0.20,0.25,rainfall)
	elif evening:
		env.background_color=Color("9b897e").lerp(Color("657681"),rainfall)
		env.ambient_light_color=Color("e4cbaa").lerp(Color("a8bdcf"),rainfall)
		env.ambient_light_energy=lerpf(.50,.60,rainfall)
	else:
		env.background_color=Color("6f868a").lerp(Color("5a7178"),rainfall)
		env.ambient_light_color=Color("d4e1ee").lerp(Color("a8bdcf"),rainfall)
		env.ambient_light_energy=lerpf(0.42,0.66,rainfall)
	var horizon := Color("839faa")
	var zenith := Color("3c647f")
	var cloud_light := Color("e0e4df")
	var cloud_shade := Color("899fa9")
	if evening:
		horizon=Color("b89c87"); zenith=Color("596c84")
		cloud_light=Color("e8c7a7"); cloud_shade=Color("897e88")
	elif night:
		horizon=Color("26384f"); zenith=Color("08111e")
		cloud_light=Color("4c6078"); cloud_shade=Color("233447")
	sky_material.set_shader_parameter("horizon",horizon.lerp(Color("344451") if night else Color("859397"),rainfall*.72))
	sky_material.set_shader_parameter("zenith",zenith.lerp(Color("172331") if night else Color("617780"),rainfall*.8))
	sky_material.set_shader_parameter("cloud_light",cloud_light.lerp(cloud_shade,rainfall*.62))
	sky_material.set_shader_parameter("cloud_shade",cloud_shade)
	sky_material.set_shader_parameter("coverage",lerpf(.38,.94,rainfall))
	sky_material.set_shader_parameter("sky_brightness",.36 if night else .72)
	env.glow_enabled=false
	stadium.grass.set_shader_parameter("flood_glint",0.0)
	for light in floodlights:
		light.visible=night
		light.light_energy=lerpf(4.8,5.3,rainfall) if night else 0.0
	env.fog_enabled=false
	env.fog_density=0.0
	env.fog_aerial_perspective=0.0
	env.fog_sky_affect=0.0
	env.fog_sun_scatter=0.0
	env.fog_height_density=0.0
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		env.volumetric_fog_enabled=false
	shaft_material.set_shader_parameter("strength",0.0)
	for shaft in shafts: shaft.visible=false
	var glass: StandardMaterial3D=stadium.architecture.lamp_glass
	glass.emission_enabled=night
	glass.emission=Color("c3ddff")
	glass.emission_energy_multiplier=3.4 if night else 0.0
	glass.albedo_color=Color("e6efff") if night else Color("a2b0ab")
	stadium.architecture.district.set_night(night)

func apply_color_grade(env: Environment,night: bool,evening: bool) -> void:
	# Use the existing environment tonemap stage; no screen-copy material or LUT.
	# Keep contrast gentle so dark kits and white pitch markings retain detail.
	env.adjustment_enabled=true
	env.adjustment_brightness=lerpf(1.015 if night else 1.0,1.025,rainfall)
	env.adjustment_contrast=lerpf(1.055 if night else (1.035 if evening else 1.025),1.015,rainfall)
	env.adjustment_saturation=lerpf(.97 if night else (.99 if evening else .96),.93,rainfall)
	var exposure := 1.68 if night else (1.62 if evening else 1.65)
	env.tonemap_exposure=exposure if RenderingServer.get_current_rendering_method()!="gl_compatibility" else 1.0
