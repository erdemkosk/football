extends SceneTree

var game
var player
var failures := 0
var assertions := 0
var visual := false
const DT := 1.0/120
const BOOT := Vector3(0,-0.42,-0.05)

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	assertions+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func reset(speed: float=0) -> void:
	player.position=Vector3(0,0,-20)
	player.velocity=Vector3.FORWARD*speed
	player.desired=Vector3.ZERO
	player.facing=Vector3.FORWARD
	player.rig.rotation=Vector3.ZERO
	player.spine.rotation=Vector3.ZERO
	player.acceleration_lean=Vector3.ZERO
	player.run_phase=0
	player.motion_clock=0
	player.kick_timer=0
	player.shot_preparation=0
	player.wrapping=0
	player.action_timer=0
	player.call_timer=0
	player.pose="run"
	player.animate(1)

func tick(delta: float=DT) -> void:
	player.motion_clock+=delta
	player.run_phase+=Vector2(player.velocity.x,player.velocity.z).length()*delta*1.8
	player.kick_timer=maxf(0,player.kick_timer-delta)
	player.animate(delta)

func feet() -> Vector2:
	return Vector2(player.left_knee.to_global(BOOT).y,player.right_knee.to_global(BOOT).y)-Vector2.ONE*(player.position.y+0.084)

func capture(label: String) -> void:
	if not visual: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shot-animation-"+label+".png")

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/football-shot-animation-settings.cfg"
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false)
	game.ball.freeze=true; game.ball.pending_reset=false
	game.hud.visible=false
	player=game.players[9]
	for p in game.players: p.visible=p==player
	game.ball.position=Vector3(0.16,0.23,-20.8)
	game.camera.position=Vector3(5,3.6,-24)
	game.camera.look_at(Vector3(0,1,-20))
	game.camera.size=4.3
	reset()
	player.shot_preparation=1
	var lowest := Vector2(INF,INF)
	var highest := Vector2(-INF,-INF)
	for frame in range(360):
		tick()
		lowest=lowest.min(feet()); highest=highest.max(feet())
	check(lowest.x>0 and lowest.y>0 and highest.x<0.035 and highest.y<0.035,"A three-second standing charge keeps both boots on the turf")
	check((highest-lowest).length()<0.015,"Holding full power does not repeatedly lift or bounce a foot")
	check(player.spine.rotation.y< -0.15 and player.left_arm.rotation.z< -0.3,"The torso coils and arms balance a planted charging stance")
	await capture("standing-charge")
	reset(3.85)
	player.shot_preparation=1
	var min_hip := Vector2(INF,INF)
	var max_hip := Vector2(-INF,-INF)
	var raised := Vector2.ZERO
	var supports := Vector2i.ZERO
	var previous_support := -1
	var changes := 0
	var min_body := INF
	var max_body := -INF
	for frame in range(480):
		tick()
		var hips := Vector2(player.left_leg.rotation.x,player.right_leg.rotation.x)
		min_hip=min_hip.min(hips); max_hip=max_hip.max(hips)
		raised=raised.max(feet())
		var support := 0 if feet().x<feet().y else 1
		if support==0: supports.x+=1
		else: supports.y+=1
		if previous_support>=0 and previous_support!=support: changes+=1
		previous_support=support
		min_body=minf(min_body,player.rig.position.y); max_body=maxf(max_body,player.rig.position.y)
		if frame==75: await capture("stride-left")
		if frame==125: await capture("stride-right")
	check((max_hip-min_hip).x>0.65 and (max_hip-min_hip).y>0.65,"Both thighs keep swinging during a running charge")
	check(raised.x>0.1 and raised.y>0.1 and supports.x>120 and supports.y>120 and changes>=7,"Both feet alternate their swing and support phases, without one-leg hopping")
	check(max_body-min_body<0.11,"Charging keeps the running body's vertical motion bounded")
	check(player.left_elbow.rotation.x>0.4 and player.right_elbow.rotation.x>0.4,"Both elbows stay bent during the balancing arm swing")
	player.shot_preparation=0
	for frame in range(45): tick()
	check(player.shot_ready_blend==0 and absf(player.spine.rotation.y)<0.08,"Cancelling a charge smoothly restores the normal running torso")
	for speed in [0.0,3.85,8.8]:
		reset(speed)
		player.shot_preparation=0.85
		for frame in range(30): tick()
		var before: Array[Vector3]=[]
		for joint in player.kick_joints: before.append(joint.rotation)
		player.begin_kick(0.95,0.46)
		player.animate(DT)
		var start_jump := 0.0
		for i in range(before.size()): start_jump=maxf(start_jump,before[i].distance_to(player.kick_joints[i].rotation))
		check(start_jump<0.001,"Release blends from the current stance at speed %.2f" % speed)
		var peak := -INF
		var max_change := 0.0
		var support_height := 0.0
		var follow_hand := Vector3.ZERO
		var recovered_hand := Vector3.ZERO
		for frame in range(72):
			tick()
			peak=maxf(peak,player.right_leg.rotation.x)
			for i in range(before.size()):
				max_change=maxf(max_change,before[i].distance_to(player.kick_joints[i].rotation))
				before[i]=player.kick_joints[i].rotation
			if frame in range(6,16): support_height=maxf(support_height,feet().x)
			if frame==13: follow_hand=player.right_hand.global_position-player.position
			if frame==36: recovered_hand=player.right_hand.global_position-player.position
			if is_zero_approx(speed):
				if frame==5: await capture("contact")
				if frame==13: await capture("follow-through")
				if frame==30: await capture("recovery")
				if frame==68: await capture("settled")
		check(peak>1.0 and support_height<0.04,"A strong kick follows through over its planted support foot at speed %.2f" % speed)
		check(max_change<0.5 and follow_hand.distance_to(recovered_hand)>0.07,"Arms and body move through the kick without a joint snap at speed %.2f" % speed)
		check(player.kick_timer==0 and absf(player.right_leg.rotation.x-(0.1-sin(player.run_phase)*0.78*minf(speed/8.7,1)))<0.001,"The kick returns to the current stride at speed %.2f" % speed)
	for duration in [0.32,0.46]:
		reset()
		player.begin_kick(0.15,duration)
		var peak := 0.0
		for frame in range(60):
			tick()
			peak=maxf(peak,player.right_leg.rotation.x)
		check(peak>0.7 and peak<1.0 and player.kick_timer==0,"A quick, uncharged kick has a shorter swing and recovers (%.2fs)" % duration)
	reset()
	player.begin_kick(1,0.46)
	for frame in range(12): tick()
	player.receive_impact(Vector3.RIGHT,0.9)
	tick()
	check(player.kick_timer==0 and player.shot_preparation==0 and player.pose=="fall","A tackle cleanly interrupts the shooting animation")
	var sample: Array[Vector3]=[]
	for rate in [30,120]:
		reset(3.85)
		player.shot_preparation=0.8
		for frame in range(rate/2): tick(1.0/rate)
		player.begin_kick(0.9,0.46)
		for frame in range(rate/5): tick(1.0/rate)
		if rate==30:
			for joint in player.kick_joints: sample.append(joint.rotation)
		else:
			var error := 0.0
			for i in range(sample.size()): error=maxf(error,sample[i].distance_to(player.kick_joints[i].rotation))
			check(error<0.025,"Kick timing and full-body pose stay consistent at 30 and 120 updates per second")
	print("SHOT ANIMATION CHECK: %d checks, %d failures" % [assertions,failures])
	game.free(); quit(0 if failures==0 else 1)
