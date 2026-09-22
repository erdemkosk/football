extends SceneTree
const Graphics = preload("res://scripts/kit_graphics.gd")
var game
var checks := 0
var failures := 0
var visual := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)

func capture(label: String) -> void:
	if not visual: return
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/kit-"+label+".png")

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false)
	game.match_menu.config_path="/tmp/sefc-kit-physique-test.cfg"
	game.ball.freeze=true
	var original_clubs: Array=game.clubs.selected.duplicate()
	var combinations := {}; var minimum := 999; var maximum := 0
	for club in range(8):
		game.clubs.selected[0]=club
		var local_heights := {}
		var valid := true
		for member in range(18):
			var data: Dictionary=game.clubs.member(0,member)
			var repeated: Dictionary=game.clubs.member(0,member)
			var bmi: float=data.weight_kg/pow(data.height_cm/100.0,2)
			valid=valid and data==repeated and data.height_cm>=166 and data.height_cm<=199 and data.weight_kg>=58 and data.weight_kg<=96 and bmi>=20.0 and bmi<=25.1
			if data.keeper: valid=valid and data.height_cm>=186
			combinations[str(data.height_cm)+"/"+str(data.weight_kg)]=true
			local_heights[data.height_cm]=true
			minimum=mini(minimum,data.height_cm); maximum=maxi(maximum,data.height_cm)
		check(valid and local_heights.size()>=8,"Club %d: stable, natural proportions across starters and reserves" % club)
	check(combinations.size()>70 and maximum-minimum>=25,"The roster has substantial natural height and build variety")
	game.clubs.selected=original_clubs; game.clubs.apply()
	var p=game.players[9]
	var identity: Dictionary=p.identity()
	var scale_before: Vector3=p.body_scale
	var texture: Texture2D=p.kit_materials.printed.albedo_texture
	check(texture!=null and texture.get_width()==512 and texture.get_image().has_mipmaps(),"Crest, trim and number use a compact mipmapped cloth texture")
	var geometry: Array=p.jersey_body.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array=geometry[Mesh.ARRAY_VERTEX]
	check(positions[7].x>positions[9].x and positions[23].x<positions[25].x,"Front and back UVs read left-to-right from outside the shirt")
	check(p.jersey_body.get_parent()==p.spine and p.jersey_body.mesh.get_surface_count()==1,"The printed shirt follows the torso through one mesh surface")
	var standalone_prints := false
	for child in p.spine.get_children():
		if child is Label3D or (child is MeshInstance3D and child.mesh is BoxMesh): standalone_prints=true
	check(not standalone_prints,"No detached chest boxes or floating number labels remain")
	var keeper=game.players[11]
	keeper.start_dive(2.5,1.2,.4); keeper.action_timer=keeper.dive_duration-.3; keeper.animate_dive()
	var axes := Vector3(keeper.rig.basis.x.length(),keeper.rig.basis.y.length(),keeper.rig.basis.z.length())
	check(axes.is_equal_approx(keeper.body_scale),"Diving preserves body proportions instead of turning width into extra reach")
	keeper.action_timer=0; keeper.pose="run"; keeper.animate(.016)
	p.refresh_shirt()
	check(texture==p.kit_materials.printed.albedo_texture,"Repeated shirt refreshes reuse the cached texture")
	game.clubs.alternate[0]=true; game.clubs.apply()
	check(p.identity()==identity and p.body_scale==scale_before and p.kit_materials.printed.albedo_texture!=texture,"Changing strip changes print without changing the player's body")
	var away: Dictionary=game.clubs.kit(0)
	check(away.badge_primary==Color(game.clubs.data(0).primary),"Alternate shirts retain the club's crest colours")
	game.clubs.alternate[0]=false; game.clubs.apply()
	var incoming: Dictionary=game.management.bench[0][2].duplicate()
	check(game.clubs.swap_starter(9,2),"A prematch substitution is accepted")
	check(p.height_cm==incoming.height_cm and p.weight_kg==incoming.weight_kg and p.shirt_number==incoming.shirt and p.number==10,"The substitute brings his measurements and number, preserving the AI slot")
	check(is_equal_approx(p.body_collision.shape.height,1.72*(p.body_scale.y/1.20)),"Collision height follows the individual build")
	game.clubs.swap_starter(9,2)
	check(p.identity()==identity and p.body_scale==scale_before,"Undoing the swap restores the same body")
	game.state="playing"; game.match_time=0
	game.management.queue_sub(9,2); game.management.prepare_substitutions()
	p.position=Vector3(32.8,0,-3+9*1.2)
	game.management.update_substitutions(0)
	check(p.height_cm==incoming.height_cm and p.weight_kg==incoming.weight_kg and p.shirt_number==incoming.shirt and game.management.transit[9].phase=="in","Live substitution switches build only when the replacement enters")
	check(p.kit_soil==0,"The incoming player wears a clean shirt")
	game.management.reset()
	check(p.identity()==identity,"New match/reset restores the selected lineup's physiques")
	var dirty_texture: Texture2D=p.kit_materials.printed.albedo_texture
	p.kit_soil=.7; game.state="playing"; p.stain(.01)
	check(p.kit_materials.printed.albedo_color.r<1 and p.kit_materials.printed.albedo_texture==dirty_texture,"Mud shades the existing cloth without allocating another texture")
	p.apply_kit(game.clubs.kit(0))
	game.frontend.open_selection(); await process_frame
	check(game.frontend.previews[0].player.identity()==identity,"The team preview wears the actual starter's identity and build")
	await capture("selection")
	game.frontend.open_tactics(true); game.frontend.selected_slot=9; game.frontend.preview_reserve=2
	check(game.frontend.player_data("slot",9).height_cm==identity.height_cm and game.frontend.player_data("bench",2).weight_kg==incoming.weight_kg,"Tactics and reserve comparison expose actual height and weight")
	await capture("tactics")
	game.frontend.hide(); game.hud.hide(); game.match_menu.hide(); game.ball.hide()
	game.state="playing"
	for player in game.players: player.visible=false
	game.stadium.light_rig.select(0)
	var show: Array=[]
	# Real squad extremes and a median player, plus two alternate club shirts.
	var catalog: Array=[]
	for i in range(18): catalog.append(game.clubs.member(0,i))
	catalog.sort_custom(func(a,b): return a.height_cm<b.height_cm)
	var examples: Array=[catalog[0],catalog[8],catalog[17]]
	for i in range(5):
		var actor=preload("res://scripts/footballer.gd").new()
		actor.number=i+2
		actor.keeper=i==2
		game.add_child(actor); actor.collision_layer=0; actor.collision_mask=0; actor.marker.hide()
		actor.apply_identity(examples[i] if i<3 else game.clubs.member(0,i))
		game.clubs.selected[0]=0 if i<3 else (i-2)
		actor.apply_kit(game.clubs.kit(0))
		actor.position=Vector3((i-2)*1.5,0,-20); actor.rig.rotation=Vector3.ZERO
		actor.prematch=true; actor.animate(.016); actor.rig.rotation=Vector3.ZERO
		show.append(actor)
		var label := Label3D.new(); label.text="%d cm  /  %d kg" % [actor.height_cm,actor.weight_kg]
		label.position=actor.position+Vector3(0,2.95,0); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size=32; label.pixel_size=.005; label.no_depth_test=true
		game.add_child(label)
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL; game.camera.size=7.6
	game.camera.position=Vector3(0,3.8,-30); game.camera.look_at(Vector3(0,1.3,-20)); game.camera.current=true
	await capture("lineup-front")
	for actor in show: actor.rig.rotation.y=PI
	await capture("lineup-back")
	for actor in show:
		actor.rig.rotation.y=.7; actor.spine.rotation.x=-.48
	await capture("cloth-bend")
	if visual:
		var gallery := CanvasLayer.new(); root.add_child(gallery)
		var background := ColorRect.new(); background.color=Color("0a1c24"); background.size=Vector2(1440,900); gallery.add_child(background)
		for i in range(8):
			var club: Dictionary=game.clubs.CLUBS[i]
			var badge := TextureRect.new(); badge.texture=Graphics.badge(i,Color(club.primary),Color(club.accent))
			badge.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			badge.position=Vector2(180+(i%4)*300,130+floori(i/4.0)*370); badge.size=Vector2(170,170); gallery.add_child(badge)
			var label := Label.new(); label.text=club.name; label.position=badge.position+Vector2(-40,200); label.size=Vector2(250,40)
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size",22); gallery.add_child(label)
		await capture("club-crests"); gallery.free()
	print("KIT / PHYSIQUE CHECK: %d checks, %d failures; %d body profiles, %d–%d cm" % [checks,failures,combinations.size(),minimum,maximum])
	game.free(); quit(0 if failures==0 else 1)
