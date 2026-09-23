extends RefCounted
const LABELS := {"low":"ALÇAK SERT ŞUT","power":"POWER SHOT","outside":"DIŞ AYAK","timed":"ZAMANLAMALI ŞUT"}
var game
var style := ""
var timed_armed := false
var pending: Dictionary = {}
var result := ""
var result_time := 0.0

func reset() -> void:
	clear_pending()
	style=""; timed_armed=false; result=""; result_time=0

func clear_pending() -> void:
	if not pending.is_empty(): game.players[pending.index].dribble_motion.release_collision()
	pending.clear()

func active(index: int) -> bool:
	return not pending.is_empty() and pending.index==index

func timing_press() -> void:
	if pending.is_empty() or pending.tapped: return
	pending.tapped=true
	var error: float=pending.contact-pending.age
	if error>=.005 and error<=.075:
		pending.quality=1.08; result="MÜKEMMEL ZAMANLAMA"
	else:
		pending.quality=.76; result="ERKEN VURUŞ"
	result_time=1.6

func velocity(index: int,aim: Vector3,power: float,kind: String,quality: float=1) -> Vector3:
	var p=game.players[index]
	var ability: float=p.Attributes.kick_factor(p,game.ball.position)
	var speed := lerpf(19,32,power)
	var lift := lerpf(1.6,5.1,power)
	match kind:
		"low": speed=lerpf(23,33,power); lift=lerpf(.32,.75,power)
		"power": speed=lerpf(33,45,power); lift=lerpf(1.5,4.2,power)
		"outside": speed=lerpf(19,30,power); lift=lerpf(1.2,3.2,power)
		"punt": speed=lerpf(24,36,power); lift=lerpf(7,10,power)
	var direction := aim
	if quality<.9: direction=direction.rotated(Vector3.UP,.055*(-1 if p.ball_actions.foot==0 else 1))
	return direction*speed*ability*quality+Vector3.UP*(lift+(1-minf(quality,1))*2.2)

func curve(index: int,kind: String) -> float:
	return (-1.0 if game.players[index].ball_actions.foot==0 else 1.0)*3.4 if kind=="outside" else 0.0

func release_charged(index: int,aim: Vector3,power: float) -> bool:
	if not pending.is_empty() or not game.can_release_ground_shot(index) or style not in ["low","power","outside"]: return false
	var kind := style
	var p=game.players[index]
	p.ball_actions.foot=p.ball_actions.choose_foot(p,game.ball.position)
	var contact := .39 if kind=="power" else .22
	if not game.commit_strike(index,velocity(index,aim,power,kind),curve(index,kind),false,"finish"): return false
	p.volley_motion.begin(p,{"point":game.ball.position,"time":contact,"kind":kind},aim)
	p.volley_motion.contact_time=contact
	p.volley_motion.duration=contact+(.42 if kind=="power" else .33)
	p.pose="finish"
	p.action_timer=p.volley_motion.duration
	p.volley_motion.hit=true
	p.volley_motion.apply(p)
	p.recovery_delay=maxf(p.recovery_delay,contact+(.58 if kind=="power" else .5))
	game.skills.active.erase(index); p.skill_move.clear()
	game.shots[p.team]+=1
	game.hint(LABELS[kind])
	style=""; timed_armed=false
	return true

func queue(index: int,aim: Vector3,power: float,kind: String="") -> bool:
	if not pending.is_empty(): return false
	if kind=="": kind=style
	if kind=="" or game.players[index].action_timer>0: return false
	var p=game.players[index]
	var controlled_ball: bool=game.dribbler==index and game.flat_distance(p.position,game.ball.position)<1.3 and game.ball.position.y<.6
	var contact := .39 if kind=="power" else .22
	p.volley_motion.begin(p,{"point":game.ball.position,"time":contact,"kind":kind},aim)
	p.volley_motion.contact_time=contact
	p.volley_motion.duration=contact+(.42 if kind=="power" else .33)
	p.pose="finish"
	p.action_timer=p.volley_motion.duration
	p.recovery_delay=maxf(p.recovery_delay,contact+(.58 if kind=="power" else .5))
	pending={"index":index,"aim":aim,"power":power,"kind":kind,"age":0.0,"contact":contact,"quality":1.0,"tapped":false,"ball":game.ball.position,"boot":p.volley_motion.boot(p),"last_touch":game.last_kicker}
	if controlled_ball: p.dribble_motion.begin_preparation(p,game.ball)
	style=""; timed_armed=false
	game.dribbler=-1
	return true

func prepare(delta: float) -> void:
	result_time=maxf(0,result_time-delta)
	if game.state!="playing": reset(); return
	if pending.is_empty(): return
	var p=game.players[pending.index]
	pending.age+=delta
	if not p.visible or p.dismissed or p.pose!="finish" or p.action_timer<=0 or pending.age>pending.contact+.14 or (p.team==0 and not game.menu_match.running and game.controlled!=pending.index) or game.ball.held_by!=null or game.last_kicker!=pending.last_touch or (game.dribbler>=0 and game.dribbler!=pending.index):
		clear_pending(); return
	p.desired*=.28 if pending.kind=="power" else .6
	p.sprinting=false
	if not p.dribble_motion.settle_preparation(p,game.ball,delta): clear_pending(); return
	p.volley_motion.target=game.ball.position

func resolve() -> void:
	if pending.is_empty() or game.ball.pending_kick or game.ball.held_by!=null: return
	var p=game.players[pending.index]
	var boot: Vector3=p.volley_motion.boot(p)
	var from: Vector3=pending.ball-pending.boot
	var to: Vector3=game.ball.position-boot
	var gap := Geometry3D.get_closest_point_to_segment(Vector3.ZERO,from,to).length()
	pending.ball=game.ball.position; pending.boot=boot
	if pending.age<pending.contact or gap>.40: return
	var shot := pending.duplicate()
	clear_pending()
	var output := velocity(shot.index,shot.aim,shot.power,shot.kind,shot.quality)
	if shot.kind=="punt" and shot.has("ai_delivery"):
		var route: Dictionary=shot.ai_delivery.route
		output=game.Passing.Motion.lob_velocity(game.ball.position,route.target,route.flight,game.weather)
	if game.strike(shot.index,output,curve(shot.index,shot.kind),false,"punt" if shot.kind=="punt" else "finish"):
		p.volley_motion.hit=true; p.volley_motion.target=game.ball.position
		if shot.kind=="punt":
			game.passes[p.team]+=1
			if shot.has("ai_delivery"):
				game.ai_receivers[p.team]=shot.ai_delivery.receiver
				game.ai_pass_time[p.team]=float(shot.ai_delivery.route.flight)+2.5
				game.ai_attack.record("keeper_punt")
		else: game.shots[p.team]+=1
		game.hint(LABELS.get(shot.kind,"AYAKTAN AÇIŞ")+(" · "+result if shot.tapped else ""))

func draw(hud) -> void:
	if pending.is_empty(): return
	var at: Vector2=game.screen_position(game.players[game.controlled].position)+Vector2(-36,25)
	if not pending.is_empty():
		var progress: float=clampf(pending.age/pending.contact,0,1)
		hud.panel(Rect2(at,Vector2(72,7)),Color("173139"),3)
		hud.panel(Rect2(at+Vector2(72*(1-.075/pending.contact),0),Vector2(72*.07/pending.contact,7)),Color("7cdd96"),2)
		hud.draw_line(at+Vector2(72*progress,-3),at+Vector2(72*progress,10),hud.PAPER,2)
