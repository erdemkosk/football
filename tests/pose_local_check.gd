extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<5: push_error(label)
func run() -> void:
	var source := FileAccess.get_file_as_string("res://tests/footballer_local_before.gd").replace("res://scripts/locomotion.gd","res://tests/locomotion_local_before.gd")
	var script := GDScript.new(); script.source_code=source
	if script.reload()!=OK: quit(1); return
	var old=script.new(); var current=load("res://scripts/footballer.gd").new()
	root.add_child(old); root.add_child(current)
	var ground := Node3D.new(); root.add_child(ground)
	preload("res://scripts/geometry.gd").collision_box(ground,Vector3(200,1,200),Vector3(0,-.5,0))
	for p in [old,current]: p.collision_layer=0; p.collision_mask=1
	await physics_frame
	for tick in range(1200):
		for p in [old,current]:
			p.desired=Vector3(sin(tick*.04),0,cos(tick*.017)) if tick%200<150 else Vector3.ZERO
			p.sprinting=tick%300<160; p.protecting=tick%210<25; p.jockeying=tick%180<20
			p.prematch=tick>=1000
			if tick%240==0: p.energy=.1+(tick%1000)*.0008
			p.step(1.0/120)
		check(old.velocity==current.velocity,"velocity differs")
		check(old.position==current.position,"position differs")
		check(old.energy==current.energy,"stamina differs")
		check(old.rig.transform==current.rig.transform,"rig differs")
		for i in range(old.kick_joints.size()): check(old.kick_joints[i].transform==current.kick_joints[i].transform,"joint differs")
		check(old.left_knee.to_global(old.ball_actions.BOOT)==current.left_knee.to_global(current.ball_actions.BOOT),"boot differs")
		await physics_frame
	var before: Array[float]=[]; var after: Array[float]=[]
	for trial in range(8):
		for p in ([old,current] if trial%2==0 else [current,old]):
			var start := Time.get_ticks_usec()
			for i in range(1000): p.animate(1.0/120)
			var elapsed := (Time.get_ticks_usec()-start)/1000.0
			if p==old: before.append(elapsed)
			else: after.append(elapsed)
	before.sort(); after.sort()
	print("POSE LOCAL checks=",checks," failures=",failures," before_us=",before[4]," after_us=",after[4])
	old.free(); current.free(); quit(0 if failures==0 else 1)
