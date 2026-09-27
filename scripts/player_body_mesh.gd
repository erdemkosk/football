extends RefCounted
## Shared anatomical lofts. Smooth profiles keep shoulders and muscles rounded
## without adding render surfaces or changing the articulated contact nodes.
const Builder=preload("res://scripts/character_mesh.gd")
const HEAD_SCALE:=.72
const CROWN:=.3855
const SHOULDER_X:=.28
static var cache: Dictionary={}

# Height, half width, front depth, back depth. Front/back asymmetry gives the
# chest, calf and forearm volume without turning each limb into a straight pipe.
const PROFILES:={
	"torso":[Vector4(.385,.082,.076,.074),Vector4(.365,.137,.091,.088),Vector4(.325,.228,.129,.116),Vector4(.275,.276,.158,.141),Vector4(.19,.274,.167,.144),Vector4(.08,.246,.157,.137),Vector4(-.025,.217,.139,.128),Vector4(-.095,.205,.133,.128),Vector4(-.155,.218,.140,.138)],
	"pelvis":[Vector4(-.062,.173,.121,.137),Vector4(-.030,.212,.138,.150),Vector4(.045,.228,.140,.156),Vector4(.11,.215,.134,.147),Vector4(.137,.205,.129,.138)],
	"shorts":[Vector4(-.103,.086,.098,.099),Vector4(-.087,.095,.108,.105),Vector4(.010,.111,.126,.112),Vector4(.13,.114,.131,.122),Vector4(.23,.108,.125,.120),Vector4(.268,.092,.104,.100)],
	"thigh":[Vector4(-.34,.065,.075,.070),Vector4(-.29,.076,.084,.081),Vector4(-.22,.091,.100,.091),Vector4(-.14,.094,.104,.094)],
	"knee":[Vector4(-.12,.067,.067,.075),Vector4(-.065,.072,.077,.076),Vector4(-.015,.075,.083,.072),Vector4(.037,.069,.071,.067),Vector4(.074,.062,.061,.058)],
	"calf":[Vector4(-.165,.049,.051,.054),Vector4(-.12,.052,.054,.062),Vector4(-.025,.062,.062,.084),Vector4(.050,.073,.071,.096),Vector4(.100,.074,.074,.087),Vector4(.121,.071,.072,.079)],
	"sleeve":[Vector4(-.121,.077,.085,.085),Vector4(-.100,.080,.089,.089),Vector4(-.025,.091,.101,.094),Vector4(.045,.101,.100,.090),Vector4(.099,.088,.080,.075),Vector4(.145,.058,.050,.047),Vector4(.163,.008,.008,.008)],
	"upper_arm":[Vector4(-.276,.060,.063,.061),Vector4(-.23,.066,.070,.067),Vector4(-.16,.074,.079,.071),Vector4(-.10,.076,.080,.075)],
	"forearm":[Vector4(-.291,.036,.039,.036),Vector4(-.255,.040,.043,.039),Vector4(-.19,.048,.052,.045),Vector4(-.10,.062,.064,.056),Vector4(-.025,.062,.067,.059),Vector4(.035,.055,.057,.052)],
	"neck":[Vector4(-.060,.101,.073,.078),Vector4(-.025,.073,.063,.069),Vector4(.022,.064,.059,.065),Vector4(.068,.067,.062,.068),Vector4(.086,.073,.066,.074)]}

static func model(part: String) -> ArrayMesh:
	if cache.has(part): return cache[part]
	var shirt:=part=="torso"
	var profiles: Array=PROFILES[part]
	var segments:=32 if shirt else 24
	var rows: int=(profiles.size()-1)*4+1
	var builder:=Builder.new()
	var points: Array=[]
	for row in range(rows):
		var t:=float(row)/(rows-1)
		for sector in range(segments+1):
			points.append(point(profiles,t,float(sector)/segments,shirt))
	builder.grid(points,segments+1)
	# Differentiate the same smooth surface, including at duplicated UV seams;
	# averaged face normals alone retain bands at sparse profile landmarks.
	for row in range(rows):
		var t:=float(row)/(rows-1)
		for sector in range(segments+1):
			var u:=float(sector)/segments
			var along:=point(profiles,minf(1,t+.0001),u,shirt)-point(profiles,maxf(0,t-.0001),u,shirt)
			var around:=point(profiles,t,u+.0001,shirt)-point(profiles,t,u-.0001,shirt)
			var i:=row*(segments+1)+sector
			builder.normals[i]=along.cross(around).normalized()
			# Keep the existing shirt atlas direction and neckline/hem alignment.
			if shirt: builder.uvs[i]=Vector2(u,(profiles[0].x-points[i].y)/(profiles[0].x-profiles[-1].x))
	cap(builder,segments,rows,true)
	cap(builder,segments,rows,false)
	cache[part]=builder.finish()
	return cache[part]

static func point(profiles: Array,t: float,u: float,shirt: bool) -> Vector3:
	var span:=t*(profiles.size()-1)
	var index:=mini(int(span),profiles.size()-2)
	var f:=span-index
	var a: Vector4=profiles[index]; var b: Vector4=profiles[index+1]
	var ring:=a.lerp(b,f)
	for axis in range(1,4):
		var before: Vector4=profiles[maxi(0,index-1)]
		var after: Vector4=profiles[mini(profiles.size()-1,index+2)]
		var slope: float=(b[axis]-a[axis])/(b.x-a.x)
		var m0:=slope if index==0 else tangent((a[axis]-before[axis])/(a.x-before.x),slope)
		var m1:=slope if index==profiles.size()-2 else tangent(slope,(after[axis]-b[axis])/(after.x-b.x))
		ring[axis]=(2*f*f*f-3*f*f+1)*a[axis]+(f*f*f-2*f*f+f)*(b.x-a.x)*m0+(-2*f*f*f+3*f*f)*b[axis]+(f*f*f-f*f)*(b.x-a.x)*m1
	var angle:=-(u-.25)*TAU if shirt else u*TAU
	var front:=cos(angle)
	var depth:=ring.z if front>=0 else ring.w
	var position:=Vector3(sin(angle)*ring.y,ring.x,-front*depth)
	if shirt:
		# Subtle lower-shirt folds follow the waist; the chest stays readable.
		var fold:=sin(angle*6+ring.x*9)*.0025*smoothstep(.12,-.22,ring.x)
		position+=Vector3(sin(angle),0,-front)*fold
	return position

static func tangent(a: float,b: float) -> float:
	# Monotone Hermite slopes cannot overshoot a wrist, neckline or hem.
	return 0.0 if a*b<=0 else 2*a*b/(a+b)

static func cap(builder,segments: int,rows: int,first: bool) -> void:
	var offset:=0 if first else (rows-1)*(segments+1)
	var start: int=builder.vertices.size()
	var descending: bool=builder.vertices[0].y>builder.vertices[(rows-1)*(segments+1)].y
	var normal:=Vector3.UP if first==descending else Vector3.DOWN
	var y: float=builder.vertices[offset].y
	for sector in range(segments+1):
		builder.vertices.append(builder.vertices[offset+sector]); builder.normals.append(normal)
		builder.uvs.append(Vector2(.56,.9)); builder.colors.append(Color.WHITE)
	builder.vertices.append(Vector3(0,y,0)); builder.normals.append(normal)
	builder.uvs.append(Vector2(.56,.9)); builder.colors.append(Color.WHITE)
	for sector in range(segments):
		var a:=start+sector; var center:=start+segments+1
		builder.indices.append_array(PackedInt32Array([center,a+1,a] if first else [center,a,a+1]))
