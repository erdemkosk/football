extends "res://tests/character_detail_check.gd"
const Body=preload("res://scripts/player_body_mesh.gd")

func body_gallery() -> void:
	game.camera.cull_mask=0; game.frontend.hide(); game.hud.hide()
	var canvas:=canvas_for("SEFC  /  DOĞAL VÜCUT ORANLARI")
	for i in range(4):
		var data: Dictionary=game.players[9].identity()
		data.appearance_id=[17,35,43,53][i]; data.age=26
		data.height_cm=[169,186,198,182][i]; data.weight_kg=[60,88,92,76][i]; data.keeper=i==2
		data.label=["KANAT · 169 cm / 60 kg","SANTRFOR · YAN GÖRÜNÜŞ","KALECİ · 198 cm / 92 kg","FORMA · SIRT GÖRÜNÜŞÜ"][i]
		var turn: float=[-.3,PI*.5,.25,PI-.3][i]
		studio(canvas,Rect2(20+i*355,110,330,680),data,false,turn)
	await capture("anatomy"); canvas.free()
	canvas=canvas_for("SEFC  /  HAREKET HALİNDE VÜCUT GEÇİŞLERİ")
	for i in range(3):
		var data: Dictionary=game.players[9].identity()
		data.appearance_id=35; data.height_cm=186; data.weight_kg=88; data.keeper=i==2
		data.label=["KOŞU", "ŞUT", "KALECİ · UZANMA"][i]
		studio(canvas,Rect2(20+i*475,110,450,680),data,false,-.3)
		var holder=canvas.get_child(canvas.get_child_count()-2)
		var p=holder.get_child(0).find_children("*","CharacterBody3D",true,false)[0]
		if i==0:
			p.prematch=false; p.velocity=Vector3(0,0,-6); p.sprinting=true; p.run_phase=1.2
			for frame in range(18): p.animate(1.0/60)
		if i==1:
			p.prematch=false; p.begin_kick(.85,.55,"laces")
			for frame in range(20): p.kick_timer=maxf(0,p.kick_timer-1.0/60); p.animate(1.0/60)
		if i==2:
			p.prematch=false; p.start_claim(); p.action_timer=.51; p.animate(.1)
		p.rig.rotation.y=-.3
	await capture("anatomy-motion"); canvas.free()

func run() -> void:
	for part: String in Body.PROFILES:
		var mesh:=Body.model(part); var data:=mesh.surface_get_arrays(0)
		var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array=data[Mesh.ARRAY_INDEX]
		var valid:=true; var wound:=true; var seam:=true
		for i in range(points.size()): valid=valid and points[i].is_finite() and absf(normals[i].length()-1)<.001
		for i in range(0,indices.size(),3):
			var a:=indices[i]; var b:=indices[i+1]; var c:=indices[i+2]
			var face: Vector3=-(points[b]-points[a]).cross(points[c]-points[a])
			wound=wound and face.length_squared()>1e-16 and face.dot(normals[a]+normals[b]+normals[c])>0
		var columns:=33 if part=="torso" else 25
		var rows: int=(Body.PROFILES[part].size()-1)*4+1
		for row in range(rows):
			var left:=row*columns; var right:=left+columns-1
			seam=seam and points[left].distance_to(points[right])<.00001 and normals[left].dot(normals[right])>.9999
		check(valid and wound and seam,part+": finite smooth normals, closed seams and outward triangles")
		check(mesh==Body.model(part) and mesh.get_surface_count()==1 and indices.size()/3<2300,part+": shared geometry within the per-part triangle budget")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false); game.ball.freeze=true
	var p=game.players[9]; var original: Dictionary=p.identity()
	p.body_language.enabled=false; p.idle_habit=0
	for height in [166,180,199]:
		p.height_cm=height; p.weight_kg=roundi(23*pow(height/100.0,2)); p.apply_build(); p.animate(1)
		var crown: Vector3=p.head_joint.to_global(Vector3(0,Body.CROWN,0))
		var chin: Vector3=p.head_joint.to_global(Vector3(0,-.062,0))
		var ratio: float=(height/100.0)/crown.distance_to(chin)
		check(ratio>5.8 and ratio<7.5 and absf(crown.y-height/100.0)<.035,"Adult head/body proportions preserve roster height: %d cm" % height)
		var contact: Vector3=p.head_joint.to_local(game.heading.head_point(p))
		check(contact.y>-.06 and contact.y<Body.CROWN and absf(contact.z)<.18,"Header contact remains inside the resized head")
	p.apply_identity(original)
	check(p.left_hand.get_parent()==p.left_elbow and p.left_hand.position==Vector3(0,-.30,0),"Visible palm retains an articulated save/ball attachment anchor")
	if "--visual" in OS.get_cmdline_user_args(): await body_gallery()
	print("PLAYER BODY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
