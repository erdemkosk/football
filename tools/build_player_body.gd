extends SceneTree
## A connected clothed-body base. Body, arms and legs share a 15-bone palette
## with the shirt; corrective joints and an upper-neck bone preserve volume.
const Surface=preload("res://tools/implicit_surface.gd")
const Body=preload("res://scripts/player_body_mesh.gd")
const Shirt=preload("res://tools/build_player_shirt.gd")
const ORIGIN:=Vector3(0,1.22,0)
const TORSO:=[Vector4(1.740,.075,.066,.072),Vector4(1.685,.065,.060,.066),Vector4(1.630,.061,.059,.064),Vector4(1.596,.067,.061,.067),Vector4(1.565,.087,.069,.073),Vector4(1.535,.163,.092,.086),Vector4(1.475,.249,.140,.126),Vector4(1.36,.237,.149,.132),Vector4(1.16,.188,.125,.121),Vector4(1.07,.191,.129,.137),Vector4(.965,.205,.135,.154),Vector4(.88,.180,.128,.137),Vector4(.825,.105,.055,.066)]
const ARM:=[Vector4(1.515,.055,.060,.055),Vector4(1.43,.078,.081,.075),Vector4(1.33,.071,.077,.068),Vector4(1.23,.058,.061,.058),Vector4(1.20,.057,.059,.061),Vector4(1.16,.061,.065,.054),Vector4(1.08,.053,.059,.048),Vector4(.99,.034,.039,.033),Vector4(.915,.026,.030,.026)]
const LEG:=[Vector4(.980,.084,.096,.102),Vector4(.87,.108,.121,.122),Vector4(.74,.102,.119,.109),Vector4(.635,.083,.096,.088),Vector4(.55,.067,.075,.066),Vector4(.52,.066,.079,.064),Vector4(.47,.070,.068,.078),Vector4(.365,.073,.069,.093),Vector4(.255,.055,.051,.065),Vector4(.135,.039,.042,.044),Vector4(.095,.037,.043,.040)]
func _initialize() -> void: call_deferred("build")

static func loft(p: Vector3,rings: Array) -> float:
	var ring: Vector4=rings[0] if p.y>rings[0].x else rings[-1]
	for i in range(rings.size()-1):
		if p.y<=rings[i].x and p.y>=rings[i+1].x:
			var a: Vector4=rings[i]; var b: Vector4=rings[i+1]
			var t:=inverse_lerp(a.x,b.x,p.y); ring=a.lerp(b,t)
			for axis in range(1,4):
				var prev: Vector4=rings[maxi(0,i-1)]; var next: Vector4=rings[mini(rings.size()-1,i+2)]
				var slope: float=(b[axis]-a[axis])/(b.x-a.x)
				var m0:=slope if i==0 else Body.tangent((a[axis]-prev[axis])/(a.x-prev.x),slope)
				var m1:=slope if i==rings.size()-2 else Body.tangent(slope,(next[axis]-b[axis])/(next.x-b.x))
				ring[axis]=(2*t*t*t-3*t*t+1)*a[axis]+(t*t*t-2*t*t+t)*(b.x-a.x)*m0+(-2*t*t*t+3*t*t)*b[axis]+(t*t*t-t*t)*(b.x-a.x)*m1
			break
	var depth:=ring.z if p.z<0 else ring.w
	var radial: float=(Vector2(p.x/ring.y,p.z/depth).length()-1)*minf(ring.y,depth)
	return maxf(radial,maxf(p.y-rings[0].x,rings[-1].x-p.y))

# Mesh the wrists away from the thighs, then restore their authored rest pose.
# Otherwise a marching cell bridges the tiny gap and stretches skin between limbs.
static func arm_spread(y: float) -> float:
	return .08*(1-smoothstep(1.12,1.32,y))

static func arm_point(p: Vector3) -> Vector3:
	var center:=lerpf(.28,.247,smoothstep(1.26,1.51,p.y))+arm_spread(p.y)
	return p-Vector3((1.0 if p.x>=0 else -1.0)*center,0,0)

static func sample(p: Vector3) -> float:
	var trunk:=loft(p,TORSO)
	# Zero belongs to the right half; signf(0) would create a phantom middle leg.
	var leg:=loft(p-Vector3((1.0 if p.x>=0 else -1.0)*.14,0,0),LEG)
	var arm:=loft(arm_point(p),ARM)
	var core:=Surface.union(trunk,leg,.042)
	return Surface.union(core,arm,.035) if p.y>1.30 else minf(core,arm)

static func bend_weights(y: float,pivot: float,parent: int,child: int,middle: int,span: float) -> Dictionary:
	if y>pivot:
		var upper:=smoothstep(pivot,pivot+span,y)
		return {parent:upper,middle:1-upper}
	var lower:=1-smoothstep(pivot-span,pivot,y)
	return {child:lower,middle:1-lower}

static func binding(at: Vector3) -> Dictionary:
	if at.y>1.59:
		var head:=smoothstep(1.59,1.73,at.y)*.72
		return {0:1-head,14:head}
	var side:=0 if at.x<0 else 1
	var arm_field:=loft(arm_point(at),ARM)
	var body_field:=Surface.union(loft(at,TORSO),loft(at-Vector3((1.0 if at.x>=0 else -1.0)*.14,0,0),LEG),.042)
	var arm:=1-clampf(.5+.5*(arm_field-body_field)/(.035 if at.y>1.30 else .00001),0,1)
	# Skin under the shirt uses the cloth's shoulder/waist deformation field.
	# Different blend boundaries let the chest pierce the sleeves on high saves.
	if at.y>1.12 and (arm<.001 or at.y>1.285):
		var rest:=at-Vector3((-1.0 if at.x<0 else 1.0)*arm_spread(at.y)*arm,0,0)
		return Shirt.binding(rest)
	if arm>.001:
		var bound:=bend_weights(at.y,1.20,1+side,3+side,10+side,.082)
		for key in bound: bound[key]*=arm
		bound[0]=1-arm
		return bound
	if at.y<1.10:
		var bound:=bend_weights(at.y,.52,6+side,8+side,12+side,.085)
		var hip:=smoothstep(.84,1.02,at.y)
		for key in bound: bound[key]*=1-hip
		bound[5]=hip
		return bound
	var hip:=1-smoothstep(1.07,1.30,at.y)
	return {0:1-hip,5:hip}

func build() -> void:
	var surface:=Surface.new(); surface.build(sample,Vector3(-.468,.066,-.208),Vector3i(36,65,16),.026)
	var groups: Array=[[],[],[]]
	for i in range(0,surface.indices.size(),3):
		var center: Vector3=(surface.points[surface.indices[i]]+surface.points[surface.indices[i+1]]+surface.points[surface.indices[i+2]])/3
		var part:=0 # Skin includes the neck and the continuous under-shirt torso.
		if center.y<.378: part=2
		elif center.y<1.106 and center.y>.612:
			var arm:=loft(arm_point(center),ARM)
			var trunk:=Surface.union(loft(center,TORSO),loft(center-Vector3((1.0 if center.x>=0 else -1.0)*.14,0,0),LEG),.042)
			if trunk<arm: part=1
		for j in range(3): groups[part].append(surface.indices[i+j])
	var importer:=ImporterMesh.new()
	var total:=0
	for part in range(3):
		var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
		var vertices:=PackedVector3Array(); var normals:=PackedVector3Array(); var uvs:=PackedVector2Array()
		var colors:=PackedColorArray()
		var bones:=PackedInt32Array(); var weights:=PackedFloat32Array(); var indices:=PackedInt32Array(); var remap: Dictionary={}
		for source: int in groups[part]:
			if not remap.has(source):
				var at: Vector3=surface.points[source]; remap[source]=vertices.size()
				var bound:=binding(at); var keys:=bound.keys()
				var arm_weight:=0.0
				for bone in [1,2,3,4,10,11]: arm_weight+=float(bound.get(bone,0))
				var side:=1.0 if at.x>=0 else -1.0
				var restored:=at-Vector3(side*arm_spread(at.y)*arm_weight,0,0)
				var normal: Vector3=surface.normals[source]
				var slope:=side*(arm_spread(at.y+.0001)-arm_spread(at.y-.0001))/.0002*arm_weight
				normal.y+=slope*normal.x
				vertices.append(restored-ORIGIN); normals.append(normal.normalized())
				# Retain the continuous anatomical mesh but mask skin covered by
				# clothing. Extreme shoulder poses must not expose hidden armpits.
				var cuff:=lerpf(1.075,1.263,arm_weight)
				var exposed:=maxf(1-smoothstep(cuff-.005,cuff+.005,at.y),smoothstep(1.555,1.570,at.y))
				colors.append(Color(1,1,1,exposed if part==0 else 1.0))
				var axis:=Vector2(at.x-(1.0 if at.x>=0 else -1.0)*.14,at.z)
				uvs.append(Vector2(fposmod(atan2(axis.x,-axis.y)/TAU,1),clampf((.98-at.y)/.9,0,1)))
				for k in range(4):
					bones.append(keys[k] if k<keys.size() else 0)
					weights.append(bound[keys[k]] if k<keys.size() else 0)
			indices.append(remap[source])
		arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_TEX_UV]=uvs
		arrays[Mesh.ARRAY_COLOR]=colors
		arrays[Mesh.ARRAY_BONES]=bones; arrays[Mesh.ARRAY_WEIGHTS]=weights; arrays[Mesh.ARRAY_INDEX]=indices
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays); total+=vertices.size()
	importer.generate_lods(25,60,[])
	var error:=ResourceSaver.save(importer.get_mesh(),"res://assets/models/player_body.res")
	print("BODY GENERATED: ",total," vertices, ",surface.indices.size()/3," triangles, error=",error)
	quit(error)
