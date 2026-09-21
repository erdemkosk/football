extends SceneTree
const DT := 1.0/120.0
const BOOT := Vector3(0,-0.42,-0.05)
var game
var player
var failures := 0
var assertions := 0
var visual := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	assertions+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func tick(count: int=1) -> void:
	for i in range(count):
		player.step(DT)
		await physics_frame
func reset() -> void:
	player.position=Vector3(0,0,-20)
	player.velocity=Vector3.ZERO
	player.desired=Vector3.ZERO
	player.facing=Vector3.FORWARD
	player.rig.rotation=Vector3.ZERO
	player.rig.position=Vector3.ZERO
	player.spine.rotation=Vector3.ZERO
	player.reset_stamina()
	player.action_timer=0; player.kick_timer=0; player.shot_preparation=0
	player.protecting=false; player.jockeying=false
	player.discipline_pose=""; player.celebration=""; player.set_piece_pose=""
	player.pose="run"; player.last_horizontal=Vector3.ZERO
	player.acceleration_lean=Vector3.ZERO
	player.run_phase=0
	player.locomotion.reset()
	await tick(5)
func capture(label: String) -> void:
	if not visual: return
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=38
	game.camera.position=player.position+Vector3(4.4,2.9,-5.0)
	game.camera.look_at(player.position+Vector3(0,1,0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/locomotion-"+label+".png")
func feet_grounded() -> bool:
	return minf(player.left_knee.to_global(BOOT).y,player.right_knee.to_global(BOOT).y)-player.position.y>=0.075
func turn_scenario(direction: Vector3,label: String) -> void:
	await reset()
	player.desired=Vector3.FORWARD
	player.sprinting=true
	await tick(100)
	var before: Vector3=player.velocity
	var position: Vector3=player.position
	player.desired=direction
	await tick()
	check((player.velocity-before).dot(direction)>0.1 and player.position.distance_to(position)>0.001,"Direction input changes real motion on the first physics tick: "+label)
	var planted := 0
	var peak := 0.0
	var error := 0.0
	var ground := true
	var max_pelvis := 0.0
	var joints: Array[Node3D]=[player.left_leg,player.right_leg,player.left_knee,player.right_knee]
	var previous_joints: Array[Quaternion]=[]
	for joint in joints: previous_joints.append(joint.quaternion)
	var joint_step := 0.0
	for i in range(36):
		await tick()
		for j in range(joints.size()):
			if previous_joints[j].angle_to(joints[j].quaternion)>0.55:
				print("SNAP %s frame=%d joint=%d age=%.3f weight=%.3f" % [label,i,j,player.locomotion.plant_age,player.locomotion.plant_weight])
			joint_step=maxf(joint_step,previous_joints[j].angle_to(joints[j].quaternion))
			previous_joints[j]=joints[j].quaternion
		var motion=player.locomotion
		peak=maxf(peak,motion.plant_weight)
		max_pelvis=maxf(max_pelvis,absf(player.rig.position.x))
		ground=ground and feet_grounded()
		if motion.plant_weight>0.96:
			planted+=1
			var knee=player.left_knee if motion.plant_leg==0 else player.right_knee
			error=maxf(error,knee.to_global(BOOT).distance_to(motion.anchor))
		if i==5: await capture(label+"-plant")
		if i==17: await capture(label+"-recovery")
	print("TURN %s: peak=%.3f planted=%d foot_error=%.3f pelvis=%.3f joint_step=%.3f" % [label,peak,planted,error,max_pelvis,joint_step])
	check(planted>=2 and error<0.045,"Support boot holds its world contact while the body changes direction: "+label)
	check(max_pelvis>0.025 and max_pelvis<0.09,"Weight shifts onto the support leg without accumulating sideways drift: "+label)
	check(ground,"Turning boots stay above the turf: "+label)
	check(joint_step<0.55,"Plant and release avoid an abrupt leg-joint snap: "+label)
	await tick(60)
	check(player.velocity.normalized().dot(direction)>0.97 and player.locomotion.cut==0,"A completed cut returns to a normal run in the requested direction: "+label)

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-locomotion-settings.cfg"
	game.start_match(true)
	game.set_physics_process(false); game.set_process(false)
	game.ball.freeze=true; game.ball.pending_reset=false
	game.hud.visible=false
	player=game.players[9]
	for p in game.players:
		p.visible=p==player
		p.collision_layer=0
	player.collision_mask=1
	await turn_scenario(Vector3.RIGHT,"right-cut")
	await turn_scenario(Vector3.LEFT,"left-cut")
	await turn_scenario(Vector3.BACK,"reverse")
	await reset()
	player.desired=Vector3.FORWARD
	await tick(50)
	var speed: float=player.velocity.length()
	player.desired=Vector3.ZERO
	await tick(8)
	check(player.locomotion.braking>0.5 and player.velocity.length()<speed and player.velocity.length()>speed*0.6,"Release shows a braking stance while preserving existing physical coasting")
	check(player.left_knee.rotation.x< -0.35 or player.right_knee.rotation.x< -0.35,"Braking absorbs weight through bent knees")
	await capture("braking")
	await tick(120)
	check(player.velocity.length()<0.05 and player.locomotion.braking<0.05 and absf(player.rig.position.x)<0.02,"Standing after a stop clears braking and weight shift")
	await reset()
	player.jockeying=true
	player.desired=Vector3.RIGHT*0.58
	await tick(70)
	check(player.locomotion.mode=="side" and player.facing.dot(Vector3.FORWARD)>0.99 and player.velocity.x>3,"Defensive lateral movement keeps looking at the opponent")
	var lateral_spread: float=absf(player.left_leg.rotation.z)+absf(player.right_leg.rotation.z)
	check(lateral_spread>0.22 and absf(player.left_leg.rotation.x-player.right_leg.rotation.x)<0.22,"Side steps open and gather instead of playing the forward sprint")
	await capture("sidestep")
	player.desired=Vector3.LEFT*0.58
	await tick(80)
	check(player.locomotion.side< -0.9 and player.velocity.x< -3 and player.facing.dot(Vector3.FORWARD)>0.99,"Side steps mirror without rotating the defender away from play")
	await capture("sidestep-left")
	player.desired=Vector3.BACK*0.58
	await tick(90)
	check(player.locomotion.mode=="back" and player.velocity.z>3 and player.facing.dot(Vector3.FORWARD)>0.99,"Backward defensive running retains forward-facing upper body")
	var low := INF
	var high := -INF
	var grounded := true
	for i in range(120):
		await tick()
		low=minf(low,player.left_leg.rotation.x)
		high=maxf(high,player.left_leg.rotation.x)
		grounded=grounded and feet_grounded()
	check(high-low>0.3 and grounded,"Backpedalling alternates articulated steps with a grounded support foot")
	await capture("backpedal")
	player.begin_kick(0.8,0.46)
	await tick(8)
	check(player.kick_timer>0 and player.locomotion.plant_weight==0 and player.right_leg.rotation.x>0.65,"A shot immediately overrides the directional gait and foot lock")
	player.receive_impact(Vector3.RIGHT,0.9)
	await tick(12)
	check(player.pose=="fall" and player.body_collision.rotation.x< -0.2 and player.locomotion.plant_leg==-1,"A tackle interrupts locomotion and drives the falling body")
	game.reset_practice()
	check(player.locomotion.plant_leg==-1 and player.locomotion.side==0 and player.locomotion.braking==0,"Practice reset clears old contacts and movement blends")
	await reset()
	player.desired=Vector3.RIGHT
	await tick(30)
	var point: Vector3=player.position
	var phase: float=player.run_phase
	game.state="paused"
	for i in range(60):
		game.simulate_match(DT)
		await physics_frame
	check(player.position==point and player.run_phase==phase,"Pause freezes the new gait with the physics body")
	print("LOCOMOTION CHECK: %d checks, %d failures" % [assertions,failures])
	game.free()
	quit(0 if failures==0 else 1)
