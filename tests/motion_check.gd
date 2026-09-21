extends SceneTree
var game
var failures := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func simulate(p: CharacterBody3D,count: int) -> void:
	for i in range(count):
		await physics_frame
		p.step(1.0/120.0)
func capture(label: String) -> void:
	if not visual: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/"+label+".png")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_match(true)
	game.set_physics_process(false)
	game.set_process(false)
	game.ball.freeze=true
	game.hud.visible=false
	var keeper=game.players[11]
	keeper.position=Vector3(0,0,-46)
	keeper.velocity=Vector3.ZERO
	keeper.desired=Vector3.ZERO
	keeper.facing=Vector3.BACK
	game.camera.position=Vector3(6,6,-37)
	game.camera.look_at(Vector3(0.9,0.7,-46))
	game.camera.size=7.5
	await simulate(keeper,8)
	check(keeper.spine.rotation.x< -0.12 and keeper.left_knee.rotation.x< -0.25,"Keeper waits in a crouched ready stance")
	await capture("keeper-ready")
	keeper.start_dive(2.8,1.7,0.5)
	await simulate(keeper,12)
	var peak:=0.0
	for i in range(29):
		await simulate(keeper,1)
		peak=maxf(peak,keeper.position.y)
	check(peak>0.15 and keeper.position.x>0.35,"Keeper physically leaves the ground and travels sideways")
	check(keeper.body_collision.rotation.z< -1.0,"Diving collider follows the horizontal body")
	check(keeper.right_hand.global_position.x>keeper.position.x+0.7,"Gloves reach toward the shot for the north goalkeeper")
	check(keeper.can_save(keeper.right_hand.global_position),"A ball reaching the glove can be saved")
	check(not keeper.can_save(keeper.position+Vector3(-6,1,0)),"A distant ball cannot be saved magically")
	await capture("keeper-dive")
	await simulate(keeper,59)
	check(keeper.position.y<0.35,"Keeper lands back on the turf")
	await capture("keeper-landing")
	await simulate(keeper,88)
	check(keeper.pose=="run" and keeper.action_timer==0 and keeper.body_collision.rotation.length()<0.01,"Keeper recovers to an upright collider after landing")
	await capture("keeper-recovered")
	var player=game.players[9]
	player.position=Vector3(0,0,-32)
	player.desired=Vector3.FORWARD
	player.sprinting=true
	await simulate(player,80)
	check(player.spine.rotation.x< -0.13 and absf(player.left_knee.rotation.x-player.right_knee.rotation.x)>0.1,"Sprint bends the torso and alternates articulated knees")
	check(player.left_elbow.rotation.x>0.5 and player.right_elbow.rotation.x>0.5,"Elbows remain bent during the running arm swing")
	game.camera.position=player.position+Vector3(4,3.4,4)
	game.camera.look_at(player.position+Vector3(0,0.9,0))
	game.camera.size=4.5
	await capture("player-running")
	var south=game.players[0]
	south.visible=true
	south.position=Vector3(0,0,43)
	south.velocity=Vector3.ZERO
	south.facing=Vector3.FORWARD
	south.desired=Vector3.ZERO
	south.start_dive(-2.8,1.0,0.5)
	await simulate(south,40)
	check(south.position.x< -0.35 and south.left_hand.global_position.x<south.position.x-0.7,"The other goalkeeper mirrors the dive in world space")
	# A shot arriving off-centre must trigger the real keeper AI.
	game.start_match(true)
	game.ball.freeze=false
	keeper.tackle_cooldown=0
	keeper.position=Vector3(0,0,-46)
	game.ball.place(Vector3(2.8,1.1,-35),Vector3(0,1,-25))
	await frames(4)
	game.update_ai(1.0/120.0)
	check(keeper.pose=="dive" and keeper.action_timer>0,"An incoming corner shot triggers an AI dive")
	await simulate(keeper,40)
	game.reset_practice()
	check(keeper.pose=="run" and keeper.action_timer==0 and keeper.velocity==Vector3.ZERO and keeper.body_collision.rotation.length()<0.01,"Practice reset restores a diving keeper to the ready stance")
	game.free()
	await process_frame
	print("MOTION CHECK: %d failures" % failures)
	quit(0 if failures==0 else 1)
