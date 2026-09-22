extends "res://tests/dribble_control_check.gd"
var strip: Image
var strip_frame:=0
var strip_name:=""

func sample_run(input: Vector3,sprint: bool,frames: int=360) -> Dictionary:
	await setup()
	var previous_feet: Array[Vector3]=[]
	var previous_steps: Array[Vector3]=[]
	var max_foot_step:=0.0
	var max_foot_jerk:=0.0
	var max_pelvis_step:=0.0
	var previous_height: float=p.rig.position.y
	var max_ball_change:=0.0
	var previous_ball_speed:=0.0
	var intervals: Array[int]=[]
	var last_touch:=-1
	var last_count:=0
	for frame in range(frames):
		p.desired=input; p.sprinting=sprint
		p.step(DT)
		game.update_contacts(DT)
		var feet: Array[Vector3]=[p.rig.to_local(p.left_knee.to_global(p.dribble_motion.BOOT)),p.rig.to_local(p.right_knee.to_global(p.dribble_motion.BOOT))]
		var steps: Array[Vector3]=[]
		if previous_feet.size()==2:
			for i in range(2):
				steps.append(feet[i]-previous_feet[i])
				if frame>90:
					if "--trace" in OS.get_cmdline_user_args() and steps[i].length()>.10:
						print("SNAP frame=",frame," leg=",i," step=",steps[i]," phase=",p.run_phase," age=",p.dribble_motion.age," foot=",p.dribble_motion.foot," hit=",p.dribble_motion.hit," style=",p.dribble_motion.style," pelvis=",p.rig.position.y," gap=",game.flat_distance(p.position,game.ball.position))
					max_foot_step=maxf(max_foot_step,steps[i].length())
					if previous_steps.size()==2: max_foot_jerk=maxf(max_foot_jerk,(steps[i]-previous_steps[i]).length())
		if frame>90: max_pelvis_step=maxf(max_pelvis_step,absf(p.rig.position.y-previous_height))
		previous_height=p.rig.position.y; previous_feet=feet; previous_steps=steps
		if visual:
			game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=42
			game.camera.position=p.position+Vector3(3.7,1.7,-3.4)
			game.camera.look_at(p.position+Vector3(0,.75,-.2))
		if visual and frame>=140 and frame<188 and frame%4==0:
			RenderingServer.force_draw(false)
			var screen:=root.get_texture().get_image()
			var size:=screen.get_size()
			var crop:=Vector2i(size.y*.8*7/9,size.y*.8)
			var shot:=screen.get_region(Rect2i((size-crop)/2,crop))
			shot.convert(Image.FORMAT_RGBA8)
			shot.resize(280,360)
			strip.blit_rect(shot,Rect2i(0,0,280,360),Vector2i((strip_frame%4)*280,(strip_frame/4)*360))
			strip_frame+=1
		if p.dribble_motion.contacts!=last_count:
			if last_touch>=90: intervals.append(frame-last_touch)
			last_touch=frame; last_count=p.dribble_motion.contacts
		await physics_frame
		var speed: float=Vector2(game.ball.linear_velocity.x,game.ball.linear_velocity.z).length()
		if frame>90: max_ball_change=maxf(max_ball_change,absf(speed-previous_ball_speed))
		previous_ball_speed=speed
	return {"foot_step":max_foot_step,"foot_jerk":max_foot_jerk,"pelvis_step":max_pelvis_step,"ball_speed_change":max_ball_change,"intervals":intervals,"gap":game.flat_distance(p.position,game.ball.position),"owner":game.dribbler}

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-dribble-flow.cfg"
	p=game.players[9]
	for scenario in [{"input":Vector3.FORWARD,"sprint":false},{"input":Vector3.FORWARD,"sprint":true},{"input":Vector3.FORWARD*.35,"sprint":false}]:
		strip_frame=0; strip_name="sprint" if scenario.sprint else ("walk" if scenario.input.length()<.5 else "run")
		if visual: strip=Image.create(1120,1080,false,Image.FORMAT_RGBA8)
		var result:=await sample_run(scenario.input,scenario.sprint)
		if visual: strip.save_png("/tmp/sefc-dribble-flow-"+strip_name+".png")
		print("FLOW ",scenario," ",result)
		check(result.owner==9 and result.gap<1.2,"A continuous dribble stays controlled")
		# A sprint has faster feet; the change between consecutive steps must
		# still stay small, especially at contact and recovery boundaries.
		check(result.foot_step<(.16 if scenario.sprint else .10) and result.foot_jerk<.08,"The boot follows a continuous stride without jumping between touch poses")
		check(result.pelvis_step<.04,"Touch recovery does not snap the pelvis up and down")
		check(result.ball_speed_change<1.8,"Straight carries use small rolling impulses without a stop-start ball")
		check(not result.intervals.is_empty() and result.intervals.min()>=24,"Ordinary touches finish their stride before another touch starts")
	print("DRIBBLE FLOW CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
