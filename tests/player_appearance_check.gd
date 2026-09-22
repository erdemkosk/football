extends SceneTree
const Appearance=preload("res://scripts/player_appearance.gd")
const Footballer=preload("res://scripts/footballer.gd")
var game
var checks:=0
var failures:=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func signature(p) -> Array:
	return [p.kit_materials.skin.albedo_color,p.eye_forms[0].transform,p.eye_forms[1].transform,p.boot_meshes[0].mesh,p.boot_meshes[1].mesh,p.haircut.mesh,p.kit_materials.hair.albedo_color]

func identity_for(skin: int,eyes: int,boot: int=-1) -> int:
	for id in range(10000):
		var profile:=Appearance.profile(id)
		if (skin<0 or profile.skin==skin) and (eyes<0 or profile.eyes==eyes) and (boot<0 or profile.boots==boot): return id
	return -1

func screenshot(label: String) -> void:
	for i in range(6): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/sefc-appearance-"+label+".png")

func studio(rect: Rect2,data: Dictionary,boots: bool,canvas: Control) -> void:
	var container:=SubViewportContainer.new(); container.position=rect.position; container.size=rect.size
	canvas.add_child(container)
	var viewport:=SubViewport.new(); viewport.size=Vector2i(rect.size*2); viewport.transparent_bg=true; viewport.own_world_3d=true; viewport.msaa_3d=Viewport.MSAA_4X
	container.stretch=true; container.add_child(viewport)
	var world:=Node3D.new(); viewport.add_child(world)
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0,0,0,0)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("e8eee8"); environment.environment.ambient_light_energy=.65
	world.add_child(environment)
	for i in range(2):
		var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-27,-28 if i==0 else 135,0)
		light.light_energy=1.1 if i==0 else .5; world.add_child(light)
	var p=Footballer.new(); p.number=data.shirt; world.add_child(p)
	p.apply_identity(data); p.apply_kit(game.clubs.kit(0)); p.marker.hide(); p.call_label.hide(); p.animate(0)
	var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	if boots:
		camera.size=.94; camera.position=Vector3(.7,.58,-1.2); camera.look_at(Vector3(0,.19,-.04))
	else:
		var at: Vector3=p.head_joint.global_position+Vector3(0,.21,0)
		camera.size=.91; camera.position=at+Vector3(0,0,-3); camera.look_at(at)
	camera.current=true

func gallery(boots: bool) -> void:
	var canvas:=Control.new(); canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.add_child(canvas)
	var background:=ColorRect.new(); background.color=Color("101f2d"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); canvas.add_child(background)
	var title:=Label.new(); title.text="SEFC  /  KRAMPON RENKLERİ" if boots else "SEFC  /  TEN TONLARI VE GÖZ ŞEKİLLERİ"
	title.position=Vector2(48,27); title.add_theme_font_size_override("font_size",27); canvas.add_child(title)
	var count:=12 if boots else 10; var columns:=4 if boots else 5
	for i in range(count):
		var id:=identity_for(-1,-1,i) if boots else identity_for(i,i%5)
		var data: Dictionary=game.players[9].identity(); data.appearance_id=id; data.height_cm=180; data.weight_kg=76; data.shirt=i+1
		var rect:=Rect2(32+(i%columns)*344,115+(i/columns)*250,320,185) if boots else Rect2(35+(i%columns)*278,108+(i/columns)*380,254,290)
		studio(rect,data,boots,canvas)
		var label:=Label.new(); label.text=Appearance.BOOT_NAMES[i] if boots else Appearance.EYE_NAMES[i%5]
		label.position=rect.position+Vector2(0,rect.size.y+12); label.size=Vector2(rect.size.x,28)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size",17); canvas.add_child(label)
	await screenshot("boots" if boots else "faces")
	canvas.queue_free(); await process_frame

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false); game.ball.freeze=true
	game.match_menu.config_path="/tmp/sefc-appearance-settings.cfg"
	var p=game.players[9]
	var original: Dictionary=p.identity(); var body: Vector3=p.body_scale; var collision: float=p.body_collision.shape.height
	var boot_transform: Transform3D=p.boot_meshes[0].transform; var boot_bounds: AABB=p.boot_meshes[0].mesh.get_aabb()
	var tones: Dictionary={}; var eyes: Dictionary={}; var boots: Dictionary={}
	var anatomy_ok:=true; var cosmetics_only:=true
	for id in range(120):
		var data: Dictionary=original.duplicate(true); data.appearance_id=id; p.apply_identity(data)
		tones[p.kit_materials.skin.albedo_color]=true; eyes[p.eye_forms[0].transform]=true; boots[p.boot_meshes[0].mesh]=true
		anatomy_ok=anatomy_ok and p.eye_forms[0].scale==p.eye_forms[1].scale and is_equal_approx(p.eye_forms[0].rotation.z,-p.eye_forms[1].rotation.z)
		cosmetics_only=cosmetics_only and p.body_scale==body and p.body_collision.shape.height==collision and p.attributes==original.attributes and p.boot_meshes[0].transform==boot_transform and p.boot_meshes[0].mesh.get_aabb().is_equal_approx(boot_bounds)
	check(tones.size()==10,"Players use ten distinct natural skin tones")
	check(eyes.size()==5 and anatomy_ok,"Five eye shapes have mirrored, anatomically consistent left and right forms")
	check(boots.size()==12,"All twelve boot colourways appear across player identities")
	check(cosmetics_only,"Appearance changes preserve body proportions, football attributes, boot contact geometry and collision")
	var budget_ok:=true
	for mesh in boots:
		budget_ok=budget_ok and mesh.get_surface_count()==1 and mesh.surface_get_array_len(0)<=400
	check(budget_ok and Appearance.boot_cache.size()==12,"Boot accents share twelve cached meshes with one surface each and no extra draw calls")
	p.apply_identity(original)
	var expected:=signature(p)
	var changed: Dictionary=original.duplicate(true); changed.shirt=88; changed.nationality="TR"
	p.apply_identity(changed); p.apply_kit(game.clubs.kit(1))
	check(signature(p)==expected,"Changing shirt, nationality metadata and strip preserves the same person and boots")
	changed.nationality="JP"; p.apply_identity(changed)
	check(signature(p)==expected,"Cosmetic identity is independent of nationality labels")
	p.body_language.enabled=true; p.body_language.ball_target=p.position+Vector3(4,1,-6)
	p.body_language.apply_gaze(p,.2); p.body_language.reset(p)
	check(signature(p)==expected,"Eye tracking and animation reset retain the player's eye shape")
	p.apply_identity(original); p.apply_kit(game.clubs.kit(0))
	var incoming: Dictionary=game.management.bench[0][2].duplicate(true)
	game.clubs.swap_starter(9,2)
	check(p.appearance==Appearance.profile(incoming.appearance_id),"A substitute brings his own skin, eye shape and boots into the pitch model")
	game.clubs.swap_starter(9,2)
	check(signature(p)==expected,"Undoing a lineup swap restores the full original appearance")
	var photos=preload("res://scripts/squad_portraits.gd").new(); game.add_child(photos); photos.set_process(false)
	photos.build_studio(game.frontend.player_data("slot",9))
	check(signature(photos.model)==signature(p),"The generated tactics portrait uses exactly the same appearance as the match actor")
	photos.queue_free()
	var c=game.career; c.save_root="/tmp/sefc-appearance-career"; DirAccess.make_dir_recursive_absolute(c.save_root)
	c.new_career("c00",1)
	var pid: String=c.club().lineup[9]; p.apply_identity(c.player(pid)); expected=signature(p)
	c.save(); c.load_slot(1); p.apply_identity(c.player(pid))
	check(signature(p)==expected,"Existing appearance IDs reproduce the same face and boots after a career save/reload")
	var youth: Dictionary=c.World.academy_player(c.world,c.club(),3); p.apply_identity(youth)
	check(p.appearance==Appearance.profile(youth.appearance_id),"New academy players receive the same appearance variety automatically")
	var official=Footballer.new(); official.official=true; official.number=31; game.add_child(official)
	check(official.appearance.boots==0 and official.boot_meshes[0].mesh==Appearance.boot_mesh(0),"Referees retain neutral black boots")
	official.queue_free(); p.apply_identity(original)
	if "--visual" in OS.get_cmdline_user_args():
		game.camera.cull_mask=0; game.hud.hide(); game.frontend.hide()
		await gallery(false); await gallery(true)
		game.career_screen.open_hub(); game.career_screen.go("tactics")
		for i in range(130): await process_frame
		await screenshot("tactics")
	print("PLAYER APPEARANCE CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
