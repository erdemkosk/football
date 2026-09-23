extends RefCounted
const NAMES := {"roulette":"ROULETTE", "roll":"BALL ROLL", "elastico":"ELASTICO", "scoop":"SCOOP TURN", "rainbow":"RAINBOW", "heel":"HEEL FLICK", "flick":"FLICK UP"}
var game
var active: Dictionary = {}

func cancel(index: int) -> void:
	game.players[index].skill_move.clear()
	active.erase(index)

func reset() -> void:
	for i in active: game.players[i].skill_move.clear()
	active.clear()

func start(index: int,kind: String,side: float=1) -> bool:
	var p=game.players[index]
	if not NAMES.has(kind) or not game.has_ball_control(index) or p.keeper or p.action_timer>0 or p.skill_cooldown>0 or p.energy<.07 or game.ball.position.y>.6: return false
	if not game.rules.before_touch(index): return false
	if game.is_user_player(index):
		game.cancel_pass(); game.charging=false; game.heading.cancel(index); game.volleys.cancel(index)
	var duration: float={"roulette":.66,"roll":.43,"elastico":.46,"scoop":.46,"rainbow":.82,"heel":.40,"flick":.44}[kind]
	var direction: Vector3=p.facing.normalized()
	var state := {"kind":kind,"age":0.0,"duration":duration,"side":side,"direction":direction,"lifted":false,"yaw":p.rig.rotation.y}
	active[index]=state; p.skill_move=state
	p.skill_cooldown=duration+.40; p.energy-=.035 if kind=="roll" else (.07 if kind=="rainbow" else .055)
	p.recovery_delay=maxf(p.recovery_delay,duration+.35)
	p.receive_timer=0; p.kick_timer=0; p.feint_time=0
	game.dribbler=index; game.last_kicker=index; game.last_touch=p.team
	if game.is_user_player(index): game.announce(NAMES[kind])
	return true

func update(delta: float) -> void:
	if game.state!="playing": reset(); return
	for i in active.keys():
		var p=game.players[i]
		var s: Dictionary=active[i]
		s.age+=delta
		var reach := 2.6 if s.kind=="rainbow" or s.kind=="flick" else 1.8
		if s.age>=s.duration or not p.visible or p.dismissed or p.action_timer>0 or game.ball.held_by!=null or game.flat_distance(p.position,game.ball.position)>reach or (game.last_kicker!=i and game.last_touch!=p.team):
			p.skill_move.clear(); active.erase(i); continue
		var t: float=s.age/s.duration
		var forward: Vector3=s.direction
		var right := forward.cross(Vector3.UP)*float(s.side)
		var offset := forward*.65
		match s.kind:
			"roll": offset+=right*lerpf(-.18,.66,smoothstep(0,1,t))
			"roulette": offset=forward.rotated(Vector3.UP,-float(s.side)*TAU*smoothstep(0,1,t))*.56
			"elastico": offset+=right*(sin(t*PI)*.6 if t<.48 else lerpf(.55,-.72,smoothstep(.48,1,t)))
			"scoop": offset=forward.rotated(Vector3.UP,-float(s.side)*PI*.44*smoothstep(0,1,t))*.83
			"rainbow": offset=forward*lerpf(-.55,.92,smoothstep(0,1,t))+right*.08
			"heel": offset=-forward*lerpf(.12,.78,smoothstep(0,1,t))+right*.16
			"flick": offset=forward*lerpf(.28,.42,smoothstep(0,1,t))
		var target: Vector3=p.position+offset
		var velocity: Vector3=p.velocity*Vector3(1,0,1)+((target-game.ball.position)*Vector3(1,0,1)*17).limit_length(7)
		velocity.y=game.ball.linear_velocity.y
		var impulse: float=game.ball.mass*55*delta
		if s.kind=="scoop" and not s.lifted and t>.3:
			velocity.y=2.2; impulse=game.ball.mass*4.8; s.lifted=true
		elif s.kind=="rainbow" and t<.5:
			velocity.y=lerpf(5.4,1.8,t/.5); impulse=maxf(impulse,game.ball.mass*7.2); s.lifted=true
		elif s.kind=="flick" and t<.42:
			velocity.y=maxf(velocity.y,3.4); impulse=maxf(impulse,game.ball.mass*5.6); s.lifted=true
		elif s.kind=="heel" and not s.lifted and t>.2:
			velocity.y=1.15; impulse=game.ball.mass*4.4; s.lifted=true
		if s.kind=="scoop" and t>.8:
			p.facing=forward.rotated(Vector3.UP,-float(s.side)*PI*.44)
			if game.is_user_player(i) and game.movement_input().length()<.1: game.last_direction=p.facing
		game.ball.touch(velocity,impulse)
		p.ball_actions.control_grace=.12
		p.desired*=.72 if s.kind=="roulette" or s.kind=="rainbow" else .88
		p.sprinting=false

static func pose(p) -> void:
	if p.skill_move.is_empty() or p.action_timer>0: return
	var s: Dictionary=p.skill_move
	var t: float=s.age/s.duration
	var weight := sin(PI*t)
	var side: float=s.side
	if s.kind=="roulette": p.rig.rotation.y=s.yaw-side*TAU*smoothstep(0,1,t)
	elif s.kind=="scoop": p.rig.rotation.y=s.yaw-side*.75*sin(t*PI)
	elif s.kind=="rainbow": p.rig.rotation.x=-.22*sin(t*PI); p.rig.rotation.y=s.yaw+side*.35*sin(t*PI)
	elif s.kind=="heel": p.rig.rotation.y=s.yaw+side*.55*sin(t*PI)
	elif s.kind=="flick": p.rig.rotation.x=-.18*sin(t*PI)
	# Spine pose persists between frames; blend toward a bounded lean rather
	# than adding the same rotation every tick.
	p.spine.rotation.z=lerpf(p.spine.rotation.z,side*.18,weight*.85)
	p.spine.rotation.y=lerpf(p.spine.rotation.y,side*(.38 if s.kind=="elastico" else .22),weight*.85)
	if s.kind=="rainbow" or s.kind=="flick":
		p.spine.rotation.x=lerpf(p.spine.rotation.x,.28 if s.kind=="rainbow" else .16,weight*.8)
	p.left_arm.rotation.z-=weight*.5; p.right_arm.rotation.z+=weight*.5
	var leg=p.left_leg if side<0 else p.right_leg
	var knee=p.left_knee if side<0 else p.right_knee
	var point := Vector3(side*lerpf(.12,.53,t),.26,-.55)
	if s.kind=="roulette": point=Vector3(side*.20,.30,-.4)
	if s.kind=="elastico": point.x=side*(.52 if t<.48 else -.28)
	if s.kind=="rainbow": point=Vector3(side*.08,lerpf(.18,.62,sin(t*PI)),lerpf(.15,-.72,t))
	if s.kind=="heel": point=Vector3(side*.22,.22,.42)
	if s.kind=="flick": point=Vector3(side*.06,.48,-.38)
	p.locomotion.solve_leg(leg,knee,point-leg.position,weight*.92)
	var support=p.right_knee if side<0 else p.left_knee
	if p.is_on_floor(): p.rig.position.y-=support.to_global(Vector3(0,-.42,-.05)).y-p.global_position.y-.102
