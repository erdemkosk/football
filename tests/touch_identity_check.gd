extends SceneTree
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false)
	var striker=game.players[9]
	var centre=game.players[3]
	var wing=game.players[6]
	var keeper=game.players[0]
	var correct_heights := true
	for player in [keeper,striker,centre,wing]:
		correct_heights=correct_heights and is_equal_approx(player.body_scale.y,player.REFERENCE_SCALE.y*player.height_cm/180.0)
	check(correct_heights and keeper.body_scale!=wing.body_scale,"Body proportions follow each selected squad member's actual height")
	check(centre.stance>striker.stance and striker.idle_habit!=centre.idle_habit,"Defenders sit lower in their stance and idle habits differ by shirt")
	striker.energy=1; striker.velocity=Vector3.FORWARD*6; striker.desired=Vector3.FORWARD
	striker.run_phase=PI*0.5
	striker.animate(0.25)
	var fresh_stride: float=absf(striker.left_leg.rotation.x-striker.right_leg.rotation.x)
	var fresh_spine: float=striker.spine.rotation.x
	striker.energy=0.12
	striker.animate(0.25)
	check(absf(striker.left_leg.rotation.x-striker.right_leg.rotation.x)<fresh_stride-0.04 and striker.spine.rotation.x<fresh_spine-0.04,"A tired runner shortens the stride and folds the torso")
	striker.energy=1; striker.velocity=Vector3.ZERO; striker.desired=Vector3.ZERO
	# Compare established poses, not the first frame of the transition from
	# the preceding test's sprint. Explicitly use the same striking foot.
	striker.ball_actions.foot=1
	striker.begin_kick(0.25,0.32,"inside"); striker.kick_timer=0.22; striker.animate(.2)
	var inside_open: float=striker.right_leg.rotation.y
	var inside_hip: float=striker.right_leg.rotation.x
	striker.begin_kick(0.25,0.32,"laces"); striker.kick_timer=0.22; striker.animate(.2)
	check(inside_open>striker.right_leg.rotation.y+0.08 and inside_hip<striker.right_leg.rotation.x,"A short inside-foot pass opens the hip instead of swinging through like a laces kick")
	striker.begin_kick(0.7,0.32,"chip"); striker.kick_timer=0.22; striker.animate(.2)
	check(striker.spine.rotation.x< -0.18,"A lofted kick leans the torso back through contact")
	striker.kick_timer=0; striker.begin_receive("chest"); striker.receive_timer=striker.receive_duration*0.55; striker.animate(.2)
	check(striker.receive_style=="chest" and striker.left_arm.rotation.x>0.7 and striker.right_arm.rotation.x>0.7,"A high ball is taken on the chest with both arms opening")
	striker.begin_receive("thigh"); striker.receive_timer=striker.receive_duration*0.55; striker.animate(.2)
	var thigh: Node3D=striker.left_leg if striker.ball_actions.receive_foot==0 else striker.right_leg
	var knee: Node3D=striker.left_knee if striker.ball_actions.receive_foot==0 else striker.right_knee
	check(thigh.rotation.x>0.55 and knee.rotation.x<-.8,"A bouncing ball raises the receiving thigh with a folded knee")
	striker.begin_receive("foot"); striker.receive_timer=striker.receive_duration*0.55; striker.animate(.2)
	knee=striker.left_knee if striker.ball_actions.receive_foot==0 else striker.right_knee
	var boot: Vector3=knee.to_global(striker.ball_actions.BOOT)
	var contact: Vector3=striker.rig.to_global(striker.ball_actions.receive_offset)
	check(boot.distance_to(contact)<.3 and boot.y>=striker.position.y+striker.boot_ground_height()-.02,"The receiving boot reaches a low pass without sinking through the turf")
	striker.celebration="cheer"
	var punch=game.players[10]
	punch.celebration="cheer"
	striker.animate(1.0/120); punch.animate(1.0/120)
	check(absf(striker.right_arm.rotation.z-punch.right_arm.rotation.z)>0.2,"Goal celebrations are not the same two-arm raise for every shirt")
	print("TOUCH IDENTITY CHECK: %d failures" % failures)
	game.free()
	quit(0 if failures==0 else 1)
