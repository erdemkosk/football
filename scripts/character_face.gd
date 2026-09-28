extends RefCounted
const G=preload("res://scripts/geometry.gd")
const Meshes=preload("res://scripts/character_mesh.gd")
const Body=preload("res://scripts/player_body_mesh.gd")
const Appearance=preload("res://scripts/player_appearance.gd")
const Hair=preload("res://scripts/hair_styles.gd")
const IRIS:=[Color("423426"),Color("665236"),Color("56716a"),Color("65768a"),Color("2c2925")]
static var cache: Dictionary={}
static var detail_cache: Dictionary={}
const FACE_SEGMENTS:=64
const FACE_ROWS:=40
var head: MeshInstance3D
var mouth: MeshInstance3D
var brows: Array[MeshInstance3D]=[]
var lids: Array[Node3D]=[]
var eye_rims: Array[MeshInstance3D]=[]
var iris_material: StandardMaterial3D
var detail_material: StandardMaterial3D
var blink_phase:=0.0
var expression:=0.0

func build(p) -> void:
	var material:=preload("res://scripts/skin_material.gd").new(true)
	head=G.mesh(p.head_joint,Meshes.limb([Vector3(-.2,.01,.01),Vector3(.2,.01,.01)]),material,Vector3(0,.16,0)); head.name="SculptedFace"
	detail_material=G.material(Color("493124"),.93); detail_material.metallic_specular=.12
	for side in [-1,1]:
		var brow:=G.mesh(p.head_joint,ArrayMesh.new(),detail_material,Vector3(side*.071,.232,0)); brow.name="Eyebrow"
		brow.visibility_range_end=24; brow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; brows.append(brow)
	mouth=G.mesh(p.head_joint,ArrayMesh.new(),preload("res://scripts/skin_material.gd").new(true),Vector3(0,.073,0)); mouth.name="Mouth"
	mouth.visibility_range_end=25; mouth.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var white:=G.material(Color("d4d0bd"),.82); white.metallic_specular=.15
	iris_material=G.material(IRIS[0],.74); iris_material.metallic_specular=.20
	var pupil_material:=G.material(Color("171c1c"),.72)
	for side in [-1,1]:
		var eye:=Node3D.new(); p.head_joint.add_child(eye); eye.position=Vector3(side*.071,.193,-.175); p.eye_joints.append(eye)
		var form:=Node3D.new(); form.name="EyeForm"; eye.add_child(form); p.eye_forms.append(form)
		var lid:=Node3D.new(); form.add_child(lid); lids.append(lid)
		var sclera:=G.sphere(lid,.024,Vector3(0,0,-.002),white); sclera.scale=Vector3(.91,.35,.28)
		var iris:=G.sphere(lid,.008,Vector3(0,0,-.007),iris_material); iris.scale=Vector3(.90,.90,.25)
		var pupil:=G.sphere(lid,.004,Vector3(0,0,-.009),pupil_material); pupil.scale=Vector3(.85,1,.20)
		var rim:=G.mesh(p.head_joint,ArrayMesh.new(),preload("res://scripts/skin_material.gd").new(true),Vector3.ZERO); rim.name="Eyelids"; eye_rims.append(rim)
		for part in [sclera,iris,pupil,rim]: part.visibility_range_end=28; part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func face_at(x: float,y: float,traits: Dictionary) -> Vector3:
	return Body.face_point(x,y-.16,lerpf(.92,1.06,traits.jaw/4.0),lerpf(.94,1.055,traits.face/4.0),traits.nose)+Vector3.UP*.16

static func patch_mesh(points: Array,columns: int,tints: Array) -> ArrayMesh:
	var builder:=Meshes.new(); builder.grid(points,columns,tints)
	var rows: int=points.size()/columns
	# These are open facial patches, so their left and right edges do not wrap.
	for row in range(rows):
		for col in range(columns):
			var across: Vector3=points[row*columns+mini(columns-1,col+1)]-points[row*columns+maxi(0,col-1)]
			var along: Vector3=points[mini(rows-1,row+1)*columns+col]-points[maxi(0,row-1)*columns+col]
			var normal:=along.cross(across).normalized()
			builder.normals[row*columns+col]=normal if normal.length()>.5 else Vector3.FORWARD
	return builder.finish()

static func detail(identity: int,kind: String,side: int=0) -> ArrayMesh:
	var key:="%d/%s/%d" % [identity,kind,side]
	if detail_cache.has(key): return detail_cache[key]
	var traits:=Appearance.profile(identity); var skin: Color=Appearance.SKIN_TONES[traits.skin]
	var points: Array=[]; var tints: Array=[]; var columns:=17
	var center:=face_at(side*.071,.232 if kind=="brow" else .193,traits)
	if kind=="mouth":
		center=face_at(0,.073,traits)
		var width:=lerpf(.033,.041,traits.face/4.0)
		for row in range(7):
			var v: float=(row-3)/3.0
			for col in range(columns):
				var u: float=(col-8)/8.0; var taper:=maxf(.02,1-u*u)
				var cupid:=.0008*cos(u*PI*2)*taper
				var at:=face_at(u*width,center.y+v*.006*taper+cupid,traits)
				at.z-=.0007+.0015*sin(absf(v)*PI)*taper
				var pigment:=skin.lerp(Color("804a42"),.17 if row>3 else .21)
				if row==3: pigment=skin.lerp(Color("623c35"),.34)
				points.append(at-center); tints.append(skin.lerp(pigment,taper*(1-pow(absf(v),3))))
	elif kind=="brow":
		for row in range(2):
			for col in range(columns):
				var u: float=(col-8)/8.0; var taper:=pow(maxf(.03,1-u*u),.55)
				var x:=center.x+u*.032
				var y:=center.y+.004*(1-u*u)+(row-.5)*.0055*taper
				var at:=face_at(x,y,traits); at.z-=.0013
				points.append(at-center); tints.append(Color.WHITE)
	else:
		columns=33
		for row in range(3):
			var outer: float=row/2.0
			for col in range(columns):
				var angle:=TAU*col/32.0
				var x: float=center.x+cos(angle)*lerpf(.0216,.0255,outer)
				var y: float=center.y+sin(angle)*lerpf(.0079,.0115,outer)
				var at:=face_at(x,y,traits)
				at.z=lerpf(center.z-.0055,at.z-.0005,outer)
				points.append(at-center)
				tints.append(skin.lerp(skin.darkened(.12),(.22 if sin(angle)>0 else .10)*(1-outer)))
	var mesh: ArrayMesh
	if kind=="rim":
		var builder:=Meshes.new(); builder.grid(points,columns,tints)
		# Annular bands expand outwards; reverse the grid winding to face the lens.
		for i in range(0,builder.indices.size(),3):
			var swap: int=builder.indices[i+1]; builder.indices[i+1]=builder.indices[i+2]; builder.indices[i+2]=swap
		for i in range(builder.normals.size()): builder.normals[i]=-builder.normals[i]
		mesh=builder.finish()
	else: mesh=patch_mesh(points,columns,tints)
	if detail_cache.size()>=512: detail_cache.erase(detail_cache.keys()[0])
	detail_cache[key]=mesh; return mesh

# Spend vertices on the nasal bridge and lips without growing the face budget.
static func face_t(t: float) -> float: return t+.06*sin(TAU*t)
static func face_u(u: float) -> float: return u-.055*sin(TAU*u)

static func model(identity: int,age: int) -> ArrayMesh:
	var band:=clampi((age-18)/5,0,5); var key:="%d/%d" % [identity,band]
	if cache.has(key): return cache[key]
	var traits:=Appearance.profile(identity); var builder:=Meshes.new()
	var skin: Color=Appearance.SKIN_TONES[traits.skin]
	var hair: Color=Hair.color_for(identity)
	var mature:=smoothstep(25,40,18+band*5)
	var jaw:=lerpf(.92,1.06,traits.jaw/4.0)
	var cheek:=lerpf(.94,1.055,traits.face/4.0)
	var points: Array=[]; var tints: Array=[]
	# One continuous oval replaces straight segments between facial landmarks.
	for row in range(FACE_ROWS+1):
		for sector in range(FACE_SEGMENTS+1):
			var t:=face_t(float(row)/FACE_ROWS); var u:=face_u(float(sector)/FACE_SEGMENTS)
			var angle:=u*TAU; var front:=maxf(0,cos(angle))
			var at:=Body.head_point(t,u,jaw,cheek,traits.nose)
			var eye_socket:=exp(-pow((absf(at.x)-.070)/.029,2)-pow((at.y-.029)/.026,2))*front
			var color:=skin
			var cheek_flush:=exp(-pow((absf(at.x)-.11)/.06,2)-pow((at.y+.014)/.055,2))*front
			color=color.lerp(skin*Color(1.025,.84,.81),cheek_flush*.40)
			var temple:=smoothstep(.10,.17,absf(at.x))*front
			color*=1-temple*.055-eye_socket*.05
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
	builder.grid(points,FACE_SEGMENTS+1,tints)
	# Differentiate the smooth surface itself instead of averaging broad bands
	# between rings. The duplicate seam receives exactly the same normal.
	for row in range(FACE_ROWS+1):
		var t:=face_t(float(row)/FACE_ROWS)
		for sector in range(FACE_SEGMENTS+1):
			var u:=face_u(float(sector)/FACE_SEGMENTS)
			var along:=Body.head_point(minf(1,t+.0001),u,jaw,cheek,traits.nose)-Body.head_point(maxf(0,t-.0001),u,jaw,cheek,traits.nose)
			var around:=Body.head_point(t,u+.0001,jaw,cheek,traits.nose)-Body.head_point(t,u-.0001,jaw,cheek,traits.nose)
			builder.normals[row*(FACE_SEGMENTS+1)+sector]=along.cross(around).normalized()
	Body.cap(builder,FACE_SEGMENTS,FACE_ROWS+1,true); Body.cap(builder,FACE_SEGMENTS,FACE_ROWS+1,false)
	for i in range((FACE_ROWS+1)*(FACE_SEGMENTS+1),builder.colors.size()): builder.colors[i]=skin.srgb_to_linear()
	for side in [-1,1]:
		builder.ellipsoid(Vector3(side*.175,-.012,.005),Vector3(.027,.051,.025),skin)
		builder.ellipsoid(Vector3(side*.191,-.014,-.007),Vector3(.008,.026,.010),skin.lerp(Color("934638"),.25).darkened(.10))
	var mesh:=builder.finish()
	if cache.size()>=128: cache.erase(cache.keys()[0])
	cache[key]=mesh; return mesh

func refresh(p) -> void:
	var identity: int=p.appearance_id if p.appearance_id>=0 else p.shirt_number-1
	head.mesh=model(identity,p.age)
	detail_material.albedo_color=Hair.color_for(identity).darkened(.08)
	iris_material.albedo_color=IRIS[p.appearance.iris]
	mouth.mesh=detail(identity,"mouth")
	mouth.position=face_at(0,.073,p.appearance)
	expression=0; mouth.scale.y=1; mouth.rotation.z=0
	for lid in lids: lid.scale.y=1
	mouth.scale.x=1
	for i in range(eye_rims.size()):
		var side: int=-1 if i==0 else 1
		var at:=face_at(side*.071,.193,p.appearance)
		p.eye_joints[i].position=at
		eye_rims[i].position=at
		eye_rims[i].mesh=detail(identity,"rim",side)
		eye_rims[i].scale=p.eye_forms[i].scale
		eye_rims[i].rotation.z=p.eye_forms[i].rotation.z
	for i in range(brows.size()):
		var side: int=-1 if i==0 else 1
		brows[i].mesh=detail(identity,"brow",side)
		brows[i].position=face_at(side*.071,.232,p.appearance)
		brows[i].rotation.z=(-1 if i==0 else 1)*lerpf(-.05,.075,p.appearance.brow/3.0)
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
		brows[i].rotation.z=side*(lerpf(-.05,.075,p.appearance.brow/3.0)-expression*.045)

func set_wetness(wet: float) -> void:
	var roughness:=lerpf(.86,.70,wet)
	head.material_override.roughness=roughness
	mouth.material_override.roughness=roughness
	for rim in eye_rims: rim.material_override.roughness=roughness
