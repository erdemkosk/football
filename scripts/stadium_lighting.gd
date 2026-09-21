extends Node3D
## Match time and weather share one lighting rig; weather never restores a night sun.
var stadium
var period := 0
var rainfall := 0.0
var applied_period := -1
var applied_rain := -1.0
var floodlights: Array[SpotLight3D] = []

func build(arena) -> void:
	stadium=arena
	name="MatchLighting"
	for mount in stadium.architecture.floodlight_mounts:
		var flood := SpotLight3D.new()
		flood.name="RoofFloodlight"+str(floodlights.size()+1)
		add_child(flood)
		flood.position=mount
		flood.look_at(Vector3(-signf(mount.x)*5,0,mount.z*0.28))
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
	apply_weather(0)

func label() -> String:
	return "GÜNDÜZ" if period==0 else "GECE"

func select(value: int) -> void:
	period=clampi(value,0,1)
	apply_weather(rainfall)

func apply_weather(rain: float) -> void:
	rainfall=clampf(rain,0,1)
	if applied_period==period and is_equal_approx(applied_rain,rainfall): return
	applied_period=period; applied_rain=rainfall
	var night := period==1
	var sun: DirectionalLight3D=stadium.sun
	var env: Environment=stadium.env
	sun.visible=not night
	sun.rotation_degrees=Vector3(-48,-38,0)
	sun.light_color=Color("fff1dc").lerp(Color("d8e3ed"),rainfall)
	sun.light_energy=0.0 if night else lerpf(1.05,0.62,rainfall)
	sun.shadow_opacity=lerpf(0.72,0.25,rainfall)
	if night:
		env.background_color=Color("081323").lerp(Color("111a27"),rainfall)
		env.ambient_light_color=Color("8daccd")
		env.ambient_light_energy=lerpf(0.20,0.25,rainfall)
	else:
		env.background_color=Color("6f868a").lerp(Color("5a7178"),rainfall)
		env.ambient_light_color=Color("d4e1ee").lerp(Color("a8bdcf"),rainfall)
		env.ambient_light_energy=lerpf(0.42,0.66,rainfall)
	for light in floodlights:
		light.visible=night
		light.light_energy=lerpf(4.8,5.3,rainfall) if night else 0.0
	var glass: StandardMaterial3D=stadium.architecture.lamp_glass
	glass.emission_enabled=night
	glass.emission=Color("c3ddff")
	glass.emission_energy_multiplier=2.4 if night else 0.0
	glass.albedo_color=Color("e6efff") if night else Color("a2b0ab")
	stadium.architecture.district.set_night(night)
