extends RefCounted
var game
var pending: Dictionary = {}

func reset() -> void:
	for p in game.players: p.distribution_move.clear()
	pending.clear()

func active(index: int) -> bool:
	return not pending.is_empty() and pending.index==index

func launch_velocity(kind: String,aim: Vector3,power: float) -> Vector3:
	return aim*lerpf(15,25,power)+Vector3.UP*lerpf(3,5,power) if kind=="throw" else aim*lerpf(8,17,power)+Vector3.DOWN*.65

func queue(index: int,kind: String,aim: Vector3,power: float,planned_velocity: Vector3=Vector3.ZERO) -> bool:
	var p=game.players[index]
	if game.ball.held_by!=p or not pending.is_empty(): return false
	if game.is_user_player(index): game.cancel_pass(); game.charging=false; game.charge=0
	pending={"index":index,"kind":kind,"aim":aim.normalized(),"power":power,"age":0.0,"released":false}
	if planned_velocity!=Vector3.ZERO: pending.velocity=planned_velocity
	p.distribution_move=pending
	# A deliberate distribution (including the punt's drop) is not a loose
	# rebound from the preceding save, and must never be scooped back up.
	p.keeper_motion.saved_at=-10; p.keeper_motion.secured=false
	p.facing=aim.normalized(); p.set_piece_pose=""; p.receive_timer=0
	return true

func drop(index: int) -> bool:
	var p=game.players[index]
	if game.ball.held_by!=p or not pending.is_empty(): return false
	game.ball.release_hold()
	game.ball.linear_velocity=p.velocity+Vector3.DOWN*.65+p.facing*.7
	game.goalkeeping.holding=-1; game.goalkeeping.hold_age=0
	p.keeper_motion.saved_at=-10; p.keeper_motion.secured=false
	p.set_piece_pose=""; p.touch_cooldown=.35
	game.dribbler=-1; game.last_touch=p.team; game.last_kicker=index
	game.announce("TOPU YERE BIRAKTI")
	return true

func update(delta: float) -> void:
	if game.state!="playing": reset(); return
	if pending.is_empty(): return
	var p=game.players[pending.index]
	pending.age+=delta
	if not p.visible or p.dismissed or (not pending.released and game.ball.held_by!=p): reset(); return
	p.desired*=.35; p.facing=pending.aim; p.set_piece_pose=""
	if pending.age>.68:
		p.distribution_move.clear(); pending.clear()

func resolve() -> void:
	if pending.is_empty() or pending.released: return
	var p=game.players[pending.index]
	game.ball.hold_target=p.right_hand.global_position if pending.kind=="throw" else p.hand_center()
	var release_at := .34 if pending.kind=="throw" else .25
	if pending.age<release_at: return
	var aim: Vector3=pending.aim
	var power: float=pending.power
	pending.released=true
	if pending.kind=="punt":
		game.ball.release_hold(); game.ball.linear_velocity=p.velocity+aim*.6+Vector3.DOWN*1.8
		game.goalkeeping.holding=-1; p.set_piece_pose=""
		var finisher=game.ai_attack.finishing if p.team==1 else game.finishing
		finisher.game=game
		finisher.queue(pending.index,aim,power,"punt")
		p.distribution_move.clear(); pending.clear()
		return
	var velocity: Vector3=pending.get("velocity",launch_velocity(pending.kind,aim,power))
	if game.strike(pending.index,velocity,0,false,"distribution"):
		game.passes[p.team]+=1
		game.announce("UZUN EL ATIŞI" if pending.kind=="throw" else "ELLE YERDEN DAĞITIM")

static func pose(p) -> void:
	if p.distribution_move.is_empty(): return
	var s: Dictionary=p.distribution_move
	var t: float=clampf(s.age/.34,0,1)
	var recover := smoothstep(.4,.68,s.age)
	var blend := smoothstep(0,.08,s.age)*(1-recover)
	var throw_over: bool=s.kind=="throw"
	var arm := Vector3(lerpf(2.55,.95,t),.1,.20) if throw_over else Vector3(lerpf(.40,1.0,t),0,.12)
	p.right_arm.rotation=p.right_arm.rotation.lerp(arm,blend)
	p.right_elbow.rotation.x=lerpf(p.right_elbow.rotation.x,lerpf(.9,.1,t),blend)
	p.left_arm.rotation=p.left_arm.rotation.lerp(Vector3(.6,0,-.3),blend)
	p.spine.rotation.x=lerpf(p.spine.rotation.x,-.12 if throw_over else -.38,blend)
	if not throw_over: p.rig.position.y-=.22*blend
