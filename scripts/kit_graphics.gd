extends RefCounted
## All print lives in the jersey's UVs. No floating planes or decal draw calls.
static var shirts: Dictionary = {}
static var badges: Dictionary = {}
static var torso: ArrayMesh
const SHORTS := ["KIY","ATL","DEM","GÜN","ORM","KUZ","LİM","KAP"]
const SYMBOLS := [
	'<path d="M26 51Q38 40 50 51T74 51M26 65Q38 54 50 65T74 65" fill="none" stroke="currentColor" stroke-width="6"/><path d="M48 25L48 43H66Z"/>',
	'<path d="M23 67L49 28L77 67H63L49 47L36 67Z"/><circle cx="50" cy="24" r="3"/>',
	'<path d="M25 35H77L69 48H55V57L67 63V70H33V63L45 57V48H35L25 42Z"/>',
	'<circle cx="50" cy="51" r="13"/><path d="M50 25V32M50 70V77M24 51H31M69 51H76M31 32L37 38M63 64L69 70M31 70L37 64M63 38L69 32" fill="none" stroke="currentColor" stroke-width="5"/>',
	'<path d="M50 25L68 46H61L73 61H55V75H45V61H27L39 46H32Z"/>',
	'<path d="M50 25L57 43L77 44L61 56L66 76L50 65L34 76L39 56L23 44L43 43Z"/>',
	'<circle cx="50" cy="32" r="6" fill="none" stroke="currentColor" stroke-width="5"/><path d="M50 39V73M35 46H65M26 56Q27 74 50 75Q73 74 74 56M24 56L32 61M76 56L68 61" fill="none" stroke="currentColor" stroke-width="6"/>',
	'<path d="M30 70L34 48H27L41 26L54 48H46L50 70ZM56 70L59 55H54L65 37L76 55H70L75 70Z"/>'
]
const DIGITS := [
	'M12 6H28Q34 6 34 13V51Q34 58 28 58H12Q6 58 6 51V13Q6 6 12 6Z',
	'M10 15L23 6V58M10 58H35',
	'M6 14Q6 6 14 6H27Q34 6 34 14V22L6 49V58H34',
	'M6 6H27Q34 6 34 14V22Q34 32 24 32H16M24 32Q34 32 34 42V50Q34 58 26 58H6',
	'M28 58V6H22L6 39H36',
	'M34 6H6V31H26Q34 31 34 40V50Q34 58 26 58H6',
	'M33 6H16Q6 6 6 18V49Q6 58 15 58H25Q34 58 34 49V40Q34 31 25 31H6',
	'M6 6H34L15 58',
	'M15 6H25Q34 6 34 15V22Q34 32 25 32H15Q6 32 6 22V15Q6 6 15 6ZM15 32H25Q34 32 34 42V49Q34 58 25 58H15Q6 58 6 49V42Q6 32 15 32Z',
	'M7 58H24Q34 58 34 46V15Q34 6 25 6H15Q6 6 6 15V24Q6 33 15 33H34'
]

static func crest_body(id: int,primary: Color,accent: Color) -> String:
	var a := "#"+primary.to_html(false)
	var b := "#"+accent.to_html(false)
	return '<g color="%s" fill="%s"><path d="M10 9Q50 0 90 9V49Q90 80 50 97Q10 80 10 49Z" fill="%s" stroke="%s" stroke-width="3"/><path d="M17 15Q50 8 83 15V49Q83 74 50 89Q17 74 17 49Z" fill="none" stroke="%s" stroke-width="1.5"/>%s</g>' % [b,b,a,b,b,SYMBOLS[posmod(id,8)]]

static func raster(svg: String) -> ImageTexture:
	var image := Image.new()
	var error := image.load_svg_from_string(svg)
	if error!=OK: push_error("Kit SVG could not be loaded: "+str(error))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func badge(id: int,primary: Color,accent: Color) -> Texture2D:
	var key := "%d/%s/%s" % [id,primary.to_html(),accent.to_html()]
	if not badges.has(key):
		badges[key]=raster('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 100 100">'+crest_body(id,primary,accent)+'</svg>')
	return badges[key]

static func shirt(colors: Dictionary,number: int,is_keeper: bool,player_name: String="") -> Texture2D:
	var primary: Color=colors.primary
	var accent: Color=colors.accent
	var id: int=colors.get("club_id",0)
	var badge_primary: Color=colors.get("badge_primary",primary)
	var badge_accent: Color=colors.get("badge_accent",accent)
	var pattern: int=colors.get("pattern",0)
	var key := "%d/%s/%s/%d/%d/%s/%s/%s" % [id,primary.to_html(),accent.to_html(),pattern,number,is_keeper,badge_primary.to_html(),badge_accent.to_html()]
	key+="/"+player_name
	if shirts.has(key): return shirts[key]
	var a := "#"+primary.to_html(false)
	var b := "#"+accent.to_html(false)
	var ink := "#172328" if primary.get_luminance()>.45 else "#f5f3e8"
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="192" viewBox="0 0 1024 384"><rect width="1024" height="384" fill="%s"/>' % a
	# Tonal side panels and fine seams stay quiet from the match camera.
	svg+='<path d="M0 0H54V384H0ZM458 0H566V384H458ZM970 0H1024V384H970Z" fill="%s" opacity=".13"/>' % b
	if is_keeper:
		svg+='<path d="M90 150L256 214L422 150M90 191L256 255L422 191" fill="none" stroke="%s" stroke-width="17" opacity=".24"/>' % b
	elif pattern==0:
		svg+='<path d="M80 183H432" stroke="%s" stroke-width="45"/><path d="M80 216H432" stroke="%s" stroke-width="4"/>' % [b,b]
	elif pattern==1:
		svg+='<path d="M159 0V384M256 0V384M353 0V384" stroke="%s" stroke-width="43" opacity=".72"/>' % b
	else:
		svg+='<path d="M75 -24L447 385" stroke="%s" stroke-width="55"/><path d="M97 -24L469 385" stroke="%s" stroke-width="4"/>' % [b,b]
	# Club colours remain recognisable on the alternate and goalkeeper shirts.
	svg+='<g transform="translate(291 44) scale(.59 .78)">'+crest_body(id,badge_primary,badge_accent)+'</g>'
	svg+='<path d="M173 67L190 56L207 67M179 75L190 68L201 75" fill="none" stroke="%s" stroke-width="5"/>' % b
	svg+='<path d="M82 374H430M594 374H942" stroke="%s" stroke-width="5" opacity=".65"/>' % b
	# Geometric athletic numerals, baked into the back instead of floating text.
	var value := str(number)
	var scale_x := 2.55
	var start := 768.0-(value.length()*48.0-8)*scale_x/2
	# A quiet back panel keeps numbers legible on every strip.
	svg+='<rect x="638" y="78" width="260" height="246" rx="12" fill="%s" opacity=".94"/>' % a
	svg+=name_print(player_name,ink)
	for i in range(value.length()):
		svg+='<path transform="translate(%s 101) scale(%s 3.15)" d="%s" fill="none" stroke="%s" stroke-width="8" stroke-linejoin="round"/>' % [start+i*48*scale_x,scale_x,DIGITS[int(value[i])],ink]
	svg+='</svg>'
	# Bound memory even when teams/kits are cycled repeatedly in the menu.
	if shirts.size()>=96: shirts.erase(shirts.keys()[0])
	shirts[key]=raster(svg)
	return shirts[key]

static func torso_mesh() -> ArrayMesh:
	if torso!=null: return torso
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	const SEGMENTS := 32
	# Sloped shoulders join the collar instead of ending in a flat cylinder lid.
	var radii := [0.12,0.32,0.285,0.225]
	var levels := [0.275,0.21,0.06,-0.275]
	var v_coords := [0.0,0.118,0.39,1.0]
	for row in range(4):
		for i in range(SEGMENTS+1):
			var u := float(i)/SEGMENTS
			# UVs read left-to-right from outside the shirt, including its back.
			var angle := -(u-0.25)*TAU
			var radial := Vector3(sin(angle),0,-cos(angle))
			vertices.append(radial*radii[row]*Vector3(1,1,.78)+Vector3(0,levels[row],0))
			normals.append((radial*Vector3(1,1,1.0/.78)+Vector3(0,[2.77,.38,.20,-.18][row],0)).normalized())
			uv.append(Vector2(u,v_coords[row]))
	for row in range(3):
		for i in range(SEGMENTS):
			var a := row*(SEGMENTS+1)+i
			indices.append_array(PackedInt32Array([a,a+1,a+SEGMENTS+1,a+1,a+SEGMENTS+2,a+SEGMENTS+1]))
	# Caps share the cloth colour at a blank UV location.
	for row in range(2):
		var center := vertices.size()
		var y := 0.275 if row==0 else -0.275
		for i in range(SEGMENTS+1):
			var angle := i*TAU/SEGMENTS
			vertices.append(Vector3(sin(angle)*(0.12 if row==0 else 0.225),y,-cos(angle)*(0.12 if row==0 else 0.225)*.78))
			normals.append(Vector3.UP if row==0 else Vector3.DOWN); uv.append(Vector2(.56,.9))
		vertices.append(Vector3(0,y,0)); normals.append(Vector3.UP if row==0 else Vector3.DOWN); uv.append(Vector2(.56,.9))
		for i in range(SEGMENTS):
			indices.append_array(PackedInt32Array([center+SEGMENTS+1,center+i,center+i+1] if row==0 else [center+SEGMENTS+1,center+i+1,center+i]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_INDEX]=indices
	torso=ArrayMesh.new(); torso.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return torso

# Compact athletic lettering baked into the same UV atlas, including Turkish
# names. Vector cells survive mipmapping without a separate floating Label3D.
const LETTERS := {
	"A":[14,17,17,31,17,17,17],"B":[30,17,17,30,17,17,30],"C":[15,16,16,16,16,16,15],
	"D":[30,17,17,17,17,17,30],"E":[31,16,16,30,16,16,31],"F":[31,16,16,30,16,16,16],
	"G":[15,16,16,23,17,17,15],"H":[17,17,17,31,17,17,17],"I":[31,4,4,4,4,4,31],
	"J":[7,2,2,2,18,18,12],"K":[17,18,20,24,20,18,17],"L":[16,16,16,16,16,16,31],
	"M":[17,27,21,21,17,17,17],"N":[17,25,25,21,19,19,17],"O":[14,17,17,17,17,17,14],
	"P":[30,17,17,30,16,16,16],"Q":[14,17,17,17,21,18,13],"R":[30,17,17,30,20,18,17],
	"S":[15,16,16,14,1,1,30],"T":[31,4,4,4,4,4,4],"U":[17,17,17,17,17,17,14],
	"V":[17,17,17,17,17,10,4],"W":[17,17,17,21,21,27,17],"X":[17,17,10,4,10,17,17],
	"Y":[17,17,10,4,4,4,4],"Z":[31,1,2,4,8,16,31],"-":[0,0,0,31,0,0,0]}

static func name_print(value: String,ink: String) -> String:
	value=value.to_upper().substr(0,18)
	if value.is_empty(): return ""
	var unit := minf(5.3,260.0/(value.length()*6-1))
	var start := 768.0-(value.length()*6-1)*unit*.5
	var svg := '<g fill="%s">' % ink
	var accents := {"İ":"I","Ö":"O","Ü":"U","Ç":"C","Ş":"S","Ğ":"G","É":"E","Á":"A"}
	for i in range(value.length()):
		var letter := value[i]
		var rows: Array=LETTERS.get(accents.get(letter,letter),[0,0,0,0,0,0,0])
		for y in range(7):
			for x in range(5):
				if rows[y] & (1<<(4-x)):
					svg+='<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f"/>' % [start+(i*6+x)*unit,32+y*unit,unit,unit]
		if letter in ["İ","Ö","Ü","Ğ","É","Á"]:
			svg+='<rect x="%.2f" y="20" width="%.2f" height="5"/>' % [start+(i*6+1)*unit,unit*3]
		elif letter in ["Ç","Ş"]:
			svg+='<rect x="%.2f" y="72" width="%.2f" height="5"/>' % [start+(i*6+2)*unit,unit]
	return svg+'</g>'
