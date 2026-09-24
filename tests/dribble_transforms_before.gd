extends RefCounted
const P = preload("res://scripts/pitch_dimensions.gd")
## Close control uses a damped ground force and animated boot contacts.
## Sprinting loosens the guide; a released ball is an ordinary rigid body.
const BOOT := Vector3(0,-.42,-.05)
const CONTACT := .39
const WINDUP := .075
const DURATION := .24
var age := DURATION
var cooldown := 0.0
var freshness := 0.0
var gait_weight := 0.0
var foot := 1
var style := "push"
var target := Vector3.ZERO
var direction := Vector3.FORWARD
var previous_direction := Vector3.FORWARD
var previous_ball := Vector3.ZERO
var previous_boot := Vector3.ZERO
var hit := false
var contacts := 0
var last_gap := INF
var last_contact := Vector3.ZERO
var contact_position := Vector3.ZERO
var contact_ball: RigidBody3D
var contact_body: CharacterBody3D
var preparing := false
var preparation_offset := Vector3.ZERO
var pose_feet: Array[Vector3] = []
var pose_velocity: Array[Vector3] = []
var gait:=preload("res://tests/carry_transforms_before.gd").new()

func release_collision() -> void:
	preparing=false
	if is_instance_valid(contact_ball):
		contact_ball.pending_control=false
		if is_instance_valid(contact_body) and contact_body.dummy_time<=0: contact_ball.remove_collision_exception_with(contact_body)
	contact_ball=null; contact_body=null

func reset() -> void:
	release_collision()
	age=DURATION; cooldown=0; freshness=0; gait_weight=0; hit=false; contacts=0
	previous_direction=Vector3.FORWARD
	pose_feet.clear(); pose_velocity.clear()
	gait.reset()

func control_collision(p,ball) -> void:
	if contact_ball==ball and contact_body==p: return
	release_collision(); contact_ball=ball; contact_body=p
	ball.add_collision_exception_with(p)

func available(p) -> bool:
	return p.action_timer<=0 and p.kick_timer<=0 and p.skill_move.is_empty() and p.dummy_time<=0 and p.set_piece_pose=="" and p.celebration=="" and p.discipline_pose==""

func update(p,delta: float) -> void:
	age=minf(DURATION,age+delta)
	cooldown=maxf(0,cooldown-delta)
	freshness=maxf(0,freshness-delta)
	gait_weight=move_toward(gait_weight,1.0 if freshness>0 and available(p) else 0.0,delta*8)
	if preparing: return
	# A skill animates its own boot contacts around the legs. Keep only the
	# carrier's coarse capsule exempt; the opponent can still hit the live ball.
	if not p.skill_move.is_empty() and p.action_timer<=0: return
	if not available(p) or (freshness<=0 and p.ball_actions.control_grace<=0):
		age=DURATION
		release_collision()

func boot(p) -> Vector3:
	return (p.left_knee if foot==0 else p.right_knee).to_global(BOOT)

func begin_preparation(p,ball) -> void:
	control_collision(p,ball)
	preparing=true
	preparation_offset=(ball.position-p.position)*Vector3(1,0,1)
	age=DURATION

func settle_preparation(p,ball,delta: float) -> bool:
	if not preparing: return true
	var offset: Vector3=(ball.position-p.position)*Vector3(1,0,1)
	if offset.length()>1.35 or ball.position.y>.65 or ball.pending_kick or ball.pending_reset or ball.held_by!=null:
		release_collision(); return false
	# Decelerate the controlled ball with the planting step during a long
	# backswing. It stays a contestable rigid body; no position/velocity snap.
	var side := -1.0 if p.ball_actions.foot==0 else 1.0
	var goal: Vector3=p.facing*.57+p.facing.cross(Vector3.UP)*side*.08
	preparation_offset=preparation_offset.lerp(goal,1-exp(-delta*12))
	var relative: Vector3=(ball.linear_velocity-p.velocity)*Vector3(1,0,1)
	ball.guide(((preparation_offset-offset)*196-relative*28).limit_length(100))
	return true

func begin(p,ball,aim: Vector3,turn: float,stopping: bool) -> void:
	foot=p.ball_actions.choose_foot(p,ball.position)
	# On a cut, choose the foot on the ball's side of the coming stance.
	# Choosing from the old facing can leave the far leg chasing across the body.
	if turn>.5:
		var next_side: float=(ball.position-p.position).dot(aim.cross(Vector3.UP))
		if absf(next_side)>.20: foot=0 if next_side<0 else 1
	style="sole" if stopping or turn>2.15 else ("inside" if turn>.5 else "push")
	if style=="inside":
		var side: float=p.rig.to_local(ball.position).x
		if side*aim.dot(p.rig.global_basis.x)>0: style="outside"
	direction=aim
	target=ball.position+ball.linear_velocity*WINDUP
	previous_ball=ball.position; previous_boot=boot(p)
	age=0; hit=false

func carry(game,index: int,_delta: float) -> void:
	var p=game.players[index]
	var ball=game.ball
	if not available(p) or ball.pending_kick or ball.held_by!=null or ball.position.y>.6:
		release_collision(); return
	# The coarse body capsule fills the space between both legs. For a low
	# controlled ball, animated boot contact replaces that artificial solid wall.
	# Opponents, the pitch and every other obstacle remain physical colliders.
	control_collision(p,ball)
	if freshness<=0: previous_direction=p.facing
	freshness=.07
	var horizontal: Vector3=p.velocity*Vector3(1,0,1)
	var pace := horizontal.length()
	var moving: bool=p.desired.length()>.05
	var aim: Vector3=game.duels.shield_direction(index) if p.protecting else (p.desired.normalized() if moving else p.facing)
	if p.feint_time>0: aim=aim.rotated(Vector3.UP,sin((1-p.feint_time/.48)*TAU)*.85*p.feint_side)
	var offset: Vector3=(ball.position-p.position)*Vector3(1,0,1)
	var incoming: Vector3=ball.linear_velocity*Vector3(1,0,1)
	var turn := absf(previous_direction.signed_angle_to(aim,Vector3.UP))
	var stopping := not moving and incoming.length()>.25
	var feinting: bool=p.feint_time>.02
	var relative := incoming-horizontal
	var closing: bool=offset.dot(relative)<-.3
	var requested_speed: float=p.movement_speed()*p.desired.length()
	var braking: bool=pace>requested_speed+1.0
	var close: bool=offset.length()<(.84 if p.active_sprint else .70)
	var recovering: bool=moving and offset.dot(aim)<.1 and offset.length()<1.18
	# Keep a controlled ball in front of the standing player, not tied to the
	# bobbing toe. The small stride pulse preserves visible touches without jitter.
	var acquired: bool=contacts>0 or p.ball_actions.contact_cooldown>0
	var settling: bool=p.receive_timer>0 and p.ball_actions.contact_cooldown>0
	var guided: bool=acquired and offset.length()<(1.45 if settling else 1.30) and incoming.length()<15.5 and absf(ball.position.x)<P.HALF_WIDTH+.2 and absf(ball.position.z)<50.2
	if guided:
		var technique: float=clampf((float(p.attributes.control)-45)/50,0,1)
		var reach: float=(.72 if p.active_sprint else .51)+(.025 if moving else 0.0)*sin(p.run_phase*2)
		var right := aim.cross(Vector3.UP)
		var goal: Vector3=aim*reach+right*clampf(offset.dot(right),-.13,.13)
		if p.protecting: goal=aim*.48+right*clampf(offset.dot(right),-.16,.16)
		var grip: float=lerpf(90,130,technique)*(0.60 if p.active_sprint else 1.0)
		var acceleration: Vector3=(goal-offset)*grip-relative*(2*sqrt(grip))
		ball.guide(acceleration.limit_length(85 if not p.active_sprint else 65))
	var needs_touch: bool=close and (moving or stopping) or (closing and offset.length()<.78) or (turn>.5 and offset.length()<1.13 and moving) or ((stopping or braking) and offset.length()<1.25)
	needs_touch=needs_touch or (moving and absf(offset.dot(aim))<.45 and offset.length()<1.05)
	needs_touch=needs_touch or (feinting and offset.length()<1.05)
	needs_touch=needs_touch or (contacts==0 and offset.length()<.95)
	needs_touch=needs_touch or recovering
	var urgent := turn>.5 or braking or stopping or recovering
	# The physical guide already handles immediate turns and braking. Restarting
	# this leg overlay halfway through recovery made the knee jump every cut.
	if cooldown<=0 and age>=DURATION and needs_touch:
		begin(p,ball,aim,maxf(turn,1.1) if recovering else turn,stopping)
	if age>=DURATION or hit: return
	direction=aim
	if turn>2.15 or stopping: style="sole"
	elif turn>.5 and style=="push": style="inside"
	# Track only the short approach of the boot; after contact its follow-through
	# uses the recorded contact point, not a foot glued to the travelling ball.
	target=ball.position+ball.linear_velocity*maxf(0,WINDUP-age)
	var current_boot := boot(p)
	var from := previous_ball-previous_boot
	var to: Vector3=ball.position-current_boot
	var segment := to-from
	var fraction := clampf(-from.dot(segment)/maxf(.00001,segment.length_squared()),0,1)
	var gap := (from+segment*fraction).length()
	previous_ball=ball.position; previous_boot=current_boot
	if age<WINDUP*.65 or age>WINDUP+.10 or gap>CONTACT: return
	var output := Vector3.ZERO
	if feinting:
		var sway: float=sin((1-p.feint_time/.48)*TAU)*p.feint_side
		var goal: Vector3=p.position+p.facing*.70+p.facing.cross(Vector3.UP)*sway*.34
		output=horizontal+((goal-ball.position)*Vector3(1,0,1)*9).limit_length(2.5)
		style="inside"
	elif moving:
		# A small lead lets the ball roll out and be caught by the next stride.
		# Faster carries have a longer exposed interval; tired players open it more.
		var travelling: float=maxf(0,horizontal.dot(aim)) if p.active_sprint else pace
		var speed: float=minf(requested_speed,travelling+2.0)
		var lead: float=(.75 if p.active_sprint else .42)+(1-p.energy)*.12
		var lateral: Vector3=offset-aim*offset.dot(aim)
		output=aim*(speed+lead)-lateral.limit_length(.30)*2.0
		if p.protecting: output=horizontal+aim*.4-lateral.limit_length(.2)
		if turn>.9 or offset.dot(aim)<-.15:
			# A hook returns the ball around the outside of the support leg,
			# with enough pace to join the new run instead of falling behind it.
			var right := aim.cross(Vector3.UP)
			var side := signf(offset.dot(right))
			if absf(side)<.1: side=-1.0 if foot==0 else 1.0
			var return_speed := requested_speed+clampf(.6-offset.dot(aim),0,1.2)*2.0
			# Match the body's planting step before opening the next running touch.
			return_speed=minf(return_speed,maxf(2.2,horizontal.dot(aim)+2.4))
			output=aim*return_speed+(right*side*.40-lateral)*2.0
	elif pace>.5:
		output=horizontal*.84
	# A sole stop cancels the remaining roll at the boot, not a field-wide drag.
	# A low bounce is cushioned by the contacting boot, including a keeper's
	# dropped ball. Between contacts, gravity and restitution remain untouched.
	output.y=clampf(ball.linear_velocity.y*.15,-.6,.3) if absf(ball.linear_velocity.y)>.5 else ball.linear_velocity.y
	# Once acquired, the guide supplies control between light boot impulses.
	# Braking and a genuine cut still get a decisive contact with the ball.
	var impulse: float=(.65 if p.active_sprint else .40) if guided and not urgent else (22.0 if style=="sole" else 16.0)
	ball.touch(output,ball.mass*impulse)
	hit=true; contacts+=1; last_gap=gap; last_contact=ball.position
	contact_position=p.position
	previous_direction=aim
	# Keep the approach target through contact. Replacing its short prediction
	# with the ball's old position yanked the toe backwards on the next frame.
	cooldown=.075 if feinting else (.055 if style=="sole" else (.13 if p.active_sprint else .10))
	game.dribble_direction=aim
	game.last_touch=p.team; game.last_kicker=index

func apply(p) -> void:
	if age>=DURATION or freshness<=0 or not available(p): return
	var entry := smoothstep(0,WINDUP,age)
	var recover := smoothstep(WINDUP+.025,DURATION,age)
	var weight := entry*(1-recover)
	var leg=p.left_leg if foot==0 else p.right_leg
	var knee=p.left_knee if foot==0 else p.right_knee
	var side := -1.0 if foot==0 else 1.0
	var point := target-direction*.17
	if style=="sole": point=target+Vector3.UP*.18
	if hit:
		point+=direction*smoothstep(WINDUP,DURATION,age)*(.18 if style=="sole" else .24)
		# After a forward push the boot follows through with the moving hip.
		# A frozen world-space target drags the foot behind a sprinting body.
		if style=="push": point+=(p.position-contact_position)*Vector3(1,0,1)
	point.y=maxf(p.position.y+.11,point.y)
	# Guide the toe out of the live running step and back into that same stride.
	# Freezing the starting hip/knee for every touch made the leg hesitate, then
	# snap to the next running pose. The support leg keeps its ordinary footfall.
	p.rig.position.y-=(.025 if style=="push" else .085)*weight*(1-gait.weight)
	var toe: Vector3=knee.to_global(BOOT).lerp(point,weight)
	toe.y=maxf(p.position.y+p.boot_ground_height(),toe.y)
	p.locomotion.solve_leg(leg,knee,p.rig.to_local(toe)-leg.position,1)
	knee.quaternion=knee.quaternion*Quaternion(Vector3.UP,side*(.24 if style=="inside" else (-.18 if style=="outside" else 0))*weight)
	p.spine.rotation.z=lerpf(p.spine.rotation.z,-side*.12,weight*.65)
	p.spine.rotation.y=lerpf(p.spine.rotation.y,side*(.18 if style!="push" else .06),weight*.6)
	p.left_arm.rotation.z=lerpf(p.left_arm.rotation.z,-.55,weight*.75)
	p.right_arm.rotation.z=lerpf(p.right_arm.rotation.z,.55,weight*.75)

func finish_pose(p,delta: float) -> void:
	if not available(p) or freshness<=0 or preparing or delta>=.1:
		pose_feet.clear(); pose_velocity.clear(); return
	# Turning support and dribbling both solve the legs. Join their final toe
	# paths with a short critically damped blend instead of alternating IK poses.
	# The body/input is untouched; only the rendered two-bone chains are blended.
	var points: Array[Vector3]=[p.rig.to_local(p.left_knee.to_global(BOOT)),p.rig.to_local(p.right_knee.to_global(BOOT))]
	if pose_feet.size()!=2:
		pose_feet=points.duplicate(); pose_velocity.assign([Vector3.ZERO,Vector3.ZERO])
	var frequency := 50.0
	var decay := exp(-frequency*delta)
	for i in range(2):
		var error: Vector3=pose_feet[i]-points[i]
		var impulse: Vector3=pose_velocity[i]+error*frequency
		pose_feet[i]=points[i]+(error+impulse*delta)*decay
		pose_velocity[i]=(pose_velocity[i]-impulse*frequency*delta)*decay
		var point: Vector3=p.rig.to_global(pose_feet[i])
		point.y=maxf(point.y,p.position.y+p.boot_ground_height())
		var leg=p.left_leg if i==0 else p.right_leg
		var knee=p.left_knee if i==0 else p.right_knee
		p.locomotion.solve_leg(leg,knee,p.rig.to_local(point)-leg.position,1)
	# The next planted step must start at the boot that was actually displayed.
	p.locomotion.feet.assign([p.left_knee.to_global(BOOT),p.right_knee.to_global(BOOT)])

