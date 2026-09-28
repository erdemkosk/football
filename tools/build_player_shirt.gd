extends SceneTree
## Offline, deterministic smooth-union garment. Run after changing the shape:
## godot --headless --path . --script tools/build_player_shirt.gd
const Body=preload("res://scripts/player_body_mesh.gd")
const STEP:=.024
const LOW:=Vector3(-.405,1.025,-.19)
const CELLS:=Vector3i(34,26,17)
const CORNERS:=[Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]
const TETS:=[[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
var points:=PackedVector3Array()
var normals:=PackedVector3Array()
var uvs:=PackedVector2Array()
var bones:=PackedInt32Array()
var weights:=PackedFloat32Array()
var indices:=PackedInt32Array()
var edges: Dictionary={}
var field: Dictionary={}

func _initialize() -> void: call_deferred("build")

static func union(a: float,b: float,k: float) -> float:
	var h:=clampf(.5+.5*(b-a)/k,0,1)
	return lerpf(b,a,h)-k*h*(1-h)

static func torso(p: Vector3) -> float:
	var y:=p.y-1.22
	var rings: Array=Body.PROFILES.torso
	var r: Vector4=rings[0] if y>rings[0].x else rings[-1]
	for i in range(rings.size()-1):
		if y<=rings[i].x and y>=rings[i+1].x:
			var f: float=inverse_lerp(rings[i].x,rings[i+1].x,y)
			var a: Vector4=rings[i]; var b: Vector4=rings[i+1]
			r=a.lerp(b,f)
			for axis in range(1,4):
				var before: Vector4=rings[maxi(0,i-1)]; var after: Vector4=rings[mini(rings.size()-1,i+2)]
				var slope: float=(b[axis]-a[axis])/(b.x-a.x)
				var m0:=slope if i==0 else Body.tangent((a[axis]-before[axis])/(a.x-before.x),slope)
				var m1:=slope if i==rings.size()-2 else Body.tangent(slope,(after[axis]-b[axis])/(after.x-b.x))
				r[axis]=(2*f*f*f-3*f*f+1)*a[axis]+(f*f*f-2*f*f+f)*(b.x-a.x)*m0+(-2*f*f*f+3*f*f)*b[axis]+(f*f*f-f*f)*(b.x-a.x)*m1
			break
	var depth:=r.z if p.z<0 else r.w
	var ease:=1+smoothstep(1.25,1.075,p.y)*.065
	r.y*=ease; depth*=ease
	var side: float=(Vector2(p.x/r.y,p.z/depth).length()-1)*minf(r.y,depth)
	return maxf(side,maxf(1.067-p.y,p.y-1.605))

static func sleeve(p: Vector3,side: float) -> float:
	# Slightly outboard cuffs leave an actual armpit, unlike touching cylinders.
	var t:=clampf((1.50-p.y)/.235,0,1)
	var center:=side*lerpf(.247,.287,t)
	var radius:=lerpf(.103,.080,t)
	var radial: float=(Vector3((p.x-center)/radius,maxf(0,p.y-1.426)/.119,p.z/(radius*1.08)).length()-1)*radius
	return -union(-radial,-(1.263-p.y),.009)

static func sample(p: Vector3) -> float:
	var body:=union(torso(p),minf(sleeve(p,-1),sleeve(p,1)),.047)
	# Open neckline seats naturally beneath the ribbed collar.
	var neck: float=maxf((Vector2(p.x/.085,p.z/.074).length()-1)*.074,1.565-p.y)
	return maxf(body,-neck)

func value(i: Vector3i) -> float:
	if not field.has(i): field[i]=sample(LOW+Vector3(i)*STEP)
	return field[i]

static func binding(at: Vector3) -> Dictionary:
	var arm:=sleeve(at,-1.0 if at.x<0 else 1.0); var chest:=torso(at)
	var influence:=1-clampf(.5+.5*(arm-chest)/.047,0,1)
	if at.y<1.34 and absf(at.x)>.25: influence=1
	var hip: float=(1-influence)*(1-smoothstep(1.067,1.22,at.y))*.86
	return {0:1-influence-hip,(1 if at.x<0 else 2):influence,5:hip}

func vertex(a: Vector3i,b: Vector3i) -> int:
	var first:=a; var second:=b
	if str(a)>str(b): first=b; second=a
	var key:=str(first)+str(second)
	if edges.has(key): return edges[key]
	var at: Vector3=LOW+(Vector3(a).lerp(Vector3(b),value(a)/(value(a)-value(b))))*STEP
	var e:=.001
	# Refine the isosurface crossing: coarse grid interpolation otherwise leaves
	# a visibly serrated collar and cuff on close-up views.
	for _pass in range(3):
		var gradient:=Vector3(sample(at+Vector3(e,0,0))-sample(at-Vector3(e,0,0)),sample(at+Vector3(0,e,0))-sample(at-Vector3(0,e,0)),sample(at+Vector3(0,0,e))-sample(at-Vector3(0,0,e)))/(2*e)
		if gradient.length_squared()>.01: at-=(gradient*sample(at)/gradient.length_squared()).limit_length(STEP*.4)
	var normal:=Vector3(sample(at+Vector3(e,0,0))-sample(at-Vector3(e,0,0)),sample(at+Vector3(0,e,0))-sample(at-Vector3(0,e,0)),sample(at+Vector3(0,0,e))-sample(at-Vector3(0,0,e))).normalized()
	var bound:=binding(at)
	var id:=points.size()
	points.append(at-Vector3(0,1.22,0)); normals.append(normal)
	var u:=fposmod(.25-atan2(at.x,-at.z)/TAU,1.0)
	uvs.append(Vector2(u,(1.605-at.y)/.54))
	bones.append_array(PackedInt32Array([0,1 if at.x<0 else 2,5,0]))
	weights.append_array(PackedFloat32Array([bound[0],bound[1 if at.x<0 else 2],bound[5],0]))
	edges[key]=id
	return id

func triangle(a: int,b: int,c: int) -> void:
	var cross: Vector3=(points[b]-points[a]).cross(points[c]-points[a])
	if cross.length_squared()<1e-15: return
	if cross.dot(normals[a]+normals[b]+normals[c])>0: indices.append_array(PackedInt32Array([a,c,b]))
	else: indices.append_array(PackedInt32Array([a,b,c]))

func neckline() -> void:
	# Replace the coarse Boolean rim with a stitched annulus. Its open edge
	# sits underneath the rolled collar, rather than exposing clipped triangles.
	var cut:=1.560-1.22
	var previous:=indices; indices=PackedInt32Array()
	var crossings: Dictionary={}; var boundary: Array[Vector2i]=[]
	for i in range(0,previous.size(),3):
		var polygon: Array[int]=[]; var seam: Array[int]=[]
		for j in range(3):
			var a: int=previous[i+j]; var b: int=previous[i+(j+1)%3]
			var inside: bool=points[a].y<=cut; var next_inside: bool=points[b].y<=cut
			if inside: polygon.append(a)
			if inside==next_inside: continue
			var key:=Vector2i(mini(a,b),maxi(a,b))
			if not crossings.has(key):
				var t: float=inverse_lerp(points[a].y,points[b].y,cut)
				var at: Vector3=points[a].lerp(points[b],t); at.y=cut
				crossings[key]=points.size(); points.append(at)
				normals.append(normals[a].lerp(normals[b],t).normalized())
				uvs.append(Vector2(fposmod(.25-atan2(at.x,-at.z)/TAU,1),(1.605-at.y-1.22)/.54))
				bones.append_array(PackedInt32Array([0,0,0,0])); weights.append_array(PackedFloat32Array([1,0,0,0]))
			polygon.append(crossings[key]); seam.append(crossings[key])
		for j in range(1,polygon.size()-1): triangle(polygon[0],polygon[j],polygon[j+1])
		if seam.size()==2: boundary.append(Vector2i(seam[0],seam[1]))
	var columns: Dictionary={}
	for pair: Vector2i in boundary:
		for source: int in [pair.x,pair.y]:
			if columns.has(source): continue
			var strip: Array[int]=[source]; var base: Vector3=points[source]
			var angle:=atan2(base.x,-base.z)
			var end:=Vector3(sin(angle)*.079,1.614-1.22,-cos(angle)*.068)
			for row in range(1,7):
				var t:=row/6.0; var easing:=smoothstep(0,1,t)
				var at:=base.lerp(end,easing); at.y=lerpf(cut,end.y,t)
				strip.append(points.size()); points.append(at)
				var slope: Vector3=(end-base)*6*t*(1-t); slope.y=end.y-cut
				var tangent:=Vector3(cos(angle),0,sin(angle))
				var normal:=slope.cross(tangent).normalized()
				normals.append(normal)
				uvs.append(Vector2(fposmod(.25-angle/TAU,1),(1.605-at.y-1.22)/.54))
				bones.append_array(PackedInt32Array([0,0,0,0])); weights.append_array(PackedFloat32Array([1,0,0,0]))
			columns[source]=strip
		var left: Array=columns[pair.x]; var right: Array=columns[pair.y]
		for row in range(6):
			triangle(left[row],right[row],left[row+1]); triangle(right[row],right[row+1],left[row+1])

func compact_vertices() -> void:
	var kept_points:=PackedVector3Array(); var kept_normals:=PackedVector3Array(); var kept_uvs:=PackedVector2Array()
	var kept_bones:=PackedInt32Array(); var kept_weights:=PackedFloat32Array(); var remap: Dictionary={}
	for i in range(indices.size()):
		var source:=indices[i]
		if not remap.has(source):
			remap[source]=kept_points.size()
			kept_points.append(points[source]); kept_normals.append(normals[source]); kept_uvs.append(uvs[source])
			for k in range(4): kept_bones.append(bones[source*4+k]); kept_weights.append(weights[source*4+k])
		indices[i]=remap[source]
	points=kept_points; normals=kept_normals; uvs=kept_uvs; bones=kept_bones; weights=kept_weights

func build() -> void:
	for x in range(CELLS.x):
		for y in range(CELLS.y):
			for z in range(CELLS.z):
				var cell:=Vector3i(x,y,z)
				for tet in TETS:
					var inside: Array[Vector3i]=[]; var outside: Array[Vector3i]=[]
					for corner: int in tet:
						var at: Vector3i=cell+CORNERS[corner]
						if value(at)<0: inside.append(at)
						else: outside.append(at)
					if inside.size()==1:
						triangle(vertex(inside[0],outside[0]),vertex(inside[0],outside[1]),vertex(inside[0],outside[2]))
					elif inside.size()==3:
						triangle(vertex(outside[0],inside[0]),vertex(outside[0],inside[1]),vertex(outside[0],inside[2]))
					elif inside.size()==2:
						var a:=vertex(inside[0],outside[0]); var b:=vertex(inside[0],outside[1])
						var c:=vertex(inside[1],outside[0]); var d:=vertex(inside[1],outside[1])
						triangle(a,b,c); triangle(b,d,c)
	neckline()
	compact_vertices()
	# Split atlas-wrap triangles without changing the welded geometric surface.
	for i in range(0,indices.size(),3):
		var lo:=1.0; var hi:=0.0
		for j in range(3): lo=minf(lo,uvs[indices[i+j]].x); hi=maxf(hi,uvs[indices[i+j]].x)
		if hi-lo<.7: continue
		for j in range(3):
			var source:=indices[i+j]
			if uvs[source].x>.3: continue
			indices[i+j]=points.size(); points.append(points[source]); normals.append(normals[source]); uvs.append(uvs[source]+Vector2.RIGHT)
			for k in range(4): bones.append(bones[source*4+k]); weights.append(weights[source*4+k])
	var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=points; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_BONES]=bones; arrays[Mesh.ARRAY_WEIGHTS]=weights; arrays[Mesh.ARRAY_INDEX]=indices
	var importer:=ImporterMesh.new(); importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
	importer.generate_lods(25,60,[])
	var mesh:=importer.get_mesh()
	DirAccess.make_dir_recursive_absolute("res://assets/models")
	var error:=ResourceSaver.save(mesh,"res://assets/models/player_shirt.res")
	print("SHIRT GENERATED: ",points.size()," vertices, ",indices.size()/3," triangles, error=",error)
	quit(error)
