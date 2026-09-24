extends RefCounted
## Short, interruptible ground moves. A measured boot contact changes direction;
## nearby control joins the planting step and exit without locking the rigid ball.
const KINDS := ["roll","stop_go","knock_around","fake_shot","fake_pass"]
const PREPARE := .12
const CONTACT_END := .30
const BOOT := Vector3(0,-.42,-.05)

static func phase_age(s: Dictionary) -> float:
	return float(s.age)/float(s.timing_scale)

static func setup(game,p,s: Dictionary) -> void:
	s.foot=p.ball_actions.choose_foot(p,game.ball.position)
	s.target=game.ball.position
	s.origin=(p.left_knee if s.foot==0 else p.right_knee).to_global(BOOT)
	s.previous_boot=s.origin; s.previous_ball=game.ball.position
	s.contacts=0; s.contact_gap=INF; s.phase="prepare"
	s.origin_position=p.position
	s.entry_offset=(game.ball.position-p.position)*Vector3(1,0,1)
	s.opponent=-1; s.opponent_position=p.position+s.direction*2
	var nearest := 4.5
	for i in range(game.players.size()):
		var q=game.players[i]
		if not q.visible or q.dismissed or q.team==p.team: continue
		var offset: Vector3=(q.position-p.position)*Vector3(1,0,1)
		if offset.length()<nearest and offset.dot(s.direction)>.25:
			nearest=offset.length(); s.opponent=i; s.opponent_position=q.position
	s.velocity_before=game.ball.linear_velocity
	s.last_contact_age=-1.0

static func steer(game,p,s: Dictionary) -> void:
	var age := phase_age(s)
	var right: Vector3=s.direction.cross(Vector3.UP)*float(s.side)
	var requested: Vector3=p.desired
	var exit: Vector3=(s.direction*.45+right*.9).normalized()
	if s.kind=="stop_go": exit=s.direction
	elif s.kind=="knock_around":
		var around: Vector3=s.opponent_position-right*1.05+s.direction*.3
		if (p.position-s.opponent_position).dot(s.direction)>.15: around=s.opponent_position+s.direction*2
		exit=((around-p.position)*Vector3(1,0,1)).normalized()
	s.phase="prepare" if age<PREPARE else ("contact" if s.contacts==0 else "exit")
	if s.contacts==0:
		s.target=game.ball.position
		p.desired=requested*.35
		p.sprinting=false
	elif s.kind=="stop_go" and age<.38:
		p.desired=requested*.12
		p.sprinting=false
	else:
		# Deliberate steering against the suggested exit always wins.
		if requested.length()>.2 and requested.normalized().dot(exit)<-.2:
			game.skills.cancel(game.players.find(p)); return
		p.desired=exit*.65+requested*.35
		p.sprinting=s.kind=="knock_around" or (s.kind=="stop_go" and s.contacts>1)
		if s.kind=="stop_go" and s.contacts==1: s.target=game.ball.position
	p.protecting=false

static func close_control(game,p,s: Dictionary) -> void:
	# Keep the existing carry through the preparation, then recover the ball
	# after a lateral touch / second stop-go contact. An opened knock-around
	# stays completely free, and a tackle or out-of-reach ball gets no rescue.
	if s.contacts>0 and (s.kind=="knock_around" or (s.kind=="stop_go" and s.contacts==1)): return
	if game.dribbler!=game.players.find(p) or game.ball.held_by!=null or game.ball.pending_kick or game.ball.position.y>.6: return
	var offset: Vector3=(game.ball.position-p.position)*Vector3(1,0,1)
	if offset.length()>1.3: return
	var age := phase_age(s)
	var goal: Vector3=s.entry_offset.lerp(s.direction*.52,smoothstep(0,PREPARE,age))
	if s.contacts>0:
		var heading: Vector3=p.desired.normalized() if p.desired.length()>.1 else p.facing
		goal=s.exit_offset.lerp(heading*lerpf(.64,.54,float(s.quality)),smoothstep(0,.18,age-s.last_contact_age))
	var relative: Vector3=(game.ball.linear_velocity-p.velocity)*Vector3(1,0,1)
	var grip: float=lerpf(130,168,float(s.quality))
	game.ball.guide(((goal-offset)*grip-relative*2*sqrt(grip)).limit_length(lerpf(78,96,float(s.quality))))

static func pose(p,s: Dictionary) -> void:
	var age := phase_age(s)
	var duration: float=s.duration/s.timing_scale
	var weight := smoothstep(0,PREPARE,age)*(1-smoothstep(minf(.48,duration*.78),duration,age))
	var balance: float=lerpf(1.18,.82,float(s.quality))
	var leg: Node3D=p.left_leg if s.foot==0 else p.right_leg
	var knee: Node3D=p.left_knee if s.foot==0 else p.right_knee
	var waiting: bool=s.contacts==0 or (s.kind=="stop_go" and s.contacts==1)
	if waiting:
		var contact: Vector3=s.origin.lerp(s.target,smoothstep(0,PREPARE,age))
		if s.kind in ["fake_shot","fake_pass"]:
			# Show a backswing, then bring the boot across the real ball.
			contact+=s.direction*(-.20 if s.kind=="fake_shot" else -.11)*sin(PI*clampf(age/PREPARE,0,1))
		contact.y=maxf(p.global_position.y+p.boot_ground_height(),contact.y-.04)
		var local: Vector3=p.rig.to_local(contact)-leg.position
		# Do not stretch a boot across the body to rescue a lost ball.
		if local.length()<1.15:
			# The solver clamps anatomical reach; allow the boot to meet the
			# near surface of the ball instead of demanding its exact centre.
			p.locomotion.solve_leg(leg,knee,local,1)
	else:
		leg.rotation.y+=float(s.side)*.16*weight
		knee.rotation.x-=.12*weight
	p.spine.rotation.z=lerpf(p.spine.rotation.z,float(s.side)*(.12 if s.kind!="knock_around" else -.16)*balance,weight*.8)
	if s.kind in ["fake_shot","fake_pass"]:
		p.spine.rotation.y=lerpf(p.spine.rotation.y,-float(s.side)*.32,weight)
		p.spine.rotation.x=lerpf(p.spine.rotation.x,-.16,weight*.7)
	p.left_arm.rotation.z-=weight*.22*balance; p.right_arm.rotation.z+=weight*.22*balance
	var lowest: float=minf(p.left_knee.to_global(BOOT).y,p.right_knee.to_global(BOOT).y)
	p.rig.position.y+=maxf(0,p.global_position.y+p.boot_ground_height()-lowest)

static func resolve(game,index: int,s: Dictionary) -> void:
	var p=game.players[index]
	close_control(game,p,s)
	var boot: Vector3=(p.left_knee if s.foot==0 else p.right_knee).to_global(BOOT)
	var from: Vector3=s.previous_ball-s.previous_boot
	var to: Vector3=game.ball.position-boot
	s.contact_gap=Geometry3D.get_closest_point_to_segment(Vector3.ZERO,from,to).length()
	s.previous_ball=game.ball.position; s.previous_boot=boot
	var age := phase_age(s)
	var first: bool=s.contacts==0 and age>=PREPARE and age<=CONTACT_END
	var second: bool=s.kind=="stop_go" and s.contacts==1 and age>=.38 and age<.62
	if not first and not second: return
	if s.contact_gap>.34 or game.ball.position.y>.6 or game.ball.pending_kick or game.ball.held_by!=null: return
	if p.action_timer>0 or (game.dribbler>=0 and game.dribbler!=index) or game.last_kicker!=index: return
	var right: Vector3=s.direction.cross(Vector3.UP)*float(s.side)
	var velocity: Vector3=s.direction*1.1+right*lerpf(3.05,2.55,float(s.quality))+(p.velocity*Vector3(1,0,1))*.3
	if s.kind=="stop_go": velocity=Vector3.ZERO if first else s.direction*4.5
	elif s.kind=="knock_around":
		var destination: Vector3=s.opponent_position+right*1.05+s.direction*1.9
		velocity=((destination-game.ball.position)*Vector3(1,0,1)).normalized()*clampf(game.flat_distance(game.ball.position,destination)*2.4,5.5,9)
	velocity.y=.05
	game.ball.touch(velocity,game.ball.mass*18)
	s.contacts+=1; s.last_contact_age=age
	s.exit_offset=(game.ball.position-p.position)*Vector3(1,0,1)
	s.hit_gap=s.contact_gap
	p.ball_actions.control_grace=0
	game.feedback.contact("kick",index,game.ball.position,velocity.normalized(),.22)
	if s.kind=="knock_around":
		# An exposed ball belongs to whoever reaches it. No post-touch guide.
		game.dribbler=-1; game.carrier=-1; p.touch_cooldown=.35
	if game.training and game.training_drills.mode=="duel": game.training_drills.duel.used=true
