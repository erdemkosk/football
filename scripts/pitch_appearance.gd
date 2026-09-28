extends RefCounted
## Visual groundskeeping belongs to the saved venue, never match RNG or physics.
const STYLES := {
	"town":{"mow_pattern":0,"mow_axis":Vector2(0,1),"mow_width":10.0,"turf_dark":Vector3(.145,.235,.119),"turf_light":Vector3(.160,.255,.131),"turf_patchiness":1.65,"turf_age":1.30},
	"compact":{"mow_pattern":0,"mow_axis":Vector2(1,0),"mow_width":6.0,"turf_dark":Vector3(.106,.219,.143),"turf_light":Vector3(.133,.255,.166),"turf_patchiness":.80,"turf_age":.80},
	"modern":{"mow_pattern":1,"mow_axis":Vector2(0,1),"mow_width":8.5,"turf_dark":Vector3(.096,.209,.135),"turf_light":Vector3(.137,.258,.167),"turf_patchiness":.40,"turf_age":.45},
	"historic":{"mow_pattern":0,"mow_axis":Vector2(.70710678,.70710678),"mow_width":8.0,"turf_dark":Vector3(.139,.208,.110),"turf_light":Vector3(.169,.245,.132),"turf_patchiness":1.15,"turf_age":1.05}}

static func profile(venue: Dictionary) -> Dictionary:
	var style: Dictionary=STYLES.get(venue.get("kind","modern"),STYLES.modern).duplicate(true)
	var seed_value:=int(str(venue.get("owner","")).hash())
	# Even clubs sharing a stadium family retain their own cut width and tone.
	style.mow_width+=float(posmod(seed_value,5)-2)*.3
	var tint:=1.0+float(posmod(seed_value/5,7)-3)*.008
	style.turf_dark*=tint; style.turf_light*=tint
	style.turf_offset=Vector2(posmod(seed_value,101),posmod(seed_value/101,173))
	return style

static func apply(grass: ShaderMaterial,chalk: ShaderMaterial,style: Dictionary) -> void:
	for material in [grass,chalk]:
		for parameter in style: material.set_shader_parameter(parameter,style[parameter])
