extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<8: push_error(label)
func run() -> void:
	var source:=FileAccess.get_file_as_string("res://scripts/footballer.gd")
	source=source.replace("sampled_mud=surface.mud_at(position)","sampled_mud=-1.0")
	source=source.replace("speed*=1.0-sampled_mud*0.16","speed*=1.0-surface.mud_at(position)*0.16")
	source=source.replace("stain(delta,sampled_mud)","stain(delta)")
	source=source.replace("surface.grip_at(position,sampled_mud)","surface.grip_at(position)")
	var reference:=GDScript.new(); reference.source_code=source
	check(reference.reload()==OK,"Reference player loads")
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.start_match(false,false); game.set_process(false); game.set_physics_process(false); game.ball.freeze=true
	var old=reference.new(); var current=load("res://scripts/footballer.gd").new()
	for p in [old,current]:
		root.add_child(p); p.surface=game.weather; p.collision_layer=0; p.collision_mask=1
	for region in range(6):
		var patch: Vector4=game.weather.PATCHES[region]
		for p in [old,current]: p.position=Vector3(patch.x,0,patch.y); p.velocity=Vector3.ZERO
		for tick in range(120):
			game.weather.wetness=[0.0,.25,.251,.6,.95,1.0][mini(tick/20,5)]
			for p in [old,current]:
				p.desired=Vector3(sin(tick*.04),0,cos(tick*.025)); p.sprinting=tick%60<30
				p.step(1.0/120)
			check(old.position==current.position,"Position identical")
			check(old.velocity==current.velocity,"Velocity identical")
			check(old.energy==current.energy,"Stamina identical")
			check(old.kit_soil==current.kit_soil,"Dirt accumulation identical")
			check(old.rig.transform==current.rig.transform,"Rig identical")
			for i in range(old.kick_joints.size()): check(old.kick_joints[i].transform==current.kick_joints[i].transform,"Joint identical")
			await physics_frame
	var before: Array[float]=[]; var after: Array[float]=[]
	game.weather.wetness=.95
	var sink:=0.0
	for trial in range(8):
		for cached in ([false,true] if trial%2==0 else [true,false]):
			var start:=Time.get_ticks_usec()
			for i in range(10000):
				var at:=Vector3(sin(i*.01)*25,0,cos(i*.017)*49)
				var mud: float=game.weather.mud_at(at)
				var stain_mud: float=mud if cached else game.weather.mud_at(at)
				var grip: float=game.weather.grip_at(at,mud) if cached else game.weather.grip_at(at)
				sink+=mud+stain_mud+grip
			var elapsed: float=(Time.get_ticks_usec()-start)/10000.0
			if cached: after.append(elapsed)
			else: before.append(elapsed)
	before.sort(); after.sort()
	print("SURFACE REUSE checks=",checks," failures=",failures," before_us=",before[4]," after_us=",after[4]," sink=",sink)
	old.free(); current.free(); game.free(); quit(0 if failures==0 else 1)
