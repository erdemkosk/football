extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
## Walk into the tunnel, wait for Continue, then cut straight to a legal kickoff.
const TUNNEL_X := 48.0+P.SIDE_SHIFT
const BACKGROUND_BREAK := 20.0
var game
var age := 0.0
var phase := ""
var leaving: Dictionary = {}
var officials: Dictionary = {}
var resume_requested := false
var camera_at := Vector3.ZERO
var camera_eye := Vector3.ZERO
var camera_size := 49.0

func restore_players() -> void:
	for index in leaving:
		var p=game.players[index]
		var saved: Dictionary=leaving[index]
		p.rig.visible=saved.rig_visible
		p.prematch=saved.prematch
		p.collision_mask=saved.mask
		p.collision_layer=0 if p.dismissed else saved.layer
		p.stamina_free_movement=false
	leaving.clear()

func reset() -> void:
	restore_players()
	if game.half==2:
		for p in game.players: p.home*=Vector3(-1,1,-1)
	game.half=1
	age=0; phase=""; resume_requested=false; officials.clear()

func begin() -> void:
	if game.state=="halftime": return
	age=0; phase="leaving"; resume_requested=false
	leaving.clear(); officials.clear()
	game.match_time=game.LENGTH*0.5
	game.state="halftime"
	game.broadcast_event("halftime")
	game.management.prepare_substitutions()
	game.charging=false
	game.charge=0
	game.cancel_pass()
	game.clear_pass_request()
	game.support.reset()
	game.duels.reset()
	game.goalkeeping.reset()
	game.set_pieces.clear()
	game.rules.reset()
	game.heading.reset(); game.volleys.reset(); game.aerial_assist.reset()
	game.reset_advanced_play()
	game.physical_contests.reset()
	game.dribbler=-1
	game.carrier=-1
	game.ball.active=false
	game.referees.clear_decision()
	game.referees.decision="DEVRE"
	game.referees.decision_age=0
	game.referees.whistle()
	game.rules.show_deferred_cards()
	for index in range(game.players.size()):
		var p=game.players[index]
		p.desired=Vector3.ZERO
		p.sprinting=false
		p.shot_preparation=0
		p.chosen=false; p.marker.hide(); p.call_label.hide()
		if not p.visible or p.dismissed: continue
		leaving[index]={"stage":0,"mask":p.collision_mask,"layer":p.collision_layer,"prematch":p.prematch,"rig_visible":p.rig.visible}
		p.prematch=true
	camera_at=game.camera_focus
	camera_eye=game.camera.position
	camera_size=game.camera.size

func walk(p,destination: Vector3,delta: float,others: Array=[]) -> void:
	destination=game.set_pieces.recovery.around_goal(p.position,destination)
	var offset: Vector3=(destination-p.position)*Vector3(1,0,1)
	p.desired=offset.normalized()*minf(1,offset.length()*1.4)
	for other in others:
		if other==p or not other.visible or not other.rig.visible: continue
		var obstacle: Vector3=(other.position-p.position)*Vector3(1,0,1)
		var along: float=obstacle.dot(offset.normalized())
		if along<=0 or along>1.6 or obstacle.length()<.01: continue
		if (obstacle-offset.normalized()*along).length()>.82: continue
		if p.position.x>P.HALF_WIDTH-2 and absf(p.position.z)<2.5:
			# Queue inside the narrow approach instead of overtaking into its walls.
			# Only yield to someone farther into the tunnel: converging lanes
			# must not both stop because each sees the other on its diagonal.
			if obstacle.x>.05: p.desired*=clampf((obstacle.x-.75)/.85,0,1)
		else:
			var side := Vector3(-offset.z,0,offset.x).normalized()
			if side.dot(obstacle)>0: side=-side
			p.desired+=side*(1.6-along)*.9
	p.sprinting=false
	p.stamina_free_movement=true
	p.step(delta,4.6)
	p.stamina_free_movement=false

func update(delta: float) -> void:
	age+=delta
	if resume_requested:
		finish()
		if game.state!="halftime": return
	var inside := true
	for index in leaving:
		var p=game.players[index]
		var entry: Dictionary=leaving[index]
		if p.dismissed or not p.visible or entry.stage==2: continue
		inside=false
		var lane := -1.15 if p.team==0 else 1.15
		var gate := Vector3(P.HALF_WIDTH-1,0,lane)
		# Join the forward-moving tunnel lane before crowding its entrance.
		# Waiting for the exact gate point makes the two teams block each other.
		if entry.stage==0 and game.flat_distance(p.position,gate)<2.0:
			entry.stage=1
			p.collision_mask=1
		var destination := gate if entry.stage==0 else Vector3(TUNNEL_X,0,lane)
		walk(p,destination,delta,game.players)
		if entry.stage==1 and p.position.x>=TUNNEL_X-.5:
			entry.stage=2
			# Keep roster eligibility while the actual model is inside the room.
			p.rig.hide(); p.marker.hide(); p.call_label.hide()
			p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO; p.collision_layer=0
	if inside: phase="room"
	# Only the unattended menu exhibition advances without a Continue press.
	if game.menu_match.running and phase=="room" and age>=BACKGROUND_BREAK: finish()

func walk_officials(delta: float) -> void:
	for i in range(game.referees.actors.size()):
		var actor=game.referees.actors[i]
		if not actor.visible: continue
		actor.signal_pose("")
		var stage: int=officials.get(i,0)
		var lane: float=(i-1)*.7
		var gate := Vector3(P.HALF_WIDTH-1,0,lane)
		if stage==0 and game.flat_distance(actor.position,gate)<.65:
			stage=1; officials[i]=1
		walk(actor,gate if stage==0 else Vector3(TUNNEL_X,0,lane),delta)
		if stage==1 and actor.position.x>=TUNNEL_X-.5:
			actor.hide(); actor.collision_layer=0; actor.velocity=Vector3.ZERO

func finish() -> void:
	if game.state!="halftime": return
	game.management.prepare_substitutions()
	if not game.management.transit.is_empty() or not game.referees.ready_for_restart():
		resume_requested=true
		return
	restore_players()
	phase=""; resume_requested=false; officials.clear()
	game.half=2
	game.replay.frames.clear()
	game.stadium.crowd.home_attack=game.attack_sign(0)
	for p in game.players:
		p.home*=Vector3(-1,1,-1)
		# Fixed recovery also applies when the user skips the walk to the tunnel.
		p.energy=minf(p.stamina_capacity(),p.energy+0.20)
		p.recovery_delay=0
		if p.energy>=p.RECOVERY_LIMIT: p.exhausted=false
		p.action_timer=0; p.kick_timer=0; p.receive_timer=0; p.pose="run"
		p.tackle_cooldown=0; p.tackle_recovery=0
		p.velocity=Vector3.ZERO; p.desired=Vector3.ZERO
		p.ai_think=0
	game.controller.held.clear(); game.controller.clear_shot_aim()
	game.last_direction=Vector3(0,0,game.attack_sign(0))
	game.referees.activate(true)
	game.begin_restart("SANTRA",1,Vector3.ZERO)
	# No retrieval, entrance, salute or walk back across the pitch after Continue.
	game.set_pieces.snap_ready()
	if game.state=="restart":
		# Ball placement reaches the physics server on the next tick. Give it
		# time to settle rather than sending the taker to collect the old ball.
		game.set_pieces.recovery.age=0
		game.set_pieces.recovery.rest_age=0
	for p in game.players: p.reset_physics_interpolation()
	game.previous_ball=Vector3(0,game.ball.GROUND_HEIGHT,0)
	game.kick_lock=.3; game.boundary_grace=.5

func update_camera(delta: float) -> void:
	game.match_camera.cinematic()
	var blend := 1-exp(-delta*2.5)
	camera_at=camera_at.lerp(Vector3(P.HALF_WIDTH+1,1,0),blend)
	camera_eye=camera_eye.lerp(Vector3(20+P.SIDE_SHIFT,13,25),blend)
	camera_size=lerpf(camera_size,36,blend)
	game.camera.position=camera_eye
	game.camera.size=camera_size
	game.camera.look_at(camera_at)
