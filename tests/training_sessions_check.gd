extends "res://tests/training_modes_check.gd"
const Catalog=preload("res://scripts/training_catalog.gd")

func click(control: Control) -> void:
	var at: Vector2=root.get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*.5))
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=at; event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		Input.parse_input_event(event); Input.flush_buffered_events()

func practice(mode: String) -> void:
	game.training_menu.hide(); game.training_menu.result={}
	game.start_match(true,false,false,mode)
	await tick(6)

func pass_gate() -> void:
	var drill=game.training_drills.challenges
	var before: int=drill.completed
	var direction: Vector3=(drill.target-game.ball.position)*Vector3(1,0,1)
	game.players[9].facing=direction.normalized()
	game.kick_lock=0
	check(game.commit_strike(9,direction.normalized()*29+Vector3.UP*.12,0,false,"pass"),"A physical pass leaves the training player's foot")
	for frame in range(600):
		await tick()
		if drill.completed>before: break

func steer_control() -> void:
	var drill=game.training_drills.challenges
	var destination: Vector3=drill.receive_target
	if drill.control_received: destination=drill.control_exit+(drill.control_exit-drill.receive_target).normalized()*1.2
	var offset: Vector3=(destination-game.players[9].position)*Vector3(1,0,1)
	var direction:=offset.normalized() if offset.length()>.25 else Vector3.ZERO
	game.controller.stick=Vector2(direction.dot(game.match_camera.ground_right()),-direction.dot(game.match_camera.ground_forward()))
	game.controller.using_gamepad=true

func moving_control() -> void:
	var drill=game.training_drills.challenges
	var before: int=drill.completed
	var previous_points: int=drill.points
	for frame in range(1400):
		steer_control(); await tick()
		if drill.completed>before: break
	game.controller.stick=Vector2.ZERO
	check(drill.completed==before+1 and drill.points>previous_points,"Running to the pass and dribbling through the exit earns a physical control score")

func run() -> void:
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.set_physics_process(false); game.set_process(false)
	game.match_menu.config_path="/tmp/sefc-training-sessions.cfg"; game.controller.device=0
	var c=game.career
	c.save_root="/tmp/sefc-training-sessions-"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(c.save_root)
	check(c.new_career("c00",1),"Prepare an isolated career for manual/free-practice separation")
	var saved_players: Dictionary=c.world.players.duplicate(true)
	for mode in Catalog.SCORED:
		await practice(mode)
		check(game.training_drills.challenges.active() and game.controlled==9 and is_instance_valid(game.training_drills.challenges.props),"The scored exercise opens with its own physical targets: "+mode)
		check(game.state=="set_piece" if mode=="penalty" else game.state=="playing","The exercise starts in an actionable state: "+mode)
		check(game.training_drills.challenges.completed==0,"Opening an exercise does not consume any attempt: "+mode)
	await practice("passing")
	var ch=game.training_drills.challenges
	await pass_gate()
	check(ch.completed==1 and ch.points>=60,"A real rolling ball crossing the correct gate earns points")
	await tick(145)
	var attempts: int=ch.completed
	key(KEY_R); key(KEY_R,false)
	check(ch.completed==attempts+1 and ch.points<=100,"Manual retry consumes the incomplete attempt without inventing points")
	var age: float=ch.age
	tap(JOY_BUTTON_START); await tick(90)
	check(game.state=="paused" and ch.age==age,"Pausing freezes the scored drill timer")
	game.resume()
	await practice("crossing")
	# A ground pass reaching the ring is not a successful aerial cross.
	var direction: Vector3=(ch.target-game.ball.position)*Vector3(1,0,1)
	game.commit_strike(9,direction.normalized()*27,0,false,"pass")
	await tick(150)
	check(ch.points==0,"The cross target does not reward an ordinary ground pass")
	await practice("crossing")
	var velocity: Vector3=game.Passing.Motion.lob_velocity(game.ball.position,ch.target+Vector3.UP*.25,1.5,game.weather)
	game.kick_lock=0; game.commit_strike(9,velocity,0,false,"cross")
	for frame in range(350):
		await tick()
		if ch.completed>0: break
	check(ch.completed==1 and ch.points>=50,"A real airborne cross landing in the marked area earns accuracy points")
	await practice("control")
	var start: Vector3=game.players[9].position
	for frame in range(1000):
		await tick()
		if ch.completed>0: break
	check(ch.fed and ch.completed==1 and ch.points==0 and ch.age<8 and game.flat_distance(start,game.players[9].position)<.15,"Waiting at the start earns no points and a missed pass ends promptly without automatic movement")
	await practice("control")
	for frame in range(800):
		steer_control()
		await tick()
		if ch.control_received: break
	game.controller.stick=Vector2.ZERO
	await tick(90)
	check(ch.control_received and ch.completed==0 and ch.points==0,"Meeting the pass requires running to a different area; receiving alone does not complete the exit")
	await moving_control()
	await practice("shooting")
	game.players[11].visible=false; game.players[11].collision_layer=0
	velocity=(ch.target-game.ball.position).normalized()*35
	game.commit_strike(9,velocity,0,false,"shot")
	for frame in range(400):
		await tick()
		if ch.completed>0: break
	check(ch.completed==1 and ch.points>=55 and game.practice_goals==1,"A shot crossing the real goal line is scored once")
	check(c.world.players==saved_players,"All main-menu drills leave every saved career player unchanged")
	game.return_menu(); game.career_screen.open_hub(); game.career_screen.go("training")
	var rows: Array=c.training.data().slots
	var player_id: String=rows[0].player
	var mode: String="distribution" if c.player(player_id).keeper else "control"
	check(c.training.assign(0,player_id,mode),"A coach-selected player can be assigned a chosen exercise")
	game.career_screen.build()
	var play_button: Button
	for item in game.career_screen.controls.get_children():
		if item is Button and item.text=="OYNA": play_button=item; break
	click(play_button); await tick(8)
	check(not c.training.active.is_empty() and not game.career_screen.visible and game.players[9].career_id==player_id,"The career Play button launches the actual selected player's session")
	check(game.players[9].attributes==c.player(player_id).attributes and not c.in_match,"The exercise uses saved player abilities without opening a career fixture")
	var before: Dictionary=c.player(player_id).duplicate(true)
	var day: int=c.world.date
	c.advance_one()
	check(c.world.date==day and c.advance_to_event().contains("antrenmanı") and c.world.date==day,"A running manual session cannot advance its career calendar")
	for attempt in range(6):
		if mode=="control": await moving_control()
		else: await pass_gate()
		if attempt<5: await tick(145)
	check(game.training_menu.visible and game.training_menu.result.career and game.training_menu.result.score>=60,"Six physical attempts open the career result card with an earned grade")
	check(rows[0].done and rows[0].xp>0 and c.player(player_id).development!=before.development,"The earned score develops only the assigned career player")
	var progress: Dictionary=c.player(player_id).duplicate(true)
	ch.finish(); ch.finish()
	check(c.player(player_id)==progress,"Repeated result callbacks cannot duplicate the reward")
	tap(JOY_BUTTON_B); await tick(2)
	check(game.career_screen.visible and game.career_screen.page=="training" and not game.training,"Controller Back returns to the weekly career program")
	check(c.load_slot(1) and c.player(player_id)==progress and c.training.data().slots[0].done,"The awarded grade and exact player progress survive a cold save reload")
	var next_player: String=c.training.data().slots[1].player
	var next_before: Dictionary=c.player(next_player).duplicate(true)
	check(c.training.start(1),"A second weekly exercise can be started")
	game.training_menu.open_menu()
	check(c.training.active.is_empty() and c.player(next_player)==next_before and not c.training.data().slots[1].done,"Leaving an incomplete career session gives no progress and returns safely")
	check(c.training.start(1),"The uncompleted session can be resumed without awarding a free grade")
	for i in range(6): key(KEY_R); key(KEY_R,false)
	check(game.training_menu.visible and game.training_menu.result.score==0 and c.player(next_player)==next_before,"Skipping all six attempts completes with zero points and no development")
	tap(JOY_BUTTON_A)
	check(not c.training.active.is_empty() and c.training.active.slot==2 and not game.training_menu.visible,"Controller Confirm on the result starts the next available weekly session")
	game.training_menu.open_menu()
	print("TRAINING SESSIONS CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(1 if failures else 0)
