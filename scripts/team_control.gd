extends RefCounted
## One active footballer, the whole team available; manual choices get priority.
var game
var cooldown := 0.0
var manual_hold := 0.0
var run_receiver := -1
var run_target := Vector3.ZERO

func reset() -> void:
	cooldown=0
	manual_hold=0
	run_receiver=-1

func follow_pass(receiver: int,route: Dictionary) -> void:
	run_receiver=receiver if route.get("through",false) else -1
	run_target=route.target

func select(index: int,manual: bool=false) -> void:
	if game.menu_match.running: return
	if index<0 or index>=game.players.size(): return
	var p=game.players[index]
	if not p.visible or p.dismissed or p.team!=0: return
	if game.controlled!=index:
		game.heading.cancel(game.controlled)
		game.players[game.controlled].shot_preparation=0
		game.controlled=index
		game.charging=false; game.charge=0; game.cancel_pass()
		var direction: Vector3=game.movement_input()
		game.last_direction=direction.normalized() if direction.length()>0.1 else p.facing
		for i in range(game.players.size()): game.players[i].chosen=i==index
	cooldown=0.75
	if manual: manual_hold=1.4

func update(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	manual_hold=maxf(0,manual_hold-delta)
	if game.training or game.player_lock or game.state!="playing": return
	var current=game.players[game.controlled]
	if game.ball.held_by==game.players[0] and game.requested_receiver<0:
		if game.controlled!=0 and manual_hold<=0: select(0)
		return
	if current.visible and not current.dismissed and manual_hold>0: return
	# Stay on the passer while our ball is still travelling. Switching is LB, not the kick.
	var flight: float=game.ball.kick_velocity.length() if game.ball.pending_kick else game.ball.linear_velocity.length()
	if game.last_touch==0 and game.ai_pass_time[0]>0 and game.dribbler<0 and game.ball.held_by==null and flight>5:
		return
	var owner: int=game.dribbler
	if owner<0 and game.ball.linear_velocity.length()<16: owner=game.nearest_to_ball(1.12)
	if owner>=0:
		var p=game.players[owner]
		if p.team==0 and (not p.keeper or game.last_touch==0 or game.dribbler==owner) and p.visible and p.action_timer<=0 and p.touch_cooldown<=0:
			if owner!=game.controlled and game.requested_receiver<0: select(owner)
			return
	if game.charging or game.pass_charging or game.heading.active(game.controlled) or game.requested_receiver>=0: return
	if current.visible and not current.dismissed and (cooldown>0 or manual_hold>0 or current.action_timer>0): return
	var threat: Vector3=game.ball.position+game.ball.linear_velocity.limit_length(20)*0.3
	if game.ball.held_by!=null: return
	var best := -1
	var best_cost := INF
	for i in range(1,11):
		var p=game.players[i]
		if not p.visible or p.dismissed or p.action_timer>0: continue
		var cost: float=game.flat_distance(p.position,threat)+(1-p.energy)*1.5
		if cost<best_cost: best_cost=cost; best=i
	var current_distance: float=game.flat_distance(current.position,threat)
	# A substantial advantage avoids the cursor hopping between nearby defenders.
	if best>=0 and best!=game.controlled and (not current.visible or current.dismissed or (current_distance>8 and best_cost+5<current_distance)):
		select(best)

func reception_direction() -> Vector3:
	if game.player_lock or game.pass_assistance==0 or game.ai_receivers[0]!=game.controlled or game.ai_pass_time[0]<=0 or game.last_touch!=0 or game.dribbler>=0: return Vector3.ZERO
	var p=game.players[game.controlled]
	if p.action_timer>0 or game.ball.held_by!=null: return Vector3.ZERO
	var distance: float=game.flat_distance(p.position,game.ball.position)
	var velocity: Vector3=game.ball.kick_velocity if game.ball.pending_kick else game.ball.linear_velocity
	var target: Vector3=game.ball.position+velocity*clampf(distance/14,0.08,0.65)
	# A through-ball recipient keeps the run into space instead of checking back.
	if run_receiver==game.controlled and velocity.dot(run_target-game.ball.position)>0 and distance>1.1:
		target=run_target
	target.x=clampf(target.x,-30,30); target.z=clampf(target.z,-48,48)
	var offset: Vector3=(target-p.position)*Vector3(1,0,1)
	return offset.normalized()*clampf(offset.length()/1.4,0,1)
