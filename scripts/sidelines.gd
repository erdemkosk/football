extends Node3D
const G = preload("res://scripts/geometry.gd")
const Actor = preload("res://scripts/sideline_actor.gd")
var actors: Array[Node3D] = []
var clock := 0.0
var event_kind := ""
var event_team := 0
var event_age := 100.0
var event_duration := 0.0
var attention := 0.0
var team_focus := 0

func _ready() -> void:
	for team in range(2): build_dugout(team)
	reset()

func build_dugout(team: int) -> void:
	var z := -12.0 if team==0 else 12.0
	var shelter := Node3D.new()
	add_child(shelter)
	shelter.position = Vector3(37.15,0,z)
	shelter.rotation.y = PI*0.5
	var frame := G.material(Color("637878"),0.42)
	var trim := G.material(Color("244d43") if team==0 else Color("804738"))
	var chair := G.material(Color("315f51") if team==0 else Color("874e43"))
	var glass := G.material(Color(0.52,0.70,0.73,0.18),0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	G.block(shelter,Vector3(10.5,0.08,2.15),Vector3(0,0.04,0),G.material(Color("424e4c")))
	for x in [-5.15,5.15]:
		for depth in [-0.95,0.95]:
			G.rod(shelter,Vector3(x,0.06,depth),Vector3(x,2.30,depth),0.045,frame)
		var panel = G.block(shelter,Vector3(0.035,2.10,1.88),Vector3(x,1.20,0),glass)
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		G.rod(shelter,Vector3(x,2.3,-0.95),Vector3(x,2.3,0.95),0.045,frame)
	var back = G.block(shelter,Vector3(10.3,1.98,0.035),Vector3(0,1.21,0.96),glass)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var roof = G.block(shelter,Vector3(10.5,0.045,2.15),Vector3(0,2.32,0),glass)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for depth in [-1.03,0.99]: G.block(shelter,Vector3(10.55,0.14,0.08),Vector3(0,2.31,depth),frame)
	G.block(shelter,Vector3(10.48,0.26,0.065),Vector3(0,2.29,-1.05),trim)
	var label := Label3D.new()
	label.text = "KIYI SPOR  ·  YEDEK KULÜBESİ" if team==0 else "ATLAS FC  ·  YEDEK KULÜBESİ"
	label.font_size = 48
	label.pixel_size = 0.0035
	label.outline_size = 0
	label.modulate = Color("e3e8dc")
	shelter.add_child(label)
	label.position = Vector3(0,2.29,-1.092)
	label.rotation.y = PI
	for i in range(7):
		var x := -3.75+i*1.25
		G.block(shelter,Vector3(0.66,0.15,0.67),Vector3(x,0.44,0.02),chair)
		var seatback = G.block(shelter,Vector3(0.66,0.69,0.13),Vector3(x,0.79,0.38),chair)
		seatback.rotation.x = 0.12
		for edge in [-0.33,0.33]:
			G.rod(shelter,Vector3(x+edge,0.12,0.20),Vector3(x+edge,0.73,0.20),0.024,frame)
			G.rod(shelter,Vector3(x+edge,0.73,0.20),Vector3(x+edge,0.73,-0.25),0.024,frame)
		add_actor(team,"substitute",12+i,shelter.to_global(Vector3(x,0.04,0.04)))
	add_actor(team,"coach",24+team,Vector3(33.75,0,z))
	add_actor(team,"assistant",26+team,Vector3(34.65,0,z+4.6))
	add_actor(team,"physio",28+team,Vector3(37.1,0,z-5.9))
	G.block(self,Vector3(0.62,0.48,0.63),Vector3(37.2,0.24,z-5.9),chair)
	var kit = G.block(self,Vector3(0.45,0.36,0.65),Vector3(36.6,0.22,z-5.65),G.material(Color("a05543")))
	G.block(kit,Vector3(0.012,0.21,0.055),Vector3(-0.23,0,0),G.material(Color("ede9dd")))
	G.block(kit,Vector3(0.014,0.055,0.21),Vector3(-0.23,0,0),G.material(Color("ede9dd")))
	G.block(self,Vector3(0.62,0.62,0.62),Vector3(36.9,0.34,z+5.75),G.material(Color("56768b")))
	G.block(self,Vector3(0.66,0.06,0.66),Vector3(36.9,0.68,z+5.75),G.material(Color("dedfd3")))
	for i in range(3):
		G.cylinder(self,0.055,0.23,Vector3(36.65+i*0.17,0.835,z+5.75),G.material(Color("b0c8cb")))
		G.cylinder(self,0.035,0.045,Vector3(36.65+i*0.17,0.97,z+5.75),trim)

func add_actor(team: int,role: String,number: int,location: Vector3) -> void:
	var actor = Actor.new()
	actor.team = team
	actor.role = role
	actor.number = number
	actor.name = "%s_%d_%d" % [role,team,number]
	add_child(actor)
	actor.home = location
	actor.position = location
	actors.append(actor)

func reset() -> void:
	clock = 0
	event_kind = ""
	event_age = 100
	event_duration = 0
	attention = 0
	for actor in actors:
		actor.position = actor.home
		actor.response = 0
		actor.seated = 1.0 if actor.role in ["substitute","physio"] else 0.0
		actor.animate_actor(1,clock,Vector3.ZERO,"watch",0)

func react(kind: String,team: int,_location: Vector3) -> void:
	if event_kind=="goal" and event_age<event_duration and kind!="goal": return
	event_kind = kind
	event_team = team
	event_age = 0
	event_duration = 12.0 if kind=="goal" else (2.5 if kind=="save" else 1.8)

func update(delta: float,ball_position: Vector3,ball_velocity: Vector3,team: int,playing: bool) -> void:
	clock += delta
	event_age += delta
	team_focus = team
	var pressure := 0.0
	if playing and absf(ball_position.z)>27 and absf(ball_position.x)<25:
		pressure = clampf((absf(ball_position.z)-27)/20,0,1)
		if ball_velocity.length()>16: pressure = maxf(pressure,0.65)
	attention = lerpf(attention,pressure,1-exp(-delta*3))
	for actor in actors:
		var actor_mode := "encourage" if attention>0.35 else "watch"
		var intensity := attention*0.75
		var delay := float(actor.number%7)*0.065
		var age := event_age-delay
		if age>0 and age<event_duration:
			var strength := smoothstep(0,0.30,age)*(1-smoothstep(event_duration-0.7,event_duration,age))
			if event_kind=="goal":
				actor_mode = "celebrate" if actor.team==event_team else "disappointed"
				intensity = strength
			elif event_kind=="save":
				actor_mode = "encourage" if actor.team==event_team else "disappointed"
				intensity = strength*0.85
			elif event_kind=="miss":
				actor_mode = "disappointed" if actor.team==event_team else "encourage"
				intensity = strength*0.85
			elif event_kind=="shot":
				actor_mode = "encourage"
				intensity = strength*0.9
		actor.animate_actor(delta,clock,ball_position,actor_mode,intensity)
