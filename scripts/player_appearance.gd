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

static func choice(identity: int,salt: int,count: int) -> int:
	var value: int=posmod(identity,2147483647)
	value=((value ^ 0x45d9f3b)*1103515245+salt*12345)&0x7fffffff
	value=((value ^ (value>>16))*1103515245+12345)&0x7fffffff
	return value%count

static func profile(identity: int) -> Dictionary:
	return {"skin":choice(identity,11,SKIN_TONES.size()),"eyes":[0,0,0,1,1,2,2,2,3,3,4,4][choice(identity,37,12)],"boots":choice(identity,83,BOOT_COLORS.size())}

static func boot_mesh(style: int) -> ArrayMesh:
	if boot_cache.has(style): return boot_cache[style]
	# Keep the original boot shape/contact points and one draw per foot. Vertex
	# colours provide the upper, sole and inset side accent without extra pieces.
	var sphere:=SphereMesh.new(); sphere.radius=.115; sphere.height=.23
	sphere.radial_segments=16; sphere.rings=8
	var arrays:=sphere.surface_get_arrays(0)
	var colors:=PackedColorArray()
	var upper: Color=BOOT_COLORS[style][0]; var accent: Color=BOOT_COLORS[style][1]
	for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var color:=upper
		if point.y<-.046: color=Color("242b32")
		elif absf(point.x)>.077 and point.y<.051 and point.z>-.070 and point.z<.054:
			color=accent
		elif point.y>.076 and point.z<-.025 and point.z>-.077:
			color=upper.lerp(accent,.35)
		# Vertex colours are linear; the hand-picked palette above is sRGB.
		colors.append(color.srgb_to_linear())
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	boot_cache[style]=mesh
	return mesh
