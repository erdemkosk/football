extends SceneTree
const Size=preload("res://scripts/ball_dimensions.gd")
const Motion=preload("res://scripts/ball_motion.gd")
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func frames(count: int) -> void:
	for n in range(count): await physics_frame
func roll(mode: int,speed: float,origin: Vector3=Vector3(15,Size.GROUND_HEIGHT,-25),direction: Vector3=Vector3.BACK,rate: int=120) -> Dictionary:
	Engine.physics_ticks_per_second=rate
	game.weather.select(mode,true)
	game.ball.place(origin)
	await frames(4)
	game.ball.strike(direction*speed)
	await frames(2)
	var start: Vector3=origin
	var previous: float=Vector2(game.ball.linear_velocity.x,game.ball.linear_velocity.z).length()
	var initial := previous
	var smooth := true; var monotonic := true; var stopped := false
	var elapsed := 0.0; var halfway := 0.0
	var hop := 0.0; var bob := 0.0
	for n in range(rate*12):
		await physics_frame
		elapsed+=1.0/rate
		var current: float=Vector2(game.ball.linear_velocity.x,game.ball.linear_velocity.z).length()
		monotonic=monotonic and current<=previous+0.015
		smooth=smooth and previous-current<12.0/rate
		if n==rate: halfway=current
		if n>4:
			hop=maxf(hop,game.ball.position.y)
			bob=maxf(bob,absf(game.ball.linear_velocity.y))
		previous=current
		if current<0.015: stopped=true; break
	var stop: Vector3=game.ball.position
	await frames(rate)
	var drift: float=game.flat_distance(stop,game.ball.position)
	var result := {"distance":game.flat_distance(start,stop),"time":elapsed,"initial":initial,"after_second":halfway,"monotonic":monotonic,"smooth":smooth,"stopped":stopped,"drift":drift,"hop":hop,"bob":bob}
	print("ROLL mode=%d speed=%.1f rate=%d distance=%.3f stop=%.3fs drift=%.5f" % [mode,speed,rate,result.distance,elapsed,drift])
	return result
func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.start_match(false,false); game.set_physics_process(false); game.set_process(false)
	for p in game.players: p.visible=false; p.collision_layer=0
	var dry: Dictionary=await roll(0,8)
	check(dry.monotonic and dry.smooth and dry.stopped and dry.drift<0.01,"A free rolling ball slows smoothly to rest without a sudden stop, renewed acceleration or endless creep")
	check(dry.hop<Size.RADIUS+0.04 and dry.bob<0.25,"A ground pass stays on the turf instead of chattering vertically")
	var hard: Dictionary=await roll(0,16)
	check(hard.hop<Size.RADIUS+0.04 and hard.bob<0.25,"A fast ground ball stays on the turf instead of vibrating")
	check(hard.distance>dry.distance*2.5 and hard.time>dry.time*1.5 and hard.after_second>dry.after_second,"Kick power changes actual range and stopping time, rather than assigning a fixed travel distance")
	check(hard.after_second<hard.initial-3 and hard.distance<50,"A strong low ball visibly loses pace instead of crossing the pitch at nearly constant speed")
	var wet: Dictionary=await roll(2,8)
	check(wet.distance>dry.distance+1 and wet.stopped and wet.drift<0.01,"Wet intact grass allows a longer skid but the same ball still comes to rest")
	var dry_short: Dictionary=await roll(0,4,Vector3(0,Size.GROUND_HEIGHT,47),Vector3.RIGHT)
	var muddy: Dictionary=await roll(2,4,Vector3(0,Size.GROUND_HEIGHT,47),Vector3.RIGHT)
	check(muddy.distance<dry_short.distance*0.6 and muddy.smooth and muddy.stopped,"The same weak pass loses more energy in a muddy goalmouth and stops much sooner")
	var rate30: Dictionary=await roll(0,8,Vector3(15,Size.GROUND_HEIGHT,-25),Vector3.BACK,30)
	var rate60: Dictionary=await roll(0,8,Vector3(15,Size.GROUND_HEIGHT,-25),Vector3.BACK,60)
	check(absf(rate30.distance-dry.distance)<0.18 and absf(rate60.distance-dry.distance)<0.1,"Actual stopping distance remains consistent at 30, 60 and 120 physics updates")
	Engine.physics_ticks_per_second=120
	game.weather.select(2,true); game.ball.place(Vector3(-10,Size.GROUND_HEIGHT,0),Vector3(10,0,0)); await frames(3)
	var outside_loss := 0.0; var mud_loss := 0.0; var outside_count := 0; var mud_count := 0
	for n in range(250):
		var speed: float=game.ball.linear_velocity.x
		var mud: float=game.weather.mud_at(game.ball.position)
		await physics_frame
		var loss: float=(speed-game.ball.linear_velocity.x)*120
		if mud<0.05 and speed>1: outside_loss+=loss; outside_count+=1
		elif mud>0.6 and speed>1: mud_loss+=loss; mud_count+=1
	check(outside_count>0 and mud_count>0 and mud_loss/mud_count>outside_loss/outside_count+1.5,"Resistance changes at the real mud patch as the ball rolls across it")

	game.weather.select(0,true)
	var origin := Vector3(-25,1.6,15); var target := Vector3(-12,Size.GROUND_HEIGHT,15); var flight := 1.6
	var launch := Motion.lob_velocity(origin,target,flight,game.weather)
	game.ball.place(origin); await frames(3); game.ball.strike(launch)
	await frames(2)
	var horizontal_start: float=Vector2(game.ball.linear_velocity.x,game.ball.linear_velocity.z).length()
	var landed := false; var landing_speed := 0.0; var landing_point := Vector3.ZERO
	var ground_time := 0.0
	for n in range(720):
		await physics_frame
		if not landed and n>30 and game.ball.position.y<Size.RADIUS+.05:
			landed=true; landing_point=game.ball.position; landing_speed=Vector2(game.ball.linear_velocity.x,game.ball.linear_velocity.z).length()
		if landed and game.ball.position.y<Size.RADIUS+.08 and absf(game.ball.linear_velocity.y)<1.2: ground_time+=1.0/120
		if ground_time>1.0: break
	var rolling_speed: float=Vector2(game.ball.linear_velocity.x,game.ball.linear_velocity.z).length()
	check(landed and game.flat_distance(landing_point,target)<0.7,"A weather-aware lofted delivery reaches the predicted landing area through real air drag")
	print("CROSS initial=%.3f landing=%.3f rolling=%.3f" % [horizontal_start,landing_speed,rolling_speed])
	check(landing_speed<horizontal_start and rolling_speed<landing_speed-2,"A cross loses speed in flight and continues slowing through bounces and rolling after landing")

	game.weather.select(0,true)
	var dry_route=game.Passing.plan(Vector3(-3,Size.GROUND_HEIGHT,47),Vector3(3,0,47),Vector3.ZERO,false,game.weather)
	game.weather.select(2,true)
	var muddy_route=game.Passing.plan(Vector3(-3,Size.GROUND_HEIGHT,47),Vector3(3,0,47),Vector3.ZERO,false,game.weather)
	check(muddy_route.flight>dry_route.flight+0.04,"Passing predictions include the slower travel through the current muddy surface")
	var manual_dry=game.Passing.free_plan(Vector3.ZERO,Vector3.RIGHT,0.2,false,null)
	var manual_wet=game.Passing.free_plan(Vector3.ZERO,Vector3.RIGHT,0.2,false,game.weather)
	check(manual_dry.velocity==manual_wet.velocity and manual_dry.flight!=manual_wet.flight,"Manual kick power stays under player control while weather changes the expected travel")
	game.ball.place(Vector3(15,Size.GROUND_HEIGHT,-10),Vector3(0,0,8)); await frames(3)
	var point: Vector3=game.ball.position; var velocity: Vector3=game.ball.linear_velocity
	game.begin_restart("TAÇ",1,Vector3(32,0,-10))
	check(game.ball.position==point and game.ball.linear_velocity==velocity and game.ball.active,"A whistle does not replace physical friction with an instant stop")
	await frames(30)
	check(game.ball.position.distance_to(point)>1 and game.ball.linear_velocity.length()>5,"The out-of-play ball keeps rolling and slowing naturally before collection")
	print("BALL RESISTANCE CHECK: %d failures" % failures)
	game.free(); await process_frame; quit(0 if failures==0 else 1)
