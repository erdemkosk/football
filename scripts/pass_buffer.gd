extends RefCounted
## Remember a short, intentional input window for the incoming receiver only.
const WINDOW := .30
var game
var pending: Dictionary = {}

func reset(reason: String="cancelled") -> void:
	if not pending.is_empty(): game.playtest.event("pass_buffer_"+reason,pending.player,{"remaining":pending.remaining})
	pending.clear()

func queue(through: bool,lob: bool,driven: bool) -> bool:
	var index: int=game.controlled
	var p=game.players[index]
	if game.ball.held_by!=null or game.ball.pending_reset or game.dribbler>=0 or game.last_touch!=p.team or game.last_kicker==index: return false
	if not p.visible or p.dismissed or p.action_timer>0 or p.dummy_time>0: return false
	var offset: Vector3=(game.ball.position-p.position)*Vector3(1,0,1)
	var relative: Vector3=(game.ball.linear_velocity-p.velocity)*Vector3(1,0,1)
	var meeting := -offset.dot(relative)/maxf(.01,relative.length_squared())
	var approaching := meeting>0 and meeting<=WINDOW+.1 and (offset+relative*meeting).length()<1.5
	if not game.team_control.awaiting_delivery() and not approaching: return false
	var direction: Vector3=game.pass_heading()
	game.cancel_pass()
	game.charging=false; game.charge=0
	game.requested_receiver=-1; game.request_time=0; p.call_timer=0
	pending={"player":index,"remaining":WINDOW,"direction":direction,"through":through,"lob":lob,"driven":driven,"power":0.0,"released":not through and not lob}
	game.playtest.event("pass_buffer_queued",index,{"through":through,"lob":lob,"driven":driven})
	return true

func release(through: bool) -> void:
	if not pending.is_empty() and pending.through==through:
		pending.released=true

func valid() -> bool:
	if pending.is_empty(): return false
	var p=game.players[pending.player]
	return game.state=="playing" and not game.menu_match.running and game.controlled==pending.player and p.visible and not p.dismissed and p.action_timer<=0 and p.dummy_time<=0 and game.last_touch==p.team and game.ball.held_by==null and not game.ball.pending_reset and (game.dribbler<0 or game.dribbler==pending.player)

func update(delta: float) -> void:
	if pending.is_empty(): return
	if not valid(): reset(); return
	pending.remaining-=delta
	if pending.remaining<=0: reset("expired"); return
	if not pending.released:
		pending.power=minf(1,pending.power+delta/game.pass_charge_time(pending.through))
		var direction: Vector3=game.aiming_input()
		if direction.length()>.1: pending.direction=direction.normalized()
	try_execute()

func try_execute() -> void:
	if pending.is_empty(): return
	if not valid(): reset(); return
	if game.dribbler!=pending.player or not game.has_ball_control(pending.player) or game.ball.position.y>1.05 or game.kick_lock>0: return
	if not game.kick_contact.pending.is_empty(): return
	var command := pending.duplicate()
	reset("consumed")
	if not command.through and not command.lob:
		game.quick_pass(command.direction,command.driven)
	else:
		game.begin_pass(command.through,command.lob,command.driven)
		if not game.pass_charging: return
		game.pass_power=command.power
		game.pass_direction=command.direction
		game.update_pass_preview()
		if command.released: game.release_pass()
