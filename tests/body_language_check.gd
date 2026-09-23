extends SceneTree
const Language = preload("res://scripts/body_language.gd")
const DT := 1.0/120.0
var game
var player
var assertions := 0
var failures := 0
var visual := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	assertions+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func reset() -> void:
	game.state="playing"
	game.dribbler=-1
	game.support.reset()
	game.ball.freeze=true
	game.ball.pending_reset=false
	game.ball.pending_kick=false
	game.ball.linear_velocity=Vector3.ZERO
	game.ball.position=Vector3(0,0.23,-31)
	for i in range(game.players.size()):
		var p=game.players[i]
		p.visible=p==player
		p.position=Vector3(i*2-20,0,15)
		p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
		p.facing=Vector3.FORWARD
		p.rig.rotation=Vector3.ZERO; p.rig.position=Vector3.ZERO
		p.spine.rotation=Vector3.ZERO
		p.action_timer=0; p.kick_timer=0; p.shot_preparation=0; p.shot_ready_blend=0
		p.call_timer=0; p.pose="run"; p.celebration=""; p.discipline_pose=""; p.set_piece_pose=""
		p.prematch=false; p.protecting=false; p.jockeying=false; p.feint_time=0
		p.collision_layer=0; p.collision_mask=1
		p.last_horizontal=Vector3.ZERO; p.acceleration_lean=Vector3.ZERO
		p.reset_stamina()
		p.locomotion.reset(); p.body_language.reset(p)
	player.position=Vector3(0,0,-20)
	await tick(5)

func tick(count: int=1) -> void:
	for frame in range(count):
		for i in range(game.players.size()):
			var p=game.players[i]
			if not p.visible: continue
			p.body_language.observe(game,i)
			p.step(DT)
		await physics_frame

func capture(label: String,close: bool=false) -> void:
	if not visual: return
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=38
	game.camera.position=player.position+(Vector3(1.4,2.6,-3.0) if close else Vector3(4.4,3.0,-5.5))
	game.camera.look_at(player.position+Vector3(0,1.55 if close else 1,0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/body-language-"+label+".png")

func gaze_alignment() -> float:
	return (-player.head_joint.global_basis.z).normalized().dot((game.ball.position-player.head_joint.global_position).normalized())

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-body-language-settings.cfg"
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false)
	game.hud.hide()
	player=game.players[9]
	await reset()
	game.ball.position=player.position+Vector3(7,0.23,-8)
	player.desired=Vector3.FORWARD
	await tick(38)
	check(player.head_joint.rotation.y< -0.55 and gaze_alignment()>0.99,"Running head tracks a ball beside the run direction")
	check(player.facing.dot(Vector3.FORWARD)>0.99 and player.velocity.z< -player.movement_speed()*.96,"Looking sideways never steers or slows the physics body")
	await capture("tracking",true)
	game.ball.position=player.position+Vector3(-8,4,-7)
	await tick(55)
	check(player.head_joint.rotation.y>0.7 and player.head_joint.rotation.x>0.1,"Head follows a high ball across to the other side")
	check(absf(player.eye_joints[0].rotation.y)<=0.241 and absf(player.eye_joints[0].rotation.x)<=0.181,"Eye tracking stays within small natural limits")
	await capture("high-ball",true)
	game.ball.position=player.position+Vector3(-1,0.23,10)
	await tick(35)
	var shoulder: float=player.head_joint.rotation.y
	game.ball.position.x=player.position.x+0.1
	await tick(5)
	check(absf(player.head_joint.rotation.y)<=1.201 and shoulder*player.head_joint.rotation.y>0,"A ball behind cannot twist the neck around or flip shoulders at the centre")
	var hair: Node3D=player.head_joint.get_node("HairCap")
	check(hair.position.is_equal_approx(Vector3(0,0.16,0)) and hair.get_parent()==player.head_joint,"Fitted hair follows the skull through every neck rotation")
	await reset()
	game.ball.position=player.position+Vector3(0,0.23,-12)
	game.ball.linear_velocity=Vector3.BACK*10
	await tick(20)
	check(absf(player.head_joint.rotation.y)>0.55 and player.body_language.scan_age<0.3,"An approaching pass triggers a brief pre-reception shoulder check")
	await capture("scan",true)
	game.ball.position=player.position+Vector3(0,0.23,-2.8)
	await tick(28)
	check(player.body_language.urgent and absf(player.head_joint.rotation.y)<0.05 and gaze_alignment()>0.97,"Before close control the player returns attention to the ball")
	await capture("receive",true)
	await reset()
	game.ball.position=player.position+Vector3(0,0.23,-3)
	game.ball.linear_velocity=Vector3.BACK*24
	await tick(8)
	check(player.body_language.scan_age>=0.46 and absf(player.head_joint.rotation.y)<0.05,"An already urgent pass skips the distracting shoulder glance")
	await reset()
	var owner=game.players[8]
	owner.visible=true; owner.position=Vector3(-9,0,-22)
	game.dribbler=8
	game.ball.position=owner.position+Vector3(0,0.23,-0.6)
	game.support.targets[9]=player.position+Vector3(7,0,-7)
	player.body_language.point_cooldown=0
	player.body_language.scan_cooldown=10
	await tick(34)
	var arm_direction: Vector3=(player.right_hand.global_position-player.right_arm.global_position).normalized()
	var route: Vector3=(game.support.targets[9]-player.position).normalized()
	check(player.body_language.point_age<0.5 and arm_direction.dot(route)>0.94,"The extended arm points into the actual open support run")
	check(player.call_timer==0 and not player.call_label.visible,"An automatic space gesture does not create an explicit pass request")
	await capture("point-right")
	await tick(110)
	check(player.body_language.point_age>=Language.POINT_TIME and player.body_language.point_cooldown>2 and player.right_arm.rotation.z<0.3,"The gesture lowers naturally and cannot repeat continuously")
	game.support.targets[9]=player.position+Vector3(-7,0,-7)
	player.body_language.point_cooldown=0
	await tick(33)
	arm_direction=(player.left_hand.global_position-player.left_arm.global_position).normalized()
	route=(game.support.targets[9]-player.position).normalized()
	check(player.body_language.point_left and arm_direction.dot(route)>0.94,"Space on the left uses the left arm without reaching across the body")
	await capture("point-left")
	player.call_timer=1
	await tick(2)
	check(player.right_arm.rotation.z>2.5 and player.body_language.point_age>=Language.POINT_TIME,"The user's raised-hand pass request takes priority")
	player.call_timer=0; player.body_language.point_cooldown=0
	player.shot_preparation=1
	await tick(20)
	check(player.spine.rotation.y< -0.15 and player.body_language.point_age>=Language.POINT_TIME,"Shot preparation keeps its coiled torso and balancing arms")
	player.begin_kick(0.9,0.46)
	await tick(12)
	check(player.right_leg.rotation.x>0.8 and player.body_language.point_age>=Language.POINT_TIME,"A shot immediately overrides a space gesture")
	await reset()
	owner.visible=true; owner.position=Vector3(-9,0,-22)
	game.dribbler=8; game.ball.position=owner.position+Vector3(0,0.23,-0.6)
	game.support.targets[9]=player.position+Vector3(7,0,-7)
	var rival=game.players[19]
	rival.visible=true; rival.position=game.support.targets[9]
	player.body_language.point_cooldown=0
	await tick(5)
	check(player.body_language.point_age>=Language.POINT_TIME,"A marked destination is not advertised as free space")
	rival.position=(game.ball.position+game.support.targets[9])*0.5
	await tick(5)
	check(player.body_language.point_age>=Language.POINT_TIME,"A blocked passing lane suppresses the invitation")
	rival.visible=false
	await tick(5)
	var before_cancel: Quaternion=player.right_arm.quaternion
	game.dribbler=-1
	await tick()
	check(before_cancel.angle_to(player.right_arm.quaternion)<0.13,"Losing possession during gesture entry does not pop the arm up")
	await tick(32)
	check(player.body_language.point_weight==0,"An interrupted invitation blends all the way back into the stride")
	await reset()
	owner.visible=true; owner.position=Vector3(-9,0,-22)
	game.dribbler=8; game.ball.position=owner.position+Vector3(0,0.23,-0.6)
	for i in [5,6,7,9]:
		var p=game.players[i]
		p.visible=true; p.position=Vector3((i-7)*3,0,-24)
		game.support.targets[i]=p.position+Vector3(3,0,-7)
		p.body_language.point_cooldown=0
	await tick(2)
	var pointing := 0
	for i in [5,6,7,9]:
		if game.players[i].body_language.point_age<Language.POINT_TIME: pointing+=1
	check(pointing==2,"Only two teammates can signal at once instead of synchronized team-wide gestures")
	await reset()
	rival.visible=true; rival.position=player.position+Vector3(1.5,0,0)
	player.collision_layer=2; player.collision_mask=3
	rival.collision_layer=2; rival.collision_mask=3
	player.desired=Vector3.RIGHT
	for frame in range(90):
		await tick()
		if player.body_language.contact_count>0: break
	check(player.body_language.contact_count==1 and rival.body_language.contact_count==1,"A real capsule collision starts a balance response on both players")
	player.desired=Vector3.ZERO
	await tick(12)
	check(player.body_language.balance_age<0.2 and absf(player.spine.rotation.x)>0.12 and absf(player.right_arm.rotation.z)>0.45,"Contact visibly yields the torso and opens the arms")
	check(player.action_timer==0 and player.pose=="run" and player.desired==Vector3.ZERO,"A light bump never inserts an input lock or a tackle/fall state")
	await capture("contact")
	var count: int=player.body_language.contact_count
	player.body_language.contact(player,Vector3.LEFT,0.8)
	check(player.body_language.contact_count==count,"Sustained contact cannot restart the flinch every frame")
	player.desired=Vector3.LEFT
	await tick()
	check(player.velocity.x<0,"Direction input responds on the next tick during recovery")
	await tick(75)
	check(player.body_language.balance_age>=0.58 and player.action_timer==0,"The player recovers into the live running stride")
	await capture("recovered")
	player.receive_impact(Vector3.RIGHT,0.95)
	await tick(16)
	check(player.pose=="fall" and player.body_collision.basis.y.dot(Vector3.RIGHT)>0.2 and player.body_language.balance_age>=0.58,"A strong tackle falls in the impact direction and cancels the subtle layer")
	await reset()
	player.protecting=true
	player.body_language.contact(player,Vector3.RIGHT,0.65)
	await tick(14)
	check(player.body_language.contact_count==1 and absf(player.spine.rotation.z)>0.10 and player.protecting,"Shielding retains its stance while absorbing shoulder contact")
	await capture("shield-contact")
	await reset()
	player.set_piece_pose="throw"; player.handling_blend=1
	game.state="set_piece"
	await tick(10)
	check(player.right_arm.rotation.x>2.8 and not player.body_language.enabled,"Throw-in handling has priority over live-play gestures")
	var travels: Array[Vector3]=[]
	for with_gaze in [false,true]:
		await reset()
		player.desired=Vector3.FORWARD
		for frame in range(90):
			player.body_language.enabled=with_gaze
			player.body_language.ball_target=player.position+Vector3(7,1,-8)
			player.step(DT)
			await physics_frame
		travels.append(player.position)
	check(travels[0].distance_to(travels[1])<0.0001,"Identical input travels exactly the same physical distance with gaze enabled or disabled")
	await reset()
	game.ball.position=player.position+Vector3(8,0.23,-8)
	await tick(28)
	var head_pose: Transform3D=player.head_joint.transform
	var scan_age: float=player.body_language.scan_age
	game.state="paused"
	for frame in range(30): game.simulate_match(DT)
	check(player.head_joint.transform==head_pose and player.body_language.scan_age==scan_age,"Pausing freezes gestures and gaze with the match")
	check(player.head_joint in game.replay.nodes and player.eye_joints[0] in game.replay.nodes,"Replay captures the head and eye joints with the existing skeleton")
	game.replay.frames.clear()
	for frame in range(24): game.replay.frames.append(game.replay.snapshot())
	var started: bool=game.replay.begin()
	player.head_joint.rotation=Vector3.ZERO
	game.replay.update(0.1)
	check(started and player.head_joint.transform.is_equal_approx(head_pose),"Playback restores the recorded gaze")
	game.replay.finish()
	check(player.head_joint.transform.is_equal_approx(head_pose),"Leaving replay restores the live head pose")
	game.reset_practice()
	check(not player.body_language.enabled and player.head_joint.rotation==Vector3.ZERO and player.body_language.contact_count==0,"A new practice clears old gaze, contacts and gestures")
	game.state="playing"
	game.ball.freeze=false; game.ball.active=true
	game.ball.place(player.position+Vector3(6,0.23,-8))
	for frame in range(20):
		game.simulate_match(DT)
		await physics_frame
	check(player.body_language.enabled and absf(player.head_joint.rotation.y)>0.3,"Normal match simulation supplies the live ball to the animation layer")
	print("BODY LANGUAGE CHECK: %d checks, %d failures" % [assertions,failures])
	game.free()
	quit(0 if failures==0 else 1)
