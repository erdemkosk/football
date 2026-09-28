extends RefCounted
## A bounded match-long surface memory. Fresh tread meshes can be recycled
## without restoring the grass underneath them. No physics reads this map.
const P=preload("res://scripts/pitch_dimensions.gd")
const SIZE:=Vector2i(384,544)
var image: Image
var texture: ImageTexture
var dirty:=false
var upload_age:=0.0
var contacts:=0

func setup(grass: ShaderMaterial,chalk: ShaderMaterial) -> void:
	image=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RG8)
	image.fill(Color(0,0,0,1))
	texture=ImageTexture.create_from_image(image)
	for material in [grass,chalk]:
		material.set_shader_parameter("wear_map",texture)
		material.set_shader_parameter("wear_half_pitch",Vector2(P.HALF_WIDTH,P.HALF_LENGTH))

func reset() -> void:
	if image==null: return
	image.fill(Color(0,0,0,1)); texture.update(image)
	dirty=false; upload_age=0; contacts=0

func update(delta: float) -> void:
	upload_age+=delta
	if dirty and upload_age>=.25:
		texture.update(image); dirty=false; upload_age=0

func pixel(at: Vector3) -> Vector2i:
	return Vector2i(floori((at.x/P.WIDTH+.5)*SIZE.x),floori((at.z/P.LENGTH+.5)*SIZE.y))

func sample(at: Vector3) -> Vector2:
	var cell:=pixel(at)
	if not Rect2i(Vector2i.ZERO,SIZE).has_point(cell): return Vector2.ZERO
	var value:=image.get_pixelv(cell)
	return Vector2(value.r,value.g)

func press(at: Vector3,direction: Vector3,size: Vector2,wet: float,scar: bool=false,power: float=1.0) -> void:
	if image==null or absf(at.x)>=P.HALF_WIDTH or absf(at.z)>=P.HALF_LENGTH: return
	var forward:=Vector2(direction.x,direction.z).normalized()
	if forward.length_squared()<.1: forward=Vector2(0,1)
	var right:=Vector2(forward.y,-forward.x)
	# Half a texel of padding integrates narrow soles without missing the grid.
	var radius:=size*.5+Vector2(.095,.092)
	var bound:=radius.length()
	var lo:=pixel(at-Vector3(bound,0,bound)).clamp(Vector2i.ZERO,SIZE-Vector2i.ONE)
	var hi:=pixel(at+Vector3(bound,0,bound)).clamp(Vector2i.ZERO,SIZE-Vector2i.ONE)
	var strength:=clampf(power,0,2)*(.16 if scar else .075)*lerpf(1,1.65,wet)
	for y in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var world:=Vector2((float(x)+.5)/SIZE.x*P.WIDTH-P.HALF_WIDTH,(float(y)+.5)/SIZE.y*P.LENGTH-P.HALF_LENGTH)
			var offset:=world-Vector2(at.x,at.z)
			var local:=Vector2(offset.dot(right),offset.dot(forward))/radius
			var cover:=1-smoothstep(.25,1.0,local.length())
			if cover<=0: continue
			var old:=image.get_pixel(x,y)
			var amount:=strength*cover
			image.set_pixel(x,y,Color(minf(1,old.r+amount),minf(1,old.g+(amount*1.7 if scar else amount*.20)),0,1))
	contacts+=1; dirty=true
