extends SceneTree
## Validate deformed geometry, not just valid bone indices: wrists must never
## share a triangle with thighs, and no phantom strip may join the lower legs.
const Build=preload("res://tools/build_player_body.gd")
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func topology(p) -> void:
	var welded: Dictionary={}; var adjacency: Dictionary={}; var bindings: Dictionary={}
	var valid:=true; var continuous:=true; var count:=0
	for surface in range(p.shirt_skin.BODY.get_surface_count()):
		var a: Array=p.shirt_skin.BODY.surface_get_arrays(surface)
		var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX]; var ns: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
		var ids: PackedInt32Array=a[Mesh.ARRAY_INDEX]; var bones: PackedInt32Array=a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]; var local: Array[int]=[]
		count+=v.size()
		for i in range(v.size()):
			var key:=Vector3i((v[i]*100000).round()); var bound: Dictionary={}; var sum:=0.0
			for j in range(4):
				var bone:=bones[i*4+j]; var weight:=weights[i*4+j]
				valid=valid and bone>=0 and bone<p.shirt_skin.REST.size() and weight>=0 and is_finite(weight)
				if weight>0: bound[bone]=weight
				sum+=weight
			valid=valid and v[i].is_finite() and ns[i].is_finite() and absf(ns[i].length()-1)<.001 and absf(sum-1)<.0001
			if bindings.has(key): continuous=continuous and bindings[key]==bound
			else: bindings[key]=bound
			if not welded.has(key): welded[key]=welded.size()
			local.append(welded[key])
		for i in range(0,ids.size(),3):
			for j in range(3):
				var first:=local[ids[i+j]]; var second:=local[ids[i+(j+1)%3]]
				if not adjacency.has(first): adjacency[first]=[]
				adjacency[first].append(second)
	var pending: Array[int]=[0]; var reached: Dictionary={}
	while not pending.is_empty():
		var at: int=pending.pop_back()
		if reached.has(at): continue
		reached[at]=true
		for next: int in adjacency.get(at,[]):
			if not reached.has(next): pending.append(next)
	check(reached.size()==adjacency.size(),"Neck, torso, both arms and both legs form one welded body")
	check(valid and count<16000,"All body surfaces retain finite normals and normalized weights in the shared 15-bone budget")
	check(continuous,"Skin/shorts/sock seams use identical bindings and cannot split while bending")
	var skin: Array=p.shirt_skin.BODY.surface_get_arrays(0); var coverage:=true
	for i in range(skin[Mesh.ARRAY_VERTEX].size()):
		var height: float=skin[Mesh.ARRAY_VERTEX][i].y+1.22
		var alpha: float=skin[Mesh.ARRAY_COLOR][i].a
		if height>1.36 and height<1.50: coverage=coverage and alpha<.1
		if height>1.63 or height<1.05: coverage=coverage and alpha>.99
	check(coverage,"Cloth-covered skin stays masked while neck, wrists and bare knees remain opaque")
func geometry(p) -> Dictionary:
	p.shirt_skin.sync_pose()
	var longest:=0.0; var finite:=true; var bridges:=false
	for surface in range(p.shirt_skin.BODY.get_surface_count()):
		var a: Array=p.shirt_skin.BODY.surface_get_arrays(surface)
		var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX]; var ids: PackedInt32Array=a[Mesh.ARRAY_INDEX]
		var bones: PackedInt32Array=a[Mesh.ARRAY_BONES]; var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
		var transformed:=PackedVector3Array()
		for i in range(v.size()):
			var point:=Vector3.ZERO; var sum:=0.0
			for j in range(4):
				point+=(p.shirt_skin.poses[bones[i*4+j]]*v[i])*weights[i*4+j]
				sum+=weights[i*4+j]
			finite=finite and point.is_finite() and absf(sum-1)<.0001
			transformed.append(point)
		for i in range(0,ids.size(),3):
			var arms:=false; var legs:=false; var left:=false; var right:=false; var highest:=-INF
			for corner in range(3):
				var vertex:=ids[i+corner]
				highest=maxf(highest,v[vertex].y+1.22)
				for slot in range(4):
					if weights[vertex*4+slot]<.01: continue
					var bone:=bones[vertex*4+slot]
					arms=arms or bone in [1,2,3,4,10,11]
					legs=legs or bone in [6,7,8,9,12,13]
					left=left or bone in [6,8,12]; right=right or bone in [7,9,13]
			# Cloth can stretch at the crotch. A triangle joining a wrist to a
			# thigh, or one calf to the other, is always an accidental connection.
			bridges=bridges or (arms and legs and highest<1.12) or (left and right and highest<.75)
			for j in range(3): longest=maxf(longest,transformed[ids[i+j]].distance_to(transformed[ids[i+(j+1)%3]]))
	return {"longest":longest,"finite":finite,"bridges":bridges}
func run() -> void:
	var gap:=true
	for y in [.15,.3,.5,.7]: gap=gap and Build.sample(Vector3(0,y,0))>.015
	check(gap,"The model has no extra strip of leg surface on its centre plane")
	var p=load("res://scripts/footballer.gd").new(); root.add_child(p)
	topology(p)
	var longest:=0.0; var finite:=true; var bridges:=false
	p.velocity=Vector3.FORWARD*9
	for phase in [0.0,PI*.5,PI,PI*1.5]:
		p.run_phase=phase; p.motion_transition.reset(); p.animate(1)
		var result:=geometry(p)
		longest=maxf(longest,result.longest); finite=finite and result.finite
		bridges=bridges or result.bridges
	for foot in [0,1]:
		p.ball_actions.foot=foot
		p.begin_kick(.95,.46)
		for progress in [.18,.4,.65]:
			p.kick_timer=p.kick_duration*(1-progress); p.motion_transition.reset(); p.animate(1)
			var result:=geometry(p)
			longest=maxf(longest,result.longest); finite=finite and result.finite
			bridges=bridges or result.bridges
	print("SKIN maximum deformed edge=",longest)
	check(finite and not bridges,"Running and either-foot shots keep normalized, finite skin without wrist/thigh or calf/calf bridges")
	check(p.shirt_skin.body.get_surface_override_material(0)==p.kit_materials.skin,"Bare arms and knees share one skin material")
	print("PLAYER SKIN BINDING CHECK: %d checks, %d failures" % [checks,failures])
	p.free(); quit(1 if failures else 0)
