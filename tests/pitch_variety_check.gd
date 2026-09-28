extends SceneTree
const Catalog=preload("res://scripts/stadium_catalog.gd")
const Appearance=preload("res://scripts/pitch_appearance.gd")
var game
var checks:=0
var failures:=0
var visual:=false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func capture(label: String,close: bool=false) -> void:
	if not visual: return
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size=17 if close else 110
	game.camera.position=Vector3(9,12,35) if close else Vector3(85,135,90)
	game.camera.look_at(Vector3(0,0,46) if close else Vector3.ZERO)
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/pitch-variety/"+label+".png")==OK,"Captured "+label)
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	var world: Dictionary=preload("res://scripts/career_world.gd").create()
	var profiles: Dictionary={}
	for id in world.clubs: profiles[id]=Appearance.profile(Catalog.assignment(world.clubs[id],id))
	var stable:=true
	for id in world.clubs:
		world.clubs[id].reputation=99; world.clubs[id].league=0
		stable=stable and profiles[id]==Appearance.profile(Catalog.assignment(world.clubs[id],id))
	check(stable and profiles.size()==110,"All 110 clubs keep the same turf after promotion or reputation changes")
	var saved: Dictionary=bytes_to_var(var_to_bytes(world))
	check(Appearance.profile(Catalog.assignment(saved.clubs.c04,"c04"))==profiles.c04,"Reloading the saved stadium recreates its exact pitch appearance")
	check(profiles.c00!=profiles.c01,"Clubs sharing the modern arena have individual cut widths and tones")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.match_menu.config_path="/tmp/sefc-pitch-variety.cfg"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	game.frontend.hide(); game.match_menu.hide(); game.hud.hide(); game.ball.freeze=true
	if visual: await create_timer(.8).timeout
	var stadium=game.stadium; var weather=game.weather
	var grass: ShaderMaterial=stadium.grass; var chalk: ShaderMaterial=stadium.chalk
	var wear_map=weather.wear.texture
	var at:=Vector3(2,0,46)
	weather.wear.press(at,Vector3.FORWARD,Vector2(.6,1),1.0,true,2)
	weather.wear.update(.3)
	var mark: Vector2=weather.wear.sample(at)
	weather.select(2,true)
	var response:=Vector3(weather.ball_drag(at),weather.ball_bounce(at),weather.grip_at(at))
	var ids: Array=[]
	for body in stadium.find_children("*","CollisionObject3D",true,false): ids.append(body.get_instance_id())
	var rng_state: int=game.rng.state
	for id in ["c04","c03","c00","c02"]:
		var club: Dictionary=world.clubs[id]
		stadium.select_home(club,id)
		var exact:=true
		for parameter in stadium.pitch_profile:
			exact=exact and grass.get_shader_parameter(parameter)==stadium.pitch_profile[parameter] and chalk.get_shader_parameter(parameter)==stadium.pitch_profile[parameter]
		check(exact,id+": grass and painted lines share the selected mowing pattern and palette")
		check(stadium.pitch_profile==profiles[id],id+": match start uses the host club's persistent pitch identity")
		weather.select(2,true); stadium.light_rig.select(1); weather.apply_look()
		check(Vector3(weather.ball_drag(at),weather.ball_bounce(at),weather.grip_at(at)).is_equal_approx(response),id+": appearance leaves ball speed, bounce and grip unchanged")
		var now: Array=[]
		for body in stadium.find_children("*","CollisionObject3D",true,false): now.append(body.get_instance_id())
		check(now==ids and stadium.grass==grass and stadium.chalk==chalk and weather.wear.texture==wear_map,id+": pitch meshes, collisions and wear textures are reused")
		check(weather.wear.sample(at)==mark and grass.get_shader_parameter("wetness")==1.0 and grass.get_shader_parameter("mow_axis")==profiles[id].mow_axis,id+": rainy night retains both club styling and existing footsteps")
		weather.select(0,true); stadium.light_rig.select(0)
		await capture(stadium.venue.kind+"-day")
		await capture(stadium.venue.kind+"-close",true)
		weather.select(2,true); stadium.light_rig.select(1)
		await capture(stadium.venue.kind+"-night")
	check(game.rng.state==rng_state,"Choosing a surface consumes no match randomness")
	var builds: int=stadium.venue_builds
	stadium.select_home(world.clubs.c05,"c05")
	check(stadium.venue_builds==builds and stadium.pitch_profile==profiles.c05,"Another historic club changes its turf without rebuilding the stadium")
	stadium.select_home(world.clubs.c05,"c05",true)
	check(stadium.pitch_profile==profiles.c05,"Training keeps the home pitch's appearance")
	weather.reset_match()
	check(weather.wear.sample(at)==Vector2.ZERO and stadium.pitch_profile==profiles.c05,"New-match cleanup removes traffic but preserves the club's grass")
	print("PITCH VARIETY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
