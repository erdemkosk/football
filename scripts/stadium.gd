extends Node3D
const P = preload("res://scripts/pitch_dimensions.gd")
signal atmosphere_event(kind: String,team: int,location: Vector3)
const G = preload("res://scripts/geometry.gd")
const LED = preload("res://scripts/led_boards.gd")
const Crowd = preload("res://scripts/crowd.gd")
var crowd := Crowd.new()
const Sidelines = preload("res://scripts/sidelines.gd")
var sidelines: Node3D
const Architecture = preload("res://scripts/stadium_architecture.gd")
var architecture: Node3D
const GoalNet = preload("res://scripts/goal_net.gd")
var nets: Array[Node3D] = []
var white := G.material(Color("e9ebe0"))
var concrete := G.material(Color("484f49"))
var chalk := G.material(Color("b9c8b4"))
var steel := G.material(Color("7f9095"),0.5)
var dark := G.material(Color("17262c"))
var rng := RandomNumberGenerator.new()
var grass := ShaderMaterial.new()
var env := Environment.new()
var sun := DirectionalLight3D.new()
const MatchLighting = preload("res://scripts/stadium_lighting.gd")
const PitchBurst = preload("res://scripts/pitch_burst.gd")
var light_rig: Node3D
var pitch_burst: Node3D
var static_batch_stats: Dictionary = {}
var supporter_banners: Array[Dictionary] = []

func _ready() -> void:
	rng.seed = 913
	lighting()
	pitch()
	stands()
	details()
	boundary_walls()
	# Nets and sideline people animate independently; only architecture is baked.
	static_batch_stats=preload("res://scripts/static_geometry.gd").batch(self,nets+[sidelines,architecture.district])
	light_rig=MatchLighting.new()
	add_child(light_rig)
	light_rig.build(self)
	pitch_burst=PitchBurst.new()
	add_child(pitch_burst)

func lighting() -> void:
	var environment = WorldEnvironment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6f868a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d4e1ee")
	env.ambient_light_energy = 0.50
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Match the established palette's brightness on the linear Metal/Vulkan path.
	env.tonemap_exposure = 1.65 if RenderingServer.get_current_rendering_method()!="gl_compatibility" else 1.0
	environment.environment = env
	add_child(environment)
	sun.rotation_degrees = Vector3(-54,-32,0)
	sun.light_color = Color("f3efdf")
	sun.light_energy = 0.90
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.52
	sun.directional_shadow_max_distance = 150
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = .35
	add_child(sun)

func pitch() -> void:
	var foundation=G.block(self,Vector3(132+P.EXTRA_WIDTH,1,162),Vector3(0,-0.6,0),G.material(Color("202e2d")))
	foundation.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	grass.shader = load("res://shaders/grass.gdshader")
	grass.set_shader_parameter("half_pitch",Vector2(P.HALF_WIDTH,P.HALF_LENGTH))
	# Flat ground receives player/roof shadows, but has nothing below it to shade.
	# Excluding these large coplanar slabs avoids grazing-light shadow acne.
	for area in [Vector3(P.WIDTH+14,0.12,115),Vector3(P.WIDTH,0.1,P.LENGTH)]:
		var turf_mesh=G.block(self,area,Vector3(0,-0.12 if area.x>P.WIDTH else -0.05,0),grass)
		turf_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var turf = G.collision_box(self,P.TURF_COLLISION_SIZE,Vector3(0,-0.5,0),0.05)
	turf.physics_material_override.friction = 0.65
	outline(-P.HALF_WIDTH,-P.HALF_LENGTH,P.HALF_WIDTH,P.HALF_LENGTH)
	line(Vector2(-P.HALF_WIDTH,0),Vector2(P.HALF_WIDTH,0))
	arc(Vector2.ZERO,9.15,0,TAU)
	spot(Vector2.ZERO)
	for side in [-1,1]:
		outline(-20.16,side*50,20.16,side*33.5)
		outline(-9.16,side*50,9.16,side*44.5)
		spot(Vector2(0,side*39))
		arc(Vector2(0,side*39),9.15,0.645 if side<0 else PI+0.645,PI-0.645 if side<0 else TAU-0.645)
		goal_frame(side)
		for sx in [-1,1]:
			arc(Vector2(sx*P.HALF_WIDTH,side*50),1.0,0 if sx<0 and side<0 else (PI*0.5 if sx>0 and side<0 else (PI if sx>0 else PI*1.5)),PI*0.5 if sx<0 and side<0 else (PI if sx>0 and side<0 else (PI*1.5 if sx>0 else TAU)))
			G.rod(self,Vector3(sx*P.HALF_WIDTH,0,side*50),Vector3(sx*P.HALF_WIDTH,1.5,side*50),0.035,white)
			G.block(self,Vector3(0.42,0.27,0.02),Vector3(sx*P.HALF_WIDTH+0.21,1.36,side*50),G.material(Color("f2e763")))

func line(a: Vector2, b: Vector2, thickness: float = 0.12) -> void:
	var delta = b-a
	var node = G.block(self,Vector3(thickness,0.012,delta.length()),Vector3((a.x+b.x)*0.5,0.012,(a.y+b.y)*0.5),chalk)
	node.rotation.y = -delta.angle()+PI*0.5
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func outline(x1: float,z1: float,x2: float,z2: float) -> void:
	line(Vector2(x1,z1),Vector2(x2,z1))
	line(Vector2(x2,z1),Vector2(x2,z2))
	line(Vector2(x2,z2),Vector2(x1,z2))
	line(Vector2(x1,z2),Vector2(x1,z1))

func arc(center: Vector2,radius: float,start: float,end: float) -> void:
	for i in range(72):
		var a = lerpf(start,end,i/72.0)
		var b = lerpf(start,end,(i+1)/72.0)
		line(center+Vector2(cos(a),sin(a))*radius,center+Vector2(cos(b),sin(b))*radius,0.105)

func spot(p: Vector2) -> void:
	G.cylinder(self,0.16,0.017,Vector3(p.x,0.02,p.y),chalk)

func goal_frame(side: int) -> void:
	var z = side*50.0
	for x in [-3.66,3.66]:
		G.rod(self,Vector3(x,0,z),Vector3(x,2.44,z),0.065,white)
		G.collision_box(self,Vector3(0.13,2.5,0.13),Vector3(x,1.22,z),0.65)
		G.rod(self,Vector3(x,2.44,z),Vector3(x,1.9,z+side*2.4),0.04,steel)
		G.rod(self,Vector3(x,0.05,z+side*2.4),Vector3(x,1.9,z+side*2.4),0.04,steel)
		G.rod(self,Vector3(x,0.05,z),Vector3(x,0.05,z+side*2.4),0.04,white)
		# Rear pegs and tension cords anchor the net to the goalmouth.
		for depth in [.6,1.2,1.8,2.4]:
			G.cylinder(self,.065,.028,Vector3(x,.022,z+side*depth),steel)
		G.rod(self,Vector3(x,1.9,z+side*2.4),Vector3(x,.06,z+side*2.4),.012,white)
	G.rod(self,Vector3(-3.66,2.44,z),Vector3(3.66,2.44,z),0.065,white)
	G.collision_box(self,Vector3(7.5,0.13,0.13),Vector3(0,2.44,z),0.65)
	var net = GoalNet.new()
	add_child(net)
	net.build(side)
	nets.append(net)

func stands() -> void:
	crowd.rng.seed = 913
	var rail = G.material(Color("707b71"))
	var front = G.material(Color("263d36"))
	var stair_edge = G.material(Color("828579"))
	for side in [-1,1]:
		for row in range(12):
			var y = row*0.56+0.25
			var x = side*(39.5+P.SIDE_SHIFT+row*0.95)
			if side>0 and row<6:
				for end in [-1,1]: G.block(self,Vector3(1.0,0.55,53),Vector3(x,y,end*29.5),concrete)
			else: G.block(self,Vector3(1.0,0.55,112),Vector3(x,y,0),concrete)
			for col in range(133):
				var z = -54+col*0.82
				if side>0 and row<6 and absf(z)<3.3: continue
				if col%22 in [0,1]:
					G.block(self,Vector3(0.07,0.025,0.82),Vector3(x-side*0.39,y+0.29,z),stair_edge)
					continue
				crowd.seat(Vector3(x,y+0.275,z+(row%2)*0.13),side*PI*0.5,row,col/22)
		for aisle in range(1,6):
			var z = -54+aisle*22*0.82+0.41
			if side>0 and absf(z)<3.3: continue
			for edge in [-0.56,0.56]:
				G.rod(self,Vector3(side*(39.5+P.SIDE_SHIFT),1.2,z+edge),Vector3(side*(49.95+P.SIDE_SHIFT),7.36,z+edge),0.035,rail)
				for row in [0,4,8,11]:
					var x = side*(39.5+P.SIDE_SHIFT+row*0.95)
					G.rod(self,Vector3(x,row*0.56+0.5,z+edge),Vector3(x,row*0.56+1.2,z+edge),0.03,rail)
		if side>0:
			for end in [-1,1]:
				G.block(self,Vector3(0.18,0.65,53),Vector3(side*(38.8+P.SIDE_SHIFT),0.35,end*29.5),front)
				G.rod(self,Vector3(side*(38.8+P.SIDE_SHIFT),0.95,end*3),Vector3(side*(38.8+P.SIDE_SHIFT),0.95,end*56),0.045,rail)
		else:
			G.block(self,Vector3(0.18,0.65,112),Vector3(side*(38.8+P.SIDE_SHIFT),0.35,0),front)
			G.rod(self,Vector3(side*(38.8+P.SIDE_SHIFT),0.95,-56),Vector3(side*(38.8+P.SIDE_SHIFT),0.95,56),0.045,rail)
		for row in range(9):
			var y = row*0.56+0.25
			var z = side*(58.5+row*0.95)
			G.block(self,Vector3(99+P.EXTRA_WIDTH,0.55,1),Vector3(0,y,z),concrete)
			for col in range(117):
				var x = (-48+col*0.82)*(99+P.EXTRA_WIDTH)/99
				if col%23 in [0,1]:
					G.block(self,Vector3(0.82,0.025,0.07),Vector3(x,y+0.29,z-side*0.39),stair_edge)
					continue
				crowd.seat(Vector3(x+(row%2)*0.13,y+0.275,z),PI if side<0 else 0,row,col/23)
		for aisle in range(1,5):
			var x = (-48+aisle*23*0.82+0.41)*(99+P.EXTRA_WIDTH)/99
			for edge in [-0.56,0.56]:
				G.rod(self,Vector3(x+edge,1.2,side*58.5),Vector3(x+edge,5.68,side*66.1),0.035,rail)
		G.block(self,Vector3(99+P.EXTRA_WIDTH,0.65,0.18),Vector3(0,0.35,side*57.8),front)
		G.rod(self,Vector3(-49-P.SIDE_SHIFT,0.95,side*57.8),Vector3(49+P.SIDE_SHIFT,0.95,side*57.8),0.045,rail)
	architecture = Architecture.new()
	add_child(architecture)
	architecture.build(crowd)
	crowd.build(self)
	# Fabric banners add recognisable supporter sections without glowing signage.
	for side in [-1,1]:
		for section in range(3):
			var banner = Node3D.new()
			add_child(banner)
			banner.position = Vector3((-33+section*33)*P.WIDTH_RATIO,1.12,side*57.55)
			if side>0: banner.rotation.y = PI
			G.block(banner,Vector3(12,0.95,0.035),Vector3.ZERO,front)
			var title := board_label(banner,["KIYI 1967","HEP BİRLİKTE","BİZİM ŞEHRİMİZ"][section],Vector3(0,0,0.025),Color("bcbda4"),0.015)
			supporter_banners.append({"label":title,"away":banner.position.x>38 and banner.position.z>25,"section":section})

func details() -> void:
	var navy = G.material(Color("133540"))
	var gold = G.material(Color("817b60"))
	for side in [-1,1]:
		for i in range(12):
			if side>0 and absf(absf(-49.5+i*9)-12)<10.1: continue
			var board = Node3D.new()
			add_child(board)
			board.position = Vector3(side*(P.HALF_WIDTH+3.6),0.65,-49.5+i*9)
			board.rotation.y = -side*PI*0.5
			G.block(board,Vector3(8.65,1.2,0.12),Vector3.ZERO,navy if i%2==0 else gold)
			LED.face(board,Vector2(8.58,1.12),i)
		for i in range(8):
			var board = Node3D.new()
			add_child(board)
			board.position = Vector3((-30.8+i*8.8)*P.WIDTH_RATIO,0.65,side*55.8)
			if side>0: board.rotation.y = PI
			G.block(board,Vector3(8.4*P.WIDTH_RATIO,1.2,0.12),Vector3.ZERO,navy)
			LED.face(board,Vector2(8.4*P.WIDTH_RATIO-.08,1.12),i)
	# Clear technical areas give both teams a view of the pitch.
	for z in [-12,12]: outline(P.HALF_WIDTH+.4,z-5.2,P.HALF_WIDTH+3,z+5.2)
	sidelines = Sidelines.new()
	add_child(sidelines)

func boundary_walls() -> void:
	# Invisible tall faces sit on the hoardings so a ball that leaves the
	# pitch hits, rebounds, and rolls back in without freezing the match.
	for side in [-1, 1]:
		# Godot adds the two materials' bounce values. Keep the perimeter's
		# contribution small so repeated rebounds cannot add energy to the ball.
		var sideline=G.collision_box(self, Vector3(0.22, 24, 112), Vector3(side * (P.HALF_WIDTH+3.55), 12, 0), 0.08)
		var endline=G.collision_box(self, Vector3(P.WIDTH+14, 24, 0.22), Vector3(0, 12, side * 55.7), 0.08)
		# Perimeter containment belongs to the ball; people can use the tunnel.
		sideline.collision_layer=8
		endline.collision_layer=8

func board_label(parent: Node3D,text: String,p: Vector3,color: Color,pixel: float) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)
	label.position = p
	return label

func react(kind: String,team: int,location: Vector3) -> void:
	crowd.react(kind,team,location)
	sidelines.react(kind,team,location)
	if kind=="goal" and is_instance_valid(pitch_burst): pitch_burst.begin(team,location)
	atmosphere_event.emit(kind,team,location)
