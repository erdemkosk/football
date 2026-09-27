extends RefCounted
## Small reusable mesh builder. Cosmetic surfaces never replace contact anchors.
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var colors:=PackedColorArray()
var uvs:=PackedVector2Array()
var indices:=PackedInt32Array()

func append(shape: Mesh,at: Vector3,scale_value: Vector3=Vector3.ONE,color: Color=Color.WHITE,rotation: Vector3=Vector3.ZERO) -> void:
	var data:=shape.surface_get_arrays(0)
	var basis:=Basis.from_euler(rotation).scaled(scale_value)
	var normal_basis:=basis.inverse().transposed(); var first:=vertices.size()
	for i in range(data[Mesh.ARRAY_VERTEX].size()):
		vertices.append(basis*data[Mesh.ARRAY_VERTEX][i]+at)
		normals.append((normal_basis*data[Mesh.ARRAY_NORMAL][i]).normalized())
		colors.append(color.srgb_to_linear())
		uvs.append(data[Mesh.ARRAY_TEX_UV][i] if data[Mesh.ARRAY_TEX_UV]!=null else Vector2.ZERO)
	for index in data[Mesh.ARRAY_INDEX]: indices.append(first+index)

func ellipsoid(at: Vector3,radii: Vector3,color: Color=Color.WHITE) -> void:
	var shape:=SphereMesh.new(); shape.radius=1; shape.height=2; shape.radial_segments=16; shape.rings=8
	append(shape,at,radii,color)

func tube(points: Array,radius: float,color: Color=Color.WHITE) -> void:
	for i in range(points.size()-1):
		var a: Vector3=points[i]; var b: Vector3=points[i+1]
		var shape:=CylinderMesh.new(); shape.top_radius=radius; shape.bottom_radius=radius; shape.height=a.distance_to(b); shape.radial_segments=6
		append(shape,(a+b)*.5,Vector3.ONE,color,Quaternion(Vector3.UP,(b-a).normalized()).get_euler())

func grid(points: Array,columns: int,tints: Array=[]) -> void:
	var first:=vertices.size(); var rows:=points.size()/columns
	for row in range(rows):
		for col in range(columns):
			var at: int=row*columns+col
			var left: Vector3=points[row*columns+posmod(col-1,columns-1)]
			var right: Vector3=points[row*columns+(col+1)%(columns-1)]
			var down: Vector3=points[maxi(0,row-1)*columns+col]
			var up: Vector3=points[mini(rows-1,row+1)*columns+col]
			var normal: Vector3=(up-down).cross(right-left).normalized()
			if normal.length()<.5: normal=Vector3.UP if row>rows/2 else Vector3.DOWN
			vertices.append(points[at]); normals.append(normal)
			colors.append((tints[at] if not tints.is_empty() else Color.WHITE).srgb_to_linear())
			uvs.append(Vector2(float(col)/(columns-1),1.0-float(row)/(rows-1)))
	for row in range(rows-1):
		for col in range(columns-1):
			var a:=first+row*columns+col
			indices.append_array(PackedInt32Array([a,a+1,a+columns,a+1,a+columns+1,a+columns]))

func finish() -> ArrayMesh:
	var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_TEX_UV]=uvs; arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func limb(rings: Array) -> ArrayMesh:
	var builder:=new(); var points: Array=[]
	for ring: Vector3 in rings:
		for sector in range(25):
			var angle:=sector*TAU/24.0
			points.append(Vector3(sin(angle)*ring.y,ring.x,-cos(angle)*ring.z))
	builder.grid(points,25)
	return builder.finish()
