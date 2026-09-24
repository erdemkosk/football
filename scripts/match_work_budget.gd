extends RefCounted
## Only routine, distant positioning is sampled. Bodies and contacts keep 120 Hz.
var game
var enabled := true
var entries: Dictionary = {}
const ACTIVE_ROLES := ["press","press_support","contain","track","recover","give_go","one_two","overlap","channel_run"]

func reset() -> void:
	entries.clear()

func decision_delta(index: int,delta: float,nearest: Array) -> float:
	var p=game.players[index]
	var distance: float=p.position.distance_squared_to(game.ball.position)
	# Most calls are near the ball: settle those before the role/pose checks.
	if not enabled or game.training or p.keeper or game.is_user_player(index) or distance<18.0*18.0:
		return urgent_delta(index,delta)
	var role: String=game.team_tactics.roles.get(index,game.support.roles.get(index,""))
	var urgent: bool=not p.can_defer_running_pose()
	urgent=urgent or index in nearest or index in game.ai_receivers or index in game.team_tactics.pressers or game.second_balls.targets.has(index) or role in ACTIVE_ROLES
	if not urgent and game.support.targets.has(index):
		urgent=absf(p.position.z-game.rules.offside_line(p.team)*game.attack_sign(p.team))<3.0
	if urgent: return urgent_delta(index,delta)
	var signature: Array=[game.dribbler,game.carrier,game.last_touch,role,game.team_tactics.plan_for(p.team),game.support.plan_settings]
	var entry: Dictionary=entries.get(index,{})
	var target: Vector3=game.team_tactics.targets.get(index,game.support.targets.get(index,p.home))
	if entry.is_empty():
		entries[index]={"elapsed":0.0,"due":.025+float(index%6)/120.0,"signature":signature,"target":target,"position":p.position}
		return delta
	entry.elapsed+=delta
	entry.due-=delta
	if entry.due>0 and entry.signature==signature and target.distance_squared_to(entry.target)<4.0 and p.position.distance_squared_to(entry.position)<9.0:
		return 0.0
	var elapsed: float=entry.elapsed
	entry.elapsed=0.0
	entry.due=1.0/20.0 if distance<32.0*32.0 else 1.0/12.0
	entry.signature=signature; entry.target=target; entry.position=p.position
	return elapsed

func urgent_delta(index: int,delta: float) -> float:
	# Hand any time banked while sampled back to the first full-rate decision.
	if not entries.has(index): return delta
	var elapsed: float=entries[index].elapsed
	entries.erase(index)
	return delta+elapsed
