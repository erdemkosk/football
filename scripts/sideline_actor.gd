extends Node3D
const Spacing = preload("res://scripts/sideline_spacing.gd")
var avoid_people: Array[Vector3] = []
const G = preload("res://scripts/geometry.gd")
var kit_material: StandardMaterial3D
var bib_material: StandardMaterial3D
var team := 0
var role := "substitute"
var number := 12
var home := Vector3.ZERO
var body := Node3D.new()
var spine := Node3D.new()
var head := Node3D.new()
var arms: Array[Node3D] = []
var elbows: Array[Node3D] = []
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var seated := 1.0
var response := 0.0
var travel_phase := 0.0
var mode := "watch"
var target_point := Vector3.INF
var velocity := Vector3.ZERO
var pending_delta := 0.0
var substitution_board: Node3D

func _ready() -> void:
	var kit := G.material(Color("e2e9dd") if team==0 else Color("bd4936"))
	kit_material=kit
	var tracksuit := G.material(Color("1d3736") if team==0 else Color("263442"))
	var trim := G.material(Color("acc4b1") if team==0 else Color("d4aaa0"))
	var skin := G.material([Color("d6a079"),Color("8c593b"),Color("bb7e54"),Color("e2b28c")][number%4])
	var hair := G.material(Color("34302c") if role!="coach" else Color("68615a"))
	var boots := G.material(Color("20282c"))
	if role=="ball_boy":
		kit=G.material(Color("d96a2c"))
		kit_material=kit
	var top: Material = kit if role in ["substitute","ball_boy"] else tracksuit
	if role=="fourth": top=G.material(Color("dfd447"))
	add_child(body)
	body.position.y = 0.90
	body.add_child(spine)
	spine.position.y = 0.05
	G.cylinder(spine,0.23,0.49,Vector3(0,0.27,0),top,0.28)
	G.cylinder(spine,0.095,0.12,Vector3(0,0.57,0),skin)
	spine.add_child(head)
	head.position = Vector3(0,0.75,0)
	var face = G.sphere(head,0.19,Vector3.ZERO,skin)
	face.scale = Vector3(0.9,1.1,0.95)
	var haircut = G.sphere(head,0.19,Vector3(0,0.095,0.015),hair)
	haircut.scale = Vector3(0.91,0.57,0.96)
	G.sphere(head,0.038,Vector3(0,-0.015,-0.173),skin)
	for side in [-1,1]:
		G.sphere(head,0.016,Vector3(side*0.065,0.025,-0.168),boots)
	if role=="substitute" or role=="ball_boy":
		var bib := G.material(Color("75a884") if team==0 else Color("659eae"))
		bib_material=bib
		G.block(spine,Vector3(0.37,0.35,0.028),Vector3(0,0.27,-0.278),bib)
		G.block(spine,Vector3(0.36,0.35,0.028),Vector3(0,0.27,0.278),bib)
	else:
		G.block(spine,Vector3(0.016,0.43,0.02),Vector3(0,0.27,-0.266),trim)
		G.block(spine,Vector3(0.07,0.055,0.02),Vector3(-0.13,0.39,-0.265),trim)
	G.cylinder(body,0.23,0.20,Vector3(0,-0.02,0),tracksuit)
	for side in [-1,1]:
		var leg := Node3D.new()
		body.add_child(leg)
		leg.position = Vector3(side*0.14,0,0)
		legs.append(leg)
		G.cylinder(leg,0.10,0.36,Vector3(0,-0.17,0),tracksuit)
		var knee := Node3D.new()
		leg.add_child(knee)
		knee.position.y = -0.37
		knees.append(knee)
		G.sphere(knee,0.085,Vector3.ZERO,tracksuit)
		G.cylinder(knee,0.079,0.35,Vector3(0,-0.19,0),kit if role in ["substitute","ball_boy"] else tracksuit)
		var boot = G.sphere(knee,0.105,Vector3(0,-0.40,-0.055),boots)
		boot.scale = Vector3(0.85,0.65,1.6)
		var arm := Node3D.new()
		spine.add_child(arm)
		arm.position = Vector3(side*0.28,0.46,0)
		arms.append(arm)
		G.cylinder(arm,0.093,0.24,Vector3(0,-0.11,0),top)
		var elbow := Node3D.new()
		arm.add_child(elbow)
		elbow.position.y = -0.25
		elbows.append(elbow)
		G.sphere(elbow,0.072,Vector3.ZERO,skin if role in ["substitute","ball_boy"] else tracksuit)
		G.cylinder(elbow,0.065,0.26,Vector3(0,-0.12,0),skin if role in ["substitute","ball_boy"] else tracksuit)
		G.sphere(elbow,0.072,Vector3(0,-0.285,0),skin)
	if role=="assistant":
		var board = G.block(elbows[0],Vector3(0.24,0.32,0.035),Vector3(0,-0.26,-0.07),G.material(Color("b2b6a4")))
		board.rotation.x = -0.65
		G.block(board,Vector3(0.18,0.24,0.008),Vector3(0,0,-0.022),G.material(Color("e6e3cc") if role=="assistant" else Color("1d2426")))
	if role=="fourth":
		substitution_board=preload("res://scripts/substitution_board.gd").new()
		spine.add_child(substitution_board); substitution_board.position=Vector3(0,1.23,-.07)
	if role=="photographer":
		var camera = G.block(elbows[1],Vector3(0.16,0.11,0.18),Vector3(0,-0.22,-0.12),G.material(Color("1c2226")))
		G.cylinder(camera,0.045,0.08,Vector3(0,0,-0.12),G.material(Color("2a3236")))
	seated = 1.0 if role in ["substitute","physio"] else (0.42 if role=="photographer" else 0.0)
	rotation.y = PI*0.5
	# Resolve the authored rest pose before the actor is first rendered.
	travel_phase=fmod(number*2.399,TAU)
	animate_actor(1.0,number*.17,global_position+Vector3.LEFT*10,"watch",0)

func animate_actor(delta: float,clock: float,ball_position: Vector3,next_mode: String,intensity: float) -> void:
	mode = next_mode
	var blend := 1-exp(-delta*8)
	response = lerpf(response,intensity,blend)
	var seat_target := 1.0 if role in ["substitute","physio"] else (0.42 if role=="photographer" else 0.0)
	if mode in ["celebrate","disappointed","encourage","jog","collect"]: seat_target *= 1-response
	if mode in ["jog","collect","entry","handshake"]: seat_target=0
	seated = lerpf(seated,seat_target,1-exp(-delta*5))
	var destination := home
	if target_point.is_finite(): destination=target_point
	elif role=="coach":
		destination.z += sin(clock*0.38+team*1.7)*1.6*(1-response*0.75)
	elif role in ["substitute","physio"]: destination.x -= (1-seated)*0.85
	if role=="ball_boy": destination=Spacing.route(position,destination,avoid_people)
	var old := position
	position = position.lerp(destination,1-exp(-delta*(2.2 if mode in ["collect","carry"] else 3.5)))
	if mode in ["entry","handshake"]: position=old.move_toward(position,delta*6.5)
	if role=="ball_boy":
		position=old.move_toward(position,delta*7.2)
		position=Spacing.separate(position,avoid_people)
	velocity=(position-old)/maxf(delta,0.001)
	var speed := velocity.length()
	travel_phase += speed*delta*7
	var stride := sin(travel_phase)*minf(speed/1.1,1)*(1-seated)
	var look := ball_position-global_position
	var yaw := atan2(-look.x,-look.z)
	if role not in ["ball_boy","photographer","fourth"]: yaw=clampf(yaw,0.6,2.55)
	var body_yaw := yaw
	if (role=="coach" and mode=="watch" and speed>0.15) or (role=="ball_boy" and speed>0.35) or (mode=="entry" and speed>.2):
		var movement := position-old
		if movement.length()>0.001: body_yaw=atan2(-movement.x,-movement.z)
	rotation.y = lerp_angle(rotation.y,lerpf(body_yaw,PI*0.5,seated if role!="ball_boy" else 0.0),blend)
	body.position.y = lerpf(0.90,0.55,seated)
	spine.rotation = Vector3(-0.055-seated*0.10,0,sin(clock*1.5+number)*0.018)
	head.rotation.y = lerpf(head.rotation.y,clampf(yaw-rotation.y,-0.55,0.55),blend)
	for i in range(2):
		var side := -1.0 if i==0 else 1.0
		legs[i].rotation = Vector3(lerpf(stride*side*0.52,PI*0.5,seated),0,side*0.025)
		knees[i].rotation.x = lerpf(-0.12-maxf(0,-stride*side)*0.65,-PI*0.5,seated)
		var arm_target := Vector3(0.15+seated*0.40-stride*side*0.3,0,side*0.10)
		var elbow_target := Vector3(0.48+seated*0.12,0,0)
		if mode=="handshake":
			arm_target=Vector3(1.02,.48,-.08) if i==1 else Vector3(.15,0,-.16)
			elbow_target.x=.24+sin(clock*9)*.09 if i==1 else .35
		elif mode.begins_with("tactic_"):
			var beat := sin(clock*6+number)
			if mode=="tactic_attack":
				arm_target=Vector3(1.5+beat*.22,0,side*.28)
				elbow_target.x=.22+maxf(0,beat)*.35
				spine.rotation.x=.12
			elif mode=="tactic_defend":
				arm_target=Vector3(.85+beat*.10,0,side*.75)
				elbow_target.x=.30
			elif mode=="tactic_substitute":
				arm_target=Vector3(1.35,0,side*(.28+beat*.17))
				elbow_target.x=1.25
			else:
				arm_target=Vector3(.85,0,side*.5)
				elbow_target.x=.6+beat*.12
		elif mode=="celebrate":
			arm_target = arm_target.lerp(Vector3(0.12+sin(clock*5+number)*0.12,0,side*2.75),response)
			elbow_target.x = lerpf(elbow_target.x,0.28+sin(clock*7+number)*0.15,response)
			if role=="substitute" and number%3==1:
				arm_target = Vector3(0.95,0,-side*(0.34+sin(clock*10+number)*0.12))
				elbow_target.x = 0.95
			elif role=="substitute" and number%3==2 and i==1:
				arm_target.z = side*1.8
				elbow_target.x = 0.8+sin(clock*8+number)*0.35
		elif mode=="disappointed":
			arm_target = arm_target.lerp(Vector3(2.05,0,-side*0.28),response)
			elbow_target.x = lerpf(elbow_target.x,1.9,response)
			spine.rotation.x -= 0.16*response
		elif mode=="encourage":
			if role=="coach" and i==1:
				arm_target = arm_target.lerp(Vector3(1.65,0,-0.22),response)
				elbow_target.x = lerpf(elbow_target.x,0.15,response)
			else:
				arm_target = arm_target.lerp(Vector3(0.95,0,-side*(0.34+sin(clock*9+number)*0.12)),response)
				elbow_target.x = lerpf(elbow_target.x,0.95,response)
		elif role in ["assistant","fourth"] and i==0:
			arm_target.x = 0.55
			elbow_target.x = 0.95
		elif role=="photographer" and i==1:
			arm_target = Vector3(0.85,0,-0.55)
			elbow_target.x = 1.15
		elif mode=="pickup":
			arm_target=Vector3(1.15,0,-side*0.08)
			elbow_target.x=0.85
			spine.rotation.x=0.55
		elif mode=="carry":
			arm_target=Vector3(0.95,0,-side*0.42)
			elbow_target.x=1.05
		elif mode=="jog":
			arm_target = Vector3(0.22-stride*side*0.55,0,side*0.08)
			elbow_target.x = 0.55
		arms[i].rotation = arms[i].rotation.lerp(arm_target,blend)
		elbows[i].rotation = elbows[i].rotation.lerp(elbow_target,blend)
	if mode=="celebrate":
		var jump := maxf(0,sin(clock*(7.0+number*0.035)+number))
		body.position.y += jump*jump*0.18*response*(1-seated)
	if role=="coach" and mode=="watch":
		var directing := smoothstep(0.4,0.85,sin(clock*0.7))
		arms[1].rotation.x = lerpf(arms[1].rotation.x,1.4,directing*blend)
	if role=="fourth" and substitution_board.visible:
		rotation.y=PI*.5
		spine.rotation=Vector3.ZERO
		for i in range(2):
			arms[i].rotation=Vector3(2.95,0,-.4 if i==0 else .4)
			elbows[i].rotation=Vector3(.16,0,0)

func hand_center() -> Vector3:
	if elbows.size()>1: return elbows[1].to_global(Vector3(0,-0.22,0))
	return global_position+Vector3(0,1.05,0)
