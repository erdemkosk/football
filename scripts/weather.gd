extends Node3D
## One surface model drives shading, ball response, player grip and persistent marks.
const MARK_LIMIT := 3072
const SPRAY_LIMIT := 96
const PATCHES := [Vector4(0,-47,8,5),Vector4(0,47,8,5),Vector4(0,0,7,5),Vector4(-23,-17,6,10),Vector4(22,20,7,9),Vector4(9,-31,5,6)]
var game
var preset := 0
var rain := 0.0
var wetness := 0.0
var clock := 0.0
var rain_mesh: MultiMeshInstance3D
var marks: MultiMeshInstance3D
var spray: MultiMeshInstance3D
var rain_material := ShaderMaterial.new()
var mark_material := ShaderMaterial.new()
var mark_count := 0
var mark_cursor := 0
var spray_cursor := 0
var foot_state: Dictionary = {}
var spray_data: Array[Dictionary] = []
var ball_last := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var sound: AudioStreamPlayer

func _ready() -> void:
	rng.seed=8201
	rain_material.shader=load("res://shaders/rain.gdshader")
	var drop := BoxMesh.new()
	drop.size=Vector3(0.018,0.52,0.018)
	rain_mesh=instances(drop,rain_material,2200)
	for i in range(2200):
		rain_mesh.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-35,35),rng.randf_range(0,18),rng.randf_range(-54,54))))
		rain_mesh.multimesh.set_instance_custom_data(i,Color(rng.randf(),0,0,0))
	mark_material.shader=load("res://shaders/surface_mark.gdshader")
	var sole := PlaneMesh.new()
	sole.size=Vector2.ONE
	marks=instances(sole,mark_material,MARK_LIMIT)
	marks.multimesh.visible_instance_count=0
	var grain := SphereMesh.new()
	grain.radius=0.025
	grain.height=0.05
	grain.radial_segments=6
	grain.rings=3
	var splash_mat := StandardMaterial3D.new()
	splash_mat.vertex_color_use_as_albedo=true
	splash_mat.roughness=0.35
	spray=instances(grain,splash_mat,SPRAY_LIMIT)
	for i in range(SPRAY_LIMIT):
		spray_data.append({"life":0.0,"position":Vector3.ZERO,"velocity":Vector3.ZERO})
		spray.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.001),Vector3(0,-2,0)))
	sound=AudioStreamPlayer.new()
	add_child(sound)
	# A separate seeded stream leaves match randomness and crowd synthesis alone.
	var audio_script=load("res://scripts/audio.gd").new()
	sound.stream=audio_script.synth("rain",4.0)
	audio_script.free()
	sound.volume_db=-80
	sound.play()
	apply_look()

func instances(mesh: Mesh,material: Material,count: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.use_colors=true
	batch.use_custom_data=true
	batch.mesh=mesh
	batch.instance_count=count
	node.multimesh=batch
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb=AABB(Vector3(-40,-3,-60),Vector3(80,25,120))
	add_child(node)
	return node

func label() -> String:
	return ["AÇIK","YAĞMURLU","SAĞANAK"][preset]

func select(value: int,immediate: bool=false) -> void:
	preset=clampi(value,0,2)
	if immediate:
		rain=[0.0,0.45,1.0][preset]
		wetness=[0.0,0.55,1.0][preset]
	apply_look()

func reset_match() -> void:
	clock=0
	mark_count=0
	mark_cursor=0
	marks.multimesh.visible_instance_count=0
	foot_state.clear()
	ball_last=Vector3.ZERO
	for i in range(SPRAY_LIMIT):
		spray_data[i].life=0
		spray.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.001),Vector3(0,-2,0)))
	select(preset,true)

func mud_at(point: Vector3) -> float:
	if absf(point.x)>32 or absf(point.z)>50: return 0.0
	var patch := 0.0
	for area in PATCHES:
		var distance := Vector2((point.x-area.x)/area.z,(point.z-area.y)/area.w).length()
		patch=maxf(patch,1.0-smoothstep(0.3,1.0,distance))
	return patch*smoothstep(0.25,0.95,wetness)

func grip_at(point: Vector3) -> float:
	return 1.0-wetness*0.12-mud_at(point)*0.15

func ball_drag(point: Vector3) -> float:
	# Wet intact grass skids; churned earth absorbs motion.
	return 1.15-wetness*0.28+mud_at(point)*2.8

func ball_bounce(point: Vector3) -> float:
	return 0.56-wetness*0.1-mud_at(point)*0.17

func update(delta: float) -> void:
	clock+=delta
	rain=move_toward(rain,[0.0,0.45,1.0][preset],delta*0.2)
	wetness=clampf(wetness+delta*(rain*0.025-(0.003 if rain<0.05 else 0.0)),0,1)
	apply_look()
	if is_instance_valid(game.audio): sound.volume_db=-80 if game.audio.muted or game.state=="paused" or rain<0.01 else lerpf(-36,-23,rain)
	var ball=game.ball
	if ball.active and ball.held_by==null and ball.position.y<0.3 and game.state not in ["menu","finished"]:
		if ball_last!=Vector3.ZERO and ball_last.distance_to(ball.position)<2 and ball_last.distance_to(ball.position)>0.22:
			var mud := mud_at(ball.position)
			if mud>0.12: trail(ball_last,ball.position,0.08,Color(0.075,0.06,0.032,mud*0.62))
			if wetness>0.3 and ball.linear_velocity.length()>4: splash(ball.position,ball.linear_velocity,2,mud)
			ball_last=ball.position
		elif ball_last==Vector3.ZERO or ball_last.distance_to(ball.position)>=2: ball_last=ball.position
	else: ball_last=Vector3.ZERO
	for i in range(SPRAY_LIMIT):
		var drop: Dictionary=spray_data[i]
		if drop.life<=0: continue
		drop.life-=delta
		drop.velocity.y-=9.81*delta
		drop.position+=drop.velocity*delta
		if drop.position.y<0.025 or drop.life<=0:
			drop.life=0
			spray.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.001),Vector3(0,-2,0)))
		else: spray.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,drop.position))

func apply_look() -> void:
	if not is_instance_valid(rain_mesh): return
	rain_mesh.visible=rain>0.01
	rain_mesh.multimesh.visible_instance_count=int(2200*rain)
	rain_material.set_shader_parameter("clock",clock)
	rain_material.set_shader_parameter("intensity",rain)
	mark_material.set_shader_parameter("clock",clock)
	game.stadium.grass.set_shader_parameter("wetness",wetness)
	game.stadium.grass.set_shader_parameter("weather_clock",clock)
	game.stadium.grass.set_shader_parameter("rain",rain)
	game.stadium.sun.light_energy=lerpf(0.9,0.62,rain)
	game.stadium.sun.shadow_opacity=lerpf(0.52,0.22,rain)
	game.stadium.env.ambient_light_energy=lerpf(0.5,0.66,rain)
	game.stadium.env.ambient_light_color=Color("d4e1ee").lerp(Color("a8bdcf"),rain)
	game.stadium.env.background_color=Color("a7bbc2").lerp(Color("728894"),rain)

func player_step(player, _delta: float) -> void:
	if not player.visible or game.state in ["menu","paused","finished"]: return
	var id: int=player.get_instance_id()
	var here: Vector3=player.position
	if not foot_state.has(id): foot_state[id]={"last":here,"distance":0.0,"side":1.0}
	var foot: Dictionary=foot_state[id]
	var travel: Vector3=(here-foot.last)*Vector3(1,0,1)
	var distance := travel.length()
	var mud := mud_at(here)
	if distance>2 or here.y>0.13:
		foot.last=here
		foot.distance=0
		return
	if player.action_timer>0 and player.pose in ["slide","dive"]:
		if distance>0.18:
			trail(foot.last,here,0.44 if player.pose=="slide" else 0.65,Color(0.10,0.085,0.043,0.2+wetness*0.25+mud*0.3))
			if wetness>0.2: splash(here,player.velocity,5,mud)
			foot.last=here
		return
	foot.last=here
	foot.distance+=distance
	if foot.distance>0.95 and player.velocity.length()>0.6:
		foot.distance=0
		foot.side=-foot.side
		var forward: Vector3=player.facing.normalized()
		var at: Vector3=here+Vector3(-forward.z,0,forward.x)*foot.side*0.2
		if wetness>0.2:
			stamp(at,forward,Vector2(0.20,0.38),Color(0.09,0.079,0.045,wetness*(0.15+mud*0.62)))
			if player.velocity.length()>3: splash(at,player.velocity,3,mud)

func trail(from: Vector3,to: Vector3,width: float,color: Color) -> void:
	var travel := (to-from)*Vector3(1,0,1)
	if travel.length()>2 or travel.length()<0.01: return
	stamp((from+to)*0.5,travel.normalized(),Vector2(width,travel.length()+0.008),color,true)

func stamp(at: Vector3,direction: Vector3,size: Vector2,color: Color,is_trail: bool=false) -> void:
	if absf(at.x)>32 or absf(at.z)>50: return
	var basis := Basis(Vector3.UP,atan2(direction.x,direction.z))*Basis.from_scale(Vector3(size.x,1,size.y))
	marks.multimesh.set_instance_transform(mark_cursor,Transform3D(basis,Vector3(at.x,0.023+float(mark_cursor%5)*0.0002,at.z)))
	marks.multimesh.set_instance_color(mark_cursor,color)
	marks.multimesh.set_instance_custom_data(mark_cursor,Color(clock,1.0 if is_trail else 0.0,0,0))
	mark_cursor=(mark_cursor+1)%MARK_LIMIT
	mark_count=mini(mark_count+1,MARK_LIMIT)
	marks.multimesh.visible_instance_count=mark_count

func splash(at: Vector3,velocity: Vector3,count: int,mud: float) -> void:
	if absf(at.x)>32 or absf(at.z)>50: return
	for i in range(count):
		var drop: Dictionary=spray_data[spray_cursor]
		drop.position=Vector3(at.x,0.12,at.z)
		drop.velocity=-velocity*0.1+Vector3(rng.randf_range(-0.9,0.9),rng.randf_range(0.6,1.7),rng.randf_range(-0.9,0.9))
		drop.life=0.6
		spray.multimesh.set_instance_color(spray_cursor,Color("718b8d").lerp(Color("635035"),mud))
		spray_cursor=(spray_cursor+1)%SPRAY_LIMIT
