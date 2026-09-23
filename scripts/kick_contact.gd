extends RefCounted
## Ordinary kicks have a short, interruptible approach. The rigid ball remains
## live, and every audible/physical result is committed at the boot contact.
const RADIUS := 0.36
var game
var pending: Dictionary = {}
var last_gap := INF
var contacts := 0
var misses := 0

func reset() -> void:
	if not pending.is_empty():
		game.players[pending.index].ball_actions.contact_pending=false
		game.players[pending.index].dribble_motion.release_collision()
	pending.clear()

func queue(index: int,velocity: Vector3,curve: float,kind: String) -> bool:
	if not pending.is_empty(): return false
	var p=game.players[index]
	if not p.visible or p.dismissed or p.action_timer>0 or game.ball.held_by!=null: return false
	var controlled_ball: bool=kind=="shot" and game.dribbler==index and game.flat_distance(p.position,game.ball.position)<1.3 and game.ball.position.y<.6
	var power := clampf((velocity.length()-12)/20,.15,1)
	var style := "chip" if velocity.y>5.2 else ("inside" if kind!="shot" and velocity.length()<16 else "laces")
	p.begin_kick(power,.46 if kind=="shot" else .32,style,game.ball.position,velocity,game.first_touch.pressure(index))
	game.skills.active.erase(index); p.skill_move.clear()
	var windup: float=lerpf(.065,.045,clampf((float(p.attributes.control)-50)/45,0,1))
	p.ball_actions.start_contact(p,game.ball.position,windup)
	pending={"index":index,"velocity":velocity,"curve":curve,"kind":kind,"age":0.0,"windup":windup,"last_touch":game.last_kicker}
	p.facing=(velocity*Vector3(1,0,1)).normalized()
	p.dribble_motion.reset()
	if controlled_ball: p.dribble_motion.begin_preparation(p,game.ball)
	game.dribbler=-1
	return true

func prepare(delta: float) -> void:
	if pending.is_empty(): return
	var p=game.players[pending.index]
	if game.state!="playing" or not p.visible or p.dismissed or p.action_timer>0 or p.kick_timer<=0 or game.ball.held_by!=null or game.last_kicker!=pending.last_touch:
		reset(); return
	pending.age+=delta
	p.ball_actions.contact_age=pending.age
	p.ball_actions.contact_target=game.ball.position
	if not p.dribble_motion.settle_preparation(p,game.ball,delta): reset()

func resolve() -> void:
	if pending.is_empty(): return
	var p=game.players[pending.index]
	if p.action_timer>0 or game.last_kicker!=pending.last_touch or game.ball.held_by!=null:
		reset(); return
	var boot: Node3D=p.left_knee if p.ball_actions.foot==0 else p.right_knee
	last_gap=boot.to_global(p.ball_actions.BOOT).distance_to(game.ball.position)
	if pending.age>=pending.windup and last_gap<=RADIUS and not game.ball.pending_kick:
		var request := pending.duplicate()
		if request.has("ai_choice") and request.ai_choice.has("route") and request.ai_choice.kind!="clearance":
			if not game.ai_attack.delivery.safe(request.index,request.ai_choice.route,request.ai_choice.receiver):
				# The lane closed during the approach. Keep the reachable ball and
				# reconsider instead of knowingly completing a pass to the opponent.
				p.ball_actions.finish_contact(p); p.kick_timer=0
				reset()
				game.dribbler=request.index; game.carrier=request.index
				game.ai_attack.think_in[request.index]=.18
				return
		p.ball_actions.finish_contact(p)
		p.dribble_motion.release_collision()
		pending.clear()
		if game.commit_strike(request.index,request.velocity,request.curve,false,request.kind,true):
			contacts+=1
			if request.has("ai_choice"): game.ai_attack.kick_completed(request.index,request.ai_choice)
	elif pending.age>.16:
		# A late tackle or a ball rolling out of reach is a real missed swing.
		misses+=1
		p.ball_actions.finish_contact(p)
		p.dribble_motion.release_collision()
		pending.clear()
