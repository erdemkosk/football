extends "res://scripts/kit_preview.gd"
const G=preload("res://scripts/geometry.gd")
var mode:=0
var game
var ball_mesh: MeshInstance3D
var partners: Array=[]

func _ready() -> void:
	super._ready()
	viewport.gui_disable_input=true
	var scene=player.get_parent()
	player.apply_identity(game.clubs.member(0,game.clubs.lineups[0][9]))
	player.apply_kit(game.clubs.kit(0)); player.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	player.facing=Vector3.BACK; player.rig.rotation.y=PI
	for child in scene.get_children():
		if child is Camera3D:
			child.size=6.3; child.position=Vector3(5,4.6,-6.2); child.look_at(Vector3(0,.5,.3))
	G.block(scene,Vector3(6.6,.10,5.0),Vector3(0,-.12,0),G.material(Color("234e44")))
	var line=G.material(Color("9bb9a8"))
	for x in [-3.0,3.0]: G.block(scene,Vector3(.025,.01,4.5),Vector3(x,-.06,0),line)
	for z in [-2.25,2.25]: G.block(scene,Vector3(6,.01,.025),Vector3(0,-.06,z),line)
	ball_mesh=G.sphere(scene,.13,Vector3.ZERO,G.material(Color("f5f5e9")))
	for z in [-.10,.10]: G.sphere(ball_mesh,.048,Vector3(0,.065,z),G.material(Color("152531")))
	if mode==0:
		for i in range(4): G.cylinder(scene,.14,.28,Vector3(-1.3+i*.85,.08,-.8),G.material(Color("efb976")),.025)
		add_partner(Vector3(-2,0,1.1),6,0); add_partner(Vector3(2,0,1.1),8,0)
	else:
		for x in [-1.3,1.3]: G.rod(scene,Vector3(x,0,2),Vector3(x,1.65,2),.035,line)
		G.rod(scene,Vector3(-1.3,1.65,2),Vector3(1.3,1.65,2),.035,line)
		for i in range(14): G.rod(scene,Vector3(-1.3+i*.2,0,2.35),Vector3(-1.3+i*.2,1.5,2.35),.006,line)
		for i in range(8): G.rod(scene,Vector3(-1.3,i*.2,2.35),Vector3(1.3,i*.2,2.35),.006,line)
		add_partner(Vector3(0,0,1.8),0,1)
		if mode==1: add_partner(Vector3(2.3,0,-.4),8,0)
		else:
			for i in range(3): add_partner(Vector3(-.6+i*.6,0,.8),2+i,1)
	player.position=Vector3(-.45,0,-1.2)
	_process(0)

func add_partner(at: Vector3,index: int,team: int) -> void:
	var actor=preload("res://scripts/footballer.gd").new()
	actor.team=team; actor.keeper=index==0; actor.number=index+1
	player.get_parent().add_child(actor)
	actor.apply_identity(game.clubs.member(team,game.clubs.lineups[team][index])); actor.apply_kit(game.clubs.kit(team))
	actor.position=at; actor.collision_layer=0; actor.collision_mask=0; actor.marker.hide()
	actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	partners.append(actor)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(ball_mesh): return
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if not is_visible_in_tree(): return
	age+=delta
	var t:=fposmod(age,3.6)/3.6
	player.motion_clock+=delta; player.velocity=Vector3.ZERO
	player.action_timer=0; player.pose="run"; player.celebration=""
	player.position=Vector3(-.45,0,-1.2)
	if mode==0:
		player.position=Vector3(sin(age*.7)*.9,0,-1.1)
		player.velocity=Vector3(0,0,2.6); player.run_phase+=delta*5.5
		player.animate(delta); player.rig.rotation.y=PI
		ball_mesh.position=player.position+Vector3(.2,.13,.52+.10*sin(age*5.5))
	elif mode==1:
		player.position=Vector3(-.4,maxf(0,sin((t-.27)*PI*3))*.5 if t>.27 and t<.60 else 0,0)
		player.animate(delta); player.rig.rotation.y=PI-.3
		player.left_arm.rotation.z=-.85; player.right_arm.rotation.z=.85
		player.spine.rotation.x=-.24+sin(t*TAU)*.18
		var start:=Vector3(2.3,.15,-.4)
		var contact:=Vector3(-.4,2.0,0)
		ball_mesh.position=start.lerp(contact,minf(1,t/.5))+Vector3.UP*sin(minf(1,t/.5)*PI)*.7 if t<.5 else contact.lerp(Vector3(.6,.4,2.3),(t-.5)*2)
	else:
		player.animate(delta); player.rig.rotation.y=PI-.2
		var strike:=sin(smoothstep(.18,.48,t)*PI)
		player.right_leg.rotation.x=.75*strike; player.right_knee.rotation.x=-.2
		player.left_arm.rotation.z=-.75*strike; player.right_arm.rotation.z=.8*strike
		var flight:=clampf((t-.33)/.6,0,1)
		ball_mesh.position=Vector3(-.2,.13,-.65).lerp(Vector3(.95,.65,2.3),flight)+Vector3.UP*sin(flight*PI)*1.7
	ball_mesh.rotate_x(delta*4)
	for actor in partners:
		actor.motion_clock+=delta; actor.animate(delta)
		if mode==2 and not actor.keeper:
			actor.left_arm.rotation=Vector3(-.2,0,-.2); actor.right_arm.rotation=Vector3(-.2,0,.2)
			actor.left_elbow.rotation.x=1.7; actor.right_elbow.rotation.x=1.7
