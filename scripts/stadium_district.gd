extends Node3D
## The arena's surrounding neighbourhood. Geometry is baked by city block;
## only the small traffic fleet changes transforms while the menu is visible.
const Bake = preload("res://scripts/district_geometry.gd")
const ROAD := Color("343e40")
const PAVING := Color("898a7b")
const EDGE := Color("b3b3a0")
const MARK := Color("cecbb5")
const GLASS := Color("42616b")
const METAL := Color("566569")
const DARK := Color("293c40")
const WARM := Color("ffcf83")
const PAINT := [Color("d6d8cd"),Color("576d7d"),Color("a14b40"),Color("d6ac53"),Color("3e5654"),Color("89999c"),Color("c4bca7")]
var bake := Bake.new()
var materials: Dictionary = {}
var traffic := Node3D.new()
var routes: Array[Curve3D] = []
var vehicles: Array[Dictionary] = []
var light_pools: Array[MeshInstance3D] = []
var glow := ShaderMaterial.new()
var buildings: Array[Rect2] = []
var building_count := 0
var parked_count := 0
var tree_count := 0
var lamp_count := 0
var people_count := 0
var mesh_count := 0
var detail_count := 0
var night := false
var traffic_time := 0.0
var body_transform := Transform3D.IDENTITY

func build() -> void:
	name="StadiumDistrict"
	var solid := StandardMaterial3D.new()
	solid.vertex_color_use_as_albedo=true
	solid.vertex_color_is_srgb=true
	solid.roughness=0.87
	glow.shader=preload("res://shaders/district_glow.gdshader")
	var pool := ShaderMaterial.new(); pool.shader=preload("res://shaders/district_light_pool.gdshader")
	materials={"solid":solid,"flat":solid,"glow":glow,"pool":pool}
	streets()
	neighbourhood()
	forecourt()
	parking()
	street_furniture()
	detail_count=bake.part_count
	var nodes := bake.finish(self,materials)
	mesh_count=nodes.size()
	for node in nodes:
		if node.material_override==pool: light_pools.append(node)
	traffic.name="StreetTraffic"; add_child(traffic)
	create_traffic()
	set_night(false)

func box(size: Vector3,at: Vector3,color: Color,kind: String="solid",angle: float=0) -> void:
	bake.add("box",body_transform*Transform3D(Basis(Vector3.UP,angle).scaled_local(size),at),color,kind)

func round_shape(shape: String,size: Vector3,at: Vector3,color: Color,kind: String="solid") -> void:
	bake.add(shape,body_transform*Transform3D(Basis.from_scale(size),at),color,kind)

func streets() -> void:
	box(Vector3(790,0.1,850),Vector3(0,-1.06,0),Color("59684f"),"flat")
	# Continuous streets form real intersections. Buildings start outside curbs.
	for side in [-1,1]:
		for x in [side*109.0,side*184.0]:
			box(Vector3(24,0.16,680),Vector3(x,-0.92,0),PAVING,"flat")
			box(Vector3(16,0.04,680),Vector3(x,-0.81,0),ROAD,"flat")
		for z in [side*125.0,side*202.0]:
			box(Vector3(740,0.16,24),Vector3(0,-0.92,z),PAVING,"flat")
			box(Vector3(740,0.04,16),Vector3(0,-0.79,z),ROAD,"flat")
		for x in [side*109.0,side*184.0]:
			for z in range(-324,325,8):
				if absf(absf(z)-125)<13 or absf(absf(z)-202)<13: continue
				box(Vector3(0.17,0.014,3.8),Vector3(x,-0.779,z),MARK,"flat")
				for edge in [-1,1]: box(Vector3(0.22,0.09,7.9),Vector3(x+edge*8.15,-0.765,z),EDGE,"flat")
		for z in [side*125.0,side*202.0]:
			for x in range(-352,353,8):
				if absf(absf(x)-109)<13 or absf(absf(x)-184)<13: continue
				box(Vector3(3.8,0.014,0.17),Vector3(x,-0.755,z),MARK,"flat")
				for edge in [-1,1]: box(Vector3(7.9,0.09,0.22),Vector3(x,-0.745,z+edge*8.15),EDGE,"flat")
	for x in [-109,109]:
		for z in [-125,125]:
			for side in [-1,1]:
				for stripe in range(-5,6,2):
					box(Vector3(0.95,0.014,3),Vector3(x+stripe,-0.745,z+side*10.1),MARK,"flat")
					box(Vector3(3,0.014,0.95),Vector3(x+side*10.1,-0.745,z+stripe),MARK,"flat")
	# Approach walks and a planted boulevard outside the stadium footprint.
	for side in [-1,1]:
		box(Vector3(178,0.15,14),Vector3(0,-0.65,side*104),PAVING,"flat")
		box(Vector3(13,0.15,204),Vector3(side*85,-0.65,0),PAVING,"flat")
		for i in range(-8,9):
			box(Vector3(0.12,0.014,13),Vector3(i*10,-0.566,side*104),EDGE,"flat")
			box(Vector3(12,0.014,0.12),Vector3(side*85,-0.566,i*11),EDGE,"flat")

func neighbourhood() -> void:
	# Close blocks have individual shops, recessed windows and roof machinery.
	for side in [-1,1]:
		for i in range(5):
			var along := -80.0+i*40
			building(Vector3(along,-0.72,side*151),Vector2(27+(i%2)*4,25),3+(i%3) if side<0 else 2+(i%2),i%4,PI if side>0 else 0)
			building(Vector3(side*147,-0.72,along),Vector2(28,27),4+(i%3) if side<0 else 3+(i%2), (i+2)%4,-side*PI*0.5)
		# Corner hotels/offices anchor the blocks, with a clear view into the arena.
		for other in [-1,1]:
			building(Vector3(side*148,-0.72,other*151),Vector2(32,29),5 if side<0 or other<0 else 3,3,0)
		# A second street creates depth, without a wall of tall buildings in front.
		for i in range(7):
			var along: float=[-272,-154,-56,0,56,154,272][i]
			building(Vector3(along,-0.72,side*237),Vector2(36,35),6+i%4 if side<0 else 3+i%3,(i+1)%4,PI if side>0 else 0)
			building(Vector3(side*224,-0.72,along),Vector2(36,34),7+i%3 if side<0 else 3+i%3,i%4,-side*PI*0.5)
	for side in [-1,1]:
		for x in range(-80,81,20):
			tree(Vector3(x,-0.72,side*172),1.1)
		for z in range(-90,91,22): tree(Vector3(side*168,-0.72,z),1.05)

func building(at: Vector3,footprint: Vector2,floors: int,style: int,angle: float) -> void:
	var previous := body_transform
	body_transform=Transform3D(Basis(Vector3.UP,angle),at)
	var w := footprint.x; var d := footprint.y
	var height := 3.7+floors*3.15
	var wall: Color=[Color("b3a28a"),Color("956f5a"),Color("b7b8a6"),Color("758b89")][style]
	box(Vector3(w,height,d),Vector3(0,height*0.5,0),wall)
	box(Vector3(w+0.6,3.4,d+0.6),Vector3(0,1.7,0),DARK)
	for edge in [-1,1]:
		box(Vector3(w+0.9,0.35,0.45),Vector3(0,height+0.12,edge*d*0.5),EDGE)
		box(Vector3(0.45,0.35,d+0.9),Vector3(edge*w*0.5,height+0.12,0),EDGE)
	box(Vector3(w-0.3,0.16,d-0.3),Vector3(0,height+0.01,0),Color("657170"))
	for floor_index in range(floors):
		var y := 4.1+floor_index*3.15
		for face in range(4):
			var width := w if face%2==0 else d
			var normal := Vector3(0,0,1).rotated(Vector3.UP,face*PI*0.5)
			var tangent := Vector3.RIGHT.rotated(Vector3.UP,face*PI*0.5)
			var depth := d if face%2==0 else w
			var count := int((width-2)/3.4)
			for column in range(count):
				var position := tangent*((column-(count-1)*0.5)*3.4)+normal*(depth*0.5+0.025)+Vector3(0,y+0.6,0)
				var lit := posmod(column*7+floor_index*13+building_count*3+face,7)<3
				var rotation := face*PI*0.5
				box(Vector3(2.0,2.1,0.13),position,DARK,"flat",rotation)
				box(Vector3(1.68,1.78,0.035),position+normal*0.09,WARM if lit else GLASS,"glow" if lit else "flat",rotation)
				box(Vector3(0.07,1.85,0.08),position+normal*0.12,wall.lightened(0.12),"flat",rotation)
				if style==1 and floor_index<4 and column%2==0:
					box(Vector3(2.75,0.17,1.2),position+normal*0.6+Vector3(0,-1.13,0),EDGE,"solid",rotation)
					box(Vector3(2.6,0.72,0.08),position+normal*1.16+Vector3(0,-0.68,0),METAL,"flat",rotation)
			if style in [0,2,3]:
				box(Vector3(width+0.12,0.16,0.3),normal*(depth*0.5+0.1)+Vector3(0,y-0.7,0),EDGE,"flat",face*PI*0.5)
	# Street-level shopfronts with columns, awnings and warm transoms.
	for i in range(int(w/6)):
		var x := -w*0.5+3.4+i*6
		box(Vector3(4.5,2.5,0.12),Vector3(x,1.45,d*0.5+0.38),GLASS,"flat")
		box(Vector3(0.13,2.6,0.16),Vector3(x,1.45,d*0.5+0.5),EDGE,"flat")
		box(Vector3(5.0,0.48,0.25),Vector3(x,3.05,d*0.5+0.45),Color("b8985b") if i%2==0 else Color("536f65"),"flat")
		box(Vector3(4.9,0.12,2),Vector3(x,2.85,d*0.5+1),Color("bdaf8b") if i%2==0 else Color("416866"))
		box(Vector3(3.6,0.13,0.06),Vector3(x,2.25,d*0.5+0.52),WARM,"glow")
	# Rooftops are prominent from this camera: stair access, AC units and panels.
	box(Vector3(4.2,2.2,3.8),Vector3(-w*0.28,height+1.1,-d*0.25),wall.darkened(0.12))
	box(Vector3(4.5,0.25,4.1),Vector3(-w*0.28,height+2.3,-d*0.25),EDGE)
	for i in range(2+style%2):
		var p := Vector3(2.5+i*3.2,height+0.5,-d*0.27)
		box(Vector3(2.1,0.9,1.65),p,Color("abb4ae"))
		round_shape("round",Vector3(0.56,0.05,0.56),p+Vector3(0,0.48,0),DARK,"flat")
	if style%2==0:
		for i in range(3):
			box(Vector3(3.3,0.18,2.1),Vector3(-4+i*4,height+0.38,d*0.17),Color("263f55"))
			box(Vector3(0.07,0.03,2.1),Vector3(-4+i*4,height+0.49,d*0.17),METAL,"flat")
	else:
		round_shape("round",Vector3(1.0,1.2,1.0),Vector3(w*0.29,height+0.6,d*0.22),Color("94a4a5"))
	building_count+=1
	var span := footprint if is_zero_approx(sin(angle)) else Vector2(footprint.y,footprint.x)
	buildings.append(Rect2(Vector2(at.x,at.z)-span*0.5,span))
	body_transform=previous

func forecourt() -> void:
	for side in [-1,1]:
		# Entrance plaza paving, queues, ticket booths and small supporter groups.
		box(Vector3(39,0.12,15),Vector3(0,-0.47,side*98),Color("a5a390"),"flat")
		for x in [-26,26]:
			box(Vector3(6,2.9,3.3),Vector3(x,0.85,side*103),Color("52726d"))
			box(Vector3(6.8,0.25,4),Vector3(x,2.45,side*103),EDGE)
			box(Vector3(4.8,1.0,0.08),Vector3(x,1.15,side*101.3),GLASS,"flat")
		for x in range(-12,13,4):
			box(Vector3(0.08,0.8,4),Vector3(x,-0.05,side*96),METAL,"flat")
		for i in range(26):
			var x := -17.0+(i%9)*4.1+sin(i*2.7)*0.8
			var z: float=side*(94.0+(i/9)*4.3)+cos(i*1.3)
			person(Vector3(x,-0.35,z),i,side*PI*0.5)
		for z in range(-66,67,22):
			tree(Vector3(side*87,-0.49,z),0.95)
			bench(Vector3(side*81,-0.42,z+5),PI*0.5)
			for i in range(3): person(Vector3(side*(79.5+i*1.1),-0.4,z+8+i*0.6),i+z,0)
		for x in [-62,-45,45,62]:
			tree(Vector3(x,-0.48,side*106),0.95)
			bench(Vector3(x+4,-0.42,side*102),0)
	# Team coach bays on the eastern service approach, leaving the tunnel clear.
	for z in [-36,36]:
		box(Vector3(6.5,0.03,14),Vector3(94,-0.53,z),Color("444e4b"),"flat")
		car(Vector3(94,-0.49,z),0,Color("dddfd2"),true)
		parked_count+=1

func parking() -> void:
	for side in [-1,1]:
		for section in [-1,1]:
			var center := Vector3(section*59,-0.62,side*112)
			box(Vector3(63,0.04,7.6),center,ROAD,"flat")
			for i in range(20):
				var x := center.x-29+i*3.1
				box(Vector3(0.09,0.013,5.1),Vector3(x,-0.59,center.z),MARK,"flat")
				if i<19 and (i+section+side)%5!=0:
					car(Vector3(x+1.5,-0.55,center.z),0 if i%2==0 else PI,PAINT[posmod(i+section*2+side,PAINT.size())])
					parked_count+=1
	# Outer curb parking gives the neighbourhood a lived-in street edge.
	for side in [-1,1]:
		for z in range(-92,93,13):
			car(Vector3(side*115,-0.75,z),0,PAINT[posmod(z,PAINT.size())])
			parked_count+=1

func tree(at: Vector3,scale_value: float) -> void:
	round_shape("round",Vector3(2.7,0.2,2.7)*scale_value,at,Color("989e85"),"flat")
	round_shape("round",Vector3(2.4,0.05,2.4)*scale_value,at+Vector3(0,0.13,0),Color("4c613f"),"flat")
	round_shape("round",Vector3(0.19,3.3,0.19)*scale_value,at+Vector3(0,1.65,0)*scale_value,Color("655640"))
	for entry in [[Vector3(0,4.3,0),Vector3(2.2,2.35,2.0),Color("526f44")],[Vector3(1.0,3.5,0.4),Vector3(1.8,1.7,1.7),Color("657e4a")],[Vector3(-1.1,3.3,-0.3),Vector3(1.6,1.9,1.6),Color("405d3f")]]:
		round_shape("crown",entry[1]*scale_value,at+entry[0]*scale_value,entry[2])
	tree_count+=1

func bench(at: Vector3,angle: float) -> void:
	var previous := body_transform; body_transform=Transform3D(Basis(Vector3.UP,angle),at)
	box(Vector3(2.5,0.13,0.65),Vector3(0,0.52,0),Color("947550"))
	box(Vector3(2.5,0.42,0.09),Vector3(0,0.85,0.32),Color("947550"))
	for x in [-0.9,0.9]: box(Vector3(0.12,0.5,0.55),Vector3(x,0.25,0),METAL)
	body_transform=previous

func person(at: Vector3,index: int,angle: float) -> void:
	var previous := body_transform; body_transform=Transform3D(Basis(Vector3.UP,angle),at)
	var shirt: Color=[Color("e2dfcc"),Color("27635e"),Color("bf9c54"),Color("7c514b")][posmod(index,4)]
	box(Vector3(0.48,0.65,0.28),Vector3(0,1.1,0),shirt)
	round_shape("crown",Vector3(0.18,0.23,0.18),Vector3(0,1.62,0),Color("c5a183"))
	for side in [-1,1]:
		box(Vector3(0.16,0.65,0.18),Vector3(side*0.14,0.43,side*0.1),DARK)
		box(Vector3(0.13,0.57,0.14),Vector3(side*0.32,1.01,-side*0.1),shirt)
	body_transform=previous; people_count+=1

func street_furniture() -> void:
	for side in [-1,1]:
		for z in range(-95,96,30): lamp(Vector3(side*99,-0.65,z),-side*PI*0.5)
		for x in range(-85,86,28): lamp(Vector3(x,-0.65,side*136),PI if side>0 else 0)
		# Sheltered bus stops with glass sides, benches and route boards.
		var at := Vector3(side*98,-0.6,70)
		for x in [-3,3]: box(Vector3(0.15,2.8,0.15),at+Vector3(x,1.4,0),METAL)
		box(Vector3(6.6,0.18,2.8),at+Vector3(0,2.9,0.6),Color("66817b"))
		box(Vector3(6,2.2,0.07),at+Vector3(0,1.65,1.9),GLASS,"flat")
		bench(at+Vector3(0,0,1.0),0)
		box(Vector3(0.55,2.5,0.18),at+Vector3(3.8,1.25,0),Color("d2b674"))
		for i in range(4): person(at+Vector3(i*1.2-2,0,-0.8),i,0)
		for x in [-22,22]:
			box(Vector3(0.12,6,0.12),Vector3(x,2.4,side*99),METAL)
			box(Vector3(1.1,3.2,0.08),Vector3(x+0.6,3.6,side*99),Color("346a64"))
			box(Vector3(0.2,3.2,0.09),Vector3(x+0.25,3.6,side*99),Color("d8ca9f"))
	for side in [-1,1]:
		for x in [-60,-20,20,60]:
			for i in range(3): person(Vector3(x+i*1.2,-0.72,side*138),i+x,PI)

func lamp(at: Vector3,angle: float) -> void:
	var previous := body_transform; body_transform=Transform3D(Basis(Vector3.UP,angle),at)
	box(Vector3(0.18,6.2,0.18),Vector3(0,3.1,0),METAL)
	box(Vector3(0.14,0.15,2.4),Vector3(0,6.1,1.1),METAL)
	box(Vector3(0.68,0.18,1.1),Vector3(0,6.02,2.2),DARK)
	box(Vector3(0.5,0.05,0.85),Vector3(0,5.92,2.2),WARM,"glow")
	round_shape("plane",Vector3(13,1,13),Vector3(0,-0.07,2.6),WARM,"pool")
	body_transform=previous; lamp_count+=1

func car(at: Vector3,angle: float,color: Color,coach: bool=false) -> void:
	var previous := body_transform; body_transform=Transform3D(Basis(Vector3.UP,angle),at)
	var length := 10.5 if coach else 4.4
	var width := 2.65 if coach else 1.8
	box(Vector3(width,0.65,length),Vector3(0,0.64,0),color)
	box(Vector3(width*0.86,1.55 if coach else 0.61,length*0.72),Vector3(0,1.6 if coach else 1.24,0.15),GLASS)
	box(Vector3(width*0.9,0.13,length*0.69),Vector3(0,2.42 if coach else 1.58,0.15),color)
	for side in [-1,1]:
		for axle in [-1,1]:
			var tire := Transform3D(Basis(Vector3.FORWARD,PI*0.5).scaled_local(Vector3(0.39,0.18,0.39)),Vector3(side*width*0.51,0.4,axle*length*0.32))
			bake.add("round",body_transform*tire,Color("252e30"))
			box(Vector3(0.33,0.19,0.05),Vector3(side*width*0.32,0.77,-length*0.505),Color("fff1bb"),"glow")
			box(Vector3(0.29,0.17,0.05),Vector3(side*width*0.32,0.75,length*0.505),Color("f2704f"),"glow")
		box(Vector3(0.075,0.65 if not coach else 1.5,0.13),Vector3(side*width*0.44,1.25 if not coach else 1.65,0.28),color)
		if coach:
			for z in range(-3,4,2): box(Vector3(0.08,1.5,0.13),Vector3(side*width*0.44,1.65,z),color)
	box(Vector3(width*0.86,0.13,0.1),Vector3(0,0.4,-length*0.51),METAL)
	body_transform=previous

func make_route(x: float,z: float,radius: float) -> Curve3D:
	var curve := Curve3D.new(); curve.bake_interval=1.0
	var k := radius*0.55228475
	# Clockwise loop, with cubic corners instead of teleporting at intersections.
	var points := [Vector3(-x+radius,-0.74,-z),Vector3(x-radius,-0.74,-z),Vector3(x,-0.74,-z+radius),Vector3(x,-0.74,z-radius),Vector3(x-radius,-0.74,z),Vector3(-x+radius,-0.74,z),Vector3(-x,-0.74,z-radius),Vector3(-x,-0.74,-z+radius)]
	var tangents := [Vector3.RIGHT,Vector3.RIGHT,Vector3.BACK,Vector3.BACK,Vector3.LEFT,Vector3.LEFT,Vector3.FORWARD,Vector3.FORWARD]
	for i in range(points.size()): curve.add_point(points[i],-tangents[i]*k,tangents[i]*k)
	curve.add_point(points[0],-tangents[0]*k,tangents[0]*k)
	return curve

func create_traffic() -> void:
	routes=[make_route(106,122,12),make_route(112,128,12)]
	# Seven shared car models, each with two material surfaces; moving cars don't
	# join the stadium's static bake. All their sub-parts move as one rigid model.
	var parked_bake := bake
	var prototypes: Array[Array] = []
	for color in PAINT:
		bake=Bake.new(); bake.cell_size=0
		car(Vector3.ZERO,0,color)
		var holder := Node3D.new()
		var pieces := bake.finish(holder,materials)
		var meshes: Array=[]
		for piece in pieces: meshes.append([piece.mesh,piece.material_override])
		prototypes.append(meshes)
		holder.free()
	bake=parked_bake
	for lane in range(2):
		for i in range(14):
			var vehicle := Node3D.new(); vehicle.name="TrafficCar%d_%d" % [lane,i]; traffic.add_child(vehicle)
			for piece in prototypes[(i+lane*3)%prototypes.size()]:
				var part := MeshInstance3D.new(); part.mesh=piece[0]; part.material_override=piece[1]; part.layers=2
				part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				vehicle.add_child(part)
			vehicles.append({"node":vehicle,"lane":lane,"distance":i*routes[lane].get_baked_length()/14.0+lane*11})
	update_traffic(0,true)

func update_traffic(delta: float,overview: bool) -> void:
	traffic.visible=overview
	if not overview: return
	traffic_time+=delta
	for vehicle in vehicles:
		var lane: int=vehicle.lane
		var route: Curve3D=routes[lane]
		var distance := fposmod(vehicle.distance+traffic_time*(8.0 if lane==0 else -8.5),route.get_baked_length())
		var p := route.sample_baked(distance,true)
		var next := route.sample_baked(fposmod(distance+(0.8 if lane==0 else -0.8),route.get_baked_length()),true)
		vehicle.node.transform=Transform3D(Basis.looking_at((next-p).normalized()),p)

func set_night(value: bool) -> void:
	night=value
	glow.set_shader_parameter("night",1.0 if night else 0.0)
	for pool in light_pools: pool.visible=night
