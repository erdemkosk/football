extends SceneTree
const Reference=preload("res://tests/ball_motion_native_before.gd")
class Surface extends RefCounted:
	var drag := .0026
	func ball_air_drag() -> float: return drag
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var status := GDExtensionManager.load_extension("res://native/match.cfg")
	if status!=GDExtensionManager.LOAD_STATUS_OK: quit(1); return
	var kernel=ClassDB.instantiate("MatchKernels")
	var surface := Surface.new()
	var rng := RandomNumberGenerator.new(); rng.seed=8761981
	var checks := 0; var failures := 0; var max_error := 0.0
	var script_time := 0; var native_time := 0
	for i in range(2000):
		surface.drag=rng.randf_range(0,.01) if i%5 else 0.0
		var origin := Vector3(rng.randf_range(-32,32),rng.randf_range(.23,3),rng.randf_range(-48,48))
		var target := Vector3(rng.randf_range(-32,32),rng.randf_range(.23,3),rng.randf_range(-48,48))
		var duration := rng.randf_range(.3,3.2)
		var spin := 0.0
		var velocity := Vector3(rng.randf_range(-30,30),rng.randf_range(0,20),rng.randf_range(-30,30))
		var steps: int = [0,1,12,48,64][i%5]
		var a: Vector3; var b: Vector3
		for native in ([false,true] if i%2==0 else [true,false]):
			var start := Time.get_ticks_usec()
			if native: b=kernel.lob_velocity(origin,target,duration,surface.drag); native_time+=Time.get_ticks_usec()-start
			else: a=Reference.lob_velocity(origin,target,duration,surface); script_time+=Time.get_ticks_usec()-start
		checks+=1
		if a!=b:
			failures+=1; max_error=maxf(max_error,a.distance_to(b))
			if failures<4: print("LOB MISMATCH ",a," ",b)
		var expected := Reference.sample_flight(origin,velocity,spin,duration,steps,surface)
		var actual: PackedVector3Array=kernel.sample_straight_flight(origin,velocity,duration,steps,surface.drag)
		for j in range(expected.size()):
			checks+=1
			if expected[j]!=actual[j]:
				failures+=1; max_error=maxf(max_error,expected[j].distance_to(actual[j]))
				if failures<4: print("FLIGHT MISMATCH ",j," ",expected[j]," ",actual[j])
	print("NATIVE BALL checks=",checks," failures=",failures," max_error=",max_error," lob_script_us=",script_time/2000.0," lob_native_us=",native_time/2000.0)
	quit(0 if failures==0 else 1)
