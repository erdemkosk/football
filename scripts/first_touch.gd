extends RefCounted
var game

func pressure(index: int) -> float:
	var p=game.players[index]
	var nearest := 3.0
	for q in game.players:
		if q.visible and q.team!=p.team: nearest=minf(nearest,game.flat_distance(p.position,q.position))
	return 1-smoothstep(0.6,2.7,nearest)

func airborne() -> bool:
	var ball=game.ball
	if ball.position.y<0.7 or ball.position.y>2.15 or ball.pending_kick or ball.held_by!=null or game.kick_lock>0: return false
	var best := -1
	var gap := 0.88
	for i in range(game.players.size()):
		var p=game.players[i]
		if game.heading.active(i): continue
		if not p.visible or p.keeper or p.action_timer>0 or p.kick_timer>0 or p.touch_cooldown>0 or p.ball_actions.contact_cooldown>0: continue
		var offset: Vector3=(ball.position-p.position)*Vector3(1,0,1)
		if offset.length()>gap or ball.position.y>p.body_scale.y*1.75: continue
		if offset.length()>0.2 and offset.normalized().dot(p.facing)<-0.35: continue
		var relative: Vector3=ball.linear_velocity-p.velocity
		# Rising shots, departing passes and balls flying overhead are not traps.
		if relative.y>2.5 or relative.length()>22 or offset.dot(relative)>0.25: continue
		gap=offset.length(); best=i
	if best<0: return false
	if not game.rules.before_touch(best): return true
	receive(best,false)
	return true

func receive(index: int,extended: bool) -> bool:
	var p=game.players[index]
	var ball=game.ball
	var relative: Vector3=ball.linear_velocity-p.velocity
	var speed := relative.length()
	var height: float=(ball.position.y-p.position.y)/p.body_scale.y
	var style := "chest" if height>1.05 else ("thigh" if height>0.58 else "foot")
	var distance: float=game.flat_distance(p.position,ball.position)
	var reach := smoothstep(0.91,1.34,distance) if style=="foot" else 0.0
	var difficulty := clampf(reach*0.55+pressure(index)*0.22+(1-p.energy)*0.20+maxf(0,speed-12)*0.023,0,1)
	var stability: float=p.Attributes.multiplier(p.attributes.balance,.2)
	difficulty=clampf(difficulty+(72-float(p.attributes.control))*.003+p.contest_weight*.16/stability,0,1)
	var spill := extended or difficulty>0.68
	p.begin_receive(style,ball.position,relative,reach)
	p.ball_actions.control_grace=0.16 if style=="foot" else 0.25
	p.ball_actions.contact_cooldown=0.32 if spill else 0.25
	# One bounded impulse cushions the real rigid body. Hard, stretched touches
	# retain more incoming momentum; no transform snap or guaranteed possession.
	var retain := lerpf(0.12,0.42,difficulty)
	if spill: retain=maxf(retain,0.48)
	var output: Vector3=p.velocity*Vector3(1,0,1)+relative*retain
	if p.desired.length()>0.2: output+=p.desired.normalized()*lerpf(0.55,1.25,difficulty)
	if spill:
		var side := -1.0 if p.ball_actions.receive_foot==0 else 1.0
		output+=p.rig.global_basis.x.normalized()*side*(0.8+difficulty*1.2)
	if style!="foot": output.y=minf(-0.55,relative.y*0.3)
	else: output.y=maxf(0,ball.linear_velocity.y)*0.3
	ball.touch(output,ball.mass*minf(17.0,maxf(2.5,speed*(0.85 if not spill else 0.55))))
	game.reactions.received(index)
	game.last_touch=p.team
	game.last_kicker=index
	if spill: p.touch_cooldown=maxf(p.touch_cooldown,0.25)
	return not spill and style=="foot"
