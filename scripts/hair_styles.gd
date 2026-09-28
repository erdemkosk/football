extends RefCounted
## Connected hair caps with restrained surface texture; one draw per haircut.
const Meshes=preload("res://scripts/character_mesh.gd")
const Body=preload("res://scripts/player_body_mesh.gd")
const NAMES := ["Kısa kesim","Kısa dokulu","Öne kabarık","Yana ayrık","Dik saç","Kıvırcık","Afro","Düz üst","Mohawk","Örgü","Kısa burgu","Uzun burgu","Topuz","At kuyruğu","Dağınık uzun","Dalgalı","Kıvırcık üst","Geri taralı"]
const COLORS := [Color("171816"),Color("29221e"),Color("483526"),Color("785332"),Color("b9955f"),Color("bda67e"),Color("763f2d")]
static var cache: Dictionary={}

static func style_for(identity: int) -> int:
	return posmod(identity*7+identity/18,NAMES.size())

static func color_for(identity: int) -> Color:
	return COLORS[posmod(identity*13+identity/7,COLORS.size())]

static func model(style: int,_scalp: ArrayMesh) -> ArrayMesh:
	if cache.has(style): return cache[style]
	var builder:=Meshes.new(); var points: Array=[]; var tints: Array=[]
	for row in range(19):
		for sector in range(49):
			var around:=(sector%48)*TAU/48.0
			var front_edge: float=[1.00,1.06,1.08,1.00,1.06,1.18,1.20,1.00,1.08,1.02,1.16,1.16,.98,.98,1.15,1.10,1.13,.97][style]
			var edge:=lerpf(front_edge,1.78,(1-cos(around))*.5)
			# Unequal temples and a broad swept part keep the outline asymmetric.
			edge+=sin(around+style*.71)*.038+sin(around*3+style*.43)*.015
			# A shallow irregular hairline breaks the helmet-like rim without gaps.
			edge+=(sin(around*11+style*.73)*.020+sin(around*23)*.009)*(0.45 if style==0 else 1.0)
			if style in [0,3,17]: edge-=pow(maxf(0,sin(around)*cos(around)),2)*.20
			var angle:=edge*(1.0-row/18.0)
			var normal:=Vector3(sin(angle)*sin(around),cos(angle),-sin(angle)*cos(around))
			var at:=normal*Vector3(.190,.246,.203)
			# Follow the same rounded temples as the face beneath the hairline.
			at.z=-sin(angle)*Body.head_front_curve(cos(around))*.203
			var fitted:=at
			# Taper the first few rows to the real skull. A thick ellipsoid rim
			# previously hovered over the temples like the edge of a helmet.
			var root:=Body.head_point(1-angle/PI,around/TAU,1.06,1.055)+normal*.0025
			var top:=smoothstep(.11,.22,at.y)
			var grain:=sin(around*17+sin(angle*13))*sin(angle*24)
			var amplitude:=.0015
			match style:
				1: amplitude=.004
				2: at.y+=top*(.025+maxf(0,-at.z)*.30); at.z-=top*.02
				3: at.y+=top*(.028-at.x*.15); at.x-=top*.018; amplitude=.003
				4: amplitude=.010*top; at.y+=top*.027
				5: at*=Vector3(1.06,1.10,1.06); amplitude=.006
				6: at*=Vector3(1.26,1.29,1.24); amplitude=.009
				7: at.y=minf(.271,at.y*1.46)
				8: at.y+=exp(-pow(at.x/.036,2))*.070*top
				9: amplitude=.001; at+=normal*pow(maxf(0,cos(at.x*118)),5)*.010
				10,11: amplitude=.004
				12,13: at.z+=top*.017
				14: at.x*=1.04; amplitude=.005
				15: at.y+=top*(.022+sin(at.x*64+at.z*10)*.006)
				16: at.y+=top*.045; amplitude=.007*top
				17: at.z+=top*.022; at.y+=top*.012
			var locks:=pow(maxf(0,cos(around*(9 if style in [5,6,16] else 13)+angle*(5 if style in [3,15,17] else 2))),3)
			at+=normal*(grain*amplitude+locks*(.007 if style!=0 else .0015)*sin(angle))
			# Styling can add volume or sweep outward, but never shave through the
			# fitted forehead/crown. This also holds for ponytails and swept hair.
			at.x=signf(fitted.x)*maxf(absf(at.x),absf(fitted.x))
			at.z=signf(fitted.z)*maxf(absf(at.z),absf(fitted.z))
			if fitted.y>0: at.y=maxf(at.y,fitted.y)
			at=root.lerp(at,smoothstep(0,.25,row/18.0))
			points.append(at)
			tints.append(Color.WHITE*(.91+grain*.035+locks*.055))
	builder.grid(points,49,tints)
	# Buns, tails and locks emerge from the cap as overlapping tapered shapes;
	# curls themselves are a single continuous surface rather than beads.
	if style==12:
		builder.ellipsoid(Vector3(0,.14,.195),Vector3(.069,.063,.074))
	elif style==13:
		builder.ellipsoid(Vector3(0,.12,.187),Vector3(.070,.063,.072))
		builder.tube([Vector3(0,.10,.21),Vector3(.02,-.03,.24),Vector3(.03,-.16,.21)],.033)
	elif style==14:
		for side in [-1,1]: builder.ellipsoid(Vector3(side*.155,-.018,.075),Vector3(.036,.150,.104))
		builder.ellipsoid(Vector3(0,-.055,.160),Vector3(.153,.125,.044))
	elif style in [10,11]:
		for i in range(12):
			var angle:=i*TAU/12
			var start:=Vector3(sin(angle)*.125,.172,-cos(angle)*.125)
			var end:=Vector3(sin(angle)*.19,.035 if style==11 else .20,-cos(angle)*.19)
			builder.tube([start,start.lerp(end,.5)+Vector3(0,.05,0),end],.015)
		if style==11:
			for i in range(5): builder.tube([Vector3((i-2)*.05,.07,.15),Vector3((i-2)*.05,-.15,.18)],.016)
	var result:=builder.finish(); cache[style]=result; return result
