extends SceneTree
var game
var failures := 0
var assertions := 0
var samples: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	assertions+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.hud.queue_redraw()
	for i in range(5): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/district-"+label+".png")
func measure(label: String) -> void:
	if "--measure" not in OS.get_cmdline_user_args(): return
	game.set_process(true); game.set_physics_process(true)
	var begin := Time.get_ticks_usec()
	while Time.get_ticks_usec()-begin<1000000: await process_frame
	var times: Array[float]=[]
	begin=Time.get_ticks_usec()
	var last := begin
	while Time.get_ticks_usec()-begin<3000000:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now-last)/1000.0); last=now
	times.sort()
	var row := {"scene":label,"viewport":str(root.size),"fps":times.size()/((last-begin)/1000000.0),"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*0.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	samples.append(row); print("DISTRICT PERFORMANCE: ",JSON.stringify(row))
	game.set_process(false); game.set_physics_process(false)
	game.set_process_input(false)
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.set_process(false); game.set_physics_process(false)
	game.elapsed=0; game.update_camera(0)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await create_timer(0.7).timeout
		DisplayServer.window_set_size(Vector2i(1440,900))
		await create_timer(0.3).timeout
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	game.weather.select(0,true)
	var district=game.stadium.architecture.district
	check(district.building_count>=40 and district.parked_count>=70 and district.people_count>=100,"Surroundings include complete blocks, parking and stadium arrival crowds")
	var roads_clear := true
	for building in district.buildings:
		for axis in [-184,-109,109,184]: roads_clear=roads_clear and not building.intersects(Rect2(axis-8,-340,16,680))
		for axis in [-202,-125,125,202]: roads_clear=roads_clear and not building.intersects(Rect2(-370,axis-8,740,16))
	check(roads_clear,"Every building footprint stays out of the four road corridors and their junctions")
	var old_position: Vector3=district.vehicles[0].node.position
	var continuous := true
	var on_roads := true
	for route in district.routes:
		var previous: Vector3=route.sample_baked(0,true)
		for distance in range(1,int(route.get_baked_length())+2):
			var p: Vector3=route.sample_baked(fposmod(distance,route.get_baked_length()),true)
			continuous=continuous and p.distance_to(previous)<1.5
			on_roads=on_roads and (absf(absf(p.x)-109)<8 or absf(absf(p.z)-125)<8)
			previous=p
	check(continuous and on_roads,"Traffic follows continuous rounded loops on the actual asphalt, including the loop seam")
	district.update_traffic(1,true)
	check(district.vehicles[0].node.position.distance_to(old_position)>5,"Menu traffic actually moves along the route")
	var held: Transform3D=district.vehicles[0].node.transform
	district.update_traffic(10,false)
	check(not district.traffic.visible and district.vehicles[0].node.transform==held,"Close match views skip background traffic animation and drawing")
	district.update_traffic(0,true)
	check(district.detail_count>6000 and district.mesh_count<220,"Thousands of city details render in a bounded number of spatial batches")
	print("DISTRICT COUNTS: buildings=",district.building_count," cars=",district.parked_count," moving=",district.vehicles.size()," trees=",district.tree_count," people=",district.people_count," parts=",district.detail_count," meshes=",district.mesh_count)
	game.stadium.light_rig.select(0)
	check(not district.night and district.light_pools.all(func(p): return not p.visible),"Daytime turns off emissive night lighting and light-pool draws")
	await capture("day-menu")
	await measure("day-live-menu")
	game.elapsed=0; game.update_camera(0)
	game.stadium.light_rig.select(1)
	check(district.night and district.glow.get_shader_parameter("night")==1.0 and district.light_pools.all(func(p): return p.visible),"Nighttime activates windows, vehicle lamps and pavement light pools")
	check(game.stadium.light_rig.floodlights.all(func(light): return light.light_cull_mask==1),"Stadium floodlights do not incur additional city shadow passes")
	await capture("night-menu")
	await measure("night-live-menu")
	game.hud.visible=false
	game.stadium.light_rig.select(0)
	game.camera.size=110; game.camera.position=Vector3(180,93,212); game.camera.look_at(Vector3(91,0,107))
	await capture("street-detail")
	game.stadium.light_rig.select(1)
	await capture("night-street-detail")
	if not samples.is_empty():
		var file := FileAccess.open("/tmp/football-district-performance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(samples,"\t")); file.close()
	print("DISTRICT CHECK: %d checks, %d failures" % [assertions,failures])
	game.free(); quit(0 if failures==0 else 1)
