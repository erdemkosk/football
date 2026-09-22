extends RefCounted
const NAMES := {"roulette":"ROULETTE", "roll":"BALL ROLL", "elastico":"ELASTICO", "scoop":"SCOOP TURN"}
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
	var duration: float={"roulette":.66,"roll":.43,"elastico":.46,"scoop":.46}[kind]
	var direction: Vector3=p.facing.normalized()
	var state := {"kind":kind,"age":0.0,"duration":duration,"side":side,"direction":direction,"lifted":false,"yaw":p.rig.rotation.y}
	active[index]=state; p.skill_move=state
	p.skill_cooldown=duration+.40; p.energy-=.035 if kind=="roll" else .055
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
		if s.age>=s.duration or not p.visible or p.dismissed or p.action_timer>0 or game.ball.held_by!=null or game.flat_distance(p.position,game.ball.position)>1.8 or (game.last_kicker!=i and game.last_touch!=p.team):
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
		var target: Vector3=p.position+offset
		var velocity: Vector3=p.velocity*Vector3(1,0,1)+((target-game.ball.position)*Vector3(1,0,1)*17).limit_length(7)
		velocity.y=game.ball.linear_velocity.y
		var impulse: float=game.ball.mass*55*delta
		if s.kind=="scoop" and not s.lifted and t>.3:
			velocity.y=2.2; impulse=game.ball.mass*4.8; s.lifted=true
		if s.kind=="scoop" and t>.8:
			p.facing=forward.rotated(Vector3.UP,-float(s.side)*PI*.44)
			if game.is_user_player(i) and game.movement_input().length()<.1: game.last_direction=p.facing
		game.ball.touch(velocity,impulse)
		p.ball_actions.control_grace=.12
		p.desired*=.72 if s.kind=="roulette" else .88
		p.sprinting=false

static func pose(p) -> void:
	if p.skill_move.is_empty() or p.action_timer>0: return
	var s: Dictionary=p.skill_move
	var t: float=s.age/s.duration
	var weight := sin(PI*t)
	var side: float=s.side
	if s.kind=="roulette": p.rig.rotation.y=s.yaw-side*TAU*smoothstep(0,1,t)
	elif s.kind=="scoop": p.rig.rotation.y=s.yaw-side*.75*sin(t*PI)
	# Spine pose persists between frames; blend toward a bounded lean rather
	# than adding the same rotation every tick.
	p.spine.rotation.z=lerpf(p.spine.rotation.z,side*.18,weight*.85)
	p.spine.rotation.y=lerpf(p.spine.rotation.y,side*(.38 if s.kind=="elastico" else .22),weight*.85)
	p.left_arm.rotation.z-=weight*.5; p.right_arm.rotation.z+=weight*.5
	var leg=p.left_leg if side<0 else p.right_leg
	var knee=p.left_knee if side<0 else p.right_knee
	var point := Vector3(side*lerpf(.12,.53,t),.26,-.55)
	if s.kind=="roulette": point=Vector3(side*.20,.30,-.4)
	if s.kind=="elastico": point.x=side*(.52 if t<.48 else -.28)
	p.locomotion.solve_leg(leg,knee,point-leg.position,weight*.92)
	var support=p.right_knee if side<0 else p.left_knee
	if p.is_on_floor(): p.rig.position.y-=support.to_global(Vector3(0,-.42,-.05)).y-p.global_position.y-.102
