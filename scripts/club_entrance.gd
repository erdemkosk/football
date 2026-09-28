extends Node3D
## Two team-coloured tunnel lanes; lights only run during the walkout.
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/pitch_dimensions.gd")
var game
var materials: Array[StandardMaterial3D]=[]
var lights: Array[OmniLight3D]=[]

func setup(owner) -> void:
	game=owner; name="ClubEntrance"; owner.add_child(self)
	position.x=P.SIDE_SHIFT
	for team in range(2):
		var side: float=-1 if team==0 else 1
		var mat:=G.material(Color.WHITE)
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled=true; mat.emission_energy_multiplier=1.0
		materials.append(mat)
		for x in [39.0,42.0,45.0,48.0]:
			G.block(self,Vector3(.11,2.65,.09),Vector3(x,1.40,side*2.83),mat)
			G.block(self,Vector3(.11,.08,2.75),Vector3(x,2.74,side*1.4),mat)
		G.block(self,Vector3(11.6,.022,.08),Vector3(43.6,.06,side*2.60),mat)
		var lamp:=OmniLight3D.new(); add_child(lamp)
		lamp.position=Vector3(40.4,1.8,side*1.9)
		lamp.omni_range=6.5; lamp.light_energy=1.4
		lamp.shadow_enabled=false; lamp.light_cull_mask=1
		lights.append(lamp)
	hide()

func configure() -> void:
	for team in range(2):
		var club: Dictionary=game.clubs.data(team)
		var tint:=Color(club.primary).lerp(Color(club.accent),.22)
		materials[team].albedo_color=tint; materials[team].emission=tint
		lights[team].light_color=tint

func _process(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.match_menu): return
	var ceremony: bool=game.state=="ceremony" or game.state=="paused" and game.before_pause=="ceremony"
	visible=ceremony and not game.training and not game.menu_match.running
	if not visible or game.state=="paused": return
	var age: float=game.ceremony.elapsed
	for team in range(2):
		var pulse:=1.0 if game.experience.reduce_motion else .90+.10*sin(age*1.7+team*.8)
		materials[team].emission_energy_multiplier=pulse
		lights[team].light_energy=1.4*pulse
