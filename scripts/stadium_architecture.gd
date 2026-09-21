extends Node3D
var team_captions: Array[Label3D] = []
## One continuous stadium shell, with the playing surface kept unobstructed.
const G = preload("res://scripts/geometry.gd")
var stone := G.material(Color("626e6c"))
var frame := G.material(Color("7b8986"),0.60)
var roof := G.material(Color("626d68"),0.9)
var trim := G.material(Color("193e45"))
var charcoal := G.material(Color("162a30"))
var glass := G.material(Color("657f82"),0.32)
var score_labels: Array[Label3D] = []
var clock_labels: Array[Label3D] = []
var display_text := ""
var lamp_glass := G.material(Color("a2b0ab"),0.28)
var floodlight_mounts: Array[Vector3] = []
var hedge := G.material(Color("40594a"))
var city_blocks := 0
var district: Node3D

func build(crowd) -> void:
	name = "StadiumArchitecture"
	# Thin roof sheets still shade the seating below, without self-shadow banding.
	roof.disable_receive_shadows=true
	var forecourt=G.block(self,Vector3(244,0.18,270),Vector3(0,-0.82,0),G.material(Color("3a493f")))
	var paving=G.block(self,Vector3(154,0.3,196),Vector3(0,-0.63,0),G.material(Color("555d58")))
	forecourt.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paving.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1,1]:
		grandstand(crowd,side*PI*0.5,112,53,8.6,63,47,164)
		grandstand(crowd,0 if side>0 else PI,99,69,6.9,82,65,126)
		for other in [-1,1]: corner(Vector3(side*57,0,other*62))
	player_tunnel()
	broadcast_positions()
	exterior()
	update_score([0,0],0,240)

func grandstand(crowd,angle: float,width: float,start: float,base: float,back: float,lip: float,roof_width: float) -> void:
	var stand = Node3D.new()
	add_child(stand)
	stand.rotation.y = angle
	var is_end = start>60
	# A concourse separates the existing lower terrace from the upper tier.
	G.block(stand,Vector3(width,0.32,2.2),Vector3(0,base-0.55,start-1.6),stone)
	G.block(stand,Vector3(width,0.8,0.18),Vector3(0,base-0.02,start-2.6),trim)
	for row in range(6):
		var y = base+row*0.63
		var z = start+row*0.95
		G.block(stand,Vector3(width,0.6,1),Vector3(0,y,z),stone)
		var count = int(width/0.84)-2
		for col in range(count):
			var x = -width*0.5+1+col*0.84
			if col%22 in [0,1]:
				G.block(stand,Vector3(0.84,0.025,0.06),Vector3(x,y+0.32,z-0.37),frame)
				continue
			crowd.seat(stand.transform*Vector3(x,y+0.3,z),angle,row,col/22)
		for col in range(22,count,22):
			var x = -width*0.5+1+col*0.84
			G.rod(stand,Vector3(x,y+0.3,z),Vector3(x,y+1.15,z),0.025,frame)
			if row<5: G.rod(stand,Vector3(x,y+1.15,z),Vector3(x,y+1.78,z+0.95),0.025,frame)
	# Dark circulation voids and concrete piers give the upper deck depth.
	G.block(stand,Vector3(width,2,0.3),Vector3(0,base-1.8,start+0.6),charcoal)
	for x in range(-int(width/2)+4,int(width/2),14):
		G.block(stand,Vector3(0.45,base,0.6),Vector3(x,base*0.5,start),stone)
		var sign = label(stand,"%s %02d" % ["KALE" if is_end else "TRİBÜN",int((x+width/2)/14)+1],Vector3(x,base-0.03,start-2.72),0.008,Color("d4d7bf"))
		sign.rotation.y = PI
	# Closed outer elevation: plinth, glazing, repeated piers, and roof fascia.
	G.block(stand,Vector3(roof_width,6,0.45),Vector3(0,3,back),stone)
	G.block(stand,Vector3(roof_width,6,0.22),Vector3(0,9,back-0.05),glass)
	G.block(stand,Vector3(roof_width,1.1,0.4),Vector3(0,12.55,back),trim)
	for x in range(-int(roof_width/2),int(roof_width/2)+1,7):
		G.block(stand,Vector3(0.22,19.8,0.6),Vector3(x,9.9,back),frame)
		G.block(stand,Vector3(2.2,3.1,0.1),Vector3(x+2.1,1.55,back+0.28),charcoal)
	var depth = back-lip
	var inner_width = 94.0 if is_end else 130.0
	var panels = int(roof_width/7)
	roof.cull_mode = BaseMaterial3D.CULL_DISABLED
	var translucent = G.material(Color(0.4,0.55,0.53,0.22),0.6)
	translucent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	translucent.cull_mode = BaseMaterial3D.CULL_DISABLED
	translucent.disable_receive_shadows=true
	for i in range(panels):
		var t0 = float(i)/panels-0.5
		var t1 = float(i+1)/panels-0.5
		var a = Vector3(t0*inner_width,16,lip)
		var b = Vector3(t1*inner_width,16,lip)
		var c = Vector3(t0*roof_width,20,back)
		var d = Vector3(t1*roof_width,20,back)
		var e = a.lerp(c,3.5/depth)
		var f = b.lerp(d,3.5/depth)
		# Mitered corners meet on a shared hip, with no overlapping roof planes.
		var strip = roof_panel(stand,a,b,e,f,translucent)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		roof_panel(stand,e,f,c,d,roof)
		G.rod(stand,e,c,0.023,frame)
	# Triangular cantilever trusses, suspended entirely above the seating.
	var trusses = int(roof_width/14)
	for i in range(trusses+1):
		var t = float(i)/trusses-0.5
		var a = Vector3(t*inner_width,16,lip)
		var b = Vector3(t*roof_width,20,back)
		var c = Vector3(t*roof_width,17.9,back)
		G.rod(stand,a,b,0.085,frame)
		G.rod(stand,a,c,0.065,frame)
		for k in range(1,5):
			var fraction = k/4.0
			G.rod(stand,a.lerp(b,fraction),a.lerp(c,fraction),0.04,frame)
			G.rod(stand,a.lerp(c,(k-1)/4.0),a.lerp(b,fraction),0.035,frame)
	G.block(stand,Vector3(inner_width,0.55,0.22),Vector3(0,15.95,lip),trim)
	G.block(stand,Vector3(roof_width,0.7,0.35),Vector3(0,20.05,back),trim)
	# Roof-mounted luminaires replace isolated poles inside the bowl.
	for x in range(-int(width/2)+5,int(width/2),14):
		var light = G.block(stand,Vector3(2.5,0.35,0.65),Vector3(x,15.55,lip+0.8),charcoal)
		for i in range(4): G.block(light,Vector3(0.45,0.09,0.44),Vector3(-0.86+i*0.57,-0.2,0),lamp_glass)
		# Raised roof banks spread light across the turf at a steeper angle.
		if not is_end and x in [-37,33]:
			floodlight_bank(stand,x,lip)
	if is_end:
		scoreboard(stand,Vector3(0,12.8,lip+0.25))
		for x in [-5,5]: G.rod(stand,Vector3(x,15,lip+0.25),Vector3(x,16.1,lip+0.25),0.07,frame)
	var title = label(stand,"K I Y I   A R E N A",Vector3(0,15.3,back+0.37),0.034,Color("e5dfc8"))
	title.outline_size = 0
	title.double_sided = false

func floodlight_bank(stand: Node3D,x: float,lip: float) -> void:
	var head := Vector3(x,32,lip+0.8)
	G.rod(stand,Vector3(x,16,lip+2.8),head,0.14,frame)
	for side in [-1,1]:
		G.rod(stand,Vector3(x+side*2.4,16.3,lip+6),head+Vector3(0,-4,0),0.075,frame)
	var bank := Node3D.new()
	stand.add_child(bank)
	bank.position=head
	var target := Vector3(-signf(bank.global_position.x)*5,0,bank.global_position.z*0.28)
	bank.look_at(target)
	G.block(bank,Vector3(4.5,1.65,0.26),Vector3.ZERO,charcoal)
	for row in range(2):
		for column in range(6):
			G.block(bank,Vector3(0.58,0.56,0.05),Vector3(-1.75+column*0.7,-0.37+row*0.74,-0.17),lamp_glass)
	# Start beyond the glass, so the real emitter never shadows itself.
	floodlight_mounts.append(bank.global_position-bank.global_basis.z*0.24)

func roof_panel(parent: Node3D,a: Vector3,b: Vector3,c: Vector3,d: Vector3,mat: Material) -> MeshInstance3D:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [a,b,c,b,d,c]: surface.add_vertex(vertex)
	surface.generate_normals()
	return G.mesh(parent,surface.commit(),mat,Vector3.ZERO)

func corner(pos: Vector3) -> void:
	var core = Node3D.new()
	add_child(core)
	core.position = pos
	G.block(core,Vector3(7,12,8),Vector3(0,6,0),trim)
	G.block(core,Vector3(7.3,0.3,8.3),Vector3(0,12,0),frame)
	for y in [3,6,9]:
		G.block(core,Vector3(7.1,1.7,5.6),Vector3(0,y,0),glass)
		G.block(core,Vector3(7.6,0.24,8.6),Vector3(0,y-1,0),stone)

func player_tunnel() -> void:
	var tunnel = Node3D.new()
	add_child(tunnel)
	tunnel.name = "PlayerTunnel"
	var entrance_floor=G.block(tunnel,Vector3(12.3,0.03,5.4),Vector3(39.2,0.035,0),G.material(Color("334944")))
	entrance_floor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for z in [-3,3]: G.block(tunnel,Vector3(21,3.3,0.23),Vector3(49.15,1.65,z),trim)
	var tunnel_cover=stone.duplicate()
	tunnel_cover.disable_receive_shadows=true
	G.block(tunnel,Vector3(21,0.25,6.3),Vector3(49.15,3.38,0),tunnel_cover)
	G.block(tunnel,Vector3(0.15,3.3,6),Vector3(59.65,1.65,0),charcoal)
	G.block(tunnel,Vector3(0.26,0.6,6.6),Vector3(38.65,3.32,0),trim)
	var sign = label(tunnel,"KIYI ARENA",Vector3(38.49,3.32,0),0.015,Color("e5dfc8"))
	sign.rotation.y = -PI*0.5
	for x in [39.1,41.8,44.5]:
		for z in [-2.85,2.85]: G.block(tunnel,Vector3(0.1,0.08,0.1),Vector3(x,2.6,z),frame)

func scoreboard(parent: Node3D,pos: Vector3) -> void:
	var display = Node3D.new()
	parent.add_child(display)
	display.position = pos
	display.rotation.y = PI
	G.block(display,Vector3(13,4.5,0.4),Vector3.ZERO,trim)
	G.block(display,Vector3(12.5,4.0,0.08),Vector3(0,0,0.25),charcoal)
	team_captions.append(label(display,"KIYI       DEPLASMAN",Vector3(0,1.3,0.31),0.017,Color("a7c3c0")))
	score_labels.append(label(display,"0   :   0",Vector3(0,0.05,0.31),0.043,Color("f1ead5")))
	clock_labels.append(label(display,"00:00",Vector3(0,-1.35,0.31),0.016,Color("b3c8bc")))

func update_score(score: Array,seconds: float,duration: float) -> void:
	var total = int(clampf(seconds/duration,0,1)*90*60)
	var time = "%02d:%02d" % [total/60,total%60]
	var result = "%d   :   %d" % [score[0],score[1]]
	if display_text==result+time: return
	display_text = result+time
	for text in score_labels: text.text = result
	for text in clock_labels: text.text = time

func broadcast_positions() -> void:
	for x in [-33.4,33.4]:
		for z in [-44,44]:
			var pos = Vector3(x,1.35,z)
			for offset in [Vector3(-0.42,-1.3,0.3),Vector3(0.42,-1.3,0.3),Vector3(0,-1.3,-0.45)]:
				G.rod(self,pos+offset,pos,0.025,charcoal)
			var camera = Node3D.new()
			add_child(camera)
			camera.position = pos
			camera.look_at(Vector3(0,1,z*0.6))
			G.block(camera,Vector3(0.45,0.33,0.7),Vector3.ZERO,charcoal)
			G.block(camera,Vector3(0.32,0.26,0.25),Vector3(0,0,-0.45),trim)

func exterior() -> void:
	for side in [-1,1]:
		for x in range(-56,57,14):
			G.block(self,Vector3(0.35,0.9,0.35),Vector3(x,0.1,side*91),trim)
		for z in range(-70,71,14):
			G.block(self,Vector3(0.35,0.9,0.35),Vector3(side*72,0.1,z),trim)
		# Low planted beds frame the forecourt without hiding the building.
		for x in [-47,47]:
			G.block(self,Vector3(19,0.7,4),Vector3(x,-0.12,side*96),stone)
			G.block(self,Vector3(18.5,0.75,3.5),Vector3(x,0.52,side*96),hedge)
	cityscape()

func cityscape() -> void:
	district=preload("res://scripts/stadium_district.gd").new()
	add_child(district)
	district.build()
	city_blocks=district.building_count

func label(parent: Node3D,text: String,pos: Vector3,pixel: float,color: Color) -> Label3D:
	var node = Label3D.new()
	node.text = text
	node.font_size = 64
	node.pixel_size = pixel
	node.modulate = color
	node.outline_size = 0
	parent.add_child(node)
	node.position = pos
	return node
