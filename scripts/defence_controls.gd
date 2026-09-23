extends RefCounted
var game
var pressing := false
var presser := -1
var press_age := 0.0
var rest := 0.0
var intercepts: Dictionary = {}

func reset() -> void:
	pressing=false; presser=-1; press_age=0; rest=0; intercepts.clear()

func directional_choice(direction: Vector3) -> int:
	var origin: Vector3=game.players[game.controlled].position
	var best := -1
	var score := INF
	for i in range(11):
		var p=game.players[i]
		if i==game.controlled or not p.visible or p.dismissed or p.action_timer>0: continue
		var offset: Vector3=(p.position-origin)*Vector3(1,0,1)
		if offset.length()<.5: continue
		var dot := offset.normalized().dot(direction.normalized())
		if dot<.40: continue
		var cost := (1-dot)*36+offset.length()*.12
		if cost<score: score=cost; best=i
	return best

func switch_direction(direction: Vector3) -> void:
	var index := directional_choice(direction)
	if index>=0: game.clear_pass_request(); game.team_control.select(index,true)

func update(delta: float) -> void:
	if game.state!="playing": reset(); return
	rest=maxf(0,rest-delta)
	if not pressing or game.last_touch==0 or game.ball.held_by!=null or rest>0:
		presser=-1; press_age=0; return
	press_age+=delta
	if press_age>4.0:
		rest=1.6; presser=-1; press_age=0; return
	if presser<0 or presser==game.controlled or not game.players[presser].visible or game.players[presser].energy<.12 or game.players[presser].action_timer>0:
		presser=-1
		var best := 22.0
		for i in range(1,11):
			var p=game.players[i]
			if i==game.controlled or not p.visible or p.dismissed or p.energy<.18 or p.action_timer>0: continue
			var gap: float=game.flat_distance(p.position,game.ball.position)
			if gap<best: best=gap; presser=i
	if presser<0: return
	var p=game.players[presser]
	var target: Vector3=game.ball.position+game.ball.linear_velocity.limit_length(9)*.16
	var gap: Vector3=(target-p.position)*Vector3(1,0,1)
	p.desired=gap.normalized()*clampf((gap.length()-.65)/1.2,0,1)
	p.sprinting=gap.length()>2.5
	p.jockeying=gap.length()<2.3
	if gap.length()>.1: p.facing=gap.normalized()
	p.energy=maxf(0,p.energy-delta*.023)
	p.recovery_delay=maxf(p.recovery_delay,.4)

func shoulder(index: int) -> bool:
	var p=game.players[index]
	if p.action_timer>0 or p.tackle_cooldown>0 or p.keeper: return false
	var victim := -1
	var nearest := 1.2
	for i in range(game.players.size()):
		var q=game.players[i]
		if not q.visible or q.team==p.team or q.keeper: continue
		var gap: float=game.flat_distance(p.position,q.position)
		if gap<nearest: nearest=gap; victim=i
	if victim<0: return false
	var q=game.players[victim]
	var direction: Vector3=((q.position-p.position)*Vector3(1,0,1)).normalized()
	var late: bool=game.flat_distance(q.position,game.ball.position)>2.4
	var behind: bool=(-direction).dot(q.facing)<-.5
	p.tackle_cooldown=.85; p.energy=maxf(0,p.energy-.028)
	if behind or late:
		game.tackle_impact(index,victim)
		if not game.training: game.rules.foul(index,victim,false)
	else:
		p.velocity-=direction*.6
		q.velocity+=direction*clampf(float(p.weight_kg)/q.weight_kg,.75,1.3)*1.6
		p.contest_direction=direction; q.contest_direction=-direction
		p.contest_weight=1; q.contest_weight=1
		q.body_language.contact(q,direction,.38)
		game.feedback.contact("body_hit",index,q.position,direction,.32,victim)
	return true

func intercept(index: int) -> bool:
	var p=game.players[index]
	if p.action_timer>0 or p.tackle_cooldown>0 or game.dribbler==index or p.keeper: return false
	var aim: Vector3=((game.ball.position-p.position)*Vector3(1,0,1)).normalized()
	var point: Vector3=game.ball.position+game.ball.linear_velocity*.14
	point=p.position+(point-p.position).limit_length(1.0); point.y=clampf(point.y,game.ball.RADIUS,.65)
	p.volley_motion.begin(p,{"point":point,"time":.14,"kind":"intercept"},aim)
	p.pose="intercept"; p.tackle_cooldown=.65
	intercepts[index]={"ball":game.ball.position,"boot":p.volley_motion.boot(p)}
	return true

func resolve() -> void:
	for i in intercepts.keys():
		var p=game.players[i]
		if game.state!="playing" or p.pose!="intercept" or p.action_timer<=0: intercepts.erase(i); continue
		var old: Dictionary=intercepts[i]
		var boot: Vector3=p.volley_motion.boot(p)
		var from: Vector3=old.ball-old.boot
		var to: Vector3=game.ball.position-boot
		var nearest := Geometry3D.get_closest_point_to_segment(Vector3.ZERO,from,to).length()
		old.ball=game.ball.position; old.boot=boot
		var age: float=p.volley_motion.duration-p.action_timer
		if age<.07 or age>.30 or nearest>.38 or game.ball.position.y>.85 or game.ball.held_by!=null or game.ball.pending_kick: continue
		intercepts.erase(i)
		if not game.rules.before_touch(i): continue
		var incoming: Vector3=game.ball.linear_velocity
		game.ball.touch(incoming*.18+p.desired*1.8,game.ball.mass*22)
		game.last_touch=p.team; game.last_kicker=i; game.dribbler=-1
		game.team_control.touched(i)
		p.touch_cooldown=.18; p.volley_motion.hit=true
		game.hint("PAS ARASI")
