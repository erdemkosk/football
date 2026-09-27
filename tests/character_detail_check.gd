extends SceneTree
const Footballer=preload("res://scripts/footballer.gd")
const Appearance=preload("res://scripts/player_appearance.gd")
const Face=preload("res://scripts/character_face.gd")
const Hair=preload("res://scripts/hair_styles.gd")
var game
var checks:=0
var failures:=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func identity_with(trait_name: String,value: int) -> int:
	for id in range(1000):
		if Appearance.profile(id)[trait_name]==value: return id
	return 0

func capture(label: String) -> void:
	for i in range(8): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-characters-"+label+".png")

func canvas_for(title: String) -> Control:
	var canvas:=Control.new(); root.add_child(canvas)
	var background:=ColorRect.new(); background.color=Color("10232c"); background.size=Vector2(1440,900); canvas.add_child(background)
	var label:=Label.new(); label.text=title; label.position=Vector2(32,24); label.add_theme_font_size_override("font_size",26); canvas.add_child(label)
	return canvas

func studio(canvas: Control,rect: Rect2,data: Dictionary,close: bool,turn: float=0.0,gesture: String="") -> void:
	var holder:=SubViewportContainer.new(); holder.position=rect.position; holder.size=rect.size; holder.stretch=true; canvas.add_child(holder)
	var viewport:=SubViewport.new(); viewport.size=Vector2i(rect.size*2); viewport.own_world_3d=true; viewport.transparent_bg=true; viewport.msaa_3d=Viewport.MSAA_4X; holder.add_child(viewport)
	var world:=Node3D.new(); viewport.add_child(world)
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0,0,0,0)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color("dce8ef"); environment.environment.ambient_light_energy=.65; world.add_child(environment)
	for i in range(2):
		var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-30,-35 if i==0 else 125,0)
		light.light_energy=1.05 if i==0 else .55; light.light_color=Color("fff1dd") if i==0 else Color("c1dfed"); world.add_child(light)
	var p=Footballer.new(); p.keeper=data.get("keeper",false); world.add_child(p); p.apply_identity(data); p.apply_kit(game.clubs.kit(0))
	p.collision_layer=0; p.collision_mask=0; p.prematch=true; p.idle_rest=0; p.body_language.clear_intent(); p.marker.hide(); p.call_label.hide()
	p.celebration=gesture
	for i in range(60): p.motion_clock+=1.0/60; p.animate(1.0/60)
	p.rig.rotation.y=turn
	var center: Vector3=p.head_joint.global_position+Vector3(0,.05,0) if close else Vector3(0,.96,0)
	var camera:=Camera3D.new(); world.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=.91 if close else 2.45
	camera.keep_aspect=Camera3D.KEEP_WIDTH if close else Camera3D.KEEP_HEIGHT
	camera.position=center+Vector3(0,.06,-5); camera.look_at(center); camera.current=true
	var label:=Label.new(); label.text=data.get("label",""); label.position=rect.position+Vector2(0,rect.size.y+3); label.size=Vector2(rect.size.x,28)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size",16); canvas.add_child(label)

func gallery() -> void:
	game.camera.cull_mask=0; game.frontend.hide(); game.hud.hide()
	var canvas:=canvas_for("SEFC  /  YÜZLER, SAÇLAR VE SAKALLAR")
	for i in range(18):
		var id:=0
		for candidate in range(1000):
			if Hair.style_for(candidate)==i: id=candidate; break
		var data: Dictionary=game.players[9].identity(); data.appearance_id=id; data.age=24+i%4*4; data.label=Hair.NAMES[i]
		studio(canvas,Rect2(16+(i%6)*238,86+(i/6)*261,222,226),data,true,.20 if i%2==0 else -.15)
	await capture("faces"); canvas.free()
	canvas=canvas_for("SEFC  /  ORANLAR VE KUMAŞ DETAYLARI")
	for i in range(4):
		var data: Dictionary=game.players[9].identity(); data.appearance_id=[17,35,43,53][i]; data.age=[19,29,35,32][i]
		data.height_cm=[169,186,198,182][i]; data.weight_kg=[60,88,92,76][i]; data.keeper=i==2
		data.label=["KANAT · 169 cm / 60 kg","SANTRFOR · 186 cm / 88 kg","KALECİ · 198 cm / 92 kg","FORMA · SIRT DETAYI"][i]
		studio(canvas,Rect2(20+i*355,110,330,680),data,false,PI-.22 if i==3 else -.18)
	await capture("bodies"); canvas.free()
	canvas=canvas_for("SEFC  /  OYUNCULARA ÖZGÜ GOL SEVİNÇLERİ")
	for i in range(8):
		var style: String=game.celebration.STYLES[i]
		var data: Dictionary=game.players[9].identity(); data.appearance_id=identity_with("celebration",i); data.label=["Yumruk","Arma","Tribün","Kalp","Kanatlar","Selam","Gökyüzü","Kollar bağlı"][i]
		studio(canvas,Rect2(24+(i%4)*355,85+(i/4)*397,322,352),data,false,0,style)
	await capture("gestures"); canvas.free()
	game.camera.cull_mask=1048575; game.start_match(false,false); game.set_process(false); game.set_physics_process(false)
	game.frontend.hide(); game.hud.hide(); game.set_pieces.snap_ready()
	await capture("match")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false); game.ball.freeze=true
	var p=game.players[9]; var original: Dictionary=p.identity()
	var traits: Dictionary={}
	for name in ["jaw","nose","brow","beard","face","iris","movement","celebration"]: traits[name]={}
	var budget:=true
	for id in range(120):
		var profile:=Appearance.profile(id)
		for name in traits: traits[name][profile[name]]=true
		var mesh:=Face.model(id,30)
		budget=budget and mesh.get_surface_count()==1 and mesh.surface_get_array_len(0)<3600
	check(traits.jaw.size()==5 and traits.nose.size()==5 and traits.face.size()==5 and traits.brow.size()==4,"Independent jaw, nose, cheek and brow families occur across the roster")
	check(traits.beard.size()==6 and traits.iris.size()==5 and traits.movement.size()==4 and traits.celebration.size()==8,"Facial hair, eyes and personal movements have stable variety")
	check(budget,"Each complete sculpted face uses one bounded mesh surface")
	var colors: PackedColorArray=Face.model(5,33).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	Face.cache.clear()
	check(Face.model(5,37).surface_get_arrays(0)[Mesh.ARRAY_COLOR]==colors,"Age-band shading is independent of cache creation order")
	check(Face.model(5,18).surface_get_arrays(0)[Mesh.ARRAY_COLOR]!=colors,"Young and mature versions retain identity while changing face details")
	var hair_ok:=true
	for style in range(18):
		var mesh:=Hair.model(style,Footballer.scalp_mesh()); var array:=mesh.surface_get_arrays(0)
		hair_ok=hair_ok and mesh.get_surface_count()==1 and array[Mesh.ARRAY_VERTEX].size()<5000
		# Every cap is a continuous ring lattice; the duplicate seam closes exactly.
		for row in range(19):
			hair_ok=hair_ok and array[Mesh.ARRAY_VERTEX][row*49].distance_to(array[Mesh.ARRAY_VERTEX][row*49+48])<.00001
	check(hair_ok,"All eighteen haircuts use a closed connected cap within the mesh budget")
	var data: Dictionary=original.duplicate(true); data.appearance_id=identity_with("celebration",7); data.age=36
	p.apply_identity(data); var face: Mesh=p.face_detail.head.mesh; var gait: Vector3=Vector3(p.gait_arm_swing,p.gait_elbow,p.gait_posture)
	data.shirt=91; p.apply_identity(data)
	check(p.face_detail.head.mesh==face and gait==Vector3(p.gait_arm_swing,p.gait_elbow,p.gait_posture),"A shirt change preserves both facial anatomy and running mannerisms")
	game.last_kicker=9; game.celebration.begin(0)
	check(game.celebration.style=="arms_crossed","Match goal flow selects the scorer's personal gesture")
	game.celebration.clear()
	var collision: Transform3D=p.body_collision.transform; var valid:=true
	for style in game.celebration.STYLES:
		p.celebration=style
		for i in range(40): p.animate(1.0/60)
		valid=valid and p.left_hand.global_position.is_finite() and p.right_hand.global_position.is_finite() and p.body_collision.transform==collision
	check(valid,"All eight gestures animate finite hand positions without changing collision geometry")
	p.celebration=""; p.energy=1; p.match_fatigue=0; p.face_detail.expression=0
	p.motion_clock=.075-p.face_detail.blink_phase; p.face_detail.animate(p,0)
	var closed: float=p.face_detail.lids[0].scale.y
	p.motion_clock=1-p.face_detail.blink_phase; p.face_detail.animate(p,0)
	check(closed<.1 and p.face_detail.lids[0].scale.y>.9,"Eyelids blink without replacing the player's inherited eye shape")
	p.update_soil(1)
	check(p.kit_materials.skin.roughness>.65 and p.face_detail.head.material_override.roughness==p.kit_materials.skin.roughness,"Wet skin retains a restrained highlight consistent between face and body")
	var photos=preload("res://scripts/squad_portraits.gd").new()
	var portrait: Dictionary=game.frontend.player_data("slot",9); var key: String=photos.key_for(portrait); portrait.age+=5
	check(photos.key_for(portrait)!=key and game.frontend.player_data("slot",9).age==p.age,"Portraits carry match age and refresh when the player ages")
	photos.free(); p.apply_identity(original); p.update_soil(0)
	if "--visual" in OS.get_cmdline_user_args(): await gallery()
	print("CHARACTER DETAIL CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
