extends RefCounted
const G=preload("res://scripts/geometry.gd")
const Meshes=preload("res://scripts/character_mesh.gd")
const Appearance=preload("res://scripts/player_appearance.gd")
const Hair=preload("res://scripts/hair_styles.gd")
const IRIS:=[Color("423426"),Color("665236"),Color("56716a"),Color("65768a"),Color("2c2925")]
static var cache: Dictionary={}
var head: MeshInstance3D
var mouth: MeshInstance3D
var brows: Array[MeshInstance3D]=[]
var lids: Array[Node3D]=[]
var iris_material: StandardMaterial3D
var detail_material: StandardMaterial3D
var blink_phase:=0.0
var expression:=0.0

func build(p) -> void:
	var material:=G.material(Color.WHITE,.86); material.vertex_color_use_as_albedo=true; material.metallic_specular=.23
	head=G.mesh(p.head_joint,Meshes.limb([Vector3(-.2,.01,.01),Vector3(.2,.01,.01)]),material,Vector3(0,.16,0)); head.name="SculptedFace"
	detail_material=G.material(Color("493124"),.93); detail_material.metallic_specular=.16
	for side in [-1,1]:
		var builder:=Meshes.new()
		builder.tube([Vector3(-.033,-.002,0),Vector3(-.016,.006,-.003),Vector3(.009,.008,-.004),Vector3(.031,0,0)],.0055)
		var brow:=G.mesh(p.head_joint,builder.finish(),detail_material,Vector3(side*.071,.232,-.176)); brow.name="Eyebrow"
		brow.visibility_range_end=24; brow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; brows.append(brow)
	var lips:=Meshes.new()
	lips.tube([Vector3(-.036,.002,.001),Vector3(-.016,0,-.002),Vector3(0,-.001,-.003),Vector3(.016,0,-.002),Vector3(.036,.002,.001)],.0035)
	mouth=G.mesh(p.head_joint,lips.finish(),G.material(Color("855348"),.93),Vector3(0,.073,-.170)); mouth.name="Mouth"
	mouth.visibility_range_end=25; mouth.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var white:=G.material(Color("d9d6c7"),.77); white.metallic_specular=.22
	iris_material=G.material(IRIS[0],.66); iris_material.metallic_specular=.28
	var pupil_material:=G.material(Color("171c1c"),.66)
	for side in [-1,1]:
		var eye:=Node3D.new(); p.head_joint.add_child(eye); eye.position=Vector3(side*.071,.193,-.175); p.eye_joints.append(eye)
		var form:=Node3D.new(); form.name="EyeForm"; eye.add_child(form); p.eye_forms.append(form)
		var lid:=Node3D.new(); form.add_child(lid); lids.append(lid)
		var sclera:=G.sphere(lid,.024,Vector3.ZERO,white); sclera.scale=Vector3(1,.38,.24)
		var iris:=G.sphere(lid,.010,Vector3(0,0,-.005),iris_material); iris.scale=Vector3(.88,.84,.24)
		var pupil:=G.sphere(lid,.005,Vector3(0,0,-.007),pupil_material); pupil.scale=Vector3(.8,1,.22)
		for part in [sclera,iris,pupil]: part.visibility_range_end=28; part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func model(identity: int,age: int) -> ArrayMesh:
	var band:=clampi((age-18)/5,0,5); var key:="%d/%d" % [identity,band]
	if cache.has(key): return cache[key]
	var traits:=Appearance.profile(identity); var builder:=Meshes.new()
	var skin: Color=Appearance.SKIN_TONES[traits.skin]
	var hair: Color=Hair.color_for(identity)
	var mature:=smoothstep(25,40,18+band*5)
	var jaw:=lerpf(.84,1.13,traits.jaw/4.0)
	var cheek:=lerpf(.94,1.055,traits.face/4.0)
	var rings: Array=[Vector3(-.222,.003,.025),Vector3(-.206,.065*jaw,.080),Vector3(-.170,.115*jaw,.127),Vector3(-.115,.149*jaw,.154),Vector3(-.055,.168*cheek,.171),Vector3(.015,.173*cheek,.179),Vector3(.070,.174,.180),Vector3(.130,.157,.166),Vector3(.183,.118,.133),Vector3(.220,.047,.060),Vector3(.226,.002,.003)]
	var points: Array=[]; var tints: Array=[]
	# Subdivide the jaw/cheeks so stubble has a fitted boundary rather than
	# separate balls around the chin. The crown keeps the shared scalp fit.
	for row in range(41):
		var segment:=row/4; var fraction: float=(row%4)/4.0
		var ring: Vector3=rings[mini(segment,10)].lerp(rings[mini(segment+1,10)],fraction)
		for sector in range(41):
			var angle:=sector*TAU/40.0; var front:=maxf(0,cos(angle))
			var z: float=-ring.z*(pow(front,.55) if cos(angle)>=0 else cos(angle))
			var at:=Vector3(sin(angle)*ring.y,ring.x,z)
			var color:=skin
			var cheek_flush:=exp(-pow((absf(at.x)-.11)/.06,2)-pow((at.y+.014)/.055,2))*front
			color=color.lerp(skin*Color(1.015,.91,.89),cheek_flush*.23)
			var beard_top: float=-.064-absf(sin(angle))*.020+cos(angle*4)*.006
			var beard_mask:=smoothstep(beard_top+.014,beard_top-.014,at.y)*smoothstep(-.05,.30,front)
			if traits.beard==0 or band==0: beard_mask=0
			elif traits.beard==1: beard_mask*=.27
			elif traits.beard==2: beard_mask*=.52
			elif traits.beard==4: beard_mask*=1-smoothstep(.065,.10,absf(at.x))
			elif traits.beard==5: beard_mask*=smoothstep(.065,.10,absf(at.x))
			# Lower lip stays clean; sideburns join the scalp above the jaw.
			if absf(at.x)<.043 and at.y>-.11: beard_mask*=.3
			var sideburn:=smoothstep(.13,.16,absf(at.x))*smoothstep(.07,.02,at.y)*smoothstep(-.12,-.06,at.y)
			if traits.beard>0 and band>0: beard_mask=maxf(beard_mask,sideburn*.7)
			if traits.beard in [2,3,4] and band>0:
				var moustache:=exp(-pow((at.y+.067)/.012,2))*(1-smoothstep(.032,.054,absf(at.x)))*front
				beard_mask=maxf(beard_mask,moustache*.62)
			var grain: float=.90+.10*sin(sector*17.3+row*31.1)
			color=color.lerp(hair.lerp(Color("a4a09b"),mature*.18),beard_mask*.66*grain)
			# Soft eye sockets, temple definition and age-dependent under-eye tone.
			var socket:=exp(-pow((absf(at.x)-.070)/.034,2)-pow((at.y-.026)/.022,2))*front
			color*=1-socket*(.065+mature*.055)
			points.append(at); tints.append(color)
	builder.grid(points,41,tints)
	var nose_width:=lerpf(.021,.033,traits.nose/4.0)
	var nose_length:=lerpf(.026,.043,traits.nose/4.0)
	builder.ellipsoid(Vector3(0,.013,-.176),Vector3(nose_width*.64,.044,.019),skin)
	builder.ellipsoid(Vector3(0,-.016,-.181-nose_length*.45),Vector3(nose_width,.024,nose_length*.72),skin)
	for side in [-1,1]:
		builder.ellipsoid(Vector3(side*.175,-.012,.005),Vector3(.027,.051,.025),skin)
		builder.ellipsoid(Vector3(side*.191,-.014,-.007),Vector3(.008,.026,.010),skin.darkened(.15))
	var mesh:=builder.finish()
	if cache.size()>=128: cache.erase(cache.keys()[0])
	cache[key]=mesh; return mesh

func refresh(p) -> void:
	var identity: int=p.appearance_id if p.appearance_id>=0 else p.shirt_number-1
	head.mesh=model(identity,p.age)
	detail_material.albedo_color=Hair.color_for(identity).lightened(.045)
	iris_material.albedo_color=IRIS[p.appearance.iris]
	var skin: Color=Appearance.SKIN_TONES[p.appearance.skin]
	mouth.material_override.albedo_color=skin.lerp(Color("72443d"),.38)
	expression=0; mouth.scale.y=1; mouth.rotation.z=0
	for lid in lids: lid.scale.y=1
	mouth.scale.x=lerpf(.88,1.14,p.appearance.face/4.0)
	for i in range(brows.size()):
		brows[i].rotation.z=(-1 if i==0 else 1)*lerpf(-.10,.15,p.appearance.brow/3.0)
		brows[i].scale.y=lerpf(.85,1.35,p.appearance.brow/3.0)
	blink_phase=float(Appearance.choice(identity,229,100))/17.0

func animate(p,delta: float) -> void:
	if not p.visible: return
	var phase:=fmod(p.motion_clock+blink_phase,4.1+blink_phase*.22)
	var blink:=sin(clampf(phase/.15,0,1)*PI) if phase<.15 else 0.0
	var effort: float=clampf((1-p.energy)*.5+p.match_fatigue,0,1)
	var happy: bool=p.celebration in ["fist","badge","crowd","heart","wings","salute","point","arms_crossed","cheer","embrace"]
	var want:=1.0 if happy else -.5 if p.celebration=="dejected" or p.reaction.kind=="miss" else -effort*.28
	expression=move_toward(expression,want,delta*4)
	for lid in lids: lid.scale.y=maxf(.06,1-blink*.96-effort*.10)
	mouth.scale.y=1+maxf(0,expression)*.6+effort*.5
	mouth.rotation.z=sin(p.motion_clock*.8+blink_phase)*absf(expression)*.035
	for i in range(brows.size()):
		var side: float=-1 if i==0 else 1
		brows[i].rotation.z=side*(lerpf(-.10,.15,p.appearance.brow/3.0)-expression*.10)
