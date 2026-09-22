extends SceneTree
const DT := 1.0/120
var game
var p
var checks := 0
var failures := 0
var visual := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS: "+label)
	else: failures+=1; push_error("FAIL: "+label)

func setup() -> void:
	game.start_match(true)
	game.set_process(false); game.set_physics_process(false); game.hud.hide()
	for q in game.players:
		q.visible=q==p; q.collision_layer=0
	p.position=Vector3(0,0,-20); p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
	p.rig.rotation=Vector3.ZERO; p.facing=Vector3.FORWARD; p.run_phase=0
	p.body_language.enabled=false; p.motion_transition.reset(); p.animate(1)
	game.ball.freeze=true; game.ball.pending_reset=false; game.ball.pending_kick=false; game.ball.pending_touch=false
	game.ball.position=p.position+Vector3(.18,.23,-.78); game.ball.linear_velocity=Vector3.ZERO
	game.last_kicker=-1; game.last_touch=0; game.kick_lock=0; game.feedback.reset()

func tick(delta: float=DT) -> void:
	game.kick_contact.prepare(delta)
	p.step(delta)
	game.kick_contact.resolve()

func capture(label: String,actor) -> void:
	if not visual: return
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=40
	game.camera.position=actor.position+actor.facing*4.4+Vector3(3.3,2.2,0)
	game.camera.look_at(actor.position+Vector3(0,.8,0))
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/motion-"+label+".png")

func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
	game.match_menu.config_path="/tmp/sefc-motion-contact.cfg"
	p=game.players[9]
	for rate in [30,60,120]:
		for kind in ["kick","cross","shot"]:
			setup()
			var velocity := Vector3(0,7 if kind=="cross" else 1,-26 if kind=="shot" else -14)
			check(game.strike(9,velocity,0,false,kind),"%s accepted at %d Hz" % [kind,rate])
			check(not game.ball.pending_kick and game.feedback.event_count==0 and p.kick_timer>0,"Input starts motion before impulse and sound")
			var elapsed := 0.0
			while not game.kick_contact.pending.is_empty() and elapsed<.2:
				tick(1.0/rate); elapsed+=1.0/rate
			check(game.ball.pending_kick and game.kick_contact.last_gap<=.36 and elapsed<=.1,"Real boot contact commits within 100 ms at %d Hz" % rate)
			check(game.feedback.event_count==1 and game.last_kicker==9 and game.ball.kick_velocity.distance_to(velocity)<.001,"One contact commits trajectory, sound and feedback together")
			if kind=="shot": check(game.stadium.crowd.event_kind=="shot","The crowd reacts at the shot's actual contact")
			if rate==120: await capture(kind+"-contact",p)
	for direction in [Vector3.FORWARD,Vector3.LEFT]:
		setup(); p.collision_layer=2; p.velocity=direction*6; p.desired=direction; p.facing=direction
		p.rig.rotation.y=atan2(-direction.x,-direction.z); p.animate(1)
		game.ball.freeze=false; game.ball.place(p.position+direction*.82+Vector3.UP*.23,direction*6)
		await physics_frame; await physics_frame
		game.strike(9,direction*25+Vector3.UP*2,0,false,"shot")
		for i in range(18): tick(); await physics_frame
		check(game.last_kicker==9 and game.ball.linear_velocity.dot(direction)>20 and game.kick_contact.last_gap<=.36,"A moving boot releases a live running ball in either direction")
	setup(); game.strike(9,Vector3(0,2,-28),0,false,"shot")
	p.desired=Vector3.RIGHT; tick()
	check(p.velocity.x>0 and not game.ball.pending_kick,"Movement responds on the first tick during the kick approach")
	p.receive_impact(Vector3.BACK,.9); tick()
	check(game.kick_contact.pending.is_empty() and not game.ball.pending_kick and game.feedback.event_count==0,"A tackle before contact cancels the shot without ghost sound or impulse")
	setup(); game.strike(9,Vector3.FORWARD*16)
	game.ball.position.x+=3
	for i in range(24): tick()
	check(not game.ball.pending_kick and game.kick_contact.pending.is_empty(),"A ball outside anatomical reach is never remotely kicked")
	setup(); game.strike(9,Vector3.FORWARD*16)
	game.state="paused"; game.simulate_match(.1)
	check(not game.kick_contact.pending.is_empty() and game.kick_contact.pending.age==0,"Pause preserves and freezes the short contact approach")
	game.state="playing"
	for i in range(10): tick()
	check(game.ball.pending_kick,"The paused approach resumes with one physical contact")
	setup(); p.begin_kick(.8,.46,"laces",game.ball.position,Vector3.FORWARD)
	var errors: Array[float]=[]
	for i in range(14):
		p.step(DT)
		if p.ball_actions.support_weight>.98:
			var knee=p.left_knee if p.ball_actions.support_foot==0 else p.right_knee
			errors.append(knee.to_global(p.ball_actions.BOOT).distance_to(p.ball_actions.support_anchor))
	check(errors.size()>=2 and errors.max()<.05,"A shot bears weight on a stable support foot in world space")
	for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.BACK]:
		setup(); p.desired=direction; game.ball.linear_velocity=Vector3.BACK*8
		var point: Vector3=game.ball.position
		game.first_touch.receive(9,false)
		check(game.ball.touch_velocity.dot(direction)>1 and p.ball_actions.receive_direction.dot(direction)>.99,"First touch follows the requested left/right/back direction")
		check(game.ball.position==point and game.ball.touch_impulse_limit>0,"Directed control applies a bounded impulse without teleporting the ball")
		p.receive_timer*=.55; p.animate(.2)
		if direction==Vector3.RIGHT: await capture("directed-control",p)
	setup(); p.desired=Vector3.RIGHT; game.ball.linear_velocity=Vector3.BACK*8
	var original_control: float=p.attributes.control
	p.attributes.control=95; game.first_touch.receive(9,false)
	var precise: float=p.ball_actions.receive_distance
	p.receive_timer=0; p.attributes.control=50; game.first_touch.receive(9,false)
	check(p.ball_actions.receive_distance>precise+.2,"Less technical players expose the ball farther on the same directed control")
	p.attributes.control=original_control
	setup()
	var original: Dictionary=p.identity()
	p.height_cm=170; p.weight_kg=62; p.attributes.control=94; p.attributes.acceleration=94; p.apply_build()
	var agile := Vector3(p.gait_cadence,p.gait_stride,p.gait_sway)
	p.height_cm=194; p.weight_kg=94; p.attributes.control=66; p.attributes.acceleration=64; p.apply_build()
	check(agile.x>p.gait_cadence and agile.y<p.gait_stride and agile.z<p.gait_sway,"Agile and powerful builds have distinct cadence, stride and torso weight")
	p.apply_identity(original)
	setup()
	var q=game.players[17]; q.visible=true; q.position=p.position+Vector3(.8,0,0); q.desired=Vector3.ZERO; q.velocity=Vector3.ZERO
	p.protecting=true; game.dribbler=9
	for i in range(12): game.physical_contests.update(DT)
	check(game.physical_contests.pairs.has([9,17]) and p.contest_direction.dot(q.contest_direction)<-.99,"Stationary shielding creates a matched pair with opposite contact directions")
	p.animate(.1); q.animate(.1); await capture("shield-duel",p)
	game.dribbler=-1; game.ball.position=p.position+Vector3(-.5,.23,-.65)
	game.duels.standing_tackle(9)
	check(p.tackle_foot==0,"A lateral standing tackle chooses the foot on the ball's side")
	setup(); p.velocity=Vector3.FORWARD*4; p.desired=Vector3.FORWARD
	p.begin_receive("foot",game.ball.position,Vector3.BACK*9)
	for i in range(8): p.step(DT)
	var phase: float=p.run_phase
	var before: Quaternion=p.spine.quaternion
	game.dribbler=9; game.last_touch=0
	check(game.skills.start(9,"roll"),"A first touch can chain directly into a skill")
	game.skills.update(DT); p.step(DT)
	check(p.run_phase>phase and before.angle_to(p.spine.quaternion)<.3,"First touch to skill retains the current stride and torso continuity")
	check(game.strike(9,Vector3.FORWARD*15),"A skill can chain directly into a pass")
	for i in range(14): tick()
	check(game.ball.pending_kick and p.skill_move.is_empty(),"The chained pass owns one contact and cleanly ends the skill")
	setup()
	var keeper=game.players[11]; p.visible=false; keeper.visible=true
	keeper.position=Vector3(0,0,-24); keeper.facing=Vector3.FORWARD; keeper.rig.rotation=Vector3.ZERO
	for kind in ["foot","spread","smother","rebound"]:
		keeper.action_timer=0; keeper.tackle_cooldown=0; keeper.keeper_motion.reset(); keeper.animate(1)
		var point: Vector3=keeper.position+Vector3(.5,.23,-.45)
		check(keeper.keeper_motion.start(keeper,kind,point),"Keeper has a distinct %s action" % kind)
		keeper.action_timer=keeper.keeper_motion.duration-.2; keeper.animate(.2)
		var contact: Vector3=keeper.right_knee.to_global(p.ball_actions.BOOT) if kind=="foot" else keeper.right_hand.global_position
		check(keeper.can_save(contact) and not keeper.can_save(contact+Vector3.RIGHT*5),"Keeper %s save requires actual body/limb proximity" % kind)
		game.ball.position=contact
		await capture("keeper-"+kind,keeper)
		keeper.keeper_motion.saved(keeper)
		check(not keeper.can_save(contact) and not keeper.keeper_motion.rebound_ready(keeper),"A saved ball cannot trigger an instantaneous second save")
	keeper.motion_clock+=1
	keeper.action_timer=0; keeper.desired=Vector3.ZERO
	for i in range(3): keeper.step(DT); await physics_frame
	check(keeper.keeper_motion.rebound_ready(keeper),"A grounded keeper can attempt a rebound after real recovery time")
	for second in [false,true]:
		game.goalkeeping.reset(); keeper.action_timer=0; keeper.tackle_cooldown=0; keeper.touch_cooldown=0
		keeper.keeper_motion.reset(); keeper.pose="run"; keeper.position=Vector3(0,0,-47)
		keeper.velocity=Vector3.ZERO; keeper.desired=Vector3.ZERO; keeper.facing=Vector3.BACK; keeper.rig.rotation=Vector3(0,PI,0)
		keeper.collision_layer=2; keeper.animate(1)
		game.ball.freeze=false; game.ball.place(keeper.position+Vector3(0,.23,.72),Vector3(0,0,-.5))
		await physics_frame; await physics_frame
		game.last_touch=1 if second else 0; game.last_kicker=11 if second else 9; game.kick_lock=0
		if second: keeper.keeper_motion.saved(keeper)
		var seen := false
		for i in range(135):
			var target: Vector3=game.goalkeeping.update(11,DT)
			keeper.desired=((target-keeper.position)*Vector3(1,0,1)).limit_length(1)
			keeper.step(DT)
			seen=seen or keeper.pose==("keeper_rebound" if second else "keeper_smother")
			await physics_frame
			if game.ball.held_by==keeper: break
		if not seen or game.ball.held_by!=keeper: print("LOW SAVE TRACE second=",second," seen=",seen," ball=",game.ball.position," keeper=",keeper.position," pose=",keeper.pose," hands=",keeper.hand_center()," saves=",game.saves," held=",game.ball.held_by)
		check(seen and game.ball.held_by==keeper,"A real low ball is gathered by %s through the match keeper logic" % ("a recovered second attempt" if second else "a ground smother"))
		if visual: await capture("keeper-secured-"+str(second),keeper)
		game.ball.release_hold()
	print("MOTION CONTACT CHECK: %d checks, %d failures" % [checks,failures])
	game.free(); quit(0 if failures==0 else 1)
