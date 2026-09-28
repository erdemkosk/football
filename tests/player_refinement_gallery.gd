extends "res://tests/character_detail_check.gd"
## Close views for reviewing facial shape and continuous, posed fingers.
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(); return
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.ball.freeze=true; game.camera.cull_mask=0; game.frontend.hide(); game.hud.hide()
	var canvas:=canvas_for("SEFC  /  YÜZ, SAÇ VE EL DETAYLARI")
	for i in range(7):
		var data: Dictionary=game.players[9].identity()
		data.appearance_id=[3,19,35,43,3,3,3][i]; data.age=28; data.keeper=i==6
		data.label=["Çene ve göz kapakları","Burun ve yan profil","Saç çizgisi ve tutamlar","Yüz çeşitliliği","Dinlenme · hafif kıvrık","Koşu · kapanan parmaklar","Kaleci · açık eldiven"][i]
		var rect:=Rect2(18+i*355,90,330,320) if i<4 else Rect2(40+(i-4)*470,480,410,300)
		studio(canvas,rect,data,true,.8 if i==1 else .15)
		var holder=canvas.get_child(canvas.get_child_count()-2)
		var viewport: SubViewport=holder.get_child(0)
		var p=viewport.find_children("*","CharacterBody3D",true,false)[0]
		var camera: Camera3D=viewport.get_camera_3d()
		var center: Vector3=p.head_joint.to_global(Vector3(0,.16,0))
		camera.keep_aspect=Camera3D.KEEP_WIDTH; camera.size=.47
		if i>=4:
			p.left_arm.rotation.z=-.45; p.left_elbow.rotation.x=0
			p.shirt_skin.sync_pose()
			p.hand_pose.restore(p,Vector4(.20,.20,0,0) if i==4 else Vector4(.65,.65,0,0) if i==5 else Vector4(.03,.03,.8,.8))
			center=p.left_hand.to_global(Vector3(0,-.027,0)); camera.size=.23
		camera.global_position=center+Vector3(.06,.015,-.7)
		camera.look_at(center)
	await capture("refinement-closeups"); canvas.free()
	game.free(); quit()
