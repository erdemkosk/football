extends RefCounted
## Offline marching tetrahedra with shared edges and smooth field normals.
const CORNERS:=[Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]
const TETS:=[[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
var points:=PackedVector3Array()
var normals:=PackedVector3Array()
var indices:=PackedInt32Array()
var field: Dictionary={}
var edges: Dictionary={}
var distance: Callable
var low: Vector3
var step: float

static func union(a: float,b: float,k: float) -> float:
	var h:=clampf(.5+.5*(b-a)/k,0,1)
	return lerpf(b,a,h)-k*h*(1-h)

func value(at: Vector3i) -> float:
	if not field.has(at): field[at]=distance.call(low+Vector3(at)*step)
	return field[at]

func gradient(at: Vector3) -> Vector3:
	var e:=.0005
	return Vector3(distance.call(at+Vector3(e,0,0))-distance.call(at-Vector3(e,0,0)),distance.call(at+Vector3(0,e,0))-distance.call(at-Vector3(0,e,0)),distance.call(at+Vector3(0,0,e))-distance.call(at-Vector3(0,0,e)))/(2*e)

func vertex(a: Vector3i,b: Vector3i) -> int:
	var key:=[a,b] if str(a)<str(b) else [b,a]
	if edges.has(key): return edges[key]
	var at:=low+Vector3(a).lerp(Vector3(b),value(a)/(value(a)-value(b)))*step
	# Keep vertices on their grid edge so material boundaries on grid planes
	# remain level. Shared edge samples prevent cracks at joints and UV seams.
	var n:=gradient(at).normalized()
	var id:=points.size(); points.append(at); normals.append(n); edges[key]=id
	return id

func triangle(a: int,b: int,c: int) -> void:
	if (points[b]-points[a]).cross(points[c]-points[a]).length_squared()<1e-15: return
	if (points[b]-points[a]).cross(points[c]-points[a]).dot(normals[a]+normals[b]+normals[c])>0: indices.append_array(PackedInt32Array([a,c,b]))
	else: indices.append_array(PackedInt32Array([a,b,c]))

func build(sdf: Callable,origin: Vector3,cells: Vector3i,spacing: float) -> void:
	distance=sdf; low=origin; step=spacing
	for x in range(cells.x):
		for y in range(cells.y):
			for z in range(cells.z):
				var cell:=Vector3i(x,y,z)
				for tet in TETS:
					var inside: Array[Vector3i]=[]; var outside: Array[Vector3i]=[]
					for corner: int in tet:
						var at: Vector3i=cell+CORNERS[corner]
						if value(at)<0: inside.append(at)
						else: outside.append(at)
					if inside.size()==1: triangle(vertex(inside[0],outside[0]),vertex(inside[0],outside[1]),vertex(inside[0],outside[2]))
					elif inside.size()==3: triangle(vertex(outside[0],inside[0]),vertex(outside[0],inside[1]),vertex(outside[0],inside[2]))
					elif inside.size()==2:
						var a:=vertex(inside[0],outside[0]); var b:=vertex(inside[0],outside[1])
						var c:=vertex(inside[1],outside[0]); var d:=vertex(inside[1],outside[1])
						triangle(a,b,c); triangle(b,d,c)
