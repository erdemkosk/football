extends "res://scripts/footballer.gd"
var assistant := false
var gesture := ""
var gesture_age := 0.0
var zone := 1
var flag: Node3D
var card: MeshInstance3D
var card_material: StandardMaterial3D
var whistle: MeshInstance3D

func _ready() -> void:
	official=true
	super._ready()
	marker.visible=false
	# Layer 16 is excluded by both football and player masks. Officials only
	# collide with the ground, so they cannot change a pass or block a runner.
	collision_layer=16
	collision_mask=1
	if assistant:
		flag=Node3D.new()
		right_hand.add_child(flag)
		G.rod(flag,Vector3.ZERO,Vector3(0,-0.94,0),0.018,G.material(Color("33383b")))
		for x in range(2):
			for y in range(2):
				G.block(flag,Vector3(0.22,0.18,0.015),Vector3(0.11+x*0.22,-0.60-y*0.18,0),G.material(Color("f6d637") if (x+y)%2==0 else Color("f58229")))
	else:
		card_material=G.material(Color("f5d439"))
		card=G.block(right_hand,Vector3(0.16,0.24,0.018),Vector3(0,-0.13,0),card_material)
		card.visible=false
		whistle=G.block(left_hand,Vector3(0.075,0.04,0.06),Vector3(0,-0.03,-0.025),G.material(Color("b5bfc4"),0.3))
		G.block(left_arm,Vector3(0.17,0.065,0.14),Vector3(0,-0.21,0),G.material(Color("111518")))

func signal_pose(value: String) -> void:
	if gesture!=value: gesture_age=0
	gesture=value

func animate(delta: float) -> void:
	super.animate(delta)
	gesture_age+=delta
	if card!=null: card.visible=gesture in ["yellow","red"]
	if assistant:
		# Carry the flag down while running; raise it only for a decision.
		right_arm.rotation=Vector3(0.05,0,0.12)
		right_elbow.rotation.x=0.12
		if gesture=="flag_up":
			right_arm.rotation=Vector3(PI,0,0.05+sin(gesture_age*8)*0.035)
			right_elbow.rotation.x=0.05
		elif gesture in ["offside_zone","flag_direction","flag_goal_kick","flag_corner"]:
			var angle := PI*0.5
			if gesture=="offside_zone": angle=[PI*0.25,PI*0.5,PI*0.75][zone]
			elif gesture=="flag_direction": angle=PI*0.75
			elif gesture=="flag_corner": angle=PI*0.25
			right_arm.rotation=Vector3(angle,0,0)
			right_elbow.rotation.x=0.05
	else:
		if gesture in ["whistle","full_time"]:
			left_arm.rotation=Vector3(1.60,-0.98,0)
			left_elbow.rotation.x=1.12
		elif gesture=="separate":
			var calm := sin(gesture_age*5)*0.12
			left_arm.rotation=Vector3(1.25+calm,0,-0.75)
			right_arm.rotation=Vector3(1.25+calm,0,0.75)
			left_elbow.rotation.x=0.22
			right_elbow.rotation.x=0.22
		elif gesture=="advantage":
			left_arm.rotation=Vector3(1.1,0,-0.25)
			right_arm.rotation=Vector3(1.1,0,0.25)
			left_elbow.rotation.x=0.1
			right_elbow.rotation.x=0.1
		elif gesture in ["point","penalty","goal"]:
			right_arm.rotation=Vector3(PI*0.5,0,0)
			right_elbow.rotation.x=0.05
		elif gesture in ["indirect","yellow","red"]:
			right_arm.rotation=Vector3(PI,0,-0.10)
			right_elbow.rotation.x=0.04
			if card!=null: card_material.albedo_color=Color("e74b34") if gesture=="red" else Color("f5d439")
