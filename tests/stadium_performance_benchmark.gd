extends "res://artifacts/performance-polish/native_benchmark.gd"
var venue_kind:="modern"
func prepare() -> void:
	# The ordinary match-start path chooses the host's stadium.
	game.clubs.ensure_world()
	var club: Dictionary=game.clubs.exhibition.clubs[game.clubs.club_id(0)]
	club.stadium_kind=venue_kind; club.stadium_owner=game.clubs.club_id(0)
	club.stadium_name="SEFC · "+venue_kind.to_upper()
	super.prepare()
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-stadium-performance.cfg"
	game.match_menu.display.set_fullscreen(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	prepare(); game.ball.freeze=false; game.set_process(true); game.set_physics_process(true)
	var warmup:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warmup<6500000: await process_frame
	results.clear()
	for next_kind in ["modern","town","compact","historic"]:
		venue_kind=next_kind
		for scene in [0,1,2]:
			await sample(venue_kind+"-"+["day","night","rain"][scene],true,0 if scene==0 else 1,scene==2)
			print("VIEWPORT ",root.size," physics=",Engine.physics_ticks_per_second," lights=",game.stadium.light_rig.floodlights.size())
	var file:=FileAccess.open("res://artifacts/stadium-variety/after-fps.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")); file.close()
	game.free(); print("STADIUM PERFORMANCE COMPLETE"); quit()
