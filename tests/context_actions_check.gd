extends SceneTree
const DT := 1.0/120.0
var game
var p
var assertions := 0
var failures := 0
var visual := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	assertions+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)
func reset() -> void:
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false)
	game.hud.hide()
	game.kick_lock=0; game.boundary_grace=0; game.carrier=-1; game.dribbler=-1
	game.last_kicker=-1; game.last_touch=0
	for q in game.players:
		q.visible=q==p; q.collision_layer=0; q.collision_mask=1
		q.chosen=q==p
		q.reaction.reset(); q.ball_actions.reset(q)
	p.position=Vector3(0,0,-20); p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	p.facing=Vector3.FORWARD; p.rig.rotation=Vector3.ZERO; p.spine.rotation=Vector3.ZERO
	p.last_horizontal=Vector3.ZERO; p.acceleration_lean=Vector3.ZERO; p.run_phase=0
	p.shot_ready_blend=0; p.protecting=false; p.jockeying=false; p.prematch=false
	p.call_timer=0; p.idle_rest=0; p.idle_habit=0
	game.ball.freeze=false; game.ball.active=true
	game.ball.place(Vector3(5,0.23,-25))
	await tick(5)
func tick(count: int=1,contacts: bool=false) -> void:
	for i in range(count):
		game.reactions.update(DT)
		p.step(DT)
		game.kick_lock=maxf(0,game.kick_lock-DT)
		if contacts: game.update_contacts(DT)
		await physics_frame
func place_ball(offset: Vector3,velocity: Vector3=Vector3.ZERO) -> void:
	game.ball.place(p.position+offset,velocity)
	await physics_frame; await physics_frame
func capture(label: String) -> void:
	if not visual: return
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=38
	game.camera.position=p.position+Vector3(4.1,2.8,-5.2)
	game.camera.look_at(p.position+Vector3(0,0.95,0))
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/context-"+label+".png")
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await physics_frame
	game.match_menu.config_path="/tmp/sefc-context-actions.cfg"
	p=game.players[9]
	for side in [-1,1]:
		await reset()
		await place_ball(Vector3(side*0.35,0.23,-0.65))
		var velocity := Vector3(2,3,-27)
		game.strike(9,velocity,0,false,"shot")
		check(p.ball_actions.foot==(0 if side<0 else 1),"The ball's side selects the shooting foot: %d" % side)
		check(game.ball.pending_kick and game.ball.kick_velocity==velocity,"Foot selection preserves immediate release and the aimed trajectory: %d" % side)
		await tick(15)
		var leg: Node3D=p.left_leg if side<0 else p.right_leg
		var support: Node3D=p.right_leg if side<0 else p.left_leg
		check(leg.rotation.x>0.80 and leg.rotation.x>support.rotation.x+0.35,"The selected leg swings over the opposite support leg: %d" % side)
		await capture("shot-left" if side<0 else "shot-right")
	for side in [-1,1]:
		var turns: Array[float]=[]
		for angle in [-0.65,0.65]:
			await reset()
			p.begin_kick(0.65,0.46,"laces",p.position+Vector3(side*0.35,0.23,-0.65),Vector3.FORWARD.rotated(Vector3.UP,angle))
			await tick(14)
			turns.append(p.spine.rotation.y)
		check(turns[1]>turns[0]+0.20,"The torso turns toward the aimed side with either shooting foot: %d" % side)
	await reset()
	p.rig.rotation.y=PI/2; p.facing=Vector3.LEFT
	var point: Vector3=p.rig.to_global(Vector3(-0.3,0.2,-0.5))
	check(p.ball_actions.choose_foot(p,point)==0,"Foot selection follows the player's local orientation")
	await reset()
	p.begin_kick(0.15,0.32,"inside",p.position+Vector3(0.3,0.23,-0.65),Vector3.FORWARD)
	await tick(10)
	var small: float=p.right_leg.rotation.x
	await capture("short-pass")
	await reset()
	p.begin_kick(0.95,0.46,"laces",p.position+Vector3(0.3,0.23,-0.65),Vector3.FORWARD)
	await tick(14)
	check(p.right_leg.rotation.x>small+0.35 and p.spine.rotation.y>0.1,"A driven shot has a larger swing and hip follow-through than a short pass")
	await reset()
	p.energy=0.22
	p.body_language.balance_age=0.1; p.body_language.balance_strength=0.8
	p.begin_kick(0.8,0.46,"laces",p.position+Vector3(-0.4,0.23,-0.7),Vector3.RIGHT,0.9)
	await tick(14)
	check(p.ball_actions.difficulty>0.65 and p.ball_actions.foot==0 and absf(p.spine.rotation.z)>0.03,"A pressured, awkward left-foot strike adds body preparation and balance")
	await capture("awkward-shot")
	var residuals: Array[float]=[]
	for speed in [5.0,19.0]:
		await reset()
		await place_ball(Vector3(-0.30,0.23,-0.9),Vector3.BACK*speed)
		game.ai_receivers[0]=9
		var before: Vector3=game.ball.position
		game.update_contacts(DT)
		check(p.receive_style=="foot" and p.ball_actions.receive_foot==0 and p.receive_timer>0,"A ground pass uses the near foot: %.0f m/s" % speed)
		check(game.ball.position==before and game.ball.pending_touch,"Control applies an impulse without teleporting the ball: %.0f m/s" % speed)
		await physics_frame; await physics_frame
		residuals.append(game.ball.linear_velocity.length())
		await tick(10)
		await capture("soft-control" if speed<10 else "firm-control")
	check(residuals[0]<4 and residuals[1]>residuals[0]+0.5 and residuals[1]<15,"Hard passes retain more momentum after cushioning than soft passes")
	for height in [1.0,1.75]:
		await reset()
		await place_ball(Vector3(0.28,height,-0.75),Vector3(0,-1,5))
		game.update_contacts(DT)
		var expected := "chest" if height>1.3 else "thigh"
		check(p.receive_style==expected and p.receive_timer>0,"Real airborne contact selects "+expected+" control")
		check(game.dribbler==-1 and game.ball.pending_touch,"An aerial cushion does not grant instant foot possession: "+expected)
		await tick(12)
		check(game.ball.linear_velocity.y<0,"The cushioned aerial ball drops under gravity: "+expected)
		await capture(expected+"-control")
	await reset()
	await place_ball(Vector3(0,2.65,-0.6),Vector3(0,-1,5))
	game.update_contacts(DT)
	check(p.receive_timer==0 and not game.ball.pending_touch,"A ball above body reach is never pulled into control")
	await reset()
	game.training=false
	for i in [8,11,12]: game.players[i].visible=true
	game.players[8].position=p.position+Vector3(0,0,10)
	game.players[11].position=p.position+Vector3(7,0,2)
	game.players[12].position=p.position+Vector3(-7,0,4)
	game.ball.place(game.players[8].position+Vector3(0,0.23,-0.6))
	await physics_frame; await physics_frame
	game.strike(8,Vector3(0,5,-10))
	check(9 in game.rules.candidates,"The incoming aerial pass records its offside receiver")
	game.kick_lock=0
	p.facing=Vector3.BACK; p.rig.rotation.y=PI
	await place_ball(Vector3(0,0.9,0.75),Vector3(0,-1,-5))
	game.update_contacts(DT)
	check(game.restart_type=="ENDİREKT VURUŞ" and p.receive_timer==0 and game.dribbler==-1 and not game.ball.pending_touch,"An illegal airborne touch stops at the whistle without falling through to ground possession")
	await reset()
	await place_ball(Vector3(1.27,0.23,-0.36),Vector3(-5,0,0))
	var before: Vector3=game.ball.position
	game.update_contacts(DT)
	check(p.receive_timer>0 and p.ball_actions.stretch>0.5 and game.dribbler==-1,"A marginal ball triggers a reaching touch without guaranteed possession")
	check(game.ball.pending_touch and game.ball.position==before,"The reaching toe changes the physical ball through an impulse")
	await tick(12)
	check(game.ball.position.distance_to(before)>0.1 and p.touch_cooldown>0,"A stretched touch leaves a live loose ball and cannot instantly recapture it")
	await capture("toe-reach")
	await reset()
	await place_ball(Vector3(1.8,0.23,0),Vector3(-5,0,0))
	game.update_contacts(DT)
	check(p.receive_timer==0 and not game.ball.pending_touch,"A distant ball is beyond even the extended foot's reach")
	await reset()
	p.desired=Vector3.FORWARD
	await tick(40)
	p.begin_receive("foot",p.position+Vector3(-0.28,0.23,-0.62),Vector3.BACK*12,0.1)
	var old: Array[Quaternion]=[]
	for joint in p.kick_joints: old.append(joint.quaternion)
	var largest := 0.0
	for frame in range(90):
		if frame==18: p.begin_kick(0.45,0.32,"inside",p.position+Vector3(-0.28,0.23,-0.62),Vector3.FORWARD)
		await tick()
		for j in range(old.size()):
			largest=maxf(largest,old[j].angle_to(p.kick_joints[j].quaternion))
			old[j]=p.kick_joints[j].quaternion
	check(largest<0.55 and p.velocity.z< -5.8 and p.receive_timer==0 and p.kick_timer==0,"Running control-to-pass-to-run blends continuously without delaying movement (%.3f rad)" % largest)
	for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.RIGHT,Vector3.LEFT]:
		await reset()
		p.receive_impact(direction,0.95)
		await tick(40)
		var lean: Vector3=p.rig.global_basis.y.normalized()*Vector3(1,0,1)
		check(lean.normalized().dot(direction)>0.9,"The body yields in the actual impact direction "+str(direction))
		check(p.facing.dot(Vector3.FORWARD)>0.99,"A hit does not instantly turn the footballer to face the attacker")
		var lowest: float=minf(p.left_hand.global_position.y,p.right_hand.global_position.y)-p.position.y
		print("BRACE ",direction," hand=",lowest," root=",p.rig.position)
		check(lowest>=0.08 and lowest<0.25,"Hands reach the turf to brace the landing without penetrating it")
		check(p.position.y<0.08,"Rotating the collider does not lift the footballer off the turf")
		await capture("fall-"+str(direction))
		await tick(45)
		await capture("rise-"+str(direction))
		await tick(65)
		check(p.action_timer==0 and p.body_collision.rotation.length()<0.01,"Recovery restores the upright collider and free movement")
	await reset()
	game.strike(9,Vector3(0,5,-27),0,false,"shot")
	game.ball.place(Vector3(0,3,-50.6),Vector3(0,1,-20))
	await physics_frame; await physics_frame
	game.previous_ball=Vector3(0,3,-49.8)
	game.check_boundaries()
	await tick(83)
	check(p.reaction.kind=="miss" and p.reaction.weight>0.9,"A missed shot triggers the shooter's short disappointment reaction")
	await capture("miss")
	await reset()
	game.strike(9,Vector3(0,0,-10))
	p.kick_timer=0; game.kick_lock=0
	var interceptor=game.players[18]
	interceptor.visible=true; interceptor.position=p.position+Vector3(0,0,-14)
	game.ball.place(interceptor.position+Vector3(0,0.23,0.75),Vector3(0,0,-5))
	await physics_frame; await physics_frame
	game.update_contacts(DT)
	await tick(25)
	check(p.reaction.kind=="sorry" and p.right_arm.rotation.z>2,"An intercepted pass triggers the passer's apology gesture")
	await capture("apology")
	p.desired=Vector3.RIGHT
	await tick(12)
	check(p.reaction.kind=="" and p.velocity.x>3,"Movement input immediately cancels the reaction and keeps responding")
	await reset()
	var keeper=game.players[0]
	p.position=Vector3(0,0,35)
	keeper.visible=true; keeper.position=Vector3(0,0,48)
	keeper.rig.rotation=Vector3.ZERO; keeper.animate(1.0)
	game.ball.place(keeper.left_hand.global_position,Vector3(0,-0.1,1))
	await physics_frame; await physics_frame
	game.last_touch=1
	game.goalkeeping.update(0,DT)
	check(game.saves[0]>0,"The goalkeeper's real save event dispatches teammate reactions")
	await tick(28)
	check(p.reaction.kind=="applaud" and p.reaction.weight>0.9,"A nearby teammate applauds a goalkeeper's save when play is safe")
	var hand_min := INF
	var hand_max := 0.0
	for frame in range(25):
		await tick()
		var gap: float=p.left_hand.global_position.distance_to(p.right_hand.global_position)
		hand_min=minf(hand_min,gap); hand_max=maxf(hand_max,gap)
	check(hand_min<0.18 and hand_max>0.32,"Applause brings the hands together and opens them again")
	await capture("applause")
	game.ball.position=p.position+Vector3(0,0.23,-4)
	await tick(12)
	check(p.reaction.kind=="","A live rebound immediately brings the player back to football")
	game.reactions.kicked(9,"shot"); p.reaction.begin("miss",game.ball.position)
	game.reset_practice()
	check(p.receive_timer==0 and p.reaction.kind=="" and game.reactions.shooter==-1,"New practice clears reception, reaction and event history")
	print("CONTEXT ACTIONS CHECK: %d checks, %d failures" % [assertions,failures])
	game.free(); quit(0 if failures==0 else 1)
