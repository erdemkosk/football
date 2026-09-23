extends "res://tests/advanced_play_check.gd"

func start_carry(sprint: bool=false) -> void:
	await reset()
	p.position=Vector3(0,0,15)
	game.ball.place(p.position+Vector3(0,.23,-.6))
	await physics_frame; await physics_frame
	key(KEY_UP); if sprint: key(KEY_W)
	await tick(100)

func moving_shot(style: String,sprint: bool,aim: Vector3=Vector3.ZERO) -> Dictionary:
	await start_carry(sprint)
	if style=="timed": key(KEY_5); key(KEY_5,false)
	key(KEY_D,true,style=="low",style=="power",style=="outside")
	await tick(24)
	if aim.length()>0: game.shot_direction=aim
	key(KEY_D,false)
	var queued: bool=game.finishing.active(9) if style=="timed" else game.ball.pending_kick and game.shots[0]==1
	var max_gap:=0.0
	var contact_gap:=INF
	var elapsed:=0.0
	for frame in range(85):
		await tick()
		elapsed+=DT
		if visual and style=="power" and sprint and frame in [12,27,46]: await capture("power-"+str(frame))
		if game.shots[0]>0:
			contact_gap=p.volley_motion.boot(p).distance_to(game.ball.position)
			break
		max_gap=maxf(max_gap,game.flat_distance(p.position,game.ball.position))
	key(KEY_UP,false); key(KEY_W,false)
	return {"queued":queued,"gap":max_gap,"shot":game.shots[0],"speed":game.ball.kick_velocity.length(),"time":elapsed,"contact_gap":contact_gap}

func changing_stride() -> Dictionary:
	await start_carry(true)
	var old_feet: Array[Vector3]=[]
	var old_steps: Array[Vector3]=[]
	var jerk:=0.0
	var step:=0.0
	var gap:=0.0
	var lost:=0
	var direction:=KEY_UP
	for frame in range(360):
		if frame%45==0:
			key(direction,false)
			direction=[KEY_RIGHT,KEY_DOWN,KEY_LEFT,KEY_UP][(frame/45)%4]
			key(direction)
		if frame%30==0: key(KEY_W,frame%60==0)
		await tick()
		var feet: Array[Vector3]=[p.rig.to_local(p.left_knee.to_global(p.dribble_motion.BOOT)),p.rig.to_local(p.right_knee.to_global(p.dribble_motion.BOOT))]
		var steps: Array[Vector3]=[]
		for i in range(2):
			if old_feet.size()==2:
				steps.append(feet[i]-old_feet[i])
				step=maxf(step,steps[i].length())
				if old_steps.size()==2:
					var jump: float=(steps[i]-old_steps[i]).length()
					jerk=maxf(jerk,jump)
					if jump>.12 and "--trace" in OS.get_cmdline_user_args(): print("SNAP ",frame," foot=",i," jerk=",jump," age=",p.dribble_motion.age," hit=",p.dribble_motion.hit," plant=",p.locomotion.plant_weight)
		old_feet=feet; old_steps=steps
		gap=maxf(gap,game.flat_distance(p.position,game.ball.position))
		if game.dribbler!=9: lost+=1
	key(direction,false); key(KEY_W,false)
	return {"jerk":jerk,"step":step,"gap":gap,"lost":lost}

func capture(label: String) -> void:
	if not visual: return
	var velocity: Vector3=game.ball.linear_velocity
	var spin: Vector3=game.ball.angular_velocity
	game.ball.freeze=true
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=42
	game.camera.position=p.position+Vector3(3.7,1.9,-3.4)
	game.camera.look_at(p.position+Vector3(0,.8,-.2))
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/sefc-carry-"+label+".png")
	game.ball.freeze=false; game.ball.linear_velocity=velocity; game.ball.angular_velocity=spin

func cancellation_checks() -> void:
	for reason in ["opponent","switch","pause","impact","out"]:
		await start_carry(true)
		key(KEY_UP,false); key(KEY_W,false)
		game.finishing.queue(9,Vector3.FORWARD,.7,"power")
		game.finishing.prepare(DT)
		check(p.dribble_motion.preparing and game.ball.pending_control,"A controlled power-shot preparation supplies a bounded settling force")
		match reason:
			"opponent":
				var q=game.players[17]
				q.visible=true; q.position=game.ball.position+Vector3(.25,-game.ball.position.y,0)
				q.action_timer=0; q.touch_cooldown=0; q.ball_actions.contact_cooldown=0
				game.update_contacts(DT)
				check(game.dribbler==17,"An opponent can actually acquire the ball during the backswing")
				game.finishing.prepare(DT)
			"switch":
				game.players[8].visible=true; game.team_control.select(8,true)
			"pause": game.state="paused"; game.finishing.prepare(DT)
			"impact": p.receive_impact(Vector3.RIGHT,.85); game.finishing.prepare(DT)
			"out":
				game.ball.place(Vector3(34,.23,5),Vector3.RIGHT*4)
				await physics_frame; await physics_frame
				game.finishing.prepare(DT)
		check(game.finishing.pending.is_empty() and not p.dribble_motion.preparing and not game.ball.pending_control and not game.ball.get_collision_exceptions().has(p) and game.shots[0]==0,"Canceling for "+reason+" immediately releases assistance without a phantom shot")

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-carry-finish.cfg"
	for style in ["power","low","outside","timed"]:
		for sprint in [false,true]:
			var result:=await moving_shot(style,sprint)
			print("MOVING SHOT ",style," sprint=",sprint," ",result)
			check(result.queued and result.shot==1,"A moving "+style+" shot reaches its real contact, sprint="+str(sprint))
			check(result.gap<1.15,"The controlled ball stays at the player's feet during "+style+" preparation")
	for aim in [Vector3.LEFT,Vector3.RIGHT,Vector3.BACK]:
		var shot:=await moving_shot("power",true,aim)
		print("ANGLED POWER ",aim," ",shot)
		check(shot.shot==1 and shot.gap<1.15,"A power shot across or against the running direction retains the ball: "+str(aim))
	var flow:=await changing_stride()
	print("CHANGING STRIDE ",flow)
	check(flow.jerk<.10 and flow.step<.15,"Turns and sprint changes do not snap the dribbling legs between poses")
	check(flow.gap<1.3 and flow.lost==0,"Consecutive direction and sprint changes keep the ball controlled")
	await cancellation_checks()
	print("CARRY FINISH CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
