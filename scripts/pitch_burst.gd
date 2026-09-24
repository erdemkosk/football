extends Node3D
## Terrace paper, flares and unfurling banners after a goal. No gameplay state.
const G = preload("res://scripts/geometry.gd")
const P = preload("res://scripts/pitch_dimensions.gd")
const LIMIT := 80
const FLARE_LIMIT := 12
const SMOKE_LIMIT := 36
const BANNER_COUNT := 3
var game
var flakes: Array[Dictionary] = []
var flares: Array[Dictionary] = []
var smoke: Array[Dictionary] = []
var banners: Array[Dictionary] = []
var lights: Array[OmniLight3D] = []
var batch: MultiMeshInstance3D
var flare_batch: MultiMeshInstance3D
var smoke_batch: MultiMeshInstance3D
var cursor := 0
var rng := RandomNumberGenerator.new()
# True once every piece is hidden and every flare lamp is dark. Until the next
# goal, further updates would only repeat those identical writes each tick.
var idle := true

func _ready() -> void:
	rng.randomize()
	batch=make_batch("TerracePaper",Vector3(0.08,0.012,0.08),false)
	flare_batch=make_batch("TerraceFlares",Vector3(0.045,0.28,0.045),true)
	smoke_batch=make_batch("TerraceSmoke",Vector3(0.34,0.34,0.34),false,true)
	for i in range(LIMIT):
		flakes.append({"life":0.0,"position":Vector3.ZERO,"velocity":Vector3.ZERO,"spin":0.0,"yaw":0.0,"scarf":false})
		hide_instance(batch,i)
	for i in range(FLARE_LIMIT):
		flares.append({"life":0.0,"position":Vector3.ZERO,"phase":0.0})
		hide_instance(flare_batch,i)
	for i in range(SMOKE_LIMIT):
		smoke.append({"life":0.0,"position":Vector3.ZERO,"velocity":Vector3.ZERO,"size":0.4})
		hide_instance(smoke_batch,i)
	for i in range(6):
		var lamp := OmniLight3D.new()
		lamp.light_color=Color("ff6a22")
		lamp.light_energy=0
		lamp.omni_range=6.5
		lamp.shadow_enabled=false
		add_child(lamp)
		lights.append(lamp)
	for i in range(BANNER_COUNT):
		banners.append(make_banner())
	show_effects(false)

func make_batch(label: String,size: Vector3,glow: bool,haze: bool=false) -> MultiMeshInstance3D:
	var scrap := BoxMesh.new()
	scrap.size=size
	var node := MultiMeshInstance3D.new()
	node.name=label
	var mesh := MultiMesh.new()
	mesh.transform_format=MultiMesh.TRANSFORM_3D
	mesh.use_colors=true
	mesh.mesh=scrap
	mesh.instance_count=LIMIT if label=="TerracePaper" else (FLARE_LIMIT if glow else SMOKE_LIMIT)
	node.multimesh=mesh
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.vertex_color_is_srgb=true
	mat.roughness=0.55 if not glow else 0.32
	if glow:
		mat.emission_enabled=true
		mat.emission=Color("ff5a18")
		mat.emission_energy_multiplier=2.2
	if haze:
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color=Color(0.62,0.46,0.28,0.28)
	node.material_override=mat
	add_child(node)
	return node

func make_banner() -> Dictionary:
	var node := Node3D.new()
	node.visible=false
	add_child(node)
	var cloth := StandardMaterial3D.new()
	cloth.roughness=0.72
	var sheet := G.block(node,Vector3(9.2,1.7,0.04),Vector3.ZERO,cloth)
	var title := Label3D.new()
	title.font_size=56
	title.pixel_size=0.018
	title.outline_size=0
	title.position=Vector3(0,0,-0.03)
	node.add_child(title)
	return {"node":node,"cloth":sheet,"label":title,"age":0.0,"life":0.0}

func show_effects(value: bool) -> void:
	# Hidden pieces are already collapsed below the turf and the flare lamps are
	# dark. Leaving the nodes out also stops six zero-energy lamps at the centre
	# spot from being paired with and looped over by the nearby turf and players.
	for node in [batch,flare_batch,smoke_batch]: node.visible=value
	for lamp in lights: lamp.visible=value

func hide_instance(node: MultiMeshInstance3D,index: int) -> void:
	node.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.001),Vector3(0,-4,0)))

func reset() -> void:
	for i in range(LIMIT):
		flakes[i].life=0
		hide_instance(batch,i)
	for i in range(FLARE_LIMIT):
		flares[i].life=0
		hide_instance(flare_batch,i)
	for i in range(SMOKE_LIMIT):
		smoke[i].life=0
		hide_instance(smoke_batch,i)
	for lamp in lights:
		lamp.light_energy=0
	for banner in banners:
		banner.life=0
		banner.age=0
		banner.node.visible=false
		banner.node.scale=Vector3(1,0.08,1)
	idle=true
	show_effects(false)

func terrace(team: int) -> Vector3:
	if team==1:
		return Vector3(rng.randf_range(-52.0,-38.0),rng.randf_range(1.7,10.4),rng.randf_range(16.0,66.0))
	var pick := rng.randi()%5
	if pick==0:
		return Vector3(rng.randf_range(-16.0,36.0),rng.randf_range(1.5,5.9),rng.randf_range(58.2,66.6))
	if pick==1:
		return Vector3(rng.randf_range(-46.0,46.0),rng.randf_range(1.5,5.9),rng.randf_range(-66.6,-58.2))
	if pick==2:
		return Vector3(rng.randf_range(-40.0,40.0),rng.randf_range(6.6,10.4),rng.randf_range(-78.0,-68.0))
	if pick==3:
		return Vector3(rng.randf_range(-62.0,-54.0),rng.randf_range(8.0,12.4),rng.randf_range(-40.0,10.0))
	return Vector3(rng.randf_range(54.0,62.0),rng.randf_range(8.0,12.4),rng.randf_range(-40.0,22.0))

func begin(team: int,_at: Vector3) -> void:
	if game==null or game.training or game.menu_match.running: return
	idle=false
	show_effects(true)
	var kit: Dictionary=game.clubs.kit(team)
	var club: Dictionary=game.clubs.data(team)
	var palette: Array=[kit.primary,kit.accent,Color("e9ce87"),Color("f5f0df")]
	for i in range(56):
		var flake: Dictionary=flakes[cursor]
		var origin: Vector3=terrace(team)
		var inward: Vector3=Vector3(-origin.x,0,-origin.z)
		if inward.length()<1.0: inward=Vector3(0,0,-1)
		inward=inward.normalized()
		flake.position=origin+Vector3(rng.randf_range(-1.4,1.4),rng.randf_range(0.2,1.1),rng.randf_range(-1.4,1.4))
		flake.velocity=inward*rng.randf_range(2.6,6.8)+Vector3(rng.randf_range(-1.4,1.4),rng.randf_range(0.9,3.2),rng.randf_range(-1.4,1.4))
		flake.spin=rng.randf_range(-6.0,6.0)
		flake.yaw=rng.randf_range(0,TAU)
		flake.life=rng.randf_range(2.1,3.8)
		flake.scarf=i%6==0
		batch.multimesh.set_instance_color(cursor,palette[i%palette.size()])
		cursor=(cursor+1)%LIMIT
	for i in range(FLARE_LIMIT):
		var flare: Dictionary=flares[i]
		flare.position=terrace(team)
		flare.life=rng.randf_range(7.5,11.5)
		flare.phase=rng.randf()*TAU
		flare_batch.multimesh.set_instance_color(i,Color("ff6a28").lerp(Color("ffb060"),rng.randf()*0.45))
	for i in range(SMOKE_LIMIT):
		var puff: Dictionary=smoke[i]
		var host: Dictionary=flares[i%FLARE_LIMIT]
		puff.position=host.position+Vector3(rng.randf_range(-0.18,0.18),0.18,rng.randf_range(-0.18,0.18))
		puff.velocity=Vector3(rng.randf_range(-0.22,0.22),rng.randf_range(0.35,0.85),rng.randf_range(-0.22,0.22))
		puff.life=rng.randf_range(3.2,7.4)
		puff.size=rng.randf_range(0.55,1.15)
		smoke_batch.multimesh.set_instance_color(i,Color(0.58,0.42,0.28,0.32))
	place_banners(team,club,kit)

func place_banners(team: int,club: Dictionary,kit: Dictionary) -> void:
	var spots: Array
	var faces: Array
	var lines: Array
	if team==1:
		spots=[Vector3(-44.5,3.4,36.0),Vector3(-50.2,6.2,48.0),Vector3(-28.0,3.1,58.4)]
		faces=[Vector3(1,0,-0.2),Vector3(1,0,-0.15),Vector3(0.15,0,-1)]
		lines=[str(club.short),str(club.short)+" · DEPLASMAN",str(club.get("city",""))]
	else:
		spots=[Vector3(-20.0*P.WIDTH_RATIO,3.15,-57.45),Vector3(16.0*P.WIDTH_RATIO,3.55,-57.45),Vector3(-56.4,8.8,10.0)]
		faces=[Vector3(0,0,1),Vector3(0,0,1),Vector3(1,0,0)]
		lines=[str(club.short)+" · "+str(club.get("year","")),"HEP BİRLİKTE",str(club.short)]
	for i in range(BANNER_COUNT):
		var banner: Dictionary=banners[i]
		var look: Vector3=faces[i]
		banner.node.position=spots[i]
		banner.node.rotation=Vector3.ZERO
		banner.node.look_at(spots[i]+look,Vector3.UP)
		banner.node.scale=Vector3(1,0.08,1)
		banner.node.visible=true
		banner.age=0
		banner.life=11.5
		banner.cloth.material_override.albedo_color=kit.primary
		banner.label.text=lines[i]
		banner.label.modulate=kit.accent if kit.accent.get_luminance()>0.28 else Color("f2eee0")

func update(delta: float) -> void:
	if idle: return
	var alive := false
	for i in range(LIMIT):
		var flake: Dictionary=flakes[i]
		if flake.life<=0: continue
		flake.life-=delta
		flake.velocity.y-=6.4*delta
		flake.velocity.x+=sin(flake.yaw+flake.life*9.0)*1.8*delta
		flake.position+=flake.velocity*delta
		flake.yaw+=flake.spin*delta
		if flake.position.y<0.04 or flake.life<=0:
			flake.life=0
			hide_instance(batch,i)
			continue
		alive=true
		var size: Vector3=Vector3(0.42,0.08,1.85) if flake.scarf else Vector3(0.85,0.12,0.55)
		batch.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,flake.yaw)*Basis.from_scale(size),flake.position))
	for i in range(FLARE_LIMIT):
		var flare: Dictionary=flares[i]
		if flare.life<=0:
			hide_instance(flare_batch,i)
			if i<lights.size(): lights[i].light_energy=0
			continue
		alive=true
		flare.life-=delta
		var pulse: float=0.72+0.28*sin(flare.phase+flare.life*11.0)
		var basis := Basis.from_scale(Vector3(1.0,1.0+0.08*pulse,1.0))
		flare_batch.multimesh.set_instance_transform(i,Transform3D(basis,flare.position+Vector3(0,0.16,0)))
		if i<lights.size():
			lights[i].position=flare.position+Vector3(0,0.28,0)
			lights[i].light_energy=1.05*pulse if flare.life>0.4 else 0.0
	for i in range(SMOKE_LIMIT):
		var puff: Dictionary=smoke[i]
		if puff.life<=0:
			hide_instance(smoke_batch,i)
			continue
		alive=true
		puff.life-=delta
		puff.position+=puff.velocity*delta
		puff.velocity.y+=0.12*delta
		var fade: float=clampf(puff.life/2.4,0,1)
		var size: float=puff.size*(1.15-fade*0.25)
		smoke_batch.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(size,size*1.15,size)),puff.position))
		smoke_batch.multimesh.set_instance_color(i,Color(0.58,0.42,0.28,0.28*fade))
	for banner in banners:
		if banner.life<=0:
			banner.node.visible=false
			continue
		alive=true
		banner.age+=delta
		banner.life-=delta
		var open: float=smoothstep(0.0,1.15,banner.age)
		var hold: float=smoothstep(0.0,0.8,banner.life)
		banner.node.scale=Vector3(1,lerpf(0.08,1.0,open),1)
		banner.node.visible=hold>0.02
		var ink: Color=banner.label.modulate
		ink.a=hold
		banner.label.modulate=ink
	# Everything took the hidden branch above, so the scene is already final.
	idle=not alive
	if idle: show_effects(false)
