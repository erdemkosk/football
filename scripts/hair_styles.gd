extends RefCounted
## Cached silhouettes: one mesh/draw per head, including braids and curls.
const NAMES := ["Kısa kesim","Kısa dokulu","Öne kabarık","Yana ayrık","Dik saç","Kıvırcık","Afro","Düz üst","Mohawk","Örgü","Kısa burgu","Uzun burgu","Topuz","At kuyruğu","Dağınık uzun","Dalgalı","Kıvırcık üst","Geri taralı"]
const COLORS := [Color("171816"),Color("29221e"),Color("483526"),Color("785332"),Color("b9955f"),Color("bda67e"),Color("763f2d")]
static var cache: Dictionary={}
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var indices:=PackedInt32Array()

static func style_for(identity: int) -> int:
	return posmod(identity*7+identity/18, NAMES.size())

static func color_for(identity: int) -> Color:
	return COLORS[posmod(identity*13+identity/7,COLORS.size())]

func append(shape: Mesh,at: Vector3,scale_value: Vector3=Vector3.ONE,rotation: Vector3=Vector3.ZERO) -> void:
	var data:=shape.surface_get_arrays(0)
	var basis:=Basis.from_euler(rotation).scaled(scale_value)
	var normal_basis:=basis.inverse().transposed()
	var base:=vertices.size()
	for v in data[Mesh.ARRAY_VERTEX]: vertices.append(basis*v+at)
	for n in data[Mesh.ARRAY_NORMAL]: normals.append((normal_basis*n).normalized())
	for i in data[Mesh.ARRAY_INDEX]: indices.append(base+i)

func tuft(at: Vector3,scale_value: Vector3,rotation: Vector3=Vector3.ZERO) -> void:
	var sphere:=SphereMesh.new(); sphere.radius=1; sphere.height=2; sphere.radial_segments=8; sphere.rings=4
	append(sphere,at,scale_value,rotation)

func strand(a: Vector3,b: Vector3,radius: float) -> void:
	var segment:=CylinderMesh.new(); segment.bottom_radius=radius*.85; segment.top_radius=radius
	segment.height=a.distance_to(b); segment.radial_segments=6
	var direction: Vector3=(b-a).normalized()
	var rotation:=Quaternion(Vector3.UP,direction).get_euler()
	append(segment,(a+b)*.5,Vector3.ONE,rotation)
	tuft(b,Vector3.ONE*radius)

static func model(style: int,scalp: ArrayMesh) -> ArrayMesh:
	if cache.has(style): return cache[style]
	var builder:=new()
	builder.foundation(style,scalp)
	builder.decorate(style)
	var data:=[]; data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX]=builder.vertices; data[Mesh.ARRAY_NORMAL]=builder.normals; data[Mesh.ARRAY_INDEX]=builder.indices
	var result:=ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
	cache[style]=result
	return result

func foundation(style: int,scalp: ArrayMesh) -> void:
	append(scalp,Vector3.ZERO)
	# Shape the whole cap first so swept, curly and flat cuts grow out of the
	# scalp instead of looking like disconnected ornaments balanced on top.
	for i in range(vertices.size()):
		var p:=vertices[i]
		var top:=smoothstep(.06,.23,p.y)
		match style:
			2:
				p.y+=top*(.028+clampf(-p.z/.20,0,1)*.055)
				p.z-=top*.025
			3:
				p.y+=top*(.025-clampf(p.x/.18,-1,1)*.019)
				p.x-=top*.014
			5: p*=Vector3(1.055,1.06,1.055)
			6: p*=Vector3(1.22,1.20,1.18)
			7: p.y=minf(.265,p.y*1.5)
			15: p.y+=top*(.029+sin(p.x*65)*.004)
			17: p.y+=top*.018; p.z+=top*.018
		vertices[i]=p

func decorate(style: int) -> void:
	match style:
		0,7: pass
		1:
			for i in range(9): tuft(Vector3(sin(i*2.4)*.09,.214+float(i%2)*.008,cos(i*2.4)*.075),Vector3(.062,.040,.059))
		2:
			for i in range(5): tuft(Vector3((i-2)*.042,.226,-.073),Vector3(.041,.057,.124),Vector3(-.20,0,-.14))
		3:
			for i in range(5): tuft(Vector3(-.09+i*.042,.217-float(i)*.005,-.014),Vector3(.048,.047,.150),Vector3(0,0,.20))
		4:
			for i in range(11):
				var around: float=i*2.4
				var root:=Vector3(sin(around)*.11,.204,cos(around)*.08)
				var spike:=CylinderMesh.new(); spike.bottom_radius=.037; spike.top_radius=.003; spike.height=.073+float(i%3)*.008; spike.radial_segments=6
				append(spike,root+Vector3(0,.038,0),Vector3.ONE,Vector3(-.18,0,sin(around)*-.20))
		5,6,16:
			var afro: bool=style==6
			var rows: int=4 if afro else (3 if style==5 else 2)
			for ring in range(rows):
				var angle: float=.18+ring*.30
				var count: int=6+ring*5
				for i in range(count):
					var around: float=i*TAU/count+ring*.26
					var normal:=Vector3(sin(angle)*sin(around),cos(angle),-sin(angle)*cos(around))
					var radius:=Vector3(.232,.291,.228) if afro else Vector3(.191,.247,.201)
					tuft(normal*radius,Vector3.ONE*(.043 if afro else .028))
		8:
			for i in range(6): tuft(Vector3(0,.19+sin(i*PI/6)*.064,-.14+i*.055),Vector3(.038,.067,.055))
		9:
			for row in range(5):
				var x: float=(row-2)*.052
				for i in range(7):
					var z: float=-.13+i*.040
					var a:=Vector3(x,sqrt(maxf(.02,1-pow(x/.186,2)-pow(z/.198,2)))*.241+.005,z)
					var b:=Vector3(x,sqrt(maxf(.02,1-pow(x/.186,2)-pow((z+.04)/.198,2)))*.241+.005,z+.04)
					strand(a,b,.012)
		10,11:
			for i in range(16):
				var around: float=i*TAU/16
				var a:=Vector3(sin(around)*.105,.192,-cos(around)*.11)
				var b:=Vector3(sin(around)*(.20 if style==11 else .132),.105 if style==11 else .265,-cos(around)*(.21 if style==11 else .13))
				strand(a,b,.023)
			for i in range(5): strand(Vector3((i-2)*.034,.224,.013),Vector3((i-2)*.04,.274,.041),.020)
			if style==11:
				for i in range(5): strand(Vector3((i-2)*.061,.12,.16),Vector3((i-2)*.066,-.17,.19),.027)
		12:
			tuft(Vector3(0,.17,.105),Vector3(.156,.084,.123))
			tuft(Vector3(0,.17,.215),Vector3(.075,.070,.069))
		13:
			tuft(Vector3(0,.13,.175),Vector3(.10,.085,.079))
			strand(Vector3(0,.10,.23),Vector3(.035,-.18,.265),.048)
		14:
			for side in [-1,1]:
				tuft(Vector3(side*.166,.015,.04),Vector3(.035,.165,.13))
			for i in range(5): tuft(Vector3((i-2)*.055,.186,-.135),Vector3(.056,.048,.094),Vector3(0,0,-.2))
			tuft(Vector3(0,-.045,.166),Vector3(.165,.15,.051))
		15:
			for i in range(6): tuft(Vector3(-.10+i*.040,.224-float(i%2)*.01,.004),Vector3(.045,.039,.151),Vector3(.10,0,-.23))
		17:
			for i in range(5): tuft(Vector3((i-2)*.045,.213,.04),Vector3(.035,.042,.168),Vector3(.16,0,0))
