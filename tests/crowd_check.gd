extends SceneTree
var game
var crowd
var failures := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func advance(seconds: float,position: Vector3=Vector3.ZERO,velocity: Vector3=Vector3.ZERO,playing: bool=false,late: bool=false) -> void:
	for i in range(int(seconds*120)):
		crowd.update(1.0/120.0,position,velocity,0,playing,late)
func capture(label: String) -> void:
	if not visual: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/"+label+".png")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(true)
	game.set_physics_process(false)
	game.set_process(false)
	game.ball.freeze=true
	game.hud.visible=false
	crowd=game.stadium.crowd
	game.camera.position=Vector3(23,14,-24)
	game.camera.look_at(Vector3(44,3.8,-24))
	game.camera.size=21
	var seated=game.stadium.get_node("Fans_skin_0")
	var arrays=seated.multimesh.mesh.surface_get_arrays(0)
	var morph:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var reach := 0.0
	for v in morph: reach=maxf(reach,v.y)
	check(reach>0.7,"Seated fans have a real standing, raised-arm target pose")
	check(crowd.fans.size()>3000,"The full stadium uses instanced animated supporters")
	var away_count := 0
	for fan in crowd.fans:
		if fan.phase.g>=0.5: away_count+=1
	check(away_count>0 and away_count<crowd.fans.size()/2,"Away supporters occupy their own minority section")
	await capture("crowd-calm")
	if visual:
		advance(0.35)
		await capture("crowd-idle-moving")
		advance(1.2)
		await capture("crowd-idle-chant")
	advance(1,Vector3(0,0,-44),Vector3(0,0,-22),true)
	check(crowd.danger>0.7,"Support builds during a dangerous attacking position")
	await capture("crowd-anticipation")
	game.ball.position=Vector3(0,1,-30)
	game.strike(9,Vector3(0,3,-30))
	check(crowd.event_kind=="shot","An actual shot triggers the crowd reaction")
	game.goal(0)
	check(crowd.event_kind=="goal" and crowd.wave_age<0 and crowd.wave_cooldown>0,"A home goal triggers celebration and queues the Mexican wave")
	advance(1.1)
	await capture("crowd-celebration")
	crowd.react("shot",0,Vector3.ZERO)
	check(crowd.event_kind=="goal","A new shot does not interrupt goal celebrations")
	crowd.reset()
	game.goal(1)
	check(crowd.material.get_shader_parameter("event_team")==1.0 and crowd.wave_age==100,"Away goals celebrate only their supporters without starting a home wave")
	crowd.reset()
	crowd.start_wave(Vector3(44,0,-42),0)
	advance(0.45)
	var first_age:float=crowd.material.get_shader_parameter("wave_age")
	await capture("crowd-wave-start")
	advance(0.95)
	await capture("crowd-wave-moving")
	check(crowd.material.get_shader_parameter("wave_age")>first_age+0.9,"The wave advances over time around spatially ordered seats")
	var current_age:float=crowd.wave_age
	crowd.start_wave(Vector3.ZERO)
	check(crowd.wave_age==current_age,"Wave cooldown prevents repeated restarts")
	advance(12)
	check(crowd.event_age>crowd.event_duration and crowd.wave_age>9 and crowd.danger<0.001,"Support returns to calm after the event and wave finish")
	crowd.reset()
	advance(4,Vector3(0,0,-45),Vector3(0,0,-8),true,true)
	check(crowd.wave_cooldown>0,"Late pressure in a close match can start a support wave")
	game.start_match(true)
	check(crowd.event_kind=="" and crowd.danger==0 and crowd.wave_age==100,"A fresh match resets crowd reactions")
	crowd.react("save",0,Vector3(0,1,47))
	check(crowd.event_kind=="save" and crowd.event_duration>2,"A goalkeeper save has a distinct shorter cheer")
	print("CROWD CHECK: %d failures" % failures)
	game.free()
	await process_frame
	quit(0 if failures==0 else 1)
