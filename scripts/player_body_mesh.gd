extends RefCounted
## Shared anatomical lofts. Smooth profiles keep shoulders and muscles rounded
## without adding render surfaces or changing the articulated contact nodes.
const Builder=preload("res://scripts/character_mesh.gd")
const HEAD_SCALE:=.72
const CROWN:=.3855
const SHOULDER_X:=.28
static var cache: Dictionary={}

static func head_front_curve(front: float) -> float:
	# A gently fuller face, with a finite tangent where the temples meet the
	# back of the skull. Fractional powers used to make square temple corners.
	return front*(1+.20*(1-front*front)*smoothstep(0,.5,front)) if front>0 else front

static func head_point(t: float,u: float,jaw: float,cheek: float,nose: float=2.0) -> Vector3:
	# Latitude sampling gives the crown and chin a continuous oval silhouette.
	# Tiny end rings are capped separately, avoiding collapsed pole triangles.
	var latitude:=lerpf(.001,PI-.001,t)
	var y:=.002-cos(latitude)*.224
	var radius:=sin(latitude)
	var jaw_weight:=1-smoothstep(-.135,.015,y)
	var cheek_weight:=exp(-pow((y+.015)/.105,2))*(1-jaw_weight)
	var width:=.178*radius*lerpf(1,jaw,jaw_weight)*lerpf(1,cheek,cheek_weight)
	var angle:=u*TAU; var forward:=cos(angle); var front:=maxf(0,forward)
	var depth:=lerpf(.184,.190,smoothstep(0,.6,-forward))
	var at:=Vector3(sin(angle)*width,y,-head_front_curve(forward)*radius*depth)
	var eye_socket:=exp(-pow((absf(at.x)-.070)/.029,2)-pow((at.y-.029)/.026,2))*front
	var cheekbone:=exp(-pow((absf(at.x)-.108)/.045,2)-pow((at.y+.027)/.038,2))*front
	var bridge:=exp(-pow(at.x/.027,2)-pow((at.y-.013)/.069,2))*front
	var nose_width:=lerpf(.021,.030,nose/4.0)
	var tip:=exp(-pow(at.x/nose_width,2)-pow((at.y+.017)/.022,2))*front
	var wings:=exp(-pow((absf(at.x)-nose_width*.87)/.011,2)-pow((at.y+.027)/.013,2))*front
	at.z+=eye_socket*.008-cheekbone*.007-bridge*.018-tip*lerpf(.027,.043,nose/4.0)-wings*.006
	return at

static func face_point(x: float,y: float,jaw: float,cheek: float,nose: float) -> Vector3:
	var latitude:=acos(clampf((.002-y)/.224,-.99999,.99999))
	var t: float=inverse_lerp(.001,PI-.001,latitude)
	var width:=head_point(t,.25,jaw,cheek,nose).x
	return head_point(t,asin(clampf(x/width,-.999,.999))/TAU,jaw,cheek,nose)

static func collar() -> ArrayMesh:
	if cache.has("collar"): return cache.collar
	var b:=Builder.new(); var points: Array=[]
	# A closed rolled binding covers the actual neckline, without a floating
	# cylinder or exposed inside edge. Front is slightly lower than the nape.
	for row in range(9):
		var cross_section:=TAU*row/8.0
		for sector in range(49):
			var angle:=TAU*sector/48.0; var front:=maxf(0,cos(angle))
			var width:=.086+cos(cross_section)*.009
			var depth:=.075+cos(cross_section)*.008
			points.append(Vector3(sin(angle)*width,-front*.001+sin(cross_section)*.010,-cos(angle)*depth))
	b.grid(points,49)
	cache.collar=b.finish(); return cache.collar

static func hand(side: int,keeper: bool=false) -> ArrayMesh:
	var key:="hand_%d_%s" % [side,keeper]
	if cache.has(key): return cache[key]
	var base:=hand_surface(side,keeper,0,0)
	var closed:=hand_surface(side,keeper,1,0)
	var spread:=hand_surface(side,keeper,0,1)
	var mesh:=ArrayMesh.new(); mesh.add_blend_shape("Curl"); mesh.add_blend_shape("Spread")
	mesh.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
	var poses: Array[Array]=[]
	for shape in [closed,spread]:
		var source: Array=shape.surface_get_arrays(0); var pose: Array=[]; pose.resize(Mesh.ARRAY_MAX)
		pose[Mesh.ARRAY_VERTEX]=source[Mesh.ARRAY_VERTEX]; pose[Mesh.ARRAY_NORMAL]=source[Mesh.ARRAY_NORMAL]
		poses.append(pose)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,base.surface_get_arrays(0),poses)
	cache[key]=mesh; return mesh

static func hand_surface(side: int,keeper: bool,curl: float,spread: float) -> ArrayMesh:
	var b:=Builder.new()
	var size:=1.17 if keeper else 1.0
	# A tapered palm and continuous finger lofts replace bead-shaped knuckles.
	hand_loft(b,[Vector4(.068,.021,.016,0),Vector4(.045,.025,.018,0),Vector4(.020,.035,.019,0),Vector4(-.012,.036,.019,-.003),Vector4(-.031,.030,.016,-.007)],Vector3.ZERO,size)
	for i in range(4):
		var x: float=(i-1.5)*.0175
		var length: float=[.045,.062,.067,.058][i if side<0 else 3-i]
		var first:=b.vertices.size()
		hand_loft(b,[Vector4(.0,.0085,.014,0),Vector4(-length*.30,.009,.013,-.006),Vector4(-length*.63,.008,.011,-.015),Vector4(-length*.90,.0065,.009,-.025),Vector4(-length,.001,.002,-.028)],Vector3(x,-.014,.001),size)
		for v in range(first,b.vertices.size()):
			var at: Vector3=b.vertices[v]/size-Vector3(x,-.014,.001)
			var distance:=clampf(-at.y/length,0,1)
			var bend:=curl*distance*2.1
			var basis:=Basis(Vector3.RIGHT,bend)
			if curl>0:
				var neutral:=Vector3(0,-length*distance,-.028*pow(distance,1.3))
				var radius:=length/(curl*2.1)
				var center:=Vector3(0,-sin(bend)*radius,-(1-cos(bend))*radius)
				at=center+basis*(at-neutral)
			at.x+=(i-1.5)*.013*distance*spread
			b.vertices[v]=(at+Vector3(x,-.014,.001))*size
			b.normals[v]=(basis*b.normals[v]).normalized()
	hand_loft(b,[Vector4(.020,.014,.016,0),Vector4(0,.012,.014,-.007),Vector4(-.022,.010,.012,-.017),Vector4(-.040,.006,.008,-.024),Vector4(-.045,.001,.002,-.027)],Vector3(-side*(.021-.003*curl),.002,.004-curl*.010),size,-side*(.40+spread*.30-curl*.28))
	# Existing hand nodes retain their attachment transforms and scales.
	var scale:=Vector3(1.05,1.3,.66) if keeper else Vector3(.68,1.18,.43)
	for i in range(b.vertices.size()):
		b.vertices[i]/=scale
		b.normals[i]=(b.normals[i]*scale).normalized()
	return b.finish()

static func hand_loft(builder,rings: Array,offset: Vector3,size: float,turn: float=0.0) -> void:
	var local:=Builder.new(); var points: Array=[]
	for row in range((rings.size()-1)*3+1):
		var i:=mini(row/3,rings.size()-2); var t:=float(row-i*3)/3
		var a: Vector4=rings[i]; var b: Vector4=rings[i+1]
		var r:=a.lerp(b,t)
		for axis in range(1,4):
			var prev: Vector4=rings[maxi(0,i-1)]; var next: Vector4=rings[mini(rings.size()-1,i+2)]
			var m0: float=(b[axis]-prev[axis])*.5; var m1: float=(next[axis]-a[axis])*.5
			r[axis]=(2*t*t*t-3*t*t+1)*a[axis]+(t*t*t-2*t*t+t)*m0+(-2*t*t*t+3*t*t)*b[axis]+(t*t*t-t*t)*m1
		for sector in range(17):
			var angle:=sector*TAU/16
			points.append(Vector3(sin(angle)*r.y,r.x,-cos(angle)*r.z+r.w))
	local.grid(points,17)
	# These rings run wrist-to-fingertip (descending Y), the reverse of the
	# generic builder's winding. Outward normals must face the palm surface.
	for i in range(local.normals.size()): local.normals[i]=-local.normals[i]
	cap(local,16,points.size()/17,true); cap(local,16,points.size()/17,false)
	for i in range(0,local.indices.size(),3):
		var swap: int=local.indices[i+1]; local.indices[i+1]=local.indices[i+2]; local.indices[i+2]=swap
	builder.append(local.finish(),offset*size,Vector3.ONE*size,Color.WHITE,Vector3(0,0,turn))

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
	# Curved finger lofts have off-axis end rings. A centre on the world axis
	# would leave long needle-like cap triangles when those fingers curl.
	var centroid:=Vector3.ZERO
	for sector in range(segments): centroid+=builder.vertices[offset+sector]
	centroid/=segments
	for sector in range(segments+1):
		builder.vertices.append(builder.vertices[offset+sector]); builder.normals.append(normal)
		builder.uvs.append(Vector2(.56,.9)); builder.colors.append(Color.WHITE)
	builder.vertices.append(centroid); builder.normals.append(normal)
	builder.uvs.append(Vector2(.56,.9)); builder.colors.append(Color.WHITE)
	for sector in range(segments):
		var a:=start+sector; var center:=start+segments+1
		builder.indices.append_array(PackedInt32Array([center,a+1,a] if first else [center,a,a+1]))
