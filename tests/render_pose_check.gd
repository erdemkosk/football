extends "res://tests/ai_attack_check.gd"

func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	preload("res://scripts/geometry.gd").collision_box(world,Vector3(140,1,140),Vector3(0,-.5,0))
	var full=preload("res://scripts/footballer.gd").new()
	var scheduled=preload("res://scripts/footballer.gd").new()
	world.add_child(full); world.add_child(scheduled)
	full.position=Vector3(-4,0,0); scheduled.position=Vector3(4,0,0)
	scheduled.defer_running_pose=not ("--reference" in OS.get_cmdline_user_args())
	var body_error := 0.0; var energy_error := 0.0
	var foot_error := 0.0; var penetration := 0.0
	var worst_body := Vector3.ZERO
	for tick in range(600):
		var direction := Vector3.FORWARD if tick<200 else (Vector3(.7,0,-.7) if tick<400 else Vector3.ZERO)
		for player in [full,scheduled]:
			player.desired=direction; player.sprinting=tick>=100 and tick<330
			player.step(DT)
		# Emulate 20 rendered frames/sec while physics still takes 120 steps.
		if tick%6==5:
			scheduled.flush_running_pose()
			for pair in [[full.left_knee,scheduled.left_knee],[full.right_knee,scheduled.right_knee]]:
				var a: Vector3=pair[0].to_global(full.ball_actions.BOOT)-full.position
				var b: Vector3=pair[1].to_global(scheduled.ball_actions.BOOT)-scheduled.position
				foot_error=maxf(foot_error,a.distance_to(b))
				penetration=minf(penetration,b.y-scheduled.boot_ground_height())
		var difference: Vector3=scheduled.position-full.position-Vector3(8,0,0)
		if difference.length()>body_error: body_error=difference.length(); worst_body=difference
		energy_error=maxf(energy_error,absf(full.energy-scheduled.energy))
		await physics_frame
	print("POSE body_error=",body_error," vector=",worst_body," energy_error=",energy_error," foot_error=",foot_error," penetration=",penetration)
	# Two full-rate actors have the same 1.67 mm initial floor-settling delta
	# at these separate world positions (--reference); it is not pose scheduling.
	check(body_error<.002 and energy_error<.00001,"20 FPS pose scheduling preserves 120 Hz movement, turning, braking and stamina")
	check(foot_error<.02,"Scheduled running feet stay within 2 cm of the full-frequency reference through sprint and cuts")
	check(penetration>-.065,"Scheduled feet retain ground contact without sinking through the pitch")
	if scheduled.defer_running_pose:
		for tick in range(3): scheduled.step(DT)
		check(scheduled.pending_pose_delta>DT*2,"An already-idle player does not flush the same idle pose every physics tick")
	print("RENDER POSE: ",checks," checks, ",failures," failures")
	world.free(); quit(1 if failures>0 else 0)
