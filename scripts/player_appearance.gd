extends RefCounted
## Stable cosmetic traits. Nationality and football attributes do not constrain them.
const SKIN_TONES := [Color("edc6ae"),Color("dfb08f"),Color("d59e77"),Color("c68e64"),Color("b87950"),Color("a76b48"),Color("8f5538"),Color("77432e"),Color("603724"),Color("482c23")]
# Width, opening, outer-corner tilt in radians. The inner form is separate from
# the animated eye pivot, so looking at the ball never resets a player's shape.
const EYE_FORMS := [Vector3(1.00,1.00,.015),Vector3(.94,1.24,0),Vector3(1.10,.90,.045),Vector3(1.05,.66,.055),Vector3(1.06,.84,.105)]
const EYE_NAMES := ["Oval","Yuvarlak","Badem","Dar kapaklı","Yukarı eğimli"]
const BOOT_NAMES := ["Siyah / beyaz","Beyaz / altın","Kırmızı / beyaz","Mavi / buz","Turkuaz / lacivert","Limon / siyah","Sarı / siyah","Turuncu / lacivert","Pembe / koyu mor","Mor / beyaz","Lacivert / mercan","Antrasit / bakır"]
const BOOT_COLORS := [
	[Color("202429"),Color("eef0eb")],[Color("e6e9df"),Color("b99a55")],
	[Color("db4138"),Color("f5ece3")],[Color("3174c5"),Color("b6e2e8")],
	[Color("39b8ad"),Color("183e52")],[Color("abd543"),Color("242c30")],
	[Color("e6c74b"),Color("252d35")],[Color("e77c39"),Color("25394c")],
	[Color("d86291"),Color("492d51")],[Color("8561b3"),Color("ecebe4")],
	[Color("273d63"),Color("df705a")],[Color("43474a"),Color("be936f")]]
static var boot_cache: Dictionary={}
# Local coordinates keep the existing ankle/contact anchor and sole height.
# Each section is (longitudinal Z, half-width, upper height). A lower toe box
# rises into the instep, then a narrower heel cup instead of an ellipsoid.
const BOOT_SECTIONS := [
	Vector3(-.110,.006,-.054),Vector3(-.108,.015,-.040),Vector3(-.099,.050,-.020),
	Vector3(-.080,.083,-.012),Vector3(-.045,.098,.009),
	Vector3(-.006,.094,.045),Vector3(.025,.082,.080),
	Vector3(.050,.072,.083),Vector3(.074,.071,.072),
	Vector3(.087,.058,.038),Vector3(.091,.032,.010)]
const BOOT_SECTORS := 16
const BOOT_SOLE_Y := -.115
const BOOT_OUTSOLE_Y := -.101
const BOOT_SOLE_TOP := -.079

static func choice(identity: int,salt: int,count: int) -> int:
	var value: int=posmod(identity,2147483647)
	value=((value ^ 0x45d9f3b)*1103515245+salt*12345)&0x7fffffff
	value=((value ^ (value>>16))*1103515245+12345)&0x7fffffff
	return value%count

static func profile(identity: int) -> Dictionary:
	return {"skin":choice(identity,11,SKIN_TONES.size()),"eyes":[0,0,0,1,1,2,2,2,3,3,4,4][choice(identity,37,12)],"boots":choice(identity,83,BOOT_COLORS.size()),
		"jaw":choice(identity,97,5),"nose":choice(identity,109,5),"brow":choice(identity,127,4),"beard":choice(identity,149,6),
		"face":choice(identity,163,5),"iris":choice(identity,181,5),"movement":choice(identity,193,4),"celebration":choice(identity,211,8)}

static func boot_mesh(style: int) -> ArrayMesh:
	if boot_cache.has(style): return boot_cache[style]
	# All colourways share the same fitted shell and remain one surface per foot.
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var upper: Color=BOOT_COLORS[style][0]; var accent: Color=BOOT_COLORS[style][1]
	var points: Array[Vector3]=[]
	for row in range(BOOT_SECTIONS.size()):
		var section: Vector3=BOOT_SECTIONS[row]
		for sector in range(BOOT_SECTORS+1):
			var angle:=TAU*sector/BOOT_SECTORS
			var arch:=cos(angle)
			var y:=lerpf(BOOT_SOLE_TOP,section.z,pow(maxf(arch,0),.78)) if arch>=0 else lerpf(BOOT_SOLE_TOP,BOOT_OUTSOLE_Y,minf(-arch/.38,1))
			var point:=Vector3(sin(angle)*section.y,y,section.x)
			points.append(point)
			var color:=upper
			if arch<0: color=Color("242b32")
			elif (row==4 and sector in [3,13]) or (row==5 and sector in [2,14]): color=accent
			elif row in [5,6,7] and sector in [0,1,15,16]: color=upper.darkened(.20)
			elif row>=9: color=upper.darkened(.12)
			surface.set_color(color.srgb_to_linear())
			surface.set_uv(Vector2(float(sector)/BOOT_SECTORS,float(row)/(BOOT_SECTIONS.size()-1)))
			surface.add_vertex(point)
	var columns:=BOOT_SECTORS+1
	for row in range(BOOT_SECTIONS.size()-1):
		for sector in range(BOOT_SECTORS):
			var a:=row*columns+sector
			for index in [a,a+1,a+columns,a+1,a+columns+1,a+columns]: surface.add_index(index)
	# Close toe and heel with separate smoothing groups; neither end is a sphere.
	for end in range(2):
		var row:=0 if end==0 else BOOT_SECTIONS.size()-1
		var first:=points.size()+end*(columns+1)
		surface.set_smooth_group(end+1)
		for sector in range(columns):
			var point:=points[row*columns+sector]
			surface.set_color((Color("242b32") if point.y<BOOT_SOLE_TOP else upper.darkened(.12)).srgb_to_linear())
			surface.set_uv(Vector2.ZERO); surface.add_vertex(point)
		surface.set_color(upper.darkened(.12).srgb_to_linear())
		surface.add_vertex(Vector3(0,(BOOT_SECTIONS[row].z+BOOT_OUTSOLE_Y)*.5,BOOT_SECTIONS[row].x))
		for sector in range(BOOT_SECTORS):
			var triangle: Array=[first+columns,first+sector+1,first+sector] if end==0 else [first+columns,first+sector,first+sector+1]
			for index in triangle: surface.add_index(index)
	var first:=points.size()+2*(columns+1)
	# Small, flat-ended studs retain the original turf contact height. They are
	# baked into the same mesh, without additional nodes or material passes.
	for z in [-.058,-.010,.060]:
		for side in [-1,1]:
			var x: float=side*(.042 if z>0 else .056)
			surface.set_smooth_group(3)
			for level in range(2):
				for sector in range(6):
					var angle:=sector*TAU/6; var radius:=1.0 if level==0 else .78
					surface.set_color(Color("323b40").srgb_to_linear()); surface.set_uv(Vector2.ZERO)
					surface.add_vertex(Vector3(x+sin(angle)*.014*radius,BOOT_OUTSOLE_Y if level==0 else BOOT_SOLE_Y,z+cos(angle)*.007*radius))
			for sector in range(6):
				var next: int=(sector+1)%6
				for index in [first+sector,first+next,first+6+sector,first+next,first+6+next,first+6+sector]: surface.add_index(index)
			surface.set_smooth_group(4)
			for sector in range(6):
				var angle:=sector*TAU/6
				surface.add_vertex(Vector3(x+sin(angle)*.014*.78,BOOT_SOLE_Y,z+cos(angle)*.007*.78))
			surface.add_vertex(Vector3(x,BOOT_SOLE_Y,z))
			for sector in range(6):
				for index in [first+18,first+12+sector,first+12+(sector+1)%6]: surface.add_index(index)
			first+=19
	# Three short lace bars follow the instep. Geometry keeps their edges clean
	# at close range while the vertex palette supplies each colourway's tint.
	for z in [-.002,.010,.022]:
		surface.set_smooth_group(5)
		for corner in [Vector2(-1,-1),Vector2(0,-1),Vector2(1,-1),Vector2(-1,1),Vector2(0,1),Vector2(1,1)]:
			var at: float=z+corner.y*.0015
			var amount:=inverse_lerp(-.006,.025,at)
			var width:=lerpf(.094,.082,amount); var top:=lerpf(.045,.080,amount)
			var x: float=corner.x*.022
			var y:=lerpf(BOOT_SOLE_TOP,top,pow(sqrt(1-pow(x/width,2)),.78))+.001
			surface.set_color(accent.lerp(upper,.25).srgb_to_linear()); surface.set_uv(Vector2.ZERO)
			surface.add_vertex(Vector3(x,y,at))
		for index in [first,first+1,first+3,first+1,first+4,first+3,first+1,first+2,first+4,first+2,first+5,first+4]: surface.add_index(index)
		first+=6
	surface.generate_normals()
	var mesh:=surface.commit()
	boot_cache[style]=mesh
	return mesh
