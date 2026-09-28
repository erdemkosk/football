extends "res://artifacts/performance-polish/native_benchmark.gd"
var original:=false
var venue_kind:="modern"
var before_grass: Shader
var before_chalk: Shader
func prepare() -> void:
	game.clubs.ensure_world()
	var club: Dictionary=game.clubs.exhibition.clubs[game.clubs.club_id(0)]
	club.stadium_kind=venue_kind; club.stadium_owner=game.clubs.club_id(0)
	super.prepare()
	game.stadium.grass.shader=before_grass if original else load("res://shaders/grass.gdshader")
	game.stadium.chalk.shader=before_chalk if original else load("res://shaders/pitch_paint.gdshader")
	game.stadium.apply_pitch_appearance()
func run() -> void:
	before_grass=Shader.new(); before_grass.code=FileAccess.get_file_as_string("res://artifacts/pitch-variety/baseline/grass.gdshader.txt")
	before_chalk=Shader.new(); before_chalk.code=FileAccess.get_file_as_string("res://artifacts/pitch-variety/baseline/pitch_paint.gdshader.txt")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-pitch-benchmark.cfg"
	game.match_menu.display.set_fullscreen(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	print("DEVICE ",RenderingServer.get_video_adapter_name()," / ",RenderingServer.get_current_rendering_method())
	prepare(); game.ball.freeze=false; game.set_process(true); game.set_physics_process(true)
	game.stadium.light_rig.select(1); game.weather.select(2,true)
	var warmup:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warmup<6500000: await process_frame
	results.clear()
	var trial:=0
	for next_kind in ["modern","town","compact","historic"]:
		venue_kind=next_kind
		for old in ([true,false] if trial%2==0 else [false,true]):
			original=old
			await sample(venue_kind+("-before" if old else "-after"),true,1,true)
			print("VIEWPORT ",root.size)
		trial+=1
	var file:=FileAccess.open("res://artifacts/pitch-variety/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")); file.close()
	game.free(); print("PITCH BENCHMARK COMPLETE"); quit()
