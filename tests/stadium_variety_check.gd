extends SceneTree
const Catalog=preload("res://scripts/stadium_catalog.gd")
var checks:=0
var failures:=0
var game
var metrics: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func snapshot(label: String,wide: bool=true) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size=205 if wide else 63
	game.camera.position=Vector3(133,150,167) if wide else Vector3(63,63,32)
	game.camera.look_at(Vector3(0,0,0))
	for frame in range(4): await process_frame
	RenderingServer.force_draw(false)
	var path:="res://artifacts/stadium-variety/"+label+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Captured "+label)
func run() -> void:
	var world: Dictionary=preload("res://scripts/career_world.gd").create()
	var kinds: Dictionary={}; var saved: Dictionary={}
	for id in world.clubs:
		var club: Dictionary=world.clubs[id]
		var venue:=Catalog.assignment(club,id)
		kinds[venue.kind]=int(kinds.get(venue.kind,0))+1; saved[id]=venue
	check(kinds.size()==4 and saved.size()==world.clubs.size(),"Every league's clubs receive one of four stadium families")
	print("VENUE DISTRIBUTION ",kinds)
	var stable:=true
	for id in world.clubs:
		world.clubs[id].reputation=99; world.clubs[id].league=0
		stable=stable and Catalog.assignment(world.clubs[id],id)==saved[id]
	Catalog.ensure(world)
	check(stable,"Promotion and reputation changes retain the club's saved stadium")
	var roundtrip: Dictionary=bytes_to_var(var_to_bytes(world.clubs))
	check(roundtrip==world.clubs,"Venue identities survive save serialization without additional resources")
	var clone: Dictionary=world.clubs.c00.duplicate(true); clone.id="c99"; clone.reputation=50
	check(Catalog.assignment(clone,"c99").kind=="town" and Catalog.assignment(clone,"c99").name!=saved.c00.name,"Expanded clubs do not inherit the template club's stadium")
	var legacy: Dictionary={"clubs":{"c04":{"city":"VERDANT","primary":"24715b","accent":"eee5ce"}}}
	Catalog.ensure(legacy)
	check(legacy.clubs.c04.stadium_kind=="town","Old saves acquire stadium identity without resetting a career")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_process(false); game.set_physics_process(false); game.controller.set_process(false)
	game.match_menu.config_path="/tmp/sefc-stadium-visual.cfg"
	game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
	game.frontend.hide(); game.match_menu.hide(); game.hud.hide(); game.ball.freeze=true
	var stadium=game.stadium
	var collisions: Array=[]
	for body in stadium.find_children("*","CollisionObject3D",true,false): collisions.append(body.get_instance_id())
	var nets: Array=stadium.nets.duplicate(); var posts: Array=stadium.goal_posts.duplicate()
	var physical_ball=game.ball; var turf: Material=stadium.grass
	var seats: Array=[]
	for kind in ["modern","town","compact","historic","modern"]:
		var club: Dictionary=game.clubs.data(0).duplicate(true)
		club.stadium_kind=kind; club.stadium_name="SEFC · "+Catalog.LABELS[kind]; club.stadium_owner="test"
		stadium.light_rig.select(1); game.weather.select(2,true)
		var start:=Time.get_ticks_usec()
		stadium.select_home(club,"test")
		var cost:=(Time.get_ticks_usec()-start)/1000.0
		stadium.crowd.set_clubs(game.clubs.kit(0),game.clubs.kit(1))
		game.clubs.rivalry.profiles=[{},{}]
		var now: Array=[]
		for body in stadium.find_children("*","CollisionObject3D",true,false): now.append(body.get_instance_id())
		check(now==collisions and stadium.nets==nets and stadium.goal_posts==posts and game.ball==physical_ball and stadium.grass==turf,kind+": changing the stadium retains every physical pitch/goal/ball object")
		check(stadium.get_children().filter(func(n): return n.name=="ActiveVenue").size()==1,kind+": only one stadium shell is loaded")
		check(stadium.architecture.venue_kind==kind and stadium.architecture.venue_titles.all(func(t): return t.text==club.stadium_name),kind+": shell and signage match the selected club")
		check(stadium.light_rig.floodlights.size()==4 and stadium.light_rig.floodlights.all(func(l): return is_instance_valid(l) and l.visible),kind+": four shadowed floodlights survive a rainy-night change")
		check(stadium.light_rig.period==1 and stadium.light_rig.rainfall>.9 and stadium.architecture.district.night,kind+": weather and night district remain synchronized")
		stadium.architecture.update_score([3,2],100,240,1)
		check(stadium.architecture.score_labels.size()==2 and stadium.architecture.score_labels.all(func(t): return t.text=="3   :   2"),kind+": both physical scoreboards work")
		check(stadium.crowd.seat_nodes.all(func(n): return is_instance_valid(n) and n.is_inside_tree()) and stadium.supporters.displays.size()==2,kind+": crowd seats and both opening tifos are rebuilt")
		var count: int=stadium.venue_builds
		stadium.select_home(club,"test",true)
		check(stadium.venue_builds==count and stadium.crowd.session_fill==.08,kind+": replaying or training reuses the active shell")
		stadium.set_session(false); stadium.light_rig.select(0); game.weather.select(0,true)
		seats.append(stadium.crowd.chairs.size())
		metrics.append({"kind":kind,"build_ms":cost,"seats":stadium.crowd.chairs.size(),"fans":stadium.crowd.fans.size(),"batches":stadium.venue_batch_stats.batches,"city_blocks":stadium.architecture.city_blocks})
		await snapshot(kind+"-exterior")
		await snapshot(kind+"-match",false)
		stadium.light_rig.select(1); game.weather.select(2,true)
		await snapshot(kind+"-night",false)
	check(seats[1]<seats[3] and seats[3]<seats[0] and seats[2]<seats[0],"Small, historic and compact stands stay below the modern arena's crowd budget")
	# Career sides are player/opponent, not always home/away.
	game.clubs.career_clubs=[world.clubs.c04.duplicate(true),world.clubs.c02.duplicate(true)]
	game.career.world=world; game.career.in_match=true; game.career.fixture_id="venue-test"
	world.cup_fixtures=[]
	world.fixtures=[{"id":"venue-test","home":"c02","away":"c04","day":world.date,"played":false}]
	game.clubs.rivalry.begin(game,false,false)
	check(stadium.venue.owner=="c02" and stadium.venue.kind=="historic" and game.clubs.rivalry.home_team==1,"An away career match uses the actual host's historic ground and supporters")
	world.fixtures[0].home="c04"; world.fixtures[0].away="c02"
	game.clubs.rivalry.begin(game,false,false)
	check(stadium.venue.owner=="c04" and stadium.venue.kind=="town","The return fixture restores the user's own city ground")
	check(stadium.supporters.profiles==game.clubs.rivalry.profiles,"Rebuilding preserves the club's supporter identity")
	game.career.in_match=false; game.clubs.clear_career(); game.clubs.selected=[0,1]
	game.clubs.rivalry.begin(game,false,true)
	check(stadium.venue.owner=="c00" and stadium.venue.kind=="modern","Returning to quick match restores the selected home club")
	var file:=FileAccess.open("res://artifacts/stadium-variety/geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t")); file.close()
	print("STADIUM VARIETY CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
