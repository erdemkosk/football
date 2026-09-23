extends "res://tests/carry_finish_check.gd"
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	p=game.players[9]
	for sprint in [false,true]:
		await start_carry(sprint)
		var initial: int=p.dribble_motion.contacts
		var max_height:=0.0; var grounded:=0; var gap:=0.0
		for frame in range(180):
			await tick()
			var a: float=p.left_knee.to_global(p.dribble_motion.BOOT).y-p.position.y
			var b: float=p.right_knee.to_global(p.dribble_motion.BOOT).y-p.position.y
			max_height=maxf(max_height,maxf(a,b)); gap=maxf(gap,game.flat_distance(p.position,game.ball.position))
			if minf(a,b)<p.boot_ground_height()+.05: grounded+=1
			if visual and frame in [40,55,70]: await capture(("sprint" if sprint else "carry")+"-"+str(frame))
		print("GAIT sprint=",sprint," height=",max_height," grounded=",grounded," touches=",p.dribble_motion.contacts-initial," gap=",gap)
		# Sprint includes a flight phase. Walking requires more continuous support.
		check(max_height<.48 and grounded>(80 if sprint else 120),"Carrying feet follow low arcs and retain alternating ground support")
		check(p.dribble_motion.contacts>initial+1 and gap<1.3,"Both carrying speeds retain real boot contacts and ball control")
	var flow:=await changing_stride(); print("STRIDE ",flow)
	check(flow.jerk<.10 and flow.step<.15,"Cuts and sprint changes preserve continuous toe paths")
	print("CARRY GAIT: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
