extends RefCounted
const NAMES := {"roulette":"ROULETTE", "roll":"YANA ÇEK", "stop_go":"DUR–KALK", "knock_around":"AÇ VE DOLAŞ", "elastico":"ELASTICO", "scoop":"SCOOP TURN", "rainbow":"RAINBOW", "heel":"HEEL FLICK", "flick":"FLICK UP"}
const Ground = preload("res://scripts/ground_skills.gd")
var game
var active: Dictionary = {}
var notice := ""
var notice_time := 0.0

func explain(index: int,message: String) -> void:
	if not game.is_user_player(index): return
	notice=message; notice_time=1.6

func interrupt_preparation(index: int) -> bool:
	if not active.has(index): return true
	var s: Dictionary=active[index]
	if s.kind not in Ground.KINDS or s.age>=Ground.PREPARE: return false
	cancel(index); game.players[index].skill_cooldown=.12
	return true

func cancel(index: int) -> void:
	game.players[index].skill_move={}
	game.players[index].dribble_motion.release_collision()
	active.erase(index)

func reset() -> void:
	for i in active.keys(): cancel(i)
	notice=""; notice_time=0

func start(index: int,kind: String,side: float=1) -> bool:
	var p=game.players[index]
	if not NAMES.has(kind) or p.keeper: return false
	var reason := ""
	if active.has(index) or p.action_timer>0 or p.skill_cooldown>0: reason="ÖNCE DENGENİ TOPLA"
	elif p.energy<.07: reason="KONDİSYON DÜŞÜK"
	elif game.ball.position.y>.6: reason="TOPU ÖNCE YERE İNDİR"
	elif not game.has_ball_control(index): reason="TOP ÖNCE AYAĞINA GELSİN"
	if reason!="": explain(index,reason); return false
	if not game.rules.before_touch(index): return false
	if game.is_user_player(index):
		game.cancel_pass(); game.charging=false; game.heading.cancel(index); game.volleys.cancel(index)
	var duration: float={"roulette":.66,"roll":.60,"stop_go":.78,"knock_around":1.05,"elastico":.46,"scoop":.46,"rainbow":.82,"heel":.40,"flick":.44}[kind]
	var direction: Vector3=p.facing.normalized()
	var state := {"kind":kind,"age":0.0,"duration":duration,"side":side,"direction":direction,"lifted":false,"yaw":p.rig.rotation.y}
	active[index]=state; p.skill_move=state
	if kind in Ground.KINDS: Ground.setup(game,p,state)
	p.skill_cooldown=duration+.40; p.energy-=.035 if kind=="roll" else (.07 if kind=="rainbow" else .055)
	p.recovery_delay=maxf(p.recovery_delay,duration+.35)
	p.receive_timer=0; p.kick_timer=0; p.feint_time=0
	game.dribbler=index; game.carrier=index; game.last_kicker=index; game.last_touch=p.team
	p.dribble_motion.control_collision(p,game.ball)
	explain(index,{"roll":"YANA ÇEK · UZANAN AYAKTAN KAÇ", "stop_go":"DUR–KALK · RAKİBİN HIZINI KULLAN", "knock_around":"AÇ VE DOLAŞ · TOPA YETİŞ"}.get(kind,NAMES[kind]))
	return true

func update(delta: float) -> void:
	if game.state!="playing": reset(); return
	notice_time=maxf(0,notice_time-delta)
	for i in active.keys():
		var p=game.players[i]
		var s: Dictionary=active[i]
		s.age+=delta
		var reach := 5.5 if s.kind=="knock_around" else (2.6 if s.kind=="rainbow" or s.kind=="flick" else 1.8)
		var lost: bool=(game.dribbler>=0 and game.dribbler!=i) or (game.carrier>=0 and game.carrier!=i)
		if lost or not p.visible or p.dismissed or p.action_timer>0 or game.ball.held_by!=null or game.flat_distance(p.position,game.ball.position)>reach or (game.last_kicker!=i and game.last_touch!=p.team):
			if s.kind in Ground.KINDS: explain(i,"TOP AÇILDI · YENİDEN KAZAN")
			cancel(i); continue
		if s.kind in Ground.KINDS and s.contacts==0 and s.age>Ground.CONTACT_END:
			explain(i,"TOPA UZAK KALDIN"); cancel(i); continue
		if s.age>=s.duration:
			var ground_move: bool=not s.lifted
			cancel(i)
			# The last skill touch hands a low ball directly to normal control;
			# a leftover grace timer must not leave it rolling free for .12 s.
			if ground_move and game.ball.position.y<.6 and game.flat_distance(p.position,game.ball.position)<1.3:
				p.ball_actions.control_grace=0
				p.dribble_motion.contacts+=1
				p.dribble_motion.previous_direction=p.facing
			continue
		if s.kind in Ground.KINDS:
			Ground.steer(game,p,s)
			continue
		var t: float=s.age/s.duration
		var forward: Vector3=s.direction
		var right := forward.cross(Vector3.UP)*float(s.side)
		var offset := forward*.52
		match s.kind:
			"roll": offset+=right*lerpf(-.18,.62,smoothstep(0,1,t))
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
			velocity.y=2.6; impulse=game.ball.mass*4.8; s.lifted=true
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
		# The planted foot and body follow the ball's exit. This is ordinary
		# movement through the shared acceleration/collision solver, not a dash.
		var exit := exit_direction(s.kind,forward,float(s.side))
		var blend := smoothstep(.12,.65,t)
		if s.kind in ["roll","roulette","elastico","scoop"]:
			var step := forward*.20+right*.12
			if s.kind=="roulette": step=right*.42+forward*.12
			if s.kind=="elastico": blend=smoothstep(.38,.82,t); step=forward*.32+right*.22
			var technique: float=clampf((float(p.attributes.control)-50)/45,0,1)
			var pace: float=lerpf(.68,.88,technique)*lerpf(.8,1.0,p.energy)
			p.desired=p.desired*.25+step.lerp(exit*pace,blend)*.75
			p.protecting=false
		else: p.desired*=.72 if s.kind=="rainbow" else .88
		p.sprinting=false

func resolve() -> void:
	for index in active.keys():
		var s: Dictionary=active[index]
		if s.kind in Ground.KINDS: Ground.resolve(game,index,s)

static func exit_direction(kind: String,forward: Vector3,side: float) -> Vector3:
	var right := forward.cross(Vector3.UP)*side
	match kind:
		"knock_around": return (forward*.65-right*.8).normalized()
		"stop_go": return forward
		"roll": return (forward*.45+right*.9).normalized()
		"roulette": return (forward*.8+right*.65).normalized()
		"elastico": return (forward*.65-right*.9).normalized()
		"scoop": return forward.rotated(Vector3.UP,-side*PI*.44)
	return forward

static func pose(p) -> void:
	if p.skill_move.is_empty() or p.action_timer>0: return
	var s: Dictionary=p.skill_move
	if s.kind in Ground.KINDS:
		Ground.pose(p,s); return
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
