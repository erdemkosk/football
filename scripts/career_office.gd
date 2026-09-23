extends SubViewportContainer
const G=preload("res://scripts/geometry.gd")
var viewport: SubViewport
var people: Array=[]
var age := 0.0
var reaction := "listen"
var reaction_age := 0.0
var club_data: Dictionary={}
var guest_data: Dictionary={}
var pen: Node3D

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; stretch=true
	viewport=SubViewport.new(); viewport.size=Vector2i(size); viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_2X; add_child(viewport)
	var root:=Node3D.new(); viewport.add_child(root)
	var env:=WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("9cb4b4")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("d4e2db"); env.environment.ambient_light_energy=.6; root.add_child(env)
	var lamp:=DirectionalLight3D.new(); lamp.rotation_degrees=Vector3(-45,-35,0); lamp.light_energy=1.5; lamp.light_color=Color("fff0d5"); lamp.shadow_enabled=true; root.add_child(lamp)
	var fill:=OmniLight3D.new(); fill.position=Vector3(0,3,1); fill.omni_range=8; fill.light_energy=.75; root.add_child(fill)
	var wood:=G.material(Color("846d50")); var dark:=G.material(Color("163532")); var cream:=G.material(Color("d9d8c7")); var metal:=G.material(Color("bea168"),.35)
	G.block(root,Vector3(10,.15,9),Vector3(0,-.1,0),wood)
	G.block(root,Vector3(10,4,.2),Vector3(0,1.9,-3),dark)
	for i in range(32): G.block(root,Vector3(.035,3.8,.1),Vector3(-4.9+i*.31,1.9,-2.85),wood)
	G.block(root,Vector3(.2,4,8),Vector3(-4,1.9,0),cream)
	var glass:=G.material(Color("a5c8d0"))
	G.block(root,Vector3(.1,2.5,4.8),Vector3(-3.87,2,0),glass)
	for z in [-1.8,-.2,1.4]: G.block(root,Vector3(.14,2.7,.06),Vector3(-3.79,2,z),dark)
	for i in range(8): G.block(root,Vector3(.13,.3+i%3*.2,.55),Vector3(-3.8,.9,i*.6-2),G.material(Color("6b8b8d")))
	# A framed crest, cabinet and trophies establish a club office.
	G.block(root,Vector3(1.75,1.65,.13),Vector3(0,2.25,-2.75),metal)
	var badge:=Sprite3D.new(); badge.texture=preload("res://scripts/kit_graphics.gd").badge(club_data.get("badge_id",0),Color(club_data.get("primary","193d39")),Color(club_data.get("accent","e5ece5")))
	badge.pixel_size=.0057; badge.position=Vector3(0,2.25,-2.66); root.add_child(badge)
	G.block(root,Vector3(1.7,1.3,.55),Vector3(2.8,.6,-2.35),wood)
	for x in [2.25,2.8,3.35]:
		G.block(root,Vector3(.3,.08,.3),Vector3(x,1.28,-2.3),dark)
		G.cylinder(root,.04,.3,Vector3(x,1.48,-2.3),metal)
		G.cylinder(root,.15,.20,Vector3(x,1.7,-2.3),metal,.22)
	G.cylinder(root,.23,.45,Vector3(-2.9,.21,-2),cream)
	for n in range(7):
		G.rod(root,Vector3(-2.9,.4,-2),Vector3(-2.9+sin(n*2)*.28,1.1+float(n%3)*.2,-2+cos(n*2)*.28),.025,dark)
		G.sphere(root,.20,Vector3(-2.9+sin(n*2)*.28,1.1+float(n%3)*.2,-2+cos(n*2)*.28),G.material(Color("385e46")))
	G.block(root,Vector3(2.1,.12,2.45),Vector3(0,.98,.2),wood)
	for x in [-.8,.8]:
		for z in [-.8,1.2]: G.block(root,Vector3(.075,.95,.075),Vector3(x,.46,z),dark)
	G.block(root,Vector3(.44,.018,.60),Vector3(.80,1.05,.05),cream)
	for i in range(5): G.block(root,Vector3(.29,.003,.012),Vector3(.79,1.062,-.14+i*.055),G.material(Color("75837d")))
	pen=Node3D.new(); root.add_child(pen); pen.position=Vector3(.81,1.075,.1)
	G.rod(pen,Vector3.ZERO,Vector3(.14,.09,.02),.012,dark)
	for x in [-.65,.65]: G.cylinder(root,.07,.12,Vector3(x,1.1,-.1),cream)
	for i in range(2):
		var p=preload("res://scripts/footballer.gd").new(); p.number=8+i; p.team=i; root.add_child(p)
		p.collision_layer=0; p.collision_mask=0; p.marker.visible=false
		if i==1 and not guest_data.is_empty(): p.apply_identity(guest_data)
		p.apply_kit({"primary":Color("263b45") if i==0 else Color("e2dbc9"),"accent":Color("bda26c"),"shorts":Color("1c303a"),"pattern":0,"club_id":club_data.get("badge_id",0)})
		p.position=Vector3(-1.35 if i==0 else 1.35,.54-.85*p.body_scale.y,.30)
		p.rig.rotation.y=-PI/2 if i==0 else PI/2
		people.append(p)
		G.block(root,Vector3(.65,.1,.7),Vector3(p.position.x,.43,.3),dark)
		G.block(root,Vector3(.10,.8,.7),Vector3(p.position.x+(-.28 if i==0 else .28),.85,.3),dark)
		for z in [0,.6]: G.block(root,Vector3(.08,.42,.08),Vector3(p.position.x,.2,z),metal)
	var camera:=Camera3D.new(); camera.position=Vector3(4.4,3.1,5.8); root.add_child(camera); camera.look_at(Vector3(0,1.15,0)); camera.fov=43; camera.current=true

func react(value: String) -> void:
	reaction=value; reaction_age=0

func _process(delta: float) -> void:
	if viewport==null: return
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if not is_visible_in_tree(): return
	age+=delta; reaction_age+=delta
	for i in range(people.size()):
		var p=people[i]
		p.left_leg.rotation=Vector3(1.35,0,0); p.right_leg.rotation=Vector3(1.35,0,0)
		p.left_knee.rotation=Vector3(-1.4,0,0); p.right_knee.rotation=Vector3(-1.4,0,0)
		p.spine.rotation.x=-.08+sin(age*1.6+i)*.015
		p.head_joint.rotation.x=sin(age*.7+i)*.045
		p.head_joint.rotation.y=0
		p.left_arm.rotation=Vector3(.62,0,-.18); p.right_arm.rotation=Vector3(.65,0,.15)
		p.left_elbow.rotation.x=.65; p.right_elbow.rotation.x=.75
		var gesture:=sin(minf(reaction_age,1.6)/1.6*PI)
		if reaction=="offer": p.right_arm.rotation.x+=gesture*.5; p.right_arm.rotation.z+=gesture*.25
		if reaction=="reject": p.head_joint.rotation.y=sin(reaction_age*8)*gesture*.18
		if reaction in ["sign","signed"]:
			if i==1:
				p.spine.rotation.x=-.15; p.head_joint.rotation.x=.16
				pen.position=Vector3(.81+sin(age*11)*.018,1.075,.10+sin(age*7)*.014)
				reach(p,pen.position)
			else: p.head_joint.rotation.x=sin(age*3)*.07

func reach(p,target: Vector3) -> void:
	# Two-bone arm pose keeps the writing hand on the document, across body sizes.
	var shoulder: Vector3=p.right_arm.position
	var offset: Vector3=p.rig.to_local(target)-shoulder
	var distance:=clampf(offset.length(),.04,.529)
	var direction:=offset.normalized()
	var along: float=(.24*.24-.29*.29+distance*distance)/(2*distance)
	var height:=sqrt(maxf(0,.24*.24-along*along))
	var pole:=Vector3.RIGHT-direction*direction.dot(Vector3.RIGHT)
	if pole.length()<.01: pole=Vector3.BACK-direction*direction.dot(Vector3.BACK)
	var elbow:=direction*along+pole.normalized()*height
	p.right_arm.quaternion=Quaternion(Vector3.DOWN,elbow.normalized())
	p.right_elbow.quaternion=Quaternion(Vector3.DOWN,p.right_arm.basis.inverse()*(direction*distance-elbow).normalized())
